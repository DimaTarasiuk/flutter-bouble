class AppUser {
  final int id;
  final String username;
  final String role;
  final String firstName;
  final String lastName;
  final String? birthDate;
  final String gender;
  final String? lastSeen;
  final String? bannedAt;
  final String banReason;
  final String createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.gender,
    required this.lastSeen,
    required this.bannedAt,
    required this.banReason,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        username: j['username'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        birthDate: j['birth_date'] as String?,
        gender: j['gender'] as String? ?? '',
        lastSeen: j['last_seen'] as String?,
        bannedAt: j['banned_at'] as String?,
        banReason: j['ban_reason'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

class AuthResult {
  final String token;
  final AppUser user;
  AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class Conversation {
  final int id;
  final int peerId;
  final String peer;
  final String peerGender;
  final int unreadCount;
  final String createdAt;

  Conversation({
    required this.id,
    required this.peerId,
    required this.peer,
    required this.peerGender,
    required this.unreadCount,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as int,
        peerId: j['peer_id'] as int,
        peer: j['peer'] as String? ?? '',
        peerGender: j['peer_gender'] as String? ?? '',
        unreadCount: j['unread_count'] as int? ?? 0,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class ChatMessage {
  final dynamic id; // int для серверних, String "temp-..." для оптимістичних
  final int conversationId;
  final String from;
  final String text;
  final dynamic replyTo;
  /// Якщо сервер віддав вкладений reply_to — зберігаємо превʼю одразу.
  final String? replyPreviewFrom;
  final String? replyPreviewText;
  final DateTime createdAt;
  final bool edited;
  final bool isTemp;
  final bool failed;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.from,
    required this.text,
    required this.replyTo,
    this.replyPreviewFrom,
    this.replyPreviewText,
    required this.createdAt,
    this.edited = false,
    this.isTemp = false,
    this.failed = false,
  });

  bool get isNumericId => id is int || (id is num && id == (id as num).toInt());

  ChatMessage copyWith({
    dynamic id,
    String? text,
    bool? edited,
    bool? isTemp,
    bool? failed,
    Object? replyTo = _unset,
    Object? replyPreviewFrom = _unset,
    Object? replyPreviewText = _unset,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      from: from,
      text: text ?? this.text,
      replyTo: identical(replyTo, _unset) ? this.replyTo : replyTo,
      replyPreviewFrom: identical(replyPreviewFrom, _unset)
          ? this.replyPreviewFrom
          : replyPreviewFrom as String?,
      replyPreviewText: identical(replyPreviewText, _unset)
          ? this.replyPreviewText
          : replyPreviewText as String?,
      createdAt: createdAt,
      edited: edited ?? this.edited,
      isTemp: isTemp ?? this.isTemp,
      failed: failed ?? this.failed,
    );
  }

  static const Object _unset = Object();

  static dynamic normalizeId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final asInt = int.tryParse(raw);
      return asInt ?? raw;
    }
    return raw;
  }

  static bool idsEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    if (a == b) return true;
    final na = normalizeId(a);
    final nb = normalizeId(b);
    return na == nb || '$na' == '$nb';
  }

  /// Парсинг максимально толерантний до розбіжностей у назвах полів,
  /// бо точна схема REST-відповіді для messages не задокументована в API_SPEC.md.
  factory ChatMessage.fromJson(Map<String, dynamic> j, int conversationId) {
    final rawId = normalizeId(j['id']);
    DateTime created;
    final rawTime = j['created_at'] ?? j['time'] ?? j['timestamp'];
    try {
      created = rawTime != null ? DateTime.parse(rawTime as String).toLocal() : DateTime.now();
    } catch (_) {
      created = DateTime.now();
    }

    dynamic replyRaw = j['reply_to'] ?? j['reply_to_id'] ?? j['replyTo'];
    String? replyPreviewFrom;
    String? replyPreviewText;
    dynamic replyTo;
    if (replyRaw is Map) {
      final map = Map<String, dynamic>.from(replyRaw);
      replyTo = normalizeId(map['id'] ?? map['message_id']);
      final from = map['from'] ?? map['sender'] ?? map['username'];
      final text = map['text'] ?? map['body'];
      if (from is String && from.isNotEmpty) replyPreviewFrom = from;
      if (text is String && text.isNotEmpty) replyPreviewText = text;
    } else {
      replyTo = normalizeId(replyRaw);
    }

    return ChatMessage(
      id: rawId,
      conversationId: conversationId,
      from: (j['from'] ?? j['sender'] ?? j['username'] ?? '') as String,
      text: (j['text'] ?? j['body'] ?? '') as String,
      replyTo: replyTo,
      replyPreviewFrom: replyPreviewFrom,
      replyPreviewText: replyPreviewText,
      createdAt: created,
      edited: (j['edited'] as bool?) ?? (j['edited_at'] != null),
    );
  }
}

class SearchUser {
  final String username;
  final String gender;
  final bool online;

  SearchUser({required this.username, required this.gender, required this.online});

  factory SearchUser.fromJson(Map<String, dynamic> j) => SearchUser(
        username: j['username'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        online: j['online'] as bool? ?? false,
      );
}

class Announcement {
  final int id;
  final String text;
  final String createdBy;
  final String createdAt;

  Announcement({
    required this.id,
    required this.text,
    required this.createdBy,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as int,
        text: j['text'] as String? ?? '',
        createdBy: j['created_by'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}
