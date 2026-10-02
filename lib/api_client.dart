import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';
import 'session_store.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String? debugDetail;
  ApiException(this.statusCode, this.code, {this.debugDetail});

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
      case 'timeout':
        return 'Сервер довго не відповідає (можливо, він ще "прокидається" після сну). Спробуй ще раз через кілька секунд.';
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
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException(null, 'timeout');
    } catch (e) {
      throw ApiException(null, 'network_error', debugDetail: e.toString());
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
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException(null, 'timeout');
    } catch (e) {
      throw ApiException(null, 'network_error', debugDetail: e.toString());
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
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException(null, 'timeout');
    } catch (e) {
      throw ApiException(null, 'network_error', debugDetail: e.toString());
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
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<AppUser> patchMe({
    String? username,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? gender,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (birthDate != null) body['birth_date'] = birthDate;
    if (gender != null) body['gender'] = gender;

    final resp = await http
        .patch(await _uri('/api/me'), headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final auth = AuthResult.fromJson(jsonDecode(resp.body));
      await SessionStore.updateToken(auth.token);
      return auth.user;
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<SearchUser>> searchUsers(String query) async {
    final resp = await http
        .get(await _uri('/api/users?q=${Uri.encodeQueryComponent(query)}'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.map((e) => SearchUser.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<Conversation> openConversation(String username) async {
    final resp = await http
        .post(await _uri('/api/conversations'),
            headers: await _authHeaders(), body: jsonEncode({'username': username}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<List<ChatMessage>> messages(int conversationId, {int limit = 50, dynamic before}) async {
    var path = '/api/conversations/$conversationId/messages?limit=$limit';
    if (before != null) path += '&before=$before';
    final resp = await http
        .get(await _uri(path), headers: await _authHeaders())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, conversationId))
          .toList();
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<ChatMessage> sendMessage(int conversationId, String text, {dynamic replyTo}) async {
    final body = <String, dynamic>{'text': text};
    if (replyTo != null) body['reply_to'] = replyTo;
    final resp = await http
        .post(await _uri('/api/conversations/$conversationId/messages'),
            headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return ChatMessage.fromJson(jsonDecode(resp.body) as Map<String, dynamic>, conversationId);
    }
    throw ApiException(resp.statusCode, _extractError(resp));
  }

  Future<void> editMessage(int conversationId, int messageId, String text) async {
    final resp = await http
        .patch(await _uri('/api/conversations/$conversationId/messages/$messageId'),
            headers: await _authHeaders(), body: jsonEncode({'text': text}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<void> markRead(int conversationId) async {
    final resp = await http
        .post(await _uri('/api/conversations/$conversationId/read'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<void> sendFeedback(String text) async {
    final resp = await http
        .post(await _uri('/api/feedback'),
            headers: await _authHeaders(), body: jsonEncode({'text': text}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }

  Future<List<Announcement>> pendingAnnouncements() async {
    final resp = await http
        .get(await _uri('/api/announcements/pending'),
            headers: await _authHeaders())
        .timeout(const Duration(seconds: 60));
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
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, _extractError(resp));
    }
  }
}
