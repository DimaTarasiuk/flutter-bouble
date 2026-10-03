import 'package:flutter/material.dart';
import '../../admin_api_client.dart';
import '../../api_client.dart';
import '../../models_admin.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/neu.dart';

class AnnouncementsPanel extends StatefulWidget {
  const AnnouncementsPanel({super.key});

  @override
  State<AnnouncementsPanel> createState() => _AnnouncementsPanelState();
}

class _AnnouncementsPanelState extends State<AnnouncementsPanel> {
  final _admin = AdminApiClient();
  final _controller = TextEditingController();
  List<AdminAnnouncement> _history = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  static const int _maxLen = 2000;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _admin.announcementsHistory();
      if (mounted) setState(() => _history = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Надіслати оголошення', style: AppText.h3),
        content: const Text('Надіслати оголошення всім користувачам?', style: AppText.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Надіслати')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _admin.createAnnouncement(text);
      _controller.clear();
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        NeuCard(
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuTextField(
                controller: _controller,
                hint: 'Текст оголошення...',
                maxLines: 4,
                maxLength: _maxLen,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_controller.text.length}/$_maxLen', style: AppText.mutedSmall),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppText.error, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 10),
              NeuButton(label: 'Надіслати', onTap: _send, loading: _sending),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Історія', style: AppText.sectionTitle),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_history.isEmpty)
          const Text('Ще не було оголошень', style: AppText.muted)
        else
          ..._history.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.text, style: AppText.body),
                      const SizedBox(height: 6),
                      Text('${a.createdAt} · ${a.createdBy}', style: AppText.mutedSmall),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
