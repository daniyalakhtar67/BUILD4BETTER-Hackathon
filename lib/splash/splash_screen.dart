import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/services.dart'; // only for t('app') and t('tagline')

// Colours are private to this file, so it cannot clash with widgets.dart.
const _indigo = Color(0xFF1B2A5C);
const _indigoDeep = Color(0xFF111B3E);
const _crimson = Color(0xFFB3202F);
const _saffron = Color(0xFFF2B33D);

/// Splash with a loading bar that fills in 5 seconds. When it reaches 100% the splash is complete
/// and onDone is called. Nothing heavy runs meanwhile: the pattern is painted once, and only the
/// thin bar (in its own layer) redraws.
class AppSplash extends StatefulWidget {
  final VoidCallback onDone;
  final Duration showFor;
  const AppSplash({super.key, required this.onDone, this.showFor = const Duration(seconds: 5)});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> with TickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _logo =
  CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack));
  late final Animation<double> _text =
  CurvedAnimation(parent: _c, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
  // Loading bar: runs for exactly [showFor], then the splash is done.
  late final AnimationController _bar = AnimationController(vsync: this, duration: widget.showFor);
  late final Animation<double> _barValue = CurvedAnimation(parent: _bar, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _c.forward();
    _bar.forward();
    _bar.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _indigoDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_indigoDeep, _indigo]),
        ),
        child: Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(child: CustomPaint(painter: _SplashPattern())),
          SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: _logo,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x1AFFFFFF),
                      border: Border.all(color: _saffron, width: 4),
                    ),
                    child: const Icon(Icons.shield, color: _saffron, size: 74),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _text,
                  child: Column(children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t('app'),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        t('tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 18, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 44),
                // Loading bar (always fills left to right) with a percentage.
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: AnimatedBuilder(
                        animation: _barValue,
                        builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _barValue.value,
                              minHeight: 10,
                              backgroundColor: const Color(0x33FFFFFF),
                              valueColor: const AlwaysStoppedAnimation(_saffron),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${(_barValue.value * 100).round()}%',
                            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Diamond pattern: one path + one batch of dots (very cheap).
class _SplashPattern extends CustomPainter {
  const _SplashPattern();

  @override
  void paint(Canvas c, Size s) {
    const step = 52.0;
    const r = step / 2.3;
    final lines = Path();
    final dots = <Offset>[];
    double y = 0;
    int row = 0;
    while (y < s.height + step) {
      double x = row % 2 == 0 ? 0 : step / 2;
      while (x < s.width + step) {
        lines
          ..moveTo(x, y - r)
          ..lineTo(x + r, y)
          ..lineTo(x, y + r)
          ..lineTo(x - r, y)
          ..close();
        dots.add(Offset(x, y));
        x += step;
      }
      y += step / 2;
      row++;
    }
    c.drawPath(
      lines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x12FFFFFF),
    );
    c.drawPoints(
      ui.PointMode.points,
      dots,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = _crimson.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}