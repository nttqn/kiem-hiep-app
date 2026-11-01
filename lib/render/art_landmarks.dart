import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/scenery.dart';
import 'art_figures.dart';
import 'quality.dart';

/// Landmarks: one-off set pieces standing on a map (see `_landmarks` in
/// core/scenery.dart). Drawn at the feet, about 200 units wide.
void drawLandmark(Canvas c, Prop p, double t) {
  c.save();
  c.translate(p.x, p.y);
  c.scale(p.s);
  switch (p.kind) {
    case 'lm_shrine':
      _shrine(c, t);
    case 'lm_gate':
      _gate(c);
    case 'lm_pavilion':
      _pavilion(c);
    case 'lm_stele':
      _stele(c);
    case 'lm_buddha':
      _buddha(c, t);
    case 'lm_pagoda':
      _pagoda(c);
    case 'lm_ruin':
      _ruin(c);
    case 'lm_wreck':
      _wreck(c, t);
  }
  c.restore();
}

void _ground(Canvas c, double w, double h) {
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: w, height: h), fillOf(0x40000000));
}

/// A curved tiled roof between [x0] and [x1] at [y], eaves turned up.
void _roof(Canvas c, double x0, double x1, double y, double rise, int colr) {
  final mid = (x0 + x1) / 2;
  final p = Path()
    ..moveTo(x0 - 12, y - 4)
    ..quadraticBezierTo(x0 + 6, y + 2, x0 + 14, y)
    ..lineTo(mid - (x1 - x0) * 0.18, y - rise)
    ..lineTo(mid + (x1 - x0) * 0.18, y - rise)
    ..lineTo(x1 - 14, y)
    ..quadraticBezierTo(x1 - 6, y + 2, x1 + 12, y - 4)
    ..lineTo(x1 - 4, y + 6)
    ..lineTo(x0 + 4, y + 6)
    ..close();
  c.drawPath(p, fillOf(colr));
  for (var x = x0 + 10; x < x1 - 6; x += 9) {
    c.drawLine(Offset(x, y + 5), Offset(mid + (x - mid) * 0.4, y - rise + 3), lineOf(shade(colr, -0.25), 1));
  }
  c.drawLine(Offset(mid - (x1 - x0) * 0.18, y - rise), Offset(mid + (x1 - x0) * 0.18, y - rise),
      lineOf(shade(colr, 0.2), 3));
}

void _shrine(Canvas c, double t) {
  _ground(c, 150, 34);
  // Stone plinth, red posts, a little altar with incense.
  c.drawRect(const Rect.fromLTRB(-62, -14, 62, 0), fillOf(0xFF8A8278));
  c.drawRect(const Rect.fromLTRB(-62, -16, 62, -12), fillOf(0xFFA8A096));
  for (final x in const [-46.0, 40.0]) {
    c.drawRect(Rect.fromLTRB(x, -78, x + 7, -14), fillOf(0xFFA83228));
  }
  c.drawRect(const Rect.fromLTRB(-40, -70, 40, -14), fillOf(0xFF4A2A22));
  c.drawRect(const Rect.fromLTRB(-20, -40, 20, -14), fillOf(0xFF6A3A2A));
  c.drawRect(const Rect.fromLTRB(-10, -54, 10, -40), fillOf(0xFFD8A040));
  _roof(c, -66, 66, -78, 30, 0xFF3A4A5A);
  // Incense smoke.
  for (var i = 0; i < 3; i++) {
    final u = (t * 0.4 + i / 3) % 1;
    c.drawCircle(Offset(math.sin(t + i * 2) * 4 + (i - 1) * 6, -42 - u * 40), 2 + u * 4,
        fillOf(0xFFE8E4DC)..color = const Color(0xFFE8E4DC).withValues(alpha: 0.35 * (1 - u)));
  }
}

void _gate(Canvas c) {
  _ground(c, 230, 30);
  // A stone pailou: two pillars, two beams, a tiled crown.
  for (final x in const [-80.0, 70.0]) {
    c.drawRect(Rect.fromLTRB(x - 2, -6, x + 12, 0), fillOf(0xFF6A645E));
    c.drawRect(Rect.fromLTRB(x, -130, x + 10, -4), fillOf(0xFF9A928A));
    c.drawLine(Offset(x + 3, -126), Offset(x + 3, -10), lineOf(0xFFB8B0A6, 1.4));
  }
  c.drawRect(const Rect.fromLTRB(-90, -118, 90, -106), fillOf(0xFF8A8278));
  c.drawRect(const Rect.fromLTRB(-96, -140, 96, -128), fillOf(0xFF8A8278));
  c.drawRect(const Rect.fromLTRB(-30, -128, 30, -118), fillOf(0xFF5A2A22));
  c.drawRect(const Rect.fromLTRB(-24, -126, 24, -120), fillOf(0xFFD8B050));
  _roof(c, -104, 104, -142, 24, 0xFF4A4A52);
  // Moss on the stones.
  for (final o in const [Offset(-78, -40), Offset(74, -70), Offset(-80, -100)]) {
    c.drawCircle(o, 4, fillOf(0x885A7A3A));
  }
}

