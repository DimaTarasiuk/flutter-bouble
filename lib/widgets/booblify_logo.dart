import 'package:flutter/material.dart';

class BooblifyLogo extends StatefulWidget {
  const BooblifyLogo({super.key, this.text = 'Booblify', this.fontSize = 15});

  final String text;
  final double fontSize;

  @override
  State<BooblifyLogo> createState() => _BooblifyLogoState();
}

class _BooblifyLogoState extends State<BooblifyLogo>
    with TickerProviderStateMixin {
  static const _shineDuration = Duration(milliseconds: 4500);
  static const _waveDuration = Duration(milliseconds: 3200);
  static const _shineLetterShift = 0.18; // с, фазовий зсув shine на літеру
  static const _waveLetterDelay = 0.12; // с, затримка wave на літеру

  late final AnimationController _shine =
      AnimationController(vsync: this, duration: _shineDuration);
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: _waveDuration);

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion || (!_shine.isAnimating && !reduce)) {
      _reduceMotion = reduce;
      if (reduce) {
        _shine.stop();
        _wave.stop();
        _shine.value = 0;
        _wave.value = 0;
      } else {
        _shine.repeat();
        _wave.repeat();
      }
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.text.split('');
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([_shine, _wave]),
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              for (var i = 0; i < letters.length; i++)
                _BooblifyLetter(
                  char: letters[i],
                  fontSize: widget.fontSize,
                  shinePhase: _reduceMotion
                      ? 0
                      : (_shine.value +
                              i *
                                  _shineLetterShift /
                                  (_shineDuration.inMilliseconds / 1000)) %
                          1.0,
                  wavePhase: _reduceMotion ? 0 : _wavePhase(_wave.value, i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _wavePhase(double v, int i) {
    final offset = i * _waveLetterDelay / (_waveDuration.inMilliseconds / 1000);
    return ((v - offset) % 1.0 + 1.0) % 1.0;
  }
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

// CSS ease-in-out == Curves.easeInOut
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

class _BooblifyLetter extends StatelessWidget {
  const _BooblifyLetter({
    required this.char,
    required this.fontSize,
    required this.shinePhase,
    required this.wavePhase,
  });

  final String char;
  final double fontSize;
  final double shinePhase; // 0..1
  final double wavePhase; // 0..1

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: fontSize * 0.02,
      height: 1.35,
    );

    // Шар 1: тільки тінь (текст прозорий)
    final shadowLayer = Text(
      char,
      style: base.copyWith(
        color: Colors.transparent,
        shadows: const [
          Shadow(color: Color(0xE6FFFFFF), offset: Offset(0, 1), blurRadius: 1),
          Shadow(color: Color(0x596B8FB5), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
    );

    // Шар 2: градієнтна заливка
    final gradientLayer = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final w = bounds.width;
        // CSS: background-size 300%, position 0% -> 300% за цикл
        // => зсув вікна на 6w за цикл, період тайла = 3w
        final dx = -6 * w * shinePhase;
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _gradientColors,
          stops: _gradientStops,
          tileMode: TileMode.repeated,
        ).createShader(Rect.fromLTWH(dx, 0, 3 * w, bounds.height));
      },
      child: Text(char, style: base.copyWith(color: Colors.white)),
    );

    return Transform.translate(
      offset: Offset(0, _waveDy.transform(wavePhase)),
      child: Transform.scale(
        scale: _waveScale.transform(wavePhase),
        alignment: const Alignment(0, 0.4), // 50% 70%
        child: Stack(children: [shadowLayer, gradientLayer]),
      ),
    );
  }
}
