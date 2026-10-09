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

  // Локальні кольори нейоморфізму (фон як у решти екрана).
  static const Color _neuBg = Color(0xFFE0E5EC);
  static const Color _neuLight = Color(0xFFFFFFFF);
  static const Color _neuDark = Color(0x66A3B1C6);
  static const Color _myAvatarText = Color(0xFF6C8EBF);

  static const double _avatarSize = 40;

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

  Widget _buildAvatar() {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _neuBg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _neuDark, blurRadius: 8, offset: Offset(3, 3)),
          BoxShadow(color: _neuLight, blurRadius: 8, offset: Offset(-3, -3)),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: kAccentPink),
              Flexible(
                child: Container(
                  color: const Color(0x99FFFFFF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.replyPreviewFrom ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kAccentPink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyPreviewText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.replyPreviewText != null) _buildReplyPreview(),
          Text(
            widget.msg.text,
            style: const TextStyle(fontSize: 16, color: kTextMain),
          ),
        ],
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
            // Чужий аватар — на рівні низу бабла (над рядком часу),
            // мій — на рівні рядка часу, як у макеті.
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

    // AnimatedScale гарантує плавне повернення до 1.0 навіть якщо
    // onUpdate не встигає відпрацювати на кожному кадрі snap-back анімації.
    final scaledRow = AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: row,
    );

    if (!isMine && widget.onSwipeReply != null) {
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
