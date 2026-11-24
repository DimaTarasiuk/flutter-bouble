const int kRandomMinAge = 18;
const int kRandomMaxAge = 99;

class RandomAgeBand {
  final int min;
  final int max;
  final String label;
  final String value;

  const RandomAgeBand({
    required this.min,
    required this.max,
    required this.label,
    required this.value,
  });
}

const List<RandomAgeBand> kRandomAgeBands = [
  RandomAgeBand(min: 18, max: 22, label: '18-22', value: '18-22'),
  RandomAgeBand(min: 23, max: 28, label: '23-28', value: '23-28'),
  RandomAgeBand(min: 28, max: kRandomMaxAge, label: '28-30+', value: '28-30+'),
];

RandomAgeBand? ageBandByValue(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final b in kRandomAgeBands) {
    if (b.value == value) return b;
  }
  return null;
}

RandomAgeBand? ageBandByRange(int min, int max) {
  for (final b in kRandomAgeBands) {
    if (b.min == min && b.max == max) return b;
  }
  return null;
}

class RandomPrefs {
  final String gender;
  final int ageMin;
  final int ageMax;
  final String seekGender;
  final int seekAgeMin;
  final int seekAgeMax;

  const RandomPrefs({
    required this.gender,
    required this.ageMin,
    required this.ageMax,
    required this.seekGender,
    required this.seekAgeMin,
    required this.seekAgeMax,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age_min': ageMin,
        'age_max': ageMax,
        'seek_gender': seekGender,
        'seek_age_min': seekAgeMin,
        'seek_age_max': seekAgeMax,
      };

  factory RandomPrefs.fromJson(Map<String, dynamic> j) => RandomPrefs(
        gender: j['gender'] as String? ?? '',
        ageMin: (j['age_min'] as num?)?.toInt() ?? kRandomMinAge,
        ageMax: (j['age_max'] as num?)?.toInt() ?? kRandomMaxAge,
        seekGender: j['seek_gender'] as String? ?? 'any',
        seekAgeMin: (j['seek_age_min'] as num?)?.toInt() ?? kRandomMinAge,
        seekAgeMax: (j['seek_age_max'] as num?)?.toInt() ?? 35,
      );
}

class RandomSession {
  final int id;
  final String peerGender;
  final String peerAge;
  final String status;
  final DateTime? createdAt;

  const RandomSession({
    required this.id,
    required this.peerGender,
    required this.peerAge,
    required this.status,
    this.createdAt,
  });

