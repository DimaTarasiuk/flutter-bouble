import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Анімоване лого Booblify (shine + wave), як у веб-клієнті.
///
/// Малюється одним [CustomPainter] на [Ticker]. Попередня версія з
/// `ShaderMask` + `Transform` на кожну літеру робила 8 saveLayer/кадр
/// і на Android виглядала як ~10 fps.
class BooblifyLogo extends StatefulWidget {
  const BooblifyLogo({super.key, this.text = 'Booblify', this.fontSize = 15});

  final String text;
  final double fontSize;

  @override
  State<BooblifyLogo> createState() => _BooblifyLogoState();
}

class _BooblifyLogoState extends State<BooblifyLogo>
    with SingleTickerProviderStateMixin {
  // Трохи швидше за веб (4.5 / 3.2), щоб на телефоні читалось живіше.
  static const _shinePeriod = 3.2;
  static const _wavePeriod = 2.3;
  static const _shineLetterShiftSec = 0.13;
  static const _waveLetterDelaySec = 0.09;

  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier(0);
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / 1e6;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion && (_ticker.isActive || reduce)) return;
    _reduceMotion = reduce;
    if (reduce) {
      _ticker.stop();
      _seconds.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final metrics = _measure(widget.text, widget.fontSize, fontFamily);

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _seconds,
            builder: (context, t, _) {
              final shineT = _reduceMotion ? 0.0 : (t / _shinePeriod) % 1.0;
              final waveT = _reduceMotion ? 0.0 : (t / _wavePeriod) % 1.0;
              return CustomPaint(
                size: Size(metrics.width, metrics.height),
                painter: _BooblifyPainter(
                  text: widget.text,
                  fontSize: widget.fontSize,
                  fontFamily: fontFamily,
                  letterWidths: metrics.widths,
                  height: metrics.height,
                  shineT: shineT,
                  waveT: waveT,
                  shineLetterShift: _shineLetterShiftSec / _shinePeriod,
                  waveLetterDelay: _waveLetterDelaySec / _wavePeriod,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static _Metrics _measure(String text, double fontSize, String? fontFamily) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: fontSize * 0.02,
      height: 1.35,
      fontFamily: fontFamily,
    );
    final widths = <double>[];
    var w = 0.0;
    var h = fontSize * 1.35;
    for (final ch in text.characters) {
      final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      widths.add(tp.width);
      w += tp.width;
      if (tp.height > h) h = tp.height;
    }
    // Запас по вертикалі під wave (scale 1.18 + dy 2.5).
    return _Metrics(widths: widths, width: w + 2, height: h + 8);
  }
}

class _Metrics {
  const _Metrics({
    required this.widths,
    required this.width,
    required this.height,
  });
  final List<double> widths;
  final double width;
  final double height;
}

// ---------------------------------------------------------------------------

const _gradientColors = <Color>[
  Color(0xFF5B7399),
  Color(0xFF6B8FB5),
  Color(0xFF9A8BB8),
  Color(0xFFC084A0),
  Color(0xFFE01B77),
  Color(0xFFFF9EC4),
  Color(0xFFC084A0),
  Color(0xFF6B8FB5),
  Color(0xFF5B7399),
];
const _gradientStops = <double>[0, .20, .36, .50, .60, .66, .76, .90, 1];

final _waveDy = TweenSequence<double>([
  TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -2.5)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 22),
  TweenSequenceItem(
      tween: Tween(begin: -2.5, end: 0.5)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 16),
  TweenSequenceItem(
      tween: Tween(begin: 0.5, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 17),
  TweenSequenceItem(tween: ConstantTween(0.0), weight: 45),
]);

final _waveScale = TweenSequence<double>([
  TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.18)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 22),
  TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 0.97)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 16),
  TweenSequenceItem(
      tween: Tween(begin: 0.97, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 17),
  TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
]);

class _BooblifyPainter extends CustomPainter {
  _BooblifyPainter({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
    required this.letterWidths,
    required this.height,
    required this.shineT,
    required this.waveT,
    required this.shineLetterShift,
    required this.waveLetterDelay,
  });

  final String text;
  final double fontSize;
  final String? fontFamily;
  final List<double> letterWidths;
  final double height;
  final double shineT;
  final double waveT;
  final double shineLetterShift;
  final double waveLetterDelay;

  @override
  void paint(Canvas canvas, Size size) {
    final letters = text.characters.toList();
    if (letters.isEmpty) return;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: fontSize * 0.02,
      height: 1.35,
      fontFamily: fontFamily,
    );

    var x = 1.0;
    final midY = size.height / 2;

    for (var i = 0; i < letters.length; i++) {
      final w = letterWidths[i];
      final shinePhase = (shineT + i * shineLetterShift) % 1.0;
      var wavePhase = (waveT - i * waveLetterDelay) % 1.0;
      if (wavePhase < 0) wavePhase += 1.0;

      final dy = _waveDy.transform(wavePhase);
      final scale = _waveScale.transform(wavePhase);

      // Pivot 50% × 70% висоти літери.
      final letterH = fontSize * 1.35;
      final pivotX = w / 2;
      final pivotY = letterH * 0.7;

      canvas.save();
      canvas.translate(x + pivotX, midY - letterH / 2 + pivotY + dy);
      canvas.scale(scale);
      canvas.translate(-pivotX, -pivotY);

      // Drop-shadow (0, 1).
      final shadowStyle = baseStyle.copyWith(
        color: Colors.transparent,
        shadows: const [
          Shadow(color: Color(0xE6FFFFFF), offset: Offset(0, 1), blurRadius: 1),
          Shadow(color: Color(0x596B8FB5), offset: Offset(0, 1), blurRadius: 2),
        ],
      );
      TextPainter(
        text: TextSpan(text: letters[i], style: shadowStyle),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset.zero);

      // Градієнт: тайл 3w, зсув 6w за цикл (як CSS background-size 300%).
      final dx = -6 * w * shinePhase;
      final shader = ui.Gradient.linear(
        Offset(dx, 0),
        Offset(dx + 3 * w, 0),
        _gradientColors,
        _gradientStops,
        TileMode.repeated,
      );
      final fillStyle = baseStyle.copyWith(
        color: null,
        foreground: Paint()..shader = shader,
      );
      TextPainter(
        text: TextSpan(text: letters[i], style: fillStyle),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset.zero);

      canvas.restore();
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant _BooblifyPainter old) =>
      old.shineT != shineT ||
      old.waveT != waveT ||
      old.text != text ||
      old.fontSize != fontSize ||
      old.fontFamily != fontFamily;
}
