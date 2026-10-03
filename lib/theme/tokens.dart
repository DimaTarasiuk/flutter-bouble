import 'package:flutter/material.dart';

// ---------- Design tokens (1:1 з React-фронтом) ----------

const Color kBg = Color(0xFFE0E5EC);
const Color kShadowDark = Color(0xFFB8BEC7);
const Color kShadowLight = Color(0xFFFFFFFF);

const Color kTextMain = Color(0xFF4B5563);
const Color kTextMuted = Color(0xFF9CA3AF);

const Color kAccentBlue = Color(0xFF6B8FB5);
const Color kAccentPink = Color(0xFFC084A0);
const Color kSendGrey = Color(0xFF868E99);

const Color kOnlineMale = Color(0xFF60A5FA);
const Color kOnlineFemale = Color(0xFFF9A8D4);
const Color kOnlineDefault = Color(0xFF86EFAC);
const Color kOfflineDot = Color(0xFFC5CAD3);

const Color kDivider = Color.fromRGBO(163, 177, 198, 0.35);

const Color kMyBubble = Color(0xFFFFFFFF);
const Color kTheirBubble = Color(0xFFF5E8EE);

const Color kDangerRed = Color(0xFFD9534F);

// Аліаси для старих екранів (login/register), щоб не редагувати їх під нові назви
const Color kTextDark = kTextMain;
const Color kTextGray = kTextMuted;

Color onlineColorForGender(String? gender) {
  switch (gender) {
    case 'male':
      return kOnlineMale;
    case 'female':
      return kOnlineFemale;
    default:
      return kOnlineDefault;
  }
}

// ---------- Neumorphism decorations ----------
// neu(inset, d, b): d = offset, b = blur, спогад з CSS-специфікації

BoxDecoration neuBox({
  bool inset = false,
  double d = 4,
  double b = 8,
  double radius = 20,
  Color color = kBg,
}) {
  if (inset) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: kShadowDark,
          offset: Offset(d, d),
          blurRadius: b,
          spreadRadius: -d / 2,
        ),
        BoxShadow(
          color: kShadowLight,
          offset: Offset(-d, -d),
          blurRadius: b,
          spreadRadius: -d / 2,
        ),
      ],
    );
  }
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: kShadowDark.withOpacity(0.9), offset: Offset(d, d), blurRadius: b),
      BoxShadow(color: kShadowLight, offset: Offset(-d, -d), blurRadius: b),
    ],
  );
}

// Збережено для сумісності зі старими екранами (login/register)
BoxDecoration neuRaised({double radius = 24}) => neuBox(d: 6, b: 14, radius: radius);
BoxDecoration neuInset({double radius = 30}) => neuBox(inset: true, d: 4, b: 8, radius: radius);

// ---------- Press effect ----------
// .neu-press: scale(0.97) + inset; .neu-press-send: scale(0.93); .neu-press-soft: scale(0.96)+opacity 0.65
class NeuPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double pressedOpacity;

  const NeuPress({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.pressedOpacity = 1.0,
  });

  @override
  State<NeuPress> createState() => _NeuPressState();
}

class _NeuPressState extends State<NeuPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}
