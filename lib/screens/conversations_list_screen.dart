import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../app_state.dart';
import '../api_client.dart';
import '../models.dart';
import '../role_helpers.dart';
import '../session_store.dart';
import '../theme/tokens.dart';
import '../widgets/neu.dart';
import '../widgets/update_button.dart';
import 'chat_screen.dart';
import '../widgets/booblify_logo.dart';
import 'profile_screen.dart';
import 'feedback_sheet.dart';
import 'admin/users_panel.dart';
import 'admin/stats_panel.dart';
import 'admin/announcements_panel.dart';
import 'admin/feedback_inbox_screen.dart';
import 'admin/random_monitor_panel.dart';

enum _HeadTab { chats, users, stats, news, random }

class ConversationsListScreen extends StatefulWidget {
  final AppState appState;
  final AppUser me;
  final ValueNotifier<bool> listActive;
  final VoidCallback onOpenIncognito;
  final Future<void> Function() onLogout;

  const ConversationsListScreen({
    super.key,
    required this.appState,
    required this.me,
    required this.listActive,
    required this.onOpenIncognito,
    required this.onLogout,
  });

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _reloadDebounce;

  List<Conversation> _conversations = [];
  List<Conversation> _hidden = [];
  bool _vault = false;
  bool _blockOpen = false;
  List<SearchUser> _searchResults = [];
  bool _searching = false;
  bool _loading = true;
  String? _error;
  bool _profileHintSeen = true;
  _HeadTab _headTab = _HeadTab.chats;
  int _seenConversationsRevision = 0;

  static Future<String> _appVersionLabel() {
    return PackageInfo.fromPlatform().then((info) {
      return 'v ${info.version}';
    }).catchError((_) => '');
  }

  @override
  void initState() {
    super.initState();
    _seenConversationsRevision = widget.appState.conversationsRevision;
    _load();
    _loadHintState();
    _searchController.addListener(_onSearchChanged);
    widget.appState.addListener(_onAppState);
    widget.listActive.addListener(_onListActiveChanged);
  }

  void _onListActiveChanged() {
    if (!mounted) return;
    if (!widget.listActive.value) {
      _lockVault(pop: true);
      return;
    }
    setState(() {});
    final rev = widget.appState.conversationsRevision;
    if (rev != _seenConversationsRevision) {
      _seenConversationsRevision = rev;
      _scheduleConversationsReload();
    }
  }

  void _onAppState() {
    if (!mounted || !widget.listActive.value) return;
    // Presence / onlineCount / feedback — потрібен setState, щоб рядки чатів
    // оновлювались у реальному часі (не лише через батьківський AnimatedBuilder).
    setState(() {});
    if (_vault) return;
    final rev = widget.appState.conversationsRevision;
    if (rev != _seenConversationsRevision) {
      _seenConversationsRevision = rev;
      _scheduleConversationsReload();
    }
  }

