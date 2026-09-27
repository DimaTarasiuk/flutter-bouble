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
