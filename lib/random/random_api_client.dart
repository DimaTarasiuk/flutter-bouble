import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../config.dart';
import 'random_models.dart';
import 'random_session_store.dart';

class RandomApiClient {
  Future<Uri> _uri(String path) async {
    final base = await AppConfig.getBaseUrl();
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _guestHeaders(String? token) async {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _extractError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return 'unknown error (${resp.statusCode})';
  }

  Future<http.Response> _send(
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException(null, 'timeout');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(null, 'network_error', debugDetail: e.toString());
    }
  }

  Future<RandomStartResult> start(RandomPrefs prefs, String anonId) async {
    final resp = await _send(() async {
      return http.post(
        await _uri('/api/random/start'),
        headers: await _guestHeaders(null),
        body: jsonEncode({
          ...prefs.toJson(),
          'anon_id': anonId,
        }),
      );
    });
    if (resp.statusCode == 201) {
      return RandomStartResult.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<RandomSearchResult> search(String token) async {
    final resp = await _send(() async {
      return http.post(
        await _uri('/api/random/search'),
        headers: await _guestHeaders(token),
      );
    });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      RandomSession? session;
      final raw = data['session'];
      if (raw is Map<String, dynamic>) {
        session = RandomSession.fromJson(raw);
      }
      return RandomSearchResult(
        status: data['status'] as String? ?? 'waiting',
        session: session,
      );
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> skip(String token) async {
    final resp = await _send(() async {
      return http.post(
        await _uri('/api/random/skip'),
        headers: await _guestHeaders(token),
      );
    });
    if (resp.statusCode == 200) return;
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<RandomHistory> messages(String token) async {
    final resp = await _send(() async {
      return http.get(
        await _uri('/api/random/messages'),
        headers: await _guestHeaders(token),
      );
    });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['messages'] as List? ?? [])
          .map((e) => RandomMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return RandomHistory(
        session: RandomSession.fromJson(data['session'] as Map<String, dynamic>),
        messages: list,
      );
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<RandomMessage> send(
    String token,
    String text, {
    int? replyTo,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (replyTo != null) body['reply_to'] = replyTo;
    final resp = await _send(() async {
      return http.post(
        await _uri('/api/random/messages'),
        headers: await _guestHeaders(token),
        body: jsonEncode(body),
      );
    });
    if (resp.statusCode == 201) {
      return RandomMessage.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<String?> currentToken() => RandomSessionStore.getToken();
}