  void _scheduleConversationsReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _loadHintState() async {
    final seen = await SessionStore.getProfileHintSeen();
    if (mounted) setState(() => _profileHintSeen = seen);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _api.conversations();
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _error = null;
      });
      widget.appState.clearUnreadBumps();
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.userMessage);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _searching = true);
      try {
        final results = await _api.searchUsers(q);
        if (mounted) setState(() => _searchResults = results);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _openWithUser(String username) async {
    if (username == widget.me.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не можна писати самому собі')),
      );
      return;
    }
    try {
      final conv = await _api.openConversation(username);
      if (conv.hidden && !_vault) return;
      _searchController.clear();
      setState(() => _searchResults = []);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(appState: widget.appState, me: widget.me, conversation: conv)),
      );
      if (_vault) return;
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Future<void> _openConversation(Conversation c) async {
    if (_blockOpen) {
      _blockOpen = false;
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(appState: widget.appState, me: widget.me, conversation: c)),
    );
    if (!mounted) return;
    if (_vault) {
      setState(() {
        _hidden = [
          for (final item in _hidden)
            if (item.id == c.id) item.copyWith(unreadCount: 0) else item,
        ];
      });
      return;
    }
    _load();
  }

  void _lockVault({required bool pop}) {
    final was = _vault;
    widget.appState.setHiddenVault(false);
    if (mounted) {
      setState(() {
        _vault = false;
        _hidden = [];
      });
    }
    if (was && pop && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _unlock(String raw) async {
    final code = raw.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) return;
    try {
      final result = await _api.unlockHidden(code);
      if (!mounted || !result.ok) return;
      _searchController.clear();
      widget.appState.setHiddenVault(true);
      setState(() {
        _vault = true;
        _hidden = result.chats;
        _searchResults = [];
      });
    } catch (_) {}
  }

  Future<bool> _ask(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Так', style: TextStyle(fontWeight: FontWeight.w800, color: kAccentPink)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _hide(Conversation c) async {
    _blockOpen = true;
    final yes = await _ask('Сховати чат?');
    if (!yes || !mounted) return;
    try {
      await _api.hideConversation(c.id);
      if (!mounted) return;
      setState(() {
        _conversations = _conversations.where((item) => item.id != c.id).toList();
      });
    } on ApiException catch (e) {
      if (e.code == 'code_required' && mounted) {
        await _hideWithCode(c);
      }
    }
  }

  Future<void> _hideWithCode(Conversation c) async {
    final pair = await showDialog<({String code, String again})>(
      context: context,
      builder: (ctx) => const _HiddenCodeDialog(),
    );
    if (pair == null || !mounted) return;
    try {
      await _api.hideConversation(c.id, code: pair.code, codeConfirm: pair.again);
      if (!mounted) return;
      setState(() {
        _conversations = _conversations.where((item) => item.id != c.id).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final text = e.code == 'code mismatch' ? 'Коди не співпадають' : 'Код має бути від 4 до 8 цифр';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _unhide(Conversation c) async {
    try {
      await _api.unhideConversation(c.id);
      if (!mounted) return;
      setState(() {
        _hidden = _hidden.where((item) => item.id != c.id).toList();
      });
      _load(silent: true);
    } catch (_) {}
  }

  Future<void> _dismiss(Conversation c) async {
    final yes = await _ask('Видалити чат назавжди?');
    if (!yes || !mounted) return;
    try {
      await _api.dismissConversation(c.id);
      if (!mounted) return;
      setState(() {
        _hidden = _hidden.where((item) => item.id != c.id).toList();
      });
      if (widget.appState.activeConversationId == c.id && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {}
  }

  Future<void> _openProfile() async {
    if (!_profileHintSeen) {
      await SessionStore.setProfileHintSeen();
      setState(() => _profileHintSeen = true);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(me: widget.me)),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text(
          'Вийти?',
          style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark),
        ),
        content: const Text(
          'Точно вийти з акаунта?',
          style: TextStyle(color: kTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Так',
              style: TextStyle(fontWeight: FontWeight.w800, color: kAccentPink),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      _lockVault(pop: false);
      await widget.onLogout();
    }
  }

  void _openIncognito() => widget.onOpenIncognito();

  void _openFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FeedbackSheet(),
    );
  }

  void _openFeedbackInbox() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FeedbackInboxScreen(appState: widget.appState)),
    );
  }

  @override
  void dispose() {
    widget.listActive.removeListener(_onListActiveChanged);
    widget.appState.removeListener(_onAppState);
    _debounce?.cancel();
    _reloadDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.me.role;
    final staff = isStaffRole(role);
    final head = isHeadRole(role);
    final online = widget.appState.online;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(staff),
            if (head) _buildHeadTabs(),
            if (_vault && (!head || _headTab == _HeadTab.chats))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const Text(
                      'Скриті чати',
                      style: TextStyle(fontWeight: FontWeight.w800, color: kAccentBlue, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _lockVault(pop: true),
                      child: const Text('Заблокувати', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            if (!head || _headTab == _HeadTab.chats)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: NeuTextField(
                  controller: _searchController,
                  hint: 'Пошук за логіном...',
                  radius: 28,
                  insetDepth: 5,
                  onSubmitted: _unlock,
                  trailing: _searching
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, color: kTextMuted),
                ),
              ),
            Expanded(child: _buildBody(head, online)),
            _buildBottomBar(head),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool head) {
    final showFeedback = !head || _headTab == _HeadTab.chats;
    String? baseLabel;
    VoidCallback? onPressed;
    TextStyle style = const TextStyle(color: kTextMuted);

    if (!head) {
      baseLabel = 'feedback';
      onPressed = _openFeedback;
    } else if (_headTab == _HeadTab.chats) {
      baseLabel = widget.appState.feedbackUnread > 0
          ? 'feedbacks (${widget.appState.feedbackUnread})'
          : 'feedbacks';
      onPressed = _openFeedbackInbox;
      style = TextStyle(
        color: widget.appState.feedbackUnread > 0 ? kAccentPink : kTextMuted,
        fontWeight: widget.appState.feedbackUnread > 0 ? FontWeight.w800 : FontWeight.normal,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UpdateButton(compact: true),
          if (showFeedback && baseLabel != null && onPressed != null)
            FutureBuilder<String>(
              future: _appVersionLabel(),
              builder: (context, snap) {
                final v = snap.data;
                final label = (v == null || v.isEmpty) ? baseLabel! : '$baseLabel · $v';
                return TextButton(
                  onPressed: onPressed,
                  child: Text(label, style: style),
                );
              },
            )
          else
            FutureBuilder<String>(
              future: _appVersionLabel(),
              builder: (context, snap) {
                final v = snap.data;
                if (v == null || v.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    v,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool head, Set<String> online) {
    if (!head || _headTab == _HeadTab.chats) {
      return _searchController.text.trim().isNotEmpty
          ? _buildSearchResults()
          : _buildConversationsList(online);
    }
    switch (_headTab) {
      case _HeadTab.users:
        return UsersPanel(appState: widget.appState, me: widget.me);
      case _HeadTab.stats:
        return const StatsPanel();
      case _HeadTab.news:
        return const AnnouncementsPanel();
      case _HeadTab.random:
        return const RandomMonitorPanel();
      case _HeadTab.chats:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeadTabs() {
    Widget tab(_HeadTab t, String label) {
      final selected = _headTab == t;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (t != _HeadTab.chats) _lockVault(pop: true);
            setState(() => _headTab = t);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: selected
                ? neuBox(inset: true, d: 3, b: 6, radius: 14)
                : neuBox(d: 3, b: 6, radius: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? kAccentBlue : kTextMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          tab(_HeadTab.chats, 'Чати'),
          tab(_HeadTab.users, 'Юзери'),
          tab(_HeadTab.stats, 'Стат'),
          tab(_HeadTab.news, 'Новини'),
          tab(_HeadTab.random, 'Інкогніто'),
        ],
      ),
    );
  }

  Widget _buildHeader(bool staff) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: _ProfilePulse(
              enabled: !_profileHintSeen,
              child: Avatar(
                username: widget.me.username,
                size: 44,
                raised: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BooblifyLogo(),
                Text(
                  staff ? 'Онлайн зараз: ${widget.appState.onlineCount}' : 'Приватні чати',
                  style: const TextStyle(fontSize: 12.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                staff ? '${widget.me.username} · ${widget.me.role}' : widget.me.username,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextMain),
              ),
              TextButton(
                onPressed: _logout,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(10, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Вийти', style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _buildIncognitoButton(),
        ],
      ),
    );
  }

  Widget _buildIncognitoButton() {
    return NeuPress(
      onTap: _openIncognito,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kShadowDark.withValues(alpha: 0.9),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            const BoxShadow(
              color: kShadowLight,
              offset: Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Text(
          '🎲',
          style: TextStyle(fontSize: 18, height: 1.1),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_searching) {
      return const Center(
        child: Text('Нікого не знайдено', style: TextStyle(color: kTextMuted)),
      );
    }
    final online = widget.appState.online;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final u = _searchResults[i];
        return _UserRow(
          username: u.username,
          gender: u.gender,
          online: online.contains(u.username) || u.online,
          onTap: () => _openWithUser(u.username),
        );
      },
    );
  }

  Widget _buildConversationsList(Set<String> online) {
    final list = _vault ? _hidden : _conversations;
    if (!_vault && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_vault && _error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: kDangerRed)));
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _vault ? 'Немає скритих чатів' : 'Немає діалогів. Знайдіть користувача за логіном',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextMuted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _vault ? () async {} : _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          final bump = widget.appState.unreadBump[c.id] ?? 0;
          final unread = c.unreadCount + bump;
          final row = _UserRow(
            username: c.peer,
            gender: c.peerGender,
            online: online.contains(c.peer),
            unreadCount: unread,
            onTap: _vault ? null : () => _openConversation(c),
          );
          if (!_vault) {
            return _HoldToHide(onHold: () => _hide(c), child: row);
          }
          return _SwipeActions(
            onOpen: () => _openConversation(c),
            onReturn: () => _unhide(c),
            onDelete: () => _dismiss(c),
            child: row,
          );
        },
      ),
    );
  }
}

class _ProfilePulse extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const _ProfilePulse({required this.enabled, required this.child});

  @override
  State<_ProfilePulse> createState() => _ProfilePulseState();
}

class _ProfilePulseState extends State<_ProfilePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ProfilePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Opacity pulse — scale робив коло візуально «некруглим» (субпікселі).
        final opacity = 0.72 + (_c.value * 0.28);
        return Opacity(opacity: opacity, child: child);
      },
      child: widget.child,
    );
  }
}

