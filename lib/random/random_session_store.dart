import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'random_models.dart';

const String _kAnonId = 'random_anon_id';
const String _kToken = 'random_token';
const String _kPrefs = 'random_prefs';

class RandomSessionStore {
  static String _uuidV4() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Future<String> getOrCreateAnonId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kAnonId);
    if (id == null || id.isEmpty) {
      id = _uuidV4();
      await prefs.setString(_kAnonId, id);
    }
    return id;
  }

  static Future<void> saveAnonId(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAnonId, id);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  static Future<void> savePrefs(RandomPrefs prefsData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefs, jsonEncode(prefsData.toJson()));
  }

  static Future<RandomPrefs?> getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefs);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RandomPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clears guest JWT (like web sessionStorage). Keeps anon_id.
  static Future<void> clearGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }
}
