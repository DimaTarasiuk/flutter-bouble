import 'package:flutter/material.dart';

const Color kBg = Color(0xFFE3E7ED);
const Color kShadowDark = Color(0xFFB9C1CE);
const Color kShadowLight = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF3D4552);
const Color kTextGray = Color(0xFF8B94A3);
const Color kAccentBlue = Color(0xFF3B7DDD);
const Color kDangerRed = Color(0xFFD9534F);

BoxDecoration neuRaised({double radius = 24}) {
  return BoxDecoration(
    color: kBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: kShadowDark.withOpacity(0.7),
        offset: const Offset(6, 6),
        blurRadius: 14,
      ),
      BoxShadow(
        color: kShadowLight.withOpacity(0.9),
        offset: const Offset(-6, -6),
        blurRadius: 14,
      ),
    ],
  );
}

BoxDecoration neuInset({double radius = 30}) {
  return BoxDecoration(
    color: kBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: kShadowDark.withOpacity(0.6),
        offset: const Offset(4, 4),
        blurRadius: 8,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: kShadowLight.withOpacity(0.9),
        offset: const Offset(-4, -4),
        blurRadius: 8,
        spreadRadius: -2,
      ),
    ],
  );
}

class NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;

  const NeuTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: neuInset(),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 16, color: kTextDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kTextGray, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (trailing != null) trailing!,
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
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: neuRaised(radius: 30),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
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
      decoration: neuRaised(radius: radius),
      child: child,
    );
  }
}
