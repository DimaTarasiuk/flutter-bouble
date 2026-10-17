import 'package:flutter/material.dart';
import '../theme/tokens.dart';

export '../theme/tokens.dart';

class NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final FocusNode? focusNode;
  final void Function(String)? onSubmitted;
  final double radius;
  final double insetDepth;
  final double verticalPadding;

  const NeuTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.focusNode,
    this.onSubmitted,
    this.radius = 20,
    this.insetDepth = 4,
    this.verticalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: neuBox(
        inset: true,
        d: insetDepth,
        b: insetDepth * 2,
        radius: radius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              maxLength: maxLength,
              minLines: minLines,
              maxLines: maxLines,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 16, color: kTextMain),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kTextMuted, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: verticalPadding),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class NeuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;

  const NeuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.color = kAccentBlue,
  });

  @override
  Widget build(BuildContext context) {
    return NeuPress(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: neuBox(d: 4, b: 8, radius: 24),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(
                label,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
              ),
      ),
    );
  }
}

class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: neuBox(d: 9, b: 18, radius: radius),
      child: child,
    );
  }
}

class Avatar extends StatelessWidget {
  final String username;
  final double size;
  final Color bg;
  final Color initialsColor;
  final bool raised; // неоморфна тінь навколо кола (для великих аватарів)
  final bool showDot;
  final bool online;
  final String? gender;

  const Avatar({
    super.key,
    required this.username,
    this.size = 44,
    this.bg = kBg,
    this.initialsColor = kNameAbbr,
    this.raised = false,
    this.showDot = false,
    this.online = false,
    this.gender,
  });

  String get _initials {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = online ? onlineColorForGender(gender) : kOfflineDot;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: raised
                ? [
                    BoxShadow(
                      color: kShadowDark.withOpacity(0.9),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                    ),
                    const BoxShadow(
                      color: kShadowLight,
                      offset: Offset(-5, -5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            _initials,
            style: TextStyle(
              color: initialsColor,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.36,
              letterSpacing: size * 0.36 * 0.02,
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                // CSS: 0 0 0 1px — тонке кільце без розмиття
                boxShadow: const [
                  BoxShadow(color: kOnlineRing, spreadRadius: 1, blurRadius: 0),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
