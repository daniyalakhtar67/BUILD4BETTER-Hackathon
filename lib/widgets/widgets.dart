import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../services/services.dart';
import '../string/string.dart';

// Ajrak-inspired palette: deep indigo + crimson on warm cream. High contrast on purpose.
const cream = Color(0xFFFFF8EC);
const indigo = Color(0xFF1B2A5C);
const indigoDeep = Color(0xFF111B3E);
const crimson = Color(0xFFB3202F);
const saffron = Color(0xFFF2B33D);
const safeGreen = Color(0xFF1E7B4F);
const warnAmber = Color(0xFFB86A00);
const ink = Color(0xFF1A1A2E);

/// The ONE font used everywhere (English, Urdu, Sindhi). Must match pubspec.yaml.
/// If the font files are missing, Flutter falls back to the phone font.
const String kFont = 'Cairo';

Color levelColor(Level l) => l == Level.safe ? safeGreen : (l == Level.suspicious ? warnAmber : crimson);

IconData levelIcon(Level l) =>
    l == Level.safe ? Icons.check_circle : (l == Level.suspicious ? Icons.warning_amber_rounded : Icons.dangerous);

String levelKey(Level l) => l == Level.safe ? 'safe' : (l == Level.suspicious ? 'suspicious' : 'scam');

Color _darken(Color c, [double amt = 0.12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amt).clamp(0.0, 1.0).toDouble()).toColor();
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: kFont,
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(seedColor: indigo, primary: indigo, secondary: crimson),
  // The default Android 12 "sparkle" ripple compiles a shader on first tap, which feels like a
  // freeze. The classic ripple has no such delay.
  splashFactory: InkRipple.splashFactory,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 20, height: 1.4),
    bodyMedium: TextStyle(fontSize: 18, height: 1.4),
  ),
  navigationBarTheme: NavigationBarThemeData(
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final sel = states.contains(WidgetState.selected);
      return TextStyle(
        fontFamily: kFont,
        fontSize: 14,
        fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
        color: sel ? indigo : Colors.black54,
      );
    }),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: indigoDeep,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

/// One look for every text box in the app.
InputDecoration fieldDecoration(String label, IconData icon, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(fontSize: 18),
  hintStyle: const TextStyle(fontSize: 18, color: Colors.black38),
  prefixIcon: Icon(icon, color: indigo, size: 28),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: indigo.withValues(alpha: 0.35), width: 1.5)),
  focusedBorder:
  OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: indigo, width: 2.5)),
);

// ───────────── Rebuilds its child whenever language / settings change ─────────────
class AppScope extends StatelessWidget {
  final WidgetBuilder builder;
  const AppScope({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) => builder(c));
}

// ───────────── Entrance animation (runs on the GPU, no per-frame rebuilds) ─────────────
class FadeSlide extends StatefulWidget {
  final Widget child;
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  State<FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<FadeSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: Duration(milliseconds: 300 + widget.index * 50));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _s = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(_a);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: SlideTransition(position: _s, child: widget.child));
}

// ───────────── Header pattern (cheap: one path + one batch of dots) ─────────────
class AjrakPainter extends CustomPainter {
  const AjrakPainter();

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
          ..color = const Color(0x12FFFFFF));
    c.drawPoints(
        ui.PointMode.points,
        dots,
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x99B3202F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class AjrakHeader extends StatelessWidget {
  final Widget child;
  const AjrakHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [indigoDeep, indigo]),
        ),
        child: Stack(children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: AjrakPainter()))),
          SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 18), child: child),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────── Header with a title and numbered steps ─────────────
class HeaderStep {
  final IconData icon;
  final String text;
  const HeaderStep(this.icon, this.text);
}

class StepsHeader extends StatelessWidget {
  final String title;
  final List<HeaderStep> steps;
  const StepsHeader({super.key, required this.title, required this.steps});

  Widget _row(int n, HeaderStep s) => Row(children: [
    Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: saffron, shape: BoxShape.circle),
      child: Text('$n', style: const TextStyle(color: indigoDeep, fontSize: 20, fontWeight: FontWeight.w900)),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Text(s.text,
          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600, height: 1.3)),
    ),
    const SizedBox(width: 8),
    Icon(s.icon, color: Colors.white70, size: 28),
  ]);

  @override
  Widget build(BuildContext context) {
    return AjrakHeader(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Align(alignment: AlignmentDirectional.centerEnd, child: LangChips()),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _row(i + 1, steps[i]),
            ],
          ]),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}

// ───────────── Round app logo ─────────────
class LogoBadge extends StatelessWidget {
  final double size;
  const LogoBadge({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.10),
      border: Border.all(color: saffron, width: 2.5),
    ),
    child: Icon(Icons.shield, color: saffron, size: size * 0.58),
  );
}