  factory RandomSession.fromJson(Map<String, dynamic> j) => RandomSession(
        id: (j['id'] as num).toInt(),
        peerGender: j['peer_gender'] as String? ?? 'male',
        peerAge: j['peer_age'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}

class RandomReplyPreview {
  final int id;
  final String from;
  final String text;

  const RandomReplyPreview({
    required this.id,
    required this.from,
    required this.text,
  });

  factory RandomReplyPreview.fromJson(Map<String, dynamic> j) => RandomReplyPreview(
        id: (j['id'] as num).toInt(),
        from: j['from'] as String? ?? '',
        text: j['text'] as String? ?? '',
      );
}

class RandomMessage {
  final int id;
  final String fromGender;
  final bool mine;
  final String text;
  final DateTime? time;
  final RandomReplyPreview? replyTo;
  final String fromGuest;

  const RandomMessage({
    required this.id,
    required this.fromGender,
    required this.mine,
    required this.text,
    this.time,
    this.replyTo,
    this.fromGuest = '',
  });

  factory RandomMessage.fromJson(Map<String, dynamic> j) {
    RandomReplyPreview? reply;
    final raw = j['reply_to'];
    if (raw is Map<String, dynamic>) {
      reply = RandomReplyPreview.fromJson(raw);
    }
    return RandomMessage(
      id: (j['id'] as num).toInt(),
      fromGender: j['from_gender'] as String? ?? 'male',
      mine: j['mine'] as bool? ?? false,
      text: j['text'] as String? ?? '',
      time: j['time'] != null ? DateTime.tryParse(j['time'] as String) : null,
      replyTo: reply,
      fromGuest: j['from_guest'] as String? ?? '',
    );
  }
}

class RandomGuestBrief {
  final String id;
  final String anonId;
  final String gender;
  final String age;

  const RandomGuestBrief({
    required this.id,
    required this.anonId,
    required this.gender,
    required this.age,
  });

  factory RandomGuestBrief.fromJson(Map<String, dynamic> j) => RandomGuestBrief(
        id: j['id'] as String? ?? '',
        anonId: j['anon_id'] as String? ?? '',
        gender: j['gender'] as String? ?? 'male',
        age: j['age'] as String? ?? '',
      );

  String get title => '${genderSign(gender)} $age';
}

class RandomSessionAdmin {
  final int id;
  final String status;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final String lastText;
  final RandomGuestBrief guestA;
  final RandomGuestBrief guestB;

  const RandomSessionAdmin({
    required this.id,
    required this.status,
    this.createdAt,
    this.endedAt,
    this.lastMessageAt,
    required this.messageCount,
    required this.lastText,
    required this.guestA,
    required this.guestB,
  });

  bool get isActive => status == 'active';

  factory RandomSessionAdmin.fromJson(Map<String, dynamic> j) => RandomSessionAdmin(
        id: (j['id'] as num).toInt(),
        status: j['status'] as String? ?? '',
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        endedAt: j['ended_at'] != null
            ? DateTime.tryParse(j['ended_at'] as String)
            : null,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.tryParse(j['last_message_at'] as String)
            : null,
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
        lastText: j['last_text'] as String? ?? '',
        guestA: RandomGuestBrief.fromJson(
          j['guest_a'] as Map<String, dynamic>? ?? {},
        ),
        guestB: RandomGuestBrief.fromJson(
          j['guest_b'] as Map<String, dynamic>? ?? {},
        ),
      );
}

class RandomSessionAdminDetail {
  final RandomSessionAdmin session;
  final List<RandomMessage> messages;

  const RandomSessionAdminDetail({
    required this.session,
    required this.messages,
  });

  factory RandomSessionAdminDetail.fromJson(Map<String, dynamic> j) {
    final list = (j['messages'] as List? ?? [])
        .map((e) => RandomMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return RandomSessionAdminDetail(
      session: RandomSessionAdmin.fromJson(
        j['session'] as Map<String, dynamic>? ?? {},
      ),
      messages: list,
    );
  }
}

class RandomStartResult {
  final String token;
  final String anonId;
  final RandomPrefs prefs;

  const RandomStartResult({
    required this.token,
    required this.anonId,
    required this.prefs,
  });

  factory RandomStartResult.fromJson(Map<String, dynamic> j) => RandomStartResult(
        token: j['token'] as String,
        anonId: j['anon_id'] as String? ?? '',
        prefs: RandomPrefs.fromJson(j['prefs'] as Map<String, dynamic>? ?? {}),
      );
}

class RandomHistory {
  final RandomSession session;
  final List<RandomMessage> messages;

  const RandomHistory({required this.session, required this.messages});
}

class RandomSearchResult {
  final String status;
  final RandomSession? session;

  const RandomSearchResult({required this.status, this.session});

  bool get isMatched => status == 'matched' && session != null;
}

const List<String> kMaleNicks = [
  'рандомним котом',
  'милим котом',
  'няшним котом',
  'дворовим котом',
];

const List<String> kFemaleNicks = [
  'рандомною кицькою',
  'милою кицькою',
  'няшною кицькою',
  'дворовою кицькою',
];

String peerNick(RandomSession session) {
  final list = session.peerGender == 'female' ? kFemaleNicks : kMaleNicks;
  return 'Чат з ${list[session.id.abs() % list.length]}';
}

String genderSign(String? gender) => gender == 'female' ? '♀' : '♂';

String genderLabel(String? gender) => gender == 'female' ? 'Вона' : 'Він';

int clampSeekAge(int n) {
  if (n < kRandomMinAge) return kRandomMinAge;
  if (n > kRandomMaxAge) return kRandomMaxAge;
  return n;
}