void _pavilion(Canvas c) {
  _ground(c, 170, 38);
  c.drawRect(const Rect.fromLTRB(-70, -12, 70, 0), fillOf(0xFF8A7A62));
  c.drawRect(const Rect.fromLTRB(-70, -14, 70, -10), fillOf(0xFFA8987E));
  for (final x in const [-60.0, -22.0, 16.0, 54.0]) {
    c.drawRect(Rect.fromLTRB(x, -88, x + 6, -12), fillOf(0xFF8A2A22));
  }
  // Railing and a stone table.
  c.drawRect(const Rect.fromLTRB(-60, -34, 60, -31), fillOf(0xFF6A2A20));
  c.drawOval(const Rect.fromLTRB(-16, -26, 16, -18), fillOf(0xFF9A928A));
  c.drawRect(const Rect.fromLTRB(-4, -20, 4, -12), fillOf(0xFF7A746E));
  _roof(c, -76, 76, -88, 34, 0xFF2E5A4A);
  c.drawCircle(const Offset(0, -124), 5, fillOf(0xFFD8A040));
}

void _stele(Canvas c) {
  _ground(c, 110, 30);
  // A stone turtle carrying a tall tablet of carved script.
  c.drawOval(const Rect.fromLTRB(-42, -24, 42, 0), fillOf(0xFF6E6A62));
  c.drawOval(const Rect.fromLTRB(36, -18, 54, -6), fillOf(0xFF6E6A62));
  for (final o in const [Offset(-30, -2), Offset(26, -2)]) {
    c.drawOval(Rect.fromCenter(center: o, width: 14, height: 8), fillOf(0xFF5A564E));
  }
  final slab = RRect.fromRectAndCorners(const Rect.fromLTRB(-20, -118, 20, -18),
      topLeft: const Radius.circular(14), topRight: const Radius.circular(14));
  c.drawRRect(slab, fillOf(0xFF8A847A));
  c.drawRRect(slab, lineOf(0xFF5A564E, 2));
  for (var col = 0; col < 3; col++) {
    for (var row = 0; row < 7; row++) {
      final x = -10.0 + col * 10, y = -96.0 + row * 10;
      c.drawLine(Offset(x - 3, y), Offset(x + 3, y), lineOf(0xFF4A463E, 1.4));
      c.drawLine(Offset(x, y - 3), Offset(x, y + 3), lineOf(0xFF4A463E, 1.4));
    }
  }
  c.drawArc(const Rect.fromLTRB(-14, -116, 14, -96), math.pi, math.pi, false, lineOf(0xFF5A564E, 1.6));
}

void _buddha(Canvas c, double t) {
  _ground(c, 190, 40);
  // A great seated Buddha of weathered stone, a soft halo behind.
  if (!liteGraphics) {
    c.drawCircle(const Offset(0, -122), 46,
        Paint()
          ..color = const Color(0x33FFE6A0)
          ..maskFilter = softBlur(14));
  }
  c.drawCircle(const Offset(0, -122), 40, lineOf(0x88C8B48A, 3));
  c.drawRect(const Rect.fromLTRB(-74, -18, 74, 0), fillOf(0xFF7A746C));
  // Lotus seat.
  for (var i = 0; i < 7; i++) {
    final x = -60.0 + i * 20;
    c.drawOval(Rect.fromCenter(center: Offset(x, -24), width: 26, height: 18), fillOf(0xFF8E887E));
  }
  // Crossed legs, body, head.
  c.drawOval(const Rect.fromLTRB(-64, -58, 64, -22), fillOf(0xFF8A847A));
  final body = Path()
    ..moveTo(-40, -44)
    ..quadraticBezierTo(-46, -100, -22, -112)
    ..lineTo(22, -112)
    ..quadraticBezierTo(46, -100, 40, -44)
    ..close();
  c.drawPath(body, fillOf(0xFF968F84));
  c.drawLine(const Offset(-18, -106), const Offset(10, -52), lineOf(0xFF7A746C, 2));
  c.drawOval(const Rect.fromLTRB(-14, -62, 14, -48), fillOf(0xFF8A847A));
  c.drawCircle(const Offset(0, -128), 19, fillOf(0xFF9E978C));
  c.drawCircle(const Offset(0, -146), 8, fillOf(0xFF8A847A));
  for (var i = 0; i < 9; i++) {
    c.drawCircle(Offset(-12.0 + (i % 5) * 6, -140.0 + (i ~/ 5) * 5), 2.4, fillOf(0xFF7A746C));
  }
  c.drawLine(const Offset(-7, -126), const Offset(-2, -126), lineOf(0xFF5A564E, 1.4));
  c.drawLine(const Offset(2, -126), const Offset(7, -126), lineOf(0xFF5A564E, 1.4));
  // Moss and a crack of age.
  c.drawLine(const Offset(30, -90), const Offset(18, -60), lineOf(0xFF5A564E, 1.2));
  for (final o in const [Offset(-50, -36), Offset(44, -30), Offset(-30, -100)]) {
    c.drawCircle(o, 5, fillOf(0x886A8A4A));
  }
  // Offerings burn at its feet.
  final f = math.sin(t * 9) * 1.5;
  c.drawCircle(Offset(-80, -10 + f * 0.3), 4, fillOf(0xFFFFB03A));
  c.drawCircle(Offset(80, -10 - f * 0.3), 4, fillOf(0xFFFFB03A));
}

