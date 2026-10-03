import 'package:flutter/material.dart';
import '../app_state.dart';
import '../api_client.dart';
import '../admin_api_client.dart';
import '../models.dart';
import '../role_helpers.dart';
import '../session_store.dart';
import '../theme/tokens.dart';
import '../widgets/announcement_popup.dart';
import 'login_screen.dart';
import 'conversations_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _api = ApiClient();
  final _appState = AppState();
  AppUser? _me;
  bool _loading = true;
  String? _loginNotice; // "banned" / "kicked" — показати на екрані входу після force_logout

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final me = await _api.me();
      _appState.me = me;
      try {
        final pending = await _api.pendingAnnouncements();
        _appState.announcementQueue = pending;
      } catch (_) {}
      if (isHeadRole(me.role)) {
        try {
          final count = await AdminApiClient().feedbackUnreadCount();
          _appState.setFeedbackUnread(count);
        } catch (_) {}
      }
      await _appState.start();
      _appState.presence.events.listen((e) {
        if (e.type == 'force_logout') {
          final reason = e.raw['reason'] as String?;
          _handleForceLogout(reason);
        }
      });
      if (mounted) setState(() => _me = me);
    } catch (_) {
      if (mounted) _goToLogin();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForceLogout(String? reason) async {
    await SessionStore.clear();
    _loginNotice = reason == 'banned' ? 'Акаунт заблоковано' : 'Вас відключив адміністратор';
    if (mounted) _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(notice: _loginNotice)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _appState.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_me == null) {
      return const Scaffold(backgroundColor: kBg);
    }

    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return Stack(
          children: [
            ConversationsListScreen(appState: _appState, me: _me!),
            if (_appState.announcementQueue.isNotEmpty)
              AnnouncementPopup(
                announcement: _appState.announcementQueue.first,
                remaining: _appState.announcementQueue.length - 1,
                onNext: () async {
                  final a = _appState.announcementQueue.first;
                  try {
                    await _api.ackAnnouncement(a.id);
                  } catch (_) {}
                  _appState.dismissAnnouncement(a);
                },
              ),
          ],
        );
      },
    );
  }
}
