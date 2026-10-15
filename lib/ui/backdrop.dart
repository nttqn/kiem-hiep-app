import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/hanh.dart';
import '../render/art_figures.dart';

/// Ink-wash mountains at dusk, with drifting mist. [town] adds a city gate.
class Backdrop extends StatefulWidget {
  const Backdrop({super.key, this.town = false, this.child});
  final bool town;
  final Widget? child;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _BackdropPainter(_t, widget.town)),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t, this.town) : super(repaint: t);
  final ValueNotifier<double> t;
  final bool town;

  @override
  void paint(Canvas c, Size s) {
    final time = t.value;
    final w = s.width, h = s.height;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A2E), Color(0xFF7A3A3A), Color(0xFFD8945A)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & s),
    );
    // Sun.
    c.drawCircle(Offset(w * 0.72, h * 0.42), h * 0.13,
        Paint()..color = const Color(0xFFF8D8A0));
    c.drawCircle(
        Offset(w * 0.72, h * 0.42),
        h * 0.24,
        Paint()
          ..color = const Color(0x44F8D8A0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    // Mountain ranges, far to near.
    const layers = [
      (0.50, 0xFF6A3A48, 0.18, 3.0),
      (0.60, 0xFF4A2A3A, 0.22, 5.0),
      (0.72, 0xFF2E1C28, 0.20, 8.0),
    ];
    for (var i = 0; i < layers.length; i++) {
      final (base, colr, amp, seed) = layers[i];
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 20; x += 20) {
        final n = math.sin(x / w * 5 + seed) * 0.5 +
            math.sin(x / w * 11 + seed * 2) * 0.3 +
            math.sin(x / w * 23 + seed * 3) * 0.12;
        p.lineTo(x, h * (base - amp * (0.5 + n * 0.6)));
      }
      p
        ..lineTo(w, h)
        ..close();
      c.drawPath(p, Paint()..color = Color(colr));
      // Mist band.
      final drift = (time * (6 + i * 4)) % w;
      for (var k = -1; k < 3; k++) {
        c.drawOval(
          Rect.fromCenter(
              center: Offset(k * w * 0.5 + drift, h * (base + 0.02)),
              width: w * 0.5,
              height: h * 0.06),
          Paint()
            ..color = const Color(0x22F3E6C8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
    }
    // Pagoda on a crag.
    _pagoda(c, Offset(w * 0.2, h * 0.5), h * 0.16, const Color(0xFF3A2230));
    if (town) _gate(c, s);
    // Ground.
    c.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14), Paint()..color = const Color(0xFF1A1016));
    // Falling petals.
    final rnd = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final sx = rnd.nextDouble() * w, sp = 20 + rnd.nextDouble() * 30;
      final y = (rnd.nextDouble() * h + time * sp) % h;
      final x = (sx + math.sin(time + i) * 30 + time * 12) % w;
      c.save();
      c.translate(x, y);
      c.rotate(time * 2 + i);
      c.drawOval(const Rect.fromLTRB(-3, -1.5, 3, 1.5), Paint()..color = const Color(0xCCF8B8C8));
      c.restore();
    }
  }

  void _pagoda(Canvas c, Offset base, double size, Color colr) {
    final p = Paint()..color = colr;
    for (var i = 0; i < 4; i++) {
      final y = base.dy - i * size * 0.24;
      final wdt = size * (0.5 - i * 0.08);
      c.drawRect(Rect.fromLTRB(base.dx - wdt * 0.55, y - size * 0.2, base.dx + wdt * 0.55, y), p);
      final roof = Path()
        ..moveTo(base.dx - wdt, y - size * 0.18)
        ..quadraticBezierTo(base.dx, y - size * 0.3, base.dx + wdt, y - size * 0.18)
        ..lineTo(base.dx + wdt * 0.6, y - size * 0.26)
        ..lineTo(base.dx - wdt * 0.6, y - size * 0.26)
        ..close();
      c.drawPath(roof, p);
    }
    c.drawLine(Offset(base.dx, base.dy - size * 1.05), Offset(base.dx, base.dy - size * 1.25),
        p..strokeWidth = 2);
  }

  void _gate(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final wall = Paint()..color = const Color(0xFF2A1A1E);
    c.drawRect(Rect.fromLTRB(0, h * 0.62, w, h * 0.88), wall);
    for (var x = 0.0; x < w; x += 26) {
      c.drawRect(Rect.fromLTRB(x, h * 0.6, x + 16, h * 0.63), wall);
    }
    final cx = w * 0.5;
    final roof = Path()
      ..moveTo(cx - w * 0.2, h * 0.5)
      ..quadraticBezierTo(cx, h * 0.38, cx + w * 0.2, h * 0.5)
      ..lineTo(cx + w * 0.14, h * 0.46)
      ..quadraticBezierTo(cx, h * 0.4, cx - w * 0.14, h * 0.46)
      ..close();
    c.drawRect(Rect.fromLTRB(cx - w * 0.14, h * 0.48, cx + w * 0.14, h * 0.64), wall);
    c.drawPath(roof, Paint()..color = const Color(0xFF5A1A1A));
    c.drawRect(Rect.fromLTRB(cx - w * 0.05, h * 0.68, cx + w * 0.05, h * 0.88),
        Paint()..color = const Color(0xFF0E0808));
    c.drawRect(Rect.fromLTRB(cx - w * 0.04, h * 0.505, cx + w * 0.04, h * 0.56),
        Paint()..color = const Color(0xFFB08A3A));
    // Lanterns.
    for (final dx in [-0.09, 0.09]) {
      c.drawOval(Rect.fromCenter(center: Offset(cx + w * dx, h * 0.6), width: 14, height: 18),
          Paint()..color = const Color(0xFFE84B3A));
      c.drawCircle(Offset(cx + w * dx, h * 0.6), 16,
          Paint()
            ..color = const Color(0x55FFB03A)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

/// An animated standing hero: idles, and strikes every few seconds.
class FigurePreview extends StatefulWidget {
  const FigurePreview({super.key, required this.hanh, this.female = false, this.scale = 2.4, this.glow = 0});
  final Hanh hanh;
  final bool female;
  final double scale;
  final int glow;

  @override
  State<FigurePreview> createState() => _FigurePreviewState();
}

class _FigurePreviewState extends State<FigurePreview> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(76 * widget.scale, 92 * widget.scale),
      painter: _FigurePainter(_t, widget.hanh, widget.female, widget.scale, widget.glow),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.t, this.hanh, this.female, this.scale, this.glow) : super(repaint: t);
  final ValueNotifier<double> t;
  final Hanh hanh;
  final bool female;
  final double scale;
  final int glow;

  @override
  void paint(Canvas c, Size s) {
    final time = t.value;
    final cycle = time % 3.2;
    final attack = cycle < 0.33 ? 1 - cycle / 0.33 : 0.0;
    c.save();
    c.translate(s.width * 0.42, s.height - 6 * scale);
    c.scale(scale);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 14),
        Paint()..color = Color(hanh.color).withValues(alpha: 0.35));
    drawShadow(c, 16);
    setClock(time);
    drawHuman(c, heroLook(hanh, female: female, glow: glow),
        attack: attack, cast: hanh == Hanh.moc || hanh == Hanh.thuy || hanh == Hanh.tho, t: time);
    c.restore();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.hanh != hanh || old.female != female || old.glow != glow;
}
