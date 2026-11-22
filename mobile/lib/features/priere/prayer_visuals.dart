import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/prayer.dart';

/// Animation affichée pendant un tour de prière : flamme, eau, ou braises en attente.
/// Tout est dessiné en code (CustomPainter) : aucune image, fonctionne hors ligne.
class PrayerVisualView extends StatefulWidget {
  const PrayerVisualView({super.key, required this.visual, this.size = 260});

  /// null = personne ne prie : braises qui attendent.
  final PrayerVisual? visual;
  final double size;

  @override
  State<PrayerVisualView> createState() => _PrayerVisualViewState();
}

class _PrayerVisualViewState extends State<PrayerVisualView> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final _clock = Stopwatch()..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        child: CustomPaint(
          key: ValueKey(widget.visual),
          painter: switch (widget.visual) {
            PrayerVisual.feu => _FirePainter(_ticker, _clock),
            PrayerVisual.eau => _WaterPainter(_ticker, _clock),
            null => _EmbersPainter(_ticker, _clock),
          },
        ),
      ),
    );
  }
}

/// Pseudo-aléatoire stable (même particule = même trajectoire à chaque image).
double _rnd(int i, int k) {
  final v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

abstract class _TimedPainter extends CustomPainter {
  _TimedPainter(Listenable repaint, this.clock) : super(repaint: repaint);
  final Stopwatch clock;
  double get t => clock.elapsedMilliseconds / 1000.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Feu ────────────────────────────────────────────────────────

class _FirePainter extends _TimedPainter {
  _FirePainter(super.repaint, super.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, base = h * 0.80;

    // Halo chaud qui respire.
    final pulse = 0.85 + 0.15 * math.sin(t * 2.3);
    canvas.drawCircle(
      Offset(cx, base - h * 0.22),
      w * 0.48 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8A00).withValues(alpha: 0.38),
            const Color(0xFFFF3D00).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: Offset(cx, base - h * 0.22), radius: w * 0.48)),
    );

    _logs(canvas, w, h, cx, base);

    // Langues latérales, puis corps de la flamme du plus large au plus chaud.
    _tongue(canvas, cx - w * 0.13, base, w * 0.16, h * 0.30, 1.7, const [Color(0xFFD84315), Color(0xFFFF7043)]);
    _tongue(canvas, cx + w * 0.14, base, w * 0.15, h * 0.27, 3.1, const [Color(0xFFD84315), Color(0xFFFF7043)]);
    _tongue(canvas, cx, base, w * 0.40, h * 0.62, 0.0, const [Color(0xFFBF360C), Color(0xFFFF5722), Color(0xFFFF9800)]);
    _tongue(canvas, cx, base, w * 0.30, h * 0.50, 0.9, const [Color(0xFFFF6D00), Color(0xFFFFA000), Color(0xFFFFC107)]);
    _tongue(canvas, cx, base, w * 0.19, h * 0.36, 2.2, const [Color(0xFFFFB300), Color(0xFFFFD54F), Color(0xFFFFF59D)]);
    _tongue(canvas, cx, base, w * 0.09, h * 0.20, 4.0, const [Color(0xFFFFF59D), Color(0xFFFFFDE7)]);

    // Braises qui montent.
    for (var i = 0; i < 22; i++) {
      final speed = 0.25 + _rnd(i, 1) * 0.35;
      final p = (t * speed + _rnd(i, 2)) % 1.0;
      final x = cx + (_rnd(i, 3) - 0.5) * w * 0.36 + math.sin(t * 2 + i) * w * 0.05 * p;
      final y = base - h * 0.15 - p * h * 0.75;
      final r = (1 - p) * w * 0.012 + 0.6;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Color.lerp(const Color(0xFFFFEB3B), const Color(0xFFFF5722), p)!.withValues(alpha: (1 - p) * 0.9),
      );
    }
  }

  void _tongue(Canvas canvas, double cx, double base, double width, double height, double phase, List<Color> colors) {
    final hh = height * (1 + 0.07 * math.sin(t * 6.3 + phase) + 0.04 * math.sin(t * 13.1 + phase * 2));
    final sway = width * 0.22 * math.sin(t * 2.7 + phase) + width * 0.10 * math.sin(t * 8.9 + phase);
    final tip = Offset(cx + sway, base - hh);
    final half = width / 2;

    final path = Path()
      ..moveTo(cx - half, base)
      ..cubicTo(cx - half * 1.25, base - hh * 0.40, cx - half * 0.20 + sway * 0.6, base - hh * 0.72, tip.dx, tip.dy)
      ..cubicTo(cx + half * 0.20 + sway * 0.6, base - hh * 0.72, cx + half * 1.25, base - hh * 0.40, cx + half, base)
      ..quadraticBezierTo(cx, base + half * 0.45, cx - half, base)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
        ).createShader(Rect.fromLTRB(cx - half, base - hh, cx + half, base))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  static void _logs(Canvas canvas, double w, double h, double cx, double base) {
    final wood = Paint()..color = const Color(0xFF4E342E);
    final edge = Paint()..color = const Color(0xFF6D4C41);
    for (final angle in [0.22, -0.22]) {
      canvas.save();
      canvas.translate(cx, base + h * 0.04);
      canvas.rotate(angle);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.58, height: h * 0.075),
        Radius.circular(h * 0.04),
      );
      canvas.drawRRect(r, wood);
      canvas.drawCircle(Offset(angle > 0 ? w * 0.27 : -w * 0.27, 0), h * 0.032, edge);
      canvas.restore();
    }
  }
}

