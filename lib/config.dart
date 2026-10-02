import 'package:shared_preferences/shared_preferences.dart';

/// Base URL за замовчуванням. Адресу можна й далі змінити прямо в застосунку
/// (іконка шестерні на екрані входу) — наприклад для локального тесту.
const String kDefaultBaseUrl = 'https://bouble-chat.onrender.com';

const String _prefsKey = 'base_url';

class AppConfig {
  static String? _cached;

  static Future<String> getBaseUrl() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_prefsKey) ?? kDefaultBaseUrl;
    return _cached!;
  }

  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, cleaned);
    _cached = cleaned;
  }

  static String toWsUrl(String httpBaseUrl) {
    if (httpBaseUrl.startsWith('https://')) {
      return 'wss://${httpBaseUrl.substring(8)}';
    }
    if (httpBaseUrl.startsWith('http://')) {
      return 'ws://${httpBaseUrl.substring(7)}';
    }
    return httpBaseUrl;
  }
}
