import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

const String _kToken = 'chat_token';
const String _kUsername = 'chat_username';
const String _kRole = 'chat_role';
const String _kProfileHintSeen = 'chat_profile_hint_seen';

class SessionStore {
  static Future<void> save(AuthResult auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, auth.token);
    await prefs.setString(_kUsername, auth.user.username);
    await prefs.setString(_kRole, auth.user.role.isEmpty ? 'user' : auth.user.role);
  }

  static Future<void> updateToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsername);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<bool> getProfileHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kProfileHintSeen) ?? false;
  }

  static Future<void> setProfileHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProfileHintSeen, true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUsername);
    await prefs.remove(_kRole);
    // profile_hint_seen навмисно НЕ чистимо при logout — як і на вебі (localStorage переживає сесію)
  }
}
