import 'package:flutter/material.dart';
import '../../admin_api_client.dart';
import '../../app_state.dart';
import '../../models_admin.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/neu.dart';

class FeedbackInboxScreen extends StatefulWidget {
  final AppState appState;
  const FeedbackInboxScreen({super.key, required this.appState});

  @override
  State<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends State<FeedbackInboxScreen> {
  final _admin = AdminApiClient();
  List<FeedbackItem> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await _admin.feedbackList();
      if (mounted) setState(() => _items = list);
      try {
        await _admin.markFeedbackRead();
        widget.appState.clearFeedbackUnread();
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _error = 'Не вдалося завантажити фідбеки');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextMain),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('Фідбеки', style: AppText.h3),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: AppText.error))
                      : _items.isEmpty
                          ? const Center(child: Text('Поки що фідбеків немає', style: AppText.muted))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _items.length,
                                itemBuilder: (context, i) {
                                  final f = _items[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: NeuCard(
                                      radius: 16,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: Text(f.username, style: AppText.bodyBold)),
                                              Text(f.createdAt, style: AppText.mutedSmall),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(f.text, style: AppText.body),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
