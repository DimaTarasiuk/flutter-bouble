import 'package:flutter/foundation.dart';
import 'models.dart';
import 'presence_service.dart';
import 'sound_service.dart';

class AppState extends ChangeNotifier {
  final PresenceService presence = PresenceService();

  AppUser? me;
  Set<String> online = {};
  int onlineCount = 0;
  List<Announcement> announcementQueue = [];
  int feedbackUnread = 0; // лише для head

  /// id розмови, яка зараз відкрита на екрані — щоб не дзвонити звук
  /// і не рахувати unread для чату, який користувач і так дивиться.
  int? activeConversationId;

  /// Локальний лічильник непрочитаних на додачу до того, що прийшло з REST
  /// (поки список розмов не перезавантажили — оновлюється через events).
  final Map<int, int> unreadBump = {};

  /// Збільшується на кожне вхідне `chat_message` поза активним чатом —
  /// список розмов може перезавантажитись і підтягнути unread з REST.
  int conversationsRevision = 0;

  bool _started = false;

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await presence.connect();
    presence.events.listen(_onEvent);
  }

  void setActiveConversation(int? id) {
    activeConversationId = id;
    if (id != null) unreadBump.remove(id);
  }

  void clearUnreadBumps() {
    if (unreadBump.isEmpty) return;
    unreadBump.clear();
    notifyListeners();
  }

  void setFeedbackUnread(int count) {
    feedbackUnread = count;
    notifyListeners();
  }

  void clearFeedbackUnread() {
    feedbackUnread = 0;
    notifyListeners();
  }

  void dismissAnnouncement(Announcement a) {
    announcementQueue.removeWhere((x) => x.id == a.id);
    notifyListeners();
  }

  static Set<String> _parseOnlineList(dynamic raw) {
    if (raw is! List) return {};
    final result = <String>{};
    for (final e in raw) {
      if (e is String) {
        if (e.isNotEmpty) result.add(e);
      } else if (e is Map) {
        final name = (e['username'] ?? e['user'] ?? '').toString();
        if (name.isNotEmpty) result.add(name);
      }
    }
    return result;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  void _onEvent(PresenceEvent e) {
    switch (e.type) {
      case 'presence_snapshot':
        online = _parseOnlineList(e.raw['online']);
        final count = _asInt(e.raw['online_count']);
        if (count != null) onlineCount = count;
        notifyListeners();
        break;

      case 'presence':
        final user = (e.raw['user'] ?? e.raw['username'])?.toString();
        final isOnline = _asBool(e.raw['online']);
        if (user != null && user.isNotEmpty) {
          // Новий Set — щоб UI точно побачив зміну після notifyListeners.
          if (isOnline) {
            online = {...online, user};
          } else {
            online = {...online}..remove(user);
          }
        }
        final count = _asInt(e.raw['online_count']);
        if (count != null) onlineCount = count;
        notifyListeners();
        break;

      case 'online_count':
        final count = _asInt(e.raw['online_count'] ?? e.raw['count']);
        if (count != null) {
          onlineCount = count;
          notifyListeners();
        }
        break;

      case 'announcement':
        final a = e.raw['announcement'];
        if (a is Map<String, dynamic>) {
          final ann = Announcement.fromJson(a);
          // автор не бачить своє (як на вебі)
          if (ann.createdBy != me?.username) {
            announcementQueue = [...announcementQueue, ann];
            notifyListeners();
          }
        }
        break;

      case 'chat_message':
        final convId = _asInt(e.raw['conversation_id']);
        if (convId != null && convId != activeConversationId) {
          unreadBump[convId] = (unreadBump[convId] ?? 0) + 1;
          conversationsRevision++;
          SoundService.playNewMessage();
          notifyListeners();
        }
        break;

      case 'feedback':
        feedbackUnread += 1;
        notifyListeners();
        break;

      case 'force_logout':
        // обробляється окремо в UI (навігація на LoginScreen)
        break;
    }
  }

  void disposeAll() {
    presence.dispose();
  }
}
