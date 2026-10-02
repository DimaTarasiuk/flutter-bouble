import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/tokens.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage msg;
  final bool isMine;
  final String? replyPreviewFrom;
  final String? replyPreviewText;
  final VoidCallback? onSwipeReply; // лише для чужих
  final VoidCallback? onLongPressEdit; // лише для своїх, у вікні 10 хв

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMine,
    this.replyPreviewFrom,
    this.replyPreviewText,
    this.onSwipeReply,
    this.onLongPressEdit,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _dragX = 0;
  static const double _maxDrag = 72;
  static const double _triggerDrag = 56;

  String get _timeLabel {
    final t = widget.msg.createdAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onSwipeReply == null) return;
    setState(() {
      _dragX = (_dragX + d.delta.dx).clamp(0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragX >= _triggerDrag) {
      widget.onSwipeReply?.call();
    }
    setState(() => _dragX = 0);
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

    if (widget.onLongPressEdit != null) {
      bubble = GestureDetector(
        onLongPress: widget.onLongPressEdit,
        child: bubble,
      );
    }

    final row = Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Transform.translate(
          offset: Offset(widget.isMine ? 0 : _dragX, 0),
          child: bubble,
        ),
      ),
    );

    if (widget.onSwipeReply == null) return row;

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: row,
    );
  }
}