class _UserRow extends StatelessWidget {
  final String username;
  final String gender;
  final bool online;
  final int unreadCount;
  final VoidCallback? onTap;

  const _UserRow({
    required this.username,
    required this.gender,
    required this.online,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
        margin: EdgeInsets.only(bottom: onTap == null ? 0 : 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: neuBox(d: 4, b: 10, radius: 18),
        child: Row(
          children: [
            Avatar(
              username: username,
              size: 44,
              raised: true,
              showDot: true,
              online: online,
              gender: gender,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kTextMain,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: online
                          ? onlineColorForGender(gender)
                          : kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kNotifyBadge,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
    );
    if (onTap == null) return card;
    return NeuPress(onTap: onTap, child: card);
  }
}

class _HoldToHide extends StatefulWidget {
  final Widget child;
  final VoidCallback onHold;

  const _HoldToHide({required this.child, required this.onHold});

  @override
  State<_HoldToHide> createState() => _HoldToHideState();
}

class _HoldToHideState extends State<_HoldToHide> {
  Timer? _timer;
  Offset? _start;

  void _down(PointerDownEvent e) {
    _start = e.position;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 7), () {
      HapticFeedback.mediumImpact();
      widget.onHold();
    });
  }

  void _move(PointerMoveEvent e) {
    final start = _start;
    if (start == null) return;
    if ((e.position - start).distance > 8) {
      _timer?.cancel();
    }
  }

  void _up(PointerEvent e) {
    _timer?.cancel();
    _start = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}

class _SwipeActions extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpen;
  final VoidCallback onReturn;
  final VoidCallback onDelete;

  const _SwipeActions({
    required this.child,
    required this.onOpen,
    required this.onReturn,
    required this.onDelete,
  });

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  const Spacer(),
                  _action('Повернути', kAccentBlue, widget.onReturn),
                  _action('Видалити', kAccentPink, widget.onDelete),
                ],
              ),
            ),
            GestureDetector(
              onTap: _dx == 0 ? widget.onOpen : () => setState(() => _dx = 0),
              onHorizontalDragUpdate: (d) {
                setState(() => _dx = (_dx + d.delta.dx).clamp(-176.0, 0.0));
              },
              onHorizontalDragEnd: (_) {
                setState(() => _dx = _dx < -48 ? -176 : 0);
              },
              child: Transform.translate(
                offset: Offset(_dx, 0),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 88,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenCodeDialog extends StatefulWidget {
  const _HiddenCodeDialog();

  @override
  State<_HiddenCodeDialog> createState() => _HiddenCodeDialogState();
}

class _HiddenCodeDialogState extends State<_HiddenCodeDialog> {
  final _code = TextEditingController();
  final _again = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _code.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    final code = _code.text.trim();
    final again = _again.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      setState(() => _error = 'Код має бути від 4 до 8 цифр');
      return;
    }
    if (code != again) {
      setState(() => _error = 'Коди не співпадають');
      return;
    }
    Navigator.pop(context, (code: code, again: again));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBg,
      title: const Text('Код скритих чатів', style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Запам’ятайте цей код, його неможливо відновити',
            style: TextStyle(color: kAccentPink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          NeuTextField(controller: _code, hint: 'Код, 4–8 цифр', obscure: true, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          NeuTextField(controller: _again, hint: 'Повторіть код', obscure: true, keyboardType: TextInputType.number),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: kAccentPink, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ні')),
        TextButton(
          onPressed: _save,
          child: const Text('Так', style: TextStyle(fontWeight: FontWeight.w800, color: kAccentBlue)),
        ),
      ],
    );
  }
}
