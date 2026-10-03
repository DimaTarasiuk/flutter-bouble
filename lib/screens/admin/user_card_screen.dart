import 'package:flutter/material.dart';
import '../../admin_api_client.dart';
import '../../api_client.dart';
import '../../app_state.dart';
import '../../models.dart';
import '../../models_admin.dart';
import '../../role_helpers.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/neu.dart';
import '../chat_screen.dart';

class UserCardScreen extends StatefulWidget {
  final String username;
  final AppState appState;
  final AppUser me;

  const UserCardScreen({super.key, required this.username, required this.appState, required this.me});

  @override
  State<UserCardScreen> createState() => _UserCardScreenState();
}

class _UserCardScreenState extends State<UserCardScreen> {
  final _admin = AdminApiClient();
  final _api = ApiClient();
  UserCardDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _admin.userDetail(widget.username);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: Text(title, style: AppText.h3),
        content: Text(message, style: AppText.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Підтвердити')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _kick() async {
    if (!await _confirm('Кік', 'Відключити користувача ${widget.username}?')) return;
    setState(() => _acting = true);
    try {
      await _admin.kick(widget.username);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Відключено')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _ban() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Забанити', style: AppText.h3),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Причина бану (опційно)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Забанити')),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _acting = true);
    try {
      await _admin.ban(widget.username, reason: reason);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _unban() async {
    if (!await _confirm('Розбанити', 'Зняти бан з ${widget.username}?')) return;
    setState(() => _acting = true);
    try {
      await _admin.unban(widget.username);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _writeMessage() async {
    try {
      final conv = await _api.openConversation(widget.username);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(appState: widget.appState, me: widget.me, conversation: conv),
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Widget _row(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: AppText.label)),
          Expanded(child: Text(value, style: AppText.bodyBold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final canModerate = d != null && !isHeadRole(d.role);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: AppText.error))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: kTextMain),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(child: Text(widget.username, style: AppText.h2)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Avatar(username: widget.username, size: 80, bg: kAccentPink),
                        ),
                        const SizedBox(height: 20),
                        NeuCard(
                          radius: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _row("Ім'я", '${d!.firstName} ${d.lastName}'.trim()),
                              _row('Стать', d.gender == 'male' ? 'Чоловіча' : d.gender == 'female' ? 'Жіноча' : ''),
                              _row('Дата народження', d.birthDate ?? ''),
                              _row('Роль', d.role),
                              _row('Зареєстрований', d.createdAt),
                              _row('Останній візит', d.lastSeen ?? ''),
                              _row('Чатів', '${d.conversationsCount}'),
                              _row('Повідомлень', '${d.messagesCount}'),
                              if (d.isBanned) ...[
                                const Divider(color: kDivider),
                                _row('Забанений', d.bannedAt ?? ''),
                                if ((d.banReason ?? '').isNotEmpty) _row('Причина', d.banReason!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        NeuButton(label: 'Написати', onTap: _writeMessage),
                        if (canModerate) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: NeuButton(
                                  label: 'Кік',
                                  onTap: _acting ? null : _kick,
                                  color: kAccentBlue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: NeuButton(
                                  label: d.isBanned ? 'Розбанити' : 'Забанити',
                                  onTap: _acting ? null : (d.isBanned ? _unban : _ban),
                                  color: kDangerRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
