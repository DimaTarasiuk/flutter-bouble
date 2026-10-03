import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'config.dart';
import 'models_admin.dart';
import 'session_store.dart';

class AdminApiClient {
  Future<Uri> _uri(String path) async {
    final base = await AppConfig.getBaseUrl();
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _extractError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['error'] is String) return body['error'] as String;
    } catch (_) {}
    return 'unknown error (${resp.statusCode})';
  }

  Future<List<AdminUser>> users() async {
    final resp = await http
        .get(await _uri('/api/admin/users'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<UserCardDetail> userDetail(String username) async {
    final resp = await http
        .get(await _uri('/api/admin/users/$username'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      return UserCardDetail.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> kick(String username) async {
    final resp = await http
        .post(await _uri('/api/admin/users/$username/kick'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<void> ban(String username, {String? reason}) async {
    final resp = await http
        .post(await _uri('/api/admin/users/$username/ban'),
            headers: await _headers(), body: jsonEncode({'reason': reason ?? ''}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<void> unban(String username) async {
    final resp = await http
        .post(await _uri('/api/admin/users/$username/unban'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<AdminStats> stats() async {
    final resp = await http
        .get(await _uri('/api/admin/stats'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      return AdminStats.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<RegistrationPoint>> registrations({int days = 14}) async {
    final resp = await http
        .get(await _uri('/api/admin/registrations?days=$days'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.map((e) => RegistrationPoint.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<AdminAnnouncement>> announcementsHistory() async {
    final resp = await http
        .get(await _uri('/api/admin/announcements'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.map((e) => AdminAnnouncement.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> createAnnouncement(String text) async {
    final resp = await http
        .post(await _uri('/api/admin/announcements'),
            headers: await _headers(), body: jsonEncode({'text': text}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<List<FeedbackItem>> feedbackList() async {
    final resp = await http
        .get(await _uri('/api/admin/feedback'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<int> feedbackUnreadCount() async {
    final resp = await http
        .get(await _uri('/api/admin/feedback/unread'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['count'] ?? 0) as int;
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> markFeedbackRead() async {
    final resp = await http
        .post(await _uri('/api/admin/feedback/read'), headers: await _headers())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }
}
