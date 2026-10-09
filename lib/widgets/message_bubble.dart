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

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 64;
  static const double _triggerAt = 48;

  // Локальні кольори нейоморфізму (фон як у решти екрана).
  static const Color _neuBg = Color(0xFFE0E5EC);
  static const Color _neuLight = Color(0xFFFFFFFF);
  static const Color _neuDark = Color(0x66A3B1C6);
  static const Color _myAvatarText = Color(0xFF6C8EBF);

  static const double _avatarSize = 40;

  late final AnimationController _spring;
  double _dragX = 0;
  double _snapFrom = 0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (!mounted) return;
        final t = Curves.easeOut.transform(_spring.value);
        setState(() => _dragX = _snapFrom * (1 - t));
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final t = widget.msg.createdAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String get _initials {
    final name = widget.msg.from.trim();
    if (name.isEmpty) return '?';
    return name.characters.take(2).toString().toUpperCase();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onSwipeReply == null) return;
    final next = (_dragX + d.delta.dx).clamp(0.0, _maxDrag);
    setState(() => _dragX = next);
  }

  void _onDragEnd(DragEndDetails _) {
    if (widget.onSwipeReply == null) return;
    final shouldReply = _dragX >= _triggerAt && !_triggered;
    if (shouldReply) {
      _triggered = true;
      widget.onSwipeReply!();
    }
    _snapFrom = _dragX;
    _spring.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _dragX = 0;
        _snapFrom = 0;
        _triggered = false;
      });
      _spring.reset();
    });
  }

  Widget _buildAvatar() {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: neuBox(
        d: 5,
        b: 10,
        radius: _avatarSize / 2,
        color: _neuBg,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: widget.isMine ? _myAvatarText : kAccentPink,
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final from = widget.replyPreviewFrom ?? '';
    final text = widget.replyPreviewText ?? '';
    if (text.isEmpty && from.isEmpty) return const SizedBox.shrink();

    final insetBg = widget.isMine
        ? const Color(0xFFE6EAF0)
        : const Color(0xFFEDE6EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
      decoration: neuBox(inset: true, d: 2.5, b: 5, radius: 12, color: insetBg),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: kAccentPink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (from.isNotEmpty)
                  Text(
                    from,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kAccentPink,
                    ),
                  ),
                if (from.isNotEmpty && text.isNotEmpty) const SizedBox(height: 2),
                if (text.isNotEmpty)
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kTextMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.msg.edited)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('ред.', style: TextStyle(fontSize: 11, color: kTextMuted)),
          ),
        Text(_timeLabel, style: const TextStyle(fontSize: 11.5, color: kTextMuted)),
        if (widget.msg.failed)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.error_outline, size: 13, color: kDangerRed),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.isMine;
    final bubbleColor = isMine ? kMyBubble : kTheirBubble;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;
    final hasReplyPreview =
        (widget.replyPreviewText != null && widget.replyPreviewText!.isNotEmpty) ||
            (widget.replyPreviewFrom != null && widget.replyPreviewFrom!.isNotEmpty);

    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(22),
          );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: _neuDark, blurRadius: 18, offset: Offset(7, 7)),
          BoxShadow(color: _neuLight, blurRadius: 14, offset: Offset(-5, -5)),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasReplyPreview) _buildReplyPreview(),
            Text(
              widget.msg.text,
              style: const TextStyle(fontSize: 16, color: kTextMain),
            ),
          ],
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 5),
            child: Text(
              widget.msg.from,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextMuted,
              ),
            ),
          ),
        GestureDetector(
          onLongPress: widget.onLongPress,
          child: bubble,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
          child: _buildMeta(),
        ),
      ],
    );

    final row = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: isMine ? 0 : 20),
              child: _buildAvatar(),
            ),
            const SizedBox(width: 10),
            Flexible(child: content),
          ],
        ),
      ),
    );

    if (widget.onSwipeReply == null) return row;

    final progress = (_dragX / _triggerAt).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () => _onDragEnd(DragEndDetails()),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.7 + (0.3 * progress),
                child: const Icon(Icons.reply, color: kAccentPink, size: 22),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: row,
          ),
        ],
      ),
    );
  }
}