// ── Eau ────────────────────────────────────────────────────────

class _WaterPainter extends _TimedPainter {
  _WaterPainter(super.repaint, super.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    final r = w * 0.40;

    // Ondes qui s'éloignent : l'eau vive.
    for (var k = 0; k < 3; k++) {
      final p = (t * 0.35 + k / 3) % 1.0;
      canvas.drawCircle(
        c,
        r * (1.0 + p * 0.25),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p) + 0.5
          ..color = const Color(0xFF29B6F6).withValues(alpha: (1 - p) * 0.55),
      );
    }

    final bowl = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.save();
    canvas.clipPath(bowl);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final level = c.dy - r * 0.15 + math.sin(t * 0.8) * r * 0.03;
    _wave(canvas, w, h, level - r * 0.06, r * 0.07, 1.6, t * 1.4, const Color(0xFF81D4FA).withValues(alpha: 0.75));
    _wave(canvas, w, h, level, r * 0.06, 2.1, -t * 1.9 + 1, const Color(0xFF29B6F6).withValues(alpha: 0.80));
    _wave(canvas, w, h, level + r * 0.10, r * 0.05, 2.7, t * 2.4 + 2, const Color(0xFF0277BD).withValues(alpha: 0.85));

    // Bulles qui remontent.
    for (var i = 0; i < 14; i++) {
      final speed = 0.18 + _rnd(i, 4) * 0.25;
      final p = (t * speed + _rnd(i, 5)) % 1.0;
      final x = c.dx + (_rnd(i, 6) - 0.5) * r * 1.4 + math.sin(t * 3 + i) * r * 0.04;
      final y = c.dy + r * 0.95 - p * (c.dy + r * 0.95 - level);
      canvas.drawCircle(
        Offset(x, y),
        r * 0.025 + _rnd(i, 7) * r * 0.03,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - p * 0.6)),
      );
    }
    canvas.restore();

    // Verre et reflet.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.82),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.06
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  static void _wave(Canvas canvas, double w, double h, double level, double amp, double k, double shift, Color color) {
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 4) {
      path.lineTo(x, level + amp * math.sin(x / w * 2 * math.pi * k + shift));
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
}

// ── En attente : braises ───────────────────────────────────────

class _EmbersPainter extends _TimedPainter {
  _EmbersPainter(super.repaint, super.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, base = h * 0.80;
    final glow = 0.5 + 0.5 * math.sin(t * 1.2);

    canvas.drawCircle(
      Offset(cx, base),
      w * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF7043).withValues(alpha: 0.10 + 0.12 * glow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, base), radius: w * 0.30)),
    );
    _FirePainter._logs(canvas, w, h, cx, base);

    for (var i = 0; i < 9; i++) {
      final x = cx + (_rnd(i, 8) - 0.5) * w * 0.38;
      final y = base - h * 0.01 + (_rnd(i, 9) - 0.5) * h * 0.04;
      final a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * (1.5 + _rnd(i, 10) * 2) + i));
      canvas.drawCircle(
        Offset(x, y),
        w * 0.012 + _rnd(i, 11) * w * 0.01,
        Paint()..color = const Color(0xFFFF6F00).withValues(alpha: a),
      );
    }
  }
}
