import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../session_store.dart';
import '../presence_service.dart';
import '../widgets/neu.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();
  final _presence = PresenceService();

  AppUser? _me;
  List<Conversation> _conversations = [];
  List<Announcement> _announcements = [];
  Set<String> _online = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _presence.connect();
    _presence.events.listen(_onPresenceEvent);
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  void _onPresenceEvent(PresenceEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case 'presence_snapshot':
        final list = (e.raw['online'] as List?)?.cast<String>() ?? [];
        setState(() => _online = list.toSet());
        break;
      case 'presence':
        final user = e.raw['user'] as String?;
        final online = e.raw['online'] as bool? ?? false;
        if (user != null) {
          setState(() {
            if (online) {
              _online.add(user);
            } else {
              _online.remove(user);
            }
          });
        }
        break;
      case 'force_logout':
        _forceLogout();
        break;
      case 'announcement':
        final a = e.raw['announcement'];
        if (a is Map<String, dynamic>) {
          setState(() => _announcements = [Announcement.fromJson(a), ..._announcements]);
        }
        break;
      case 'chat_message':
        _loadConversations();
        break;
    }
  }

  Future<void> _forceLogout() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _api.me();
      final conversations = await _api.conversations();
      final announcements = await _api.pendingAnnouncements();
      if (!mounted) return;
      setState(() {
        _me = me;
        _conversations = conversations;
        _announcements = announcements;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _forceLogout();
        return;
      }
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadConversations() async {
    try {
      final list = await _api.conversations();
      if (mounted) setState(() => _conversations = list);
    } catch (_) {}
  }

  Future<void> _ack(Announcement a) async {
    try {
      await _api.ackAnnouncement(a.id);
      setState(() => _announcements.removeWhere((x) => x.id == a.id));
    } catch (_) {}
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    await _presence.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _buildHeader(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: kDangerRed)),
                    ],
                    if (_announcements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Оголошення',
                          style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
                      const SizedBox(height: 12),
                      ..._announcements.map(_buildAnnouncement),
                    ],
                    const SizedBox(height: 24),
                    const Text('Розмови',
                        style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark)),
                    const SizedBox(height: 12),
                    if (_conversations.isEmpty)
                      const Text('Поки що немає розмов', style: TextStyle(color: kTextGray))
                    else
                      ..._conversations.map(_buildConversation),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final me = _me;
    return NeuCard(
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: neuRaised(radius: 26),
            child: const Icon(Icons.person, color: kAccentBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me?.username ?? '...',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kTextDark),
                ),
                Text(
                  me?.role ?? '',
                  style: const TextStyle(color: kTextGray, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: kTextGray),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncement(Announcement a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        radius: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.text, style: const TextStyle(color: kTextDark)),
                  const SizedBox(height: 4),
                  Text('— ${a.createdBy}',
                      style: const TextStyle(color: kTextGray, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _ack(a),
              child: const Text('Ок', style: TextStyle(color: kAccentBlue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(Conversation c) {
    final isOnline = _online.contains(c.peer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuCard(
        radius: 20,
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: neuRaised(radius: 20),
                  child: const Icon(Icons.person, size: 20, color: kAccentBlue),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: kBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(c.peer,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark)),
            ),
            if (c.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${c.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