// ───────────── Splash screen ─────────────
// Shows for about 0.9 s. Only the logo and text animate (GPU transitions), the pattern is one cached layer.
// `ready` is optional: if given, the splash also waits for it before calling onDone.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  final Future<void>? ready;
  const SplashScreen({super.key, required this.onDone, this.ready});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
  late final Animation<double> _logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
  late final Animation<double> _text = CurvedAnimation(parent: _c, curve: const Interval(0.25, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 650)),
      widget.ready ?? Future<void>.value(),
    ]).then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [indigoDeep, indigo]),
        ),
        child: Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(child: CustomPaint(painter: AjrakPainter())),
          SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: _logo,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                      border: Border.all(color: saffron, width: 4),
                    ),
                    child: const Icon(Icons.shield, color: saffron, size: 80),
                  ),
                ),
                const SizedBox(height: 26),
                FadeTransition(
                  opacity: _text,
                  child: Column(children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(t('app'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(t('tagline'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 19, height: 1.4)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────── Language chips ─────────────
class LangChips extends StatelessWidget {
  const LangChips({super.key});

  @override
  Widget build(BuildContext context) {
    const labels = ['EN', 'اردو', 'سنڌي'];
    return AppScope(
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final sel = app.lang == i;
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: () {
                HapticFeedback.selectionClick();
                app.setLang(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? saffron : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: sel ? saffron : Colors.white60, width: 1.5),
                ),
                child: Text(labels[i],
                    style: TextStyle(color: sel ? indigoDeep : Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ───────────── Buttons & cards ─────────────
class BigButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const BigButton({super.key, required this.text, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: ElevatedButton.icon(
        onPressed: onTap == null
            ? null
            : () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        icon: Icon(icon, size: 30),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: color.withValues(alpha: 0.5),
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  /// Red outline and red text, for things like "Remove".
  final bool danger;
  const SoftButton({super.key, required this.text, required this.icon, required this.onTap, this.iconColor, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final main = danger ? crimson : indigo;
    return SizedBox(
      height: 60,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon, size: 24, color: iconColor ?? main),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: danger ? crimson : ink)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: Colors.white,
          side: BorderSide(color: main.withValues(alpha: 0.45), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

/// Small rounded label with an icon, e.g. "Server not reachable".
class StatusPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const StatusPill({super.key, required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Flexible(child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, height: 1.3))),
    ]),
  );
}

/// Section heading with a coloured icon badge.
class SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const SectionTitle({super.key, required this.text, required this.icon, this.color = indigo});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink))),
  ]);
}

class ActionCard extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const ActionCard({super.key, required this.title, required this.sub, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, _darken(color)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Row(children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 17, height: 1.3)),
                ]),
              ),
              Icon(rtl ? Icons.chevron_left : Icons.chevron_right, color: Colors.white70, size: 30),
            ]),
          ),
        ),
      ),
    );
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const WhiteCard({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: indigo.withValues(alpha: 0.07), width: 1),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: child,
  );
}

// ───────────── Risk gauge ─────────────
class RiskGauge extends StatelessWidget {
  final int score;
  final Level level;
  const RiskGauge({super.key, required this.score, required this.level});

  @override
  Widget build(BuildContext context) {
    final col = levelColor(level);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: 210,
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: CustomPaint(painter: _GaugePainter(v, col))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(levelIcon(level), color: col, size: 62),
              Text('${(v * 100).round()}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: col)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final Color color;
  _GaugePainter(this.v, this.color);

  @override
  void paint(Canvas c, Size s) {
    const sw = 26.0;
    final rect = Rect.fromLTWH(sw / 2, sw / 2, s.width - sw, s.height - sw);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1F000000);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..color = color;
    const start = 135 * math.pi / 180;
    const sweep = 270 * math.pi / 180;
    c.drawArc(rect, start, sweep, false, base);
    if (v > 0) c.drawArc(rect, start, sweep * v, false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.v != v || old.color != color;
}

// ───────────── Pulsing mic button ─────────────
class PulseMic extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  const PulseMic({super.key, required this.active, required this.onTap});

  @override
  State<PulseMic> createState() => _PulseMicState();
}

class _PulseMicState extends State<PulseMic> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant PulseMic old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(alignment: Alignment.center, children: [
        // Soft ring so the button looks tappable even when idle.
        Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: (widget.active ? crimson : indigo).withValues(alpha: 0.18), width: 3),
          ),
        ),
        if (widget.active)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Opacity(
                opacity: 0.45 * (1 - _c.value),
                child: Transform.scale(scale: 1 + 0.5 * _c.value, child: child),
              ),
              child: Container(width: 130, height: 130, decoration: const BoxDecoration(color: crimson, shape: BoxShape.circle)),
            ),
          ),
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: widget.active ? crimson : indigo,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Icon(widget.active ? Icons.stop_rounded : Icons.mic, color: Colors.white, size: 62),
            ),
          ),
        ),
      ]),
    );
  }
}

// ───────────── Result card ─────────────
class ResultCard extends StatelessWidget {
  final Verdict v;
  final VoidCallback onSpeak;
  final VoidCallback onFamily;
  const ResultCard({super.key, required this.v, required this.onSpeak, required this.onFamily});

  @override
  Widget build(BuildContext context) {
    final col = levelColor(v.level);
    final adviceKey = v.level == Level.safe ? 'advice_safe' : (v.level == Level.suspicious ? 'advice_suspicious' : 'advice_scam');
    final shown = v.reasons.where(Strings.has).toList();
    return FadeSlide(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: col, width: 3),
          boxShadow: [BoxShadow(color: col.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          RiskGauge(score: v.score, level: v.level),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)),
            child: Text(t(levelKey(v.level)),
                textAlign: TextAlign.center, style: TextStyle(color: col, fontSize: 28, fontWeight: FontWeight.w900, height: 1.2)),
          ),
          const SizedBox(height: 12),
          Text(v.advice ?? t(adviceKey), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, height: 1.45)),
          if (shown.isNotEmpty) ...[
            const Divider(height: 28),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(t('why'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            for (final k in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: col, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t(k), style: const TextStyle(fontSize: 19, height: 1.4))),
                ]),
              ),
          ],
          const SizedBox(height: 6),
          Text(t(v.fromServer ? 'by_server' : 'by_phone'), style: const TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: SoftButton(text: t('read_aloud'), icon: Icons.volume_up, onTap: onSpeak)),
          if (v.level != Level.safe) ...[
            const SizedBox(height: 12),
            BigButton(text: t('tell_family'), icon: Icons.share, color: crimson, onTap: onFamily),
          ],
        ]),
      ),
    );
  }
}