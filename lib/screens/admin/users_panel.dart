import 'package:flutter/material.dart';
import '../../admin_api_client.dart';
import '../../api_client.dart';
import '../../app_state.dart';
import '../../models.dart';
import '../../models_admin.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/neu.dart';
import 'user_card_screen.dart';

class UsersPanel extends StatefulWidget {
  final AppState appState;
  final AppUser me;
  const UsersPanel({super.key, required this.appState, required this.me});

  @override
  State<UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<UsersPanel> {
  final _admin = AdminApiClient();
  final _filterController = TextEditingController();
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _filterController.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _admin.users();
      if (mounted) setState(() => _users = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filterController.text.trim().toLowerCase();
    final filtered = filter.isEmpty
        ? _users
        : _users.where((u) => u.username.toLowerCase().contains(filter)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: NeuTextField(
            controller: _filterController,
            hint: 'Фільтр юзерів...',
            trailing: const Icon(Icons.filter_list, color: kTextMuted),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: AppText.error))
                  : filtered.isEmpty
                      ? const Center(child: Text('Немає користувачів', style: AppText.muted))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final u = filtered[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UserCardScreen(
                                        username: u.username,
                                        appState: widget.appState,
                                        me: widget.me,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Avatar(username: u.username, bg: kAccentPink),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(u.username, style: AppText.bodyBold),
                                                if (u.role != 'user') ...[
                                                  const SizedBox(width: 6),
                                                  Text('· ${u.role}', style: AppText.mutedSmall),
                                                ],
                                                if (u.banned) ...[
                                                  const SizedBox(width: 6),
                                                  const Text('· бан',
                                                      style: TextStyle(fontSize: 11.5, color: kDangerRed)),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              u.online ? 'Online' : (u.lastSeen ?? 'Offline'),
                                              style: AppText.mutedSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
