/// Схеми для head-only ендпоінтів не задокументовані в API_SPEC.md з точними
/// назвами полів — парсинг тут толерантний (пробує кілька варіантів назв).
/// Якщо щось не підвантажується — скинь реальний JSON, поправлю миттєво.
library;

class AdminUser {
  final String username;
  final String role;
  final String gender;
  final bool online;
  final bool banned;
  final String? lastSeen;
  final String createdAt;

  AdminUser({
    required this.username,
    required this.role,
    required this.gender,
    required this.online,
    required this.banned,
    required this.lastSeen,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        username: j['username'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        gender: j['gender'] as String? ?? '',
        online: j['online'] as bool? ?? false,
        banned: j['banned'] as bool? ?? (j['banned_at'] != null),
        lastSeen: j['last_seen'] as String?,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class UserCardDetail {
  final String username;
  final String role;
  final String gender;
  final String firstName;
  final String lastName;
  final String? birthDate;
  final String createdAt;
  final String? lastSeen;
  final int conversationsCount;
  final int messagesCount;
  final String? bannedAt;
  final String? banReason;

  UserCardDetail({
    required this.username,
    required this.role,
    required this.gender,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.createdAt,
    required this.lastSeen,
    required this.conversationsCount,
    required this.messagesCount,
    required this.bannedAt,
    required this.banReason,
  });

  bool get isBanned => bannedAt != null;

  factory UserCardDetail.fromJson(Map<String, dynamic> j) => UserCardDetail(
        username: j['username'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        gender: j['gender'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        birthDate: j['birth_date'] as String?,
        createdAt: j['created_at'] as String? ?? '',
        lastSeen: j['last_seen'] as String?,
        conversationsCount: (j['conversations_count'] ?? j['conversations'] ?? 0) as int,
        messagesCount: (j['messages_count'] ?? j['messages'] ?? 0) as int,
        bannedAt: j['banned_at'] as String?,
        banReason: j['ban_reason'] as String?,
      );
}

class ChartPoint {
  final DateTime time;
  final int value;
  ChartPoint(this.time, this.value);

  factory ChartPoint.fromJson(Map<String, dynamic> j) {
    final raw = j['time'] ?? j['date'] ?? j['timestamp'];
    DateTime t;
    try {
      t = DateTime.parse(raw as String).toLocal();
    } catch (_) {
      t = DateTime.now();
    }
    final v = j['count'] ?? j['value'] ?? 0;
    return ChartPoint(t, v as int);
  }
}

class TopUser {
  final String username;
  final int messageCount;
  TopUser({required this.username, required this.messageCount});

  factory TopUser.fromJson(Map<String, dynamic> j) => TopUser(
        username: j['username'] as String? ?? '',
        messageCount: (j['message_count'] ?? j['count'] ?? 0) as int,
      );
}

class AdminStats {
  final int online;
  final int dau;
  final int totalUsers;
  final int regToday;
  final int reg7d;
  final int reg30d;
  final int msgToday;
  final int msg7d;
  final int msg30d;
  final List<ChartPoint> onlineChart;
  final List<ChartPoint> registrationsChart;
  final List<TopUser> topUsers7d;
  final List<Map<String, dynamic>> recentRegistrations;

  AdminStats({
    required this.online,
    required this.dau,
    required this.totalUsers,
    required this.regToday,
    required this.reg7d,
    required this.reg30d,
    required this.msgToday,
    required this.msg7d,
    required this.msg30d,
    required this.onlineChart,
    required this.registrationsChart,
    required this.topUsers7d,
    required this.recentRegistrations,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) {
    final periods = j['periods'] as Map<String, dynamic>? ?? {};
    final regs = periods['registrations'] as Map<String, dynamic>? ?? {};
    final msgs = periods['messages'] as Map<String, dynamic>? ?? {};
    return AdminStats(
      online: (j['online'] ?? j['online_now'] ?? 0) as int,
      dau: (j['dau'] ?? 0) as int,
      totalUsers: (j['total_users'] ?? j['users_count'] ?? 0) as int,
      regToday: (regs['today'] ?? 0) as int,
      reg7d: (regs['7d'] ?? regs['week'] ?? 0) as int,
      reg30d: (regs['30d'] ?? regs['month'] ?? 0) as int,
      msgToday: (msgs['today'] ?? 0) as int,
      msg7d: (msgs['7d'] ?? msgs['week'] ?? 0) as int,
      msg30d: (msgs['30d'] ?? msgs['month'] ?? 0) as int,
      onlineChart: ((j['online_chart'] ?? j['online_24h'] ?? []) as List)
          .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      registrationsChart: ((j['registrations_chart'] ?? []) as List)
          .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topUsers7d: ((j['top_users_7d'] ?? j['top_users'] ?? []) as List)
          .map((e) => TopUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentRegistrations: ((j['recent_registrations'] ?? []) as List)
          .cast<Map<String, dynamic>>(),
    );
  }
}

class RegistrationPoint {
  final DateTime date;
  final int count;
  RegistrationPoint(this.date, this.count);

  factory RegistrationPoint.fromJson(Map<String, dynamic> j) {
    DateTime d;
    try {
      d = DateTime.parse((j['date'] ?? j['time']) as String).toLocal();
    } catch (_) {
      d = DateTime.now();
    }
    return RegistrationPoint(d, (j['count'] ?? 0) as int);
  }
}

class FeedbackItem {
  final int id;
  final String username;
  final String text;
  final String createdAt;
  final bool read;

  FeedbackItem({
    required this.id,
    required this.username,
    required this.text,
    required this.createdAt,
    required this.read,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: (j['id'] ?? 0) as int,
        username: (j['username'] ?? j['from'] ?? '') as String,
        text: j['text'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        read: j['read'] as bool? ?? false,
      );
}

class AdminAnnouncement {
  final int id;
  final String text;
  final String createdBy;
  final String createdAt;

  AdminAnnouncement({
    required this.id,
    required this.text,
    required this.createdBy,
    required this.createdAt,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> j) => AdminAnnouncement(
        id: (j['id'] ?? 0) as int,
        text: j['text'] as String? ?? '',
        createdBy: j['created_by'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}
