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

  /// id розмови, яка зараз відкрита на екрані — щоб не дзвонити звук
  /// і не рахувати unread для чату, який користувач і так дивиться.
  int? activeConversationId;

  /// Локальний лічильник непрочитаних на додачу до того, що прийшло з REST
  /// (поки список розмов не перезавантажили — оновлюється через events).
  final Map<int, int> unreadBump = {};

  bool _started = false;

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

  void dismissAnnouncement(Announcement a) {
    announcementQueue.removeWhere((x) => x.id == a.id);
    notifyListeners();
  }

  void _onEvent(PresenceEvent e) {
    switch (e.type) {
      case 'presence_snapshot':
        final list = (e.raw['online'] as List?)?.cast<String>() ?? [];
        online = list.toSet();
        final count = e.raw['online_count'];
        if (count is int) onlineCount = count;
        notifyListeners();
        break;

      case 'presence':
        final user = e.raw['user'] as String?;
        final isOnline = e.raw['online'] as bool? ?? false;
        if (user != null) {
          if (isOnline) {
            online.add(user);
          } else {
            online.remove(user);
          }
        }
        final count = e.raw['online_count'];
        if (count is int) onlineCount = count;
        notifyListeners();
        break;

      case 'online_count':
        final count = e.raw['online_count'] ?? e.raw['count'];
        if (count is int) {
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
        final convId = e.raw['conversation_id'];
        if (convId is int && convId != activeConversationId) {
          unreadBump[convId] = (unreadBump[convId] ?? 0) + 1;
          SoundService.playNewMessage();
          notifyListeners();
        }
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
