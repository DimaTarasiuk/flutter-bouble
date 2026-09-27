import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';
import 'session_store.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  ApiException(this.statusCode, this.code);

  @override
  String toString() => code;

  /// Людський текст українською, згідно мапінгу з API_SPEC.md §2.1 / §2.2
  String get userMessage {
    switch (code) {
      case 'invalid credentials':
        return 'Невірний логін або пароль';
      case 'banned':
        return 'Акаунт заблоковано';
      case 'too many requests':
        return 'Забагато спроб, спробуйте пізніше';
      case 'login and password required':
        return 'Введіть логін і пароль';
      case 'passwords do not match':
        return 'Паролі не співпадають';
      case 'password too short':
        return 'Пароль надто короткий (мінімум 6 символів)';
      case 'gender required':
        return 'Оберіть стать';
      case 'username already taken':
        return 'Такий логін вже зайнятий';
      case 'unauthorized':
      case 'session revoked':
        return 'Сесія завершена, увійдіть знову';
      case 'request too large':
        return 'Забагато даних у запиті';
      case 'bad request':
        return 'Некоректний запит';
      case 'network_error':
        return 'Немає з\'єднання з сервером. Перевір адресу сервера і мережу.';
      default:
        return 'Сталася помилка. Спробуйте ще раз.';
    }
  }
}

class ApiClient {
  Future<Uri> _uri(String path) async {
    final base = await AppConfig.getBaseUrl();
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await SessionStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
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

  Future<AuthResult> login(String username, String password) async {
    http.Response resp;
    try {
      resp = await http
          .post(
            await _uri('/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(null, 'network_error');
    }

    if (resp.statusCode == 200) {
      final auth = AuthResult.fromJson(jsonDecode(resp.body));
      await SessionStore.save(auth);
      return auth;
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<AuthResult> register({
    required String username,
    required String password,
    required String passwordConfirm,
    required String gender,
  }) async {
    http.Response resp;
    try {
      resp = await http
          .post(
            await _uri('/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'password_confirm': passwordConfirm,
              'gender': gender,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(null, 'network_error');
    }

    if (resp.statusCode == 201) {
      final auth = AuthResult.fromJson(jsonDecode(resp.body));
      await SessionStore.save(auth);
      return auth;
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<AppUser> me() async {
    http.Response resp;
    try {
      resp = await http
          .get(await _uri('/api/me'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(null, 'network_error');
    }

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final auth = AuthResult.fromJson(data);
      await SessionStore.updateToken(auth.token);
      return auth.user;
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<Conversation>> conversations() async {
    final resp = await http
        .get(await _uri('/api/conversations'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<Announcement>> pendingAnnouncements() async {
    final resp = await http
        .get(await _uri('/api/announcements/pending'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> ackAnnouncement(int id) async {
    final resp = await http
        .post(await _uri('/api/announcements/$id/ack'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }
}
