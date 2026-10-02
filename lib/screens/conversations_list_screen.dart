import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../api_client.dart';
import '../models.dart';
import '../role_helpers.dart';
import '../session_store.dart';
import '../theme/tokens.dart';
import '../widgets/neu.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'feedback_sheet.dart';

class ConversationsListScreen extends StatefulWidget {
  final AppState appState;
  final AppUser me;

  const ConversationsListScreen({super.key, required this.appState, required this.me});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Conversation> _conversations = [];
  List<SearchUser> _searchResults = [];
  bool _searching = false;
  bool _loading = true;
  String? _error;
  bool _profileHintSeen = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHintState();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadHintState() async {
    final seen = await SessionStore.getProfileHintSeen();
    if (mounted) setState(() => _profileHintSeen = seen);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.conversations();
      if (mounted) setState(() => _conversations = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
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
      _searchController.clear();
      setState(() => _searchResults = []);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(appState: widget.appState, me: widget.me, conversation: conv)),
      );
      _load();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Future<void> _openConversation(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(appState: widget.appState, me: widget.me, conversation: c)),
    );
    _load();
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
    await SessionStore.clear();
    widget.appState.disposeAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FeedbackSheet(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.me.role;
    final staff = isStaffRole(role);
    final online = widget.appState.online;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(staff),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: NeuTextField(
                controller: _searchController,
                hint: 'Пошук за логіном...',
                trailing: _searching
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, color: kTextMuted),
              ),
            ),
            Expanded(
              child: _searchController.text.trim().isNotEmpty
                  ? _buildSearchResults()
                  : _buildConversationsList(online),
            ),
            if (!isHeadRole(role))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextButton(
                  onPressed: _openFeedback,
                  child: const Text('feedback', style: TextStyle(color: kTextMuted)),
                ),
              ),
          ],
        ),
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
              child: Container(
                width: 44,
                height: 44,
                decoration: neuBox(d: 4, b: 8, radius: 22),
                child: Avatar(username: widget.me.username, size: 36, bg: kAccentBlue),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                          text: 'Bouble ',
                          style: TextStyle(color: kTextMuted, fontWeight: FontWeight.w800, fontSize: 19)),
                      TextSpan(
                          text: 'Chat',
                          style: TextStyle(color: kTextMain, fontWeight: FontWeight.w800, fontSize: 19)),
                    ],
                  ),
                ),
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
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(10, 20)),
                child: const Text('Вийти', style: TextStyle(fontSize: 12, color: kTextMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_searching) {
      return const Center(
        child: Text('Нікого не знайдено', style: TextStyle(color: kTextMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final u = _searchResults[i];
        return _UserRow(
          username: u.username,
          gender: u.gender,
          online: u.online,
          onTap: () => _openWithUser(u.username),
        );
      },
    );
  }

  Widget _buildConversationsList(Set<String> online) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: kDangerRed)));
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Немає діалогів. Знайдіть користувача за логіном',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextMuted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _conversations.length,
        itemBuilder: (context, i) {
          final c = _conversations[i];
          final bump = widget.appState.unreadBump[c.id] ?? 0;
          final unread = c.unreadCount + bump;
          return _UserRow(
            username: c.peer,
            gender: c.peerGender,
            online: online.contains(c.peer),
            unreadCount: unread,
            onTap: () => _openConversation(c),
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

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
        final scale = 1.0 + (_c.value * 0.08);
        return Transform.scale(scale: scale, child: child);
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
  final VoidCallback onTap;

  const _UserRow({
    required this.username,
    required this.gender,
    required this.online,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Avatar(username: username, bg: kAccentPink, showDot: true, online: online, gender: gender),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username, style: const TextStyle(fontWeight: FontWeight.w700, color: kTextMain)),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: online ? onlineColorForGender(gender) : kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kAccentPink, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