void _pagoda(Canvas c) {
  _ground(c, 150, 34);
  for (var i = 0; i < 4; i++) {
    final y = -i * 44.0;
    final wd = 52 - i * 9.0;
    c.drawRect(Rect.fromLTRB(-wd * 0.7, y - 40, wd * 0.7, y), fillOf(i.isEven ? 0xFFE8DCC8 : 0xFFDCCFB8));
    c.drawRect(Rect.fromLTRB(-wd * 0.18, y - 30, wd * 0.18, y - 6), fillOf(0xFF4A2A22));
    _roof(c, -wd, wd, y - 40, 14, 0xFF6A2A2A);
  }
  c.drawLine(const Offset(0, -190), const Offset(0, -224), lineOf(0xFFD8A040, 3));
  for (final y in const [-200.0, -208.0, -216.0]) {
    c.drawCircle(Offset(0, y), 3.5, fillOf(0xFFD8A040));
  }
}

void _ruin(Canvas c) {
  _ground(c, 220, 40);
  // A broken wall, a toppled column and two that still stand.
  final wall = Path()
    ..moveTo(-100, 0)
    ..lineTo(-100, -60)
    ..lineTo(-80, -72)
    ..lineTo(-60, -56)
    ..lineTo(-40, -80)
    ..lineTo(-20, -48)
    ..lineTo(0, -40)
    ..lineTo(0, 0)
    ..close();
  c.drawPath(wall, fillOf(0xFF9A8A70));
  for (var y = -10.0; y > -60; y -= 14) {
    c.drawLine(Offset(-100, y), Offset(0, y), lineOf(0xFF7A6A56, 1.2));
  }
  for (final (x, h) in const [(30.0, 110.0), (70.0, 64.0)]) {
    c.drawRect(Rect.fromLTRB(x - 8, -h, x + 8, 0), fillOf(0xFFB0A088));
    c.drawRect(Rect.fromLTRB(x - 12, -h - 8, x + 12, -h), fillOf(0xFF9A8A70));
    for (var k = -4.0; k <= 4; k += 4) {
      c.drawLine(Offset(x + k, -h + 4), Offset(x + k, -6), lineOf(0xFF8A7A62, 1));
    }
  }
  c.save();
  c.translate(60, 12);
  c.rotate(0.12);
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-50, -16, 50, 0), const Radius.circular(7)),
      fillOf(0xFFA89878));
  c.restore();
}

void _wreck(Canvas c, double t) {
  _ground(c, 240, 44);
  // A junk run aground, keeled over, its mast snapped and sail in rags.
  c.save();
  c.rotate(-0.12);
  final hull = Path()
    ..moveTo(-110, -30)
    ..quadraticBezierTo(-90, 6, 0, 6)
    ..quadraticBezierTo(90, 6, 112, -40)
    ..lineTo(96, -56)
    ..lineTo(-96, -44)
    ..close();
  c.drawPath(hull, fillOf(0xFF6A4A30));
  for (var y = -40.0; y < 0; y += 9) {
    c.drawLine(Offset(-96, y), Offset(100, y - 8), lineOf(0xFF4A3220, 1.4));
  }
  // Broken planks show the ribs.
  c.drawRect(const Rect.fromLTRB(-30, -38, 10, -18), fillOf(0xFF2A1A12));
  for (var x = -26.0; x < 10; x += 8) {
    c.drawLine(Offset(x, -38), Offset(x, -18), lineOf(0xFF6A4A30, 2));
  }
  c.drawLine(const Offset(10, -50), const Offset(30, -140), lineOf(0xFF5A3A24, 6));
  final sway = math.sin(t * 1.5) * 4;
  final sail = Path()
    ..moveTo(28, -132)
    ..lineTo(70 + sway, -116)
    ..lineTo(56 + sway, -96)
    ..lineTo(66, -84)
    ..lineTo(22, -90)
    ..close();
  c.drawPath(sail, fillOf(0xFFC8A070));
  c.drawLine(const Offset(30, -140), const Offset(46, -160), lineOf(0xFF5A3A24, 4));
  c.restore();
  // Barnacles and seaweed on the sand.
  for (final o in const [Offset(-80, -8), Offset(-60, -2), Offset(84, -14)]) {
    c.drawCircle(o, 3, fillOf(0xFFE8E0D0));
  }
  c.drawLine(const Offset(-100, 0), const Offset(-110, -18), lineOf(0xFF3A6A3A, 3));
}
