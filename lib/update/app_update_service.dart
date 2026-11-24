import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AppUpdateInfo {
  final int build;
  final String version;
  final String apkUrl;

  const AppUpdateInfo({
    required this.build,
    required this.version,
    required this.apkUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      build: _asInt(json['build']) ?? 0,
      version: (json['version'] ?? '').toString(),
      apkUrl: (json['apk_url'] ?? json['apkUrl'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'build': build,
        'version': version,
        'apk_url': apkUrl,
      };

  bool get isValid => build > 0 && apkUrl.isNotEmpty;

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Push-driven Android update offer. No GitHub polling.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _prefsKey = 'pending_app_update';

  AppUpdateInfo? _available;
  int _localBuild = 0;
  String _localVersion = '';
  bool _ready = false;
  bool _checking = false;
  bool _downloading = false;
  double? _progress;
  String? _error;

  AppUpdateInfo? get available => _available;
  bool get hasUpdate => _available != null;
  bool get downloading => _downloading;
  double? get progress => _progress;
  String? get error => _error;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  int get localBuild => _localBuild;
  String get localVersion => _localVersion;

  /// e.g. `v 1.0.84` for UI.
  String get localLabel {
    if (_localVersion.isEmpty) return '';
    return 'v $_localVersion';
  }

  Future<void> init() async {
    // Always (re)load package info — hot reload can leave _ready=true with empty version.
    final info = await PackageInfo.fromPlatform();
    _localBuild = int.tryParse(info.buildNumber) ?? 0;
    _localVersion = info.version;
    if (!_ready && isAndroid) {
      await _restorePending();
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _restorePending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final info = AppUpdateInfo.fromJson(map);
      if (info.isValid && info.build > _localBuild) {
        _available = info;
      } else {
        await prefs.remove(_prefsKey);
      }
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final info = _available;
    if (info == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(info.toJson()));
    }
  }

  /// Apply remote version from WS / GET. Shows button only if newer than local.
  Future<void> applyRemote(Map<String, dynamic>? raw) async {
    if (!isAndroid || raw == null) return;
    await init();
    final info = AppUpdateInfo.fromJson(raw);
    if (!info.isValid || info.build <= _localBuild) {
      if (_available != null && (_available!.build <= _localBuild)) {
        _available = null;
        await _persist();
        notifyListeners();
      }
      return;
    }
    if (_available?.build == info.build &&
        _available?.apkUrl == info.apkUrl &&
        _available?.version == info.version) {
      return;
    }
    _available = info;
    _error = null;
    await _persist();
    notifyListeners();
  }

  /// One lightweight GET on cold start (login / shell). Not a poll loop.
  Future<void> checkOnce() async {
    if (!isAndroid || _checking) return;
    await init();
    _checking = true;
    try {
      final base = await AppConfig.getBaseUrl();
      final uri = Uri.parse('$base/api/app/version');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        await applyRemote(body);
      }
    } catch (_) {
      // ignore — offline / waking server
    } finally {
      _checking = false;
    }
  }

  Future<void> downloadAndInstall() async {
    if (!isAndroid || _available == null || _downloading) return;
    final info = _available!;
    _downloading = true;
    _progress = 0;
    _error = null;
    notifyListeners();

    try {
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(info.apkUrl));
        final res = await client.send(req).timeout(const Duration(minutes: 5));
        if (res.statusCode != 200) {
          throw Exception('download failed (${res.statusCode})');
        }
        final total = res.contentLength ?? 0;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/bouble-chat-update.apk');
        final sink = file.openWrite();
        var received = 0;
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _progress = received / total;
            notifyListeners();
          }
        }
        await sink.close();

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          _error = result.message.isNotEmpty
              ? result.message
              : 'Не вдалося відкрити інсталятор';
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _error = 'Помилка завантаження';
    } finally {
      _downloading = false;
      _progress = null;
      notifyListeners();
    }
  }
}
