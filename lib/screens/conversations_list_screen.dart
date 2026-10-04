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
import 'admin/users_panel.dart';
import 'admin/stats_panel.dart';
import 'admin/announcements_panel.dart';
import 'admin/feedback_inbox_screen.dart';

enum _HeadTab { chats, users, stats, news }

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
  _HeadTab _headTab = _HeadTab.chats;

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
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            appState: widget.appState,
            me: widget.me,
            conversation: conv,
          ),
        ),
      );
      _load();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    }
  }

  Future<void> _openConversation(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          appState: widget.appState,
          me: widget.me,
          conversation: c,
        ),
      ),
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

  void _openFeedbackInbox() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedbackInboxScreen(appState: widget.appState),
      ),
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
    final head = isHeadRole(role);
    final online = widget.appState.online;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(staff),
            if (head) _buildHeadTabs(),
            if (!head || _headTab == _HeadTab.chats)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: NeuTextField(
                  controller: _searchController,
                  hint: 'Пошук за логіном...',
                  trailing: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: kTextMuted),
                ),
              ),
            Expanded(child: _buildBody(head, online)),
            if (!head)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextButton(
                  onPressed: _openFeedback,
                  child: const Text(
                    'feedback',
                    style: TextStyle(color: kTextMuted),
                  ),
                ),
              )
            else if (_headTab == _HeadTab.chats)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextButton(
                  onPressed: _openFeedbackInbox,
                  child: Text(
                    widget.appState.feedbackUnread > 0
                        ? 'feedbacks (${widget.appState.feedbackUnread})'
                        : 'feedbacks',
                    style: TextStyle(
                      color: widget.appState.feedbackUnread > 0
                          ? kAccentPink
                          : kTextMuted,
                      fontWeight: widget.appState.feedbackUnread > 0
                          ? FontWeight.w800
                          : FontWeight.normal,
                    ),
                  ),
