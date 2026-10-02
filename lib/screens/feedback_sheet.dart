import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme/tokens.dart';
import '../widgets/neu.dart';

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _sent = false;

  static const int _maxLen = 2000;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.sendFeedback(text);
      setState(() => _sent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = 'Не вдалося надіслати');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: kShadowDark, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            if (_sent) ...[
              const SizedBox(height: 12),
              const Text('Дякуємо! Ваш відгук надіслано.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMain, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              NeuButton(label: 'Закрити', onTap: () => Navigator.of(context).pop()),
            ] else ...[
              const Text('Відгук',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextMain)),
              const SizedBox(height: 14),
              NeuTextField(
                controller: _controller,
                hint: 'Що покращити...',
                maxLines: 4,
                maxLength: _maxLen,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: kDangerRed), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              NeuButton(label: 'Надіслати', onTap: _send, loading: _sending),
            ],
          ],
        ),
      ),
    );
  }
}
