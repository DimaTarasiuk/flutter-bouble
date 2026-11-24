import 'package:flutter/material.dart';
import '../app_state.dart';
import '../api_client.dart';
import '../admin_api_client.dart';
import '../models.dart';
import '../role_helpers.dart';
import '../session_store.dart';
import '../theme/tokens.dart';
import '../widgets/announcement_popup.dart';
import 'conversations_list_screen.dart';

class HomeShell extends StatefulWidget {
  final bool active;
  final VoidCallback onOpenRandom;
  final void Function(String? notice) onLoggedOut;

  const HomeShell({
    super.key,
    this.active = true,
    required this.onOpenRandom,
    required this.onLoggedOut,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _api = ApiClient();
  final _appState = AppState();
  final _navKey = GlobalKey<NavigatorState>();
  late final ValueNotifier<bool> _listActive;
  AppUser? _me;
  bool _loading = true;
  bool _disposedPresence = false;

  @override
  void initState() {
    super.initState();
    _listActive = ValueNotifier(widget.active);
    _init();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _listActive.value = widget.active;
    }
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
      _appState.presence.events.listen((e) {
        if (e.type == 'force_logout') {
          final reason = e.raw['reason'] as String?;
          _handleForceLogout(reason);
        }
      });
      await _appState.start();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      if (mounted) {
        await SessionStore.clear();
        widget.onLoggedOut(null);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForceLogout(String? reason) async {
    await SessionStore.clear();
    final notice =
        reason == 'banned' ? 'Акаунт заблоковано' : 'Вас відключив адміністратор';
    if (!mounted) return;
    widget.onLoggedOut(notice);
  }

  Future<void> _handleLogout() async {
    await SessionStore.clear();
    if (!mounted) return;
    widget.onLoggedOut(null);
  }

  void _disposePresence() {
    if (_disposedPresence) return;
    _disposedPresence = true;
    _appState.disposeAll();
  }

  @override
  void dispose() {
    _listActive.dispose();
    _disposePresence();
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

    final me = _me!;

    Widget buildBody() {
      return Stack(
        children: [
          Navigator(
            key: _navKey,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => ConversationsListScreen(
                appState: _appState,
                me: me,
                listActive: _listActive,
                onOpenIncognito: widget.onOpenRandom,
                onLogout: _handleLogout,
              ),
            ),
          ),
          if (widget.active && _appState.announcementQueue.isNotEmpty)
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
    }

    // Avoid rebuilding the whole navigator on every presence tick while Incognito is open.
    if (!widget.active) return buildBody();
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) => buildBody(),
    );
  }
}
