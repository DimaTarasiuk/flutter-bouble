import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/tokens.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isMine;
  final String? replyPreviewFrom;
  final String? replyPreviewText;
  final VoidCallback? onSwipeReply; // лише для чужих — свайп вправо
  final VoidCallback? onLongPress; // меню дій (Відповісти / Редагувати)

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMine,
    this.replyPreviewFrom,
    this.replyPreviewText,
    this.onSwipeReply,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _scale = 1.0;

  // Поріг має збігатися з dismissThresholds нижче.
  static const double _threshold = 0.2;
  static const double _shrinkTo = 0.90; // "стискається" до порогу
  static const double _bubbleTo = 1.14; // "роздувається" як лінза/бульбашка після порогу

  String get _timeLabel {
    final t = widget.msg.createdAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _handleDismissUpdate(DismissUpdateDetails details) {
    final p = details.progress.clamp(0.0, 1.0);
    double scale;
    if (!details.reached) {
      // Фаза 1: 0 → поріг — бабл плавно стискається (1.0 → _shrinkTo)
      final t = (_threshold == 0) ? 0.0 : (p / _threshold).clamp(0.0, 1.0);
      scale = 1.0 - (1.0 - _shrinkTo) * t;
    } else {
      // Фаза 2: поріг → кінець — бабл "роздувається" як лінза (_shrinkTo → _bubbleTo)
      final t = ((p - _threshold) / (1 - _threshold)).clamp(0.0, 1.0);
      scale = _shrinkTo + (_bubbleTo - _shrinkTo) * t;
    }
    if (mounted) setState(() => _scale = scale);
  }

  void _resetScale() {
    if (mounted) setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMine ? kMyBubble : kTheirBubble;
    final radius = widget.isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    Widget bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                widget.msg.from,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: kAccentPink,
                ),
              ),
            ),
          if (widget.replyPreviewText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: kAccentPink, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.replyPreviewFrom ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kAccentPink),
                  ),
                  Text(
                    widget.replyPreviewText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                ],
              ),
            ),
          Text(widget.msg.text, style: const TextStyle(fontSize: 15, color: kTextMain)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.msg.edited)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('ред.', style: TextStyle(fontSize: 10, color: kTextMuted)),
                ),
              Text(_timeLabel, style: const TextStyle(fontSize: 10.5, color: kTextMuted)),
              if (widget.msg.failed)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.error_outline, size: 12, color: kDangerRed),
                ),
            ],
          ),
        ],
      ),
    );

    final row = Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: bubble,
        ),
      ),
    );

    // AnimatedScale гарантує плавне повернення до 1.0 навіть якщо
    // onUpdate не встигає відпрацювати на кожному кадрі snap-back анімації.
    final scaledRow = AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: row,
    );

    if (!widget.isMine && widget.onSwipeReply != null) {
      return Dismissible(
        key: ValueKey('msg-${widget.msg.id}-${widget.msg.createdAt.microsecondsSinceEpoch}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: _threshold},
        movementDuration: const Duration(milliseconds: 160),
        onUpdate: _handleDismissUpdate,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Icon(Icons.reply, color: kAccentPink, size: 22),
        ),
        confirmDismiss: (_) async {
          widget.onSwipeReply!();
          _resetScale();
          return false; // ніколи не видаляємо сам елемент — лише тригер дії
        },
        child: scaledRow,
      );
    }

    return row;
  }
}
