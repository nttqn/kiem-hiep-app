import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/realm.dart';
import '../core/world.dart';
import 'art_chibi.dart';
import 'art_figures.dart';
import 'quality.dart';

/// Bí cảnh art: chests, trận nhãn, stone shrines, captives, the lair's
/// seal, and the fog over land not yet seen. All drawn at the place's feet.

const _buffColors = [Color(0xFFFF7A5A), Color(0xFF7FDBFF), Color(0xFF8CE07A)];

void drawPoi(Canvas c, Poi o, double t, {bool lairOpen = false}) {
  c.save();
  c.translate(o.x, o.y);
  switch (o.kind) {
    case PoiKind.chest:
      _chest(c, o.done, t + o.x);
    case PoiKind.pillar:
      _pillar(c, o.done, t + o.y);
    case PoiKind.shrine:
      _shrine(c, o.done, _buffColors[o.index % _buffColors.length], t + o.x);
    case PoiKind.captive:
      if (!o.done) _captive(c, o.index, t + o.x);
    case PoiKind.lair:
      _lair(c, o.done, t);
    case PoiKind.merchant:
      if (!o.done) _merchant(c, t + o.x);
    case PoiKind.vault:
      _vault(c, o.done, t);
    case PoiKind.lever:
      _lever(c, o.index, o.done, t + o.x);
    case PoiKind.star:
      if (!o.done) _star(c, t + o.x);
  }
  c.restore();
}

const _merchantLook = HumanLook(
    skin: 0xFFE0B088, robe: 0xFF5A3A6A, trim: 0xFFE0B040, pants: 0xFF3A2A3A, hair: Hair.straw);

void _merchant(Canvas c, double t) {
  // A stall: a cloth on the ground, wares, a parasol, the trader beside.
  drawShadow(c, 40);
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-46, -14, 64, 18), const Radius.circular(3)), _fill(0xFF8A2A2A));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-46, -14, 64, 18), const Radius.circular(3)), _line(0xFF3A1010, 1.2));
  c.drawCircle(const Offset(-34, -18), 6, _fill(0xFFF0C850));
  c.drawCircle(const Offset(-20, -19), 5, _fill(0xFF7FDBFF));
  c.drawRect(const Rect.fromLTWH(-10, -26, 10, 12), _fill(0xFF6A4A2A));
  c.drawCircle(const Offset(8, -18), 5, _fill(0xFFE84B4A));
  c.drawLine(const Offset(-14, -10), const Offset(-14, -96), _line(0xFF4A3018, 2.5));
  final canopy = Path()
    ..moveTo(-62, -82)
    ..quadraticBezierTo(-14, -128, 34, -82)
    ..close();
  c.drawPath(canopy, _fill(0xFFC8503A));
  c.drawPath(canopy, _line(0xFF4A1A10, 1.5));
  c.save();
  c.translate(36, 0);
  c.scale(-0.95, 0.95);
  drawChibi(c, _merchantLook, t: t);
  c.restore();
  final bob = math.sin(t * 3) * 3;
  final coin = Paint()..color = const Color(0xFFFFD34A);
  c.drawCircle(Offset(36, -96 + bob), 8, coin);
  c.drawCircle(Offset(36, -96 + bob), 8, _line(0xFF7A5A10, 1.5));
}

void _vault(Canvas c, bool open, double t) {
  // A door cut in a rock face.
  drawShadow(c, 60);
  final rock = Path()
    ..moveTo(-80, 0)
    ..lineTo(-74, -70)
    ..lineTo(-40, -108)
    ..lineTo(30, -114)
    ..lineTo(72, -78)
    ..lineTo(80, 0)
    ..close();
  c.drawPath(rock, _fill(0xFF5A5450));
  c.drawPath(rock, _line(0xFF221E1A, 2));
  final door = RRect.fromRectAndCorners(const Rect.fromLTWH(-30, -80, 60, 80),
      topLeft: const Radius.circular(30), topRight: const Radius.circular(30));
  if (open) {
    c.drawRRect(door, _fill(0xFF120C0A));
    c.drawRRect(door, Paint()
      ..color = const Color(0x55FFD34A)
      ..maskFilter = softBlur(10));
  } else {
    c.drawRRect(door, _fill(0xFF6A4A2A));
    c.drawLine(const Offset(0, -80), Offset.zero, _line(0xFF2A1808, 2));
    for (final y in const [-60.0, -30.0]) {
      c.drawLine(Offset(-28, y), Offset(28, y), _line(0xFFB8903A, 3));
    }
    final glow = 0.5 + 0.5 * math.sin(t * 2.4);
    c.drawCircle(const Offset(0, -45), 9, Paint()..color = Color.fromRGBO(160, 230, 255, 0.4 + 0.4 * glow));
  }
  c.drawRRect(door, _line(0xFF221E1A, 2));
}

void _lever(Canvas c, int mark, bool on, double t) {
  final col = on ? const Color(0xFF9FF0FF) : const Color(0xFFB8B0A0);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 70, height: 26),
      Paint()..color = col.withValues(alpha: on ? 0.35 : 0.15));
  drawShadow(c, 18);
  c.drawRect(const Rect.fromLTWH(-12, -54, 24, 54), _fill(0xFF6A6460));
  c.drawRect(const Rect.fromLTWH(-12, -54, 24, 54), _line(0xFF221E1A, 1.5));
  c.drawCircle(const Offset(0, -66), 15, _fill(0xFF4A4440));
  c.drawCircle(const Offset(0, -66), 15, _line(0xFF221E1A, 1.5));
  final p = Paint()..color = on ? col : const Color(0xFFE8DCC0);
  switch (mark) {
    case 0: // Nhật: a sun.
      c.drawCircle(const Offset(0, -66), 6, p);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        c.drawLine(Offset(math.cos(a) * 8, -66 + math.sin(a) * 8), Offset(math.cos(a) * 11.5, -66 + math.sin(a) * 11.5),
            Paint()
              ..color = p.color
              ..strokeWidth = 1.8);
      }
    case 1: // Nguyệt: a crescent.
      c.drawPath(
          Path.combine(PathOperation.difference, Path()..addOval(Rect.fromCircle(center: const Offset(0, -66), radius: 9)),
              Path()..addOval(Rect.fromCircle(center: const Offset(4, -69), radius: 8))),
          p);
    default: // Tinh: a star.
      final s = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final r = i.isEven ? 10.0 : 4.2;
        final pt = Offset(math.cos(a) * r, -66 + math.sin(a) * r);
        i == 0 ? s.moveTo(pt.dx, pt.dy) : s.lineTo(pt.dx, pt.dy);
      }
      s.close();
      c.drawPath(s, p);
  }
  if (on) {
    c.drawCircle(const Offset(0, -66), 20, Paint()
      ..color = col.withValues(alpha: 0.3 + 0.2 * math.sin(t * 4))
      ..maskFilter = softBlur(6));
  }
}

void _star(Canvas c, double t) {
  final glow = 0.5 + 0.5 * math.sin(t * 5);
  drawShadow(c, 14);
  c.drawCircle(const Offset(0, -14), 22, Paint()
    ..color = Color.fromRGBO(255, 230, 140, 0.25 + 0.2 * glow)
    ..maskFilter = softBlur(8));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -20, 26, 18), const Radius.circular(3)), _fill(0xFF3A4A8A));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -20, 26, 18), const Radius.circular(3)), _line(0xFF141A3A, 1.2));
  c.drawRect(const Rect.fromLTWH(-13, -14, 26, 3), _fill(0xFFFFE08A));
  c.drawCircle(const Offset(0, -24), 3 + glow * 1.5, _fill(0xFFFFF4C0));
}

Paint _fill(int c) => Paint()..color = Color(c);
Paint _line(int c, double w) => Paint()
  ..color = Color(c)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w;

void _chest(Canvas c, bool open, double t) {
  drawShadow(c, 28);
  final glow = 0.5 + 0.5 * math.sin(t * 3);
  if (!open) {
    c.drawCircle(const Offset(0, -18), 34,
        Paint()
          ..color = Color.fromRGBO(255, 210, 80, 0.12 + 0.12 * glow)
          ..maskFilter = softBlur(10));
  }
  const body = Rect.fromLTWH(-24, -26, 48, 26);
  c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), _fill(0xFF7A4A24));
  c.drawRect(const Rect.fromLTWH(-24, -14, 48, 4), _fill(0xFF5A3418));
  for (final x in const [-17.0, 13.0]) {
    c.drawRect(Rect.fromLTWH(x, -26, 4, 26), _fill(0xFFD8A83A));
  }
  c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), _line(0xFF2A1808, 1.6));
  if (open) {
    // The lid thrown back, gold light pouring up.
    final lid = Path()
      ..moveTo(-24, -26)
      ..lineTo(-20, -44)
      ..lineTo(20, -44)
      ..lineTo(24, -26)
      ..close();
    c.drawPath(lid, _fill(0xFF5A3418));
    c.drawPath(lid, _line(0xFF2A1808, 1.4));
    c.drawRect(const Rect.fromLTWH(-21, -30, 42, 5), _fill(0xFF2A1808));
  } else {
    final lid = Path()
      ..moveTo(-24, -26)
      ..quadraticBezierTo(0, -42, 24, -26)
      ..close();
    c.drawPath(lid, _fill(0xFF8A5A2E));
    c.drawPath(lid, _line(0xFF2A1808, 1.4));
    c.drawRect(const Rect.fromLTWH(-4, -30, 8, 9), _fill(0xFFF0C850));
    c.drawRect(const Rect.fromLTWH(-4, -30, 8, 9), _line(0xFF2A1808, 1));
    // A glint now and then.
    final g = (t * 0.7) % 1;
    if (g < 0.15) {
      final a = 1 - g / 0.15;
      final s = Paint()..color = Color.fromRGBO(255, 255, 255, a);
      c.drawCircle(const Offset(14, -34), 2.5, s);
      c.drawLine(const Offset(14, -41), const Offset(14, -27), s..strokeWidth = 1.2);
      c.drawLine(const Offset(7, -34), const Offset(21, -34), s);
    }
  }
}

void _pillar(Canvas c, bool lit, double t) {
  final pulse = 0.5 + 0.5 * math.sin(t * 2.5);
  // Rune ring on the ground.
  final ring = lit ? const Color(0xFF7FE8FF) : const Color(0xFF6A6A78);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 120, height: 44),
      Paint()
        ..color = ring.withValues(alpha: lit ? 0.5 + 0.3 * pulse : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 92, height: 32),
      Paint()
        ..color = ring.withValues(alpha: lit ? 0.35 : 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 + (lit ? t * 0.6 : 0);
    c.drawCircle(Offset(math.cos(a) * 53, math.sin(a) * 19), 2.6, Paint()..color = ring.withValues(alpha: 0.7));
  }
  drawShadow(c, 22);
  if (lit) {
    // A beam of light to the sky.
    c.drawRect(
      const Rect.fromLTWH(-14, -320, 28, 300),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xAA9FF0FF), Color(0x009FF0FF)],
        ).createShader(const Rect.fromLTWH(-14, -320, 28, 300))
        ..maskFilter = softBlur(6),
    );
  }
  final stone = Path()
    ..moveTo(-16, 0)
    ..lineTo(-12, -78)
    ..lineTo(0, -92)
    ..lineTo(12, -78)
    ..lineTo(16, 0)
    ..close();
  c.drawRect(const Rect.fromLTWH(-22, -8, 44, 10), _fill(0xFF4A4A54));
  c.drawPath(stone, _fill(lit ? 0xFF5A6A7A : 0xFF4E4E58));
  c.drawPath(Path()
    ..moveTo(-16, 0)
    ..lineTo(-12, -78)
    ..lineTo(0, -92)
    ..lineTo(0, 0)
    ..close(), _fill(0x22FFFFFF));
  c.drawPath(stone, _line(0xFF1E1E26, 1.6));
  // The rune.
  final rune = Paint()
    ..color = lit ? Color.fromRGBO(160, 240, 255, 0.7 + 0.3 * pulse) : const Color(0xFF8A8A9A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  c.drawCircle(const Offset(0, -50), 7, rune);
  c.drawLine(const Offset(0, -64), const Offset(0, -36), rune);
  c.drawLine(const Offset(-6, -44), const Offset(6, -56), rune);
}

void _shrine(Canvas c, bool used, Color col, double t) {
  final pulse = 0.5 + 0.5 * math.sin(t * 3);
  drawShadow(c, 26);
  if (!used) {
    c.drawCircle(const Offset(0, -34), 40,
        Paint()
          ..color = col.withValues(alpha: 0.18 + 0.15 * pulse)
          ..maskFilter = softBlur(12));
  }
  c.drawRect(const Rect.fromLTWH(-28, -10, 56, 12), _fill(0xFF5A5450));
  c.drawRect(const Rect.fromLTWH(-28, -10, 56, 12), _line(0xFF221E1A, 1.4));
  final stele = RRect.fromRectAndCorners(const Rect.fromLTWH(-20, -66, 40, 58),
      topLeft: const Radius.circular(18), topRight: const Radius.circular(18));
  c.drawRRect(stele, _fill(used ? 0xFF6A6460 : 0xFF8A8278));
  c.drawRRect(stele, _line(0xFF221E1A, 1.6));
  final carve = Paint()
    ..color = used ? const Color(0xFF4A4440) : col.withValues(alpha: 0.6 + 0.4 * pulse)
    ..strokeWidth = 2.2;
  for (var i = 0; i < 3; i++) {
    c.drawLine(Offset(-8.0 + i * 8, -52), Offset(-8.0 + i * 8, -18), carve);
  }
}

const _captiveLooks = [
  HumanLook(skin: 0xFFE0B088, robe: 0xFF7A6A4A, trim: 0xFF4A3A2A, pants: 0xFF5A4A3A, hair: Hair.straw),
  HumanLook(skin: 0xFFE8BC92, robe: 0xFF3A5A8A, trim: 0xFFC8A040, pants: 0xFF2A2A3A, hair: Hair.topknot),
  HumanLook(skin: 0xFFF0C8A0, robe: 0xFFE8E0D0, trim: 0xFF6A8A5A, pants: 0xFFB8B0A0, hair: Hair.bun),
  HumanLook(skin: 0xFFF2CCA8, robe: 0xFFC86A7A, trim: 0xFFF0D8A8, pants: 0xFF8A4A5A, hair: Hair.long, female: true),
  HumanLook(skin: 0xFFD8A47A, robe: 0xFF5A3A2A, trim: 0xFFB8A070, pants: 0xFF3A2A20, hair: Hair.topknot),
  HumanLook(skin: 0xFFF2CCA8, robe: 0xFFD8E4F0, trim: 0xFF3A5A7A, pants: 0xFFB8C4D0, hair: Hair.topknot),
];

void _captive(Canvas c, int who, double t) {
  drawShadow(c, 16);
  // Kneeling: drawn smaller and low, with ropes around the middle.
  c.save();
  c.translate(0, 6);
  c.scale(0.9, 0.78);
  drawChibi(c, _captiveLooks[who % _captiveLooks.length], t: t);
  c.restore();
  final rope = _line(0xFFC8A060, 2.2);
  for (final y in const [-26.0, -18.0]) {
    c.drawOval(Rect.fromCenter(center: Offset(0, y), width: 30, height: 9), rope);
  }
  // A call for help above.
  final bob = math.sin(t * 4) * 3;
  final mark = Paint()..color = const Color(0xFFFFE04A);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3, -92 + bob, 6, 14), const Radius.circular(2)), mark);
  c.drawCircle(Offset(0, -72 + bob), 3, mark);
}

void _lair(Canvas c, bool open, double t) {
  if (open) {
    // The broken seal: a faint scorched ring.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 300, height: 110), _line(0x553A1A2A, 6));
    return;
  }
  final pulse = 0.5 + 0.5 * math.sin(t * 2);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 300, height: 110),
      Paint()..color = Color.fromRGBO(120, 40, 160, 0.18 + 0.1 * pulse));
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 300, height: 110),
      Paint()
        ..color = Color.fromRGBO(200, 120, 255, 0.6 + 0.3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6 + t * 0.4;
    final o = Offset(math.cos(a) * 130, math.sin(a) * 46);
    c.drawCircle(o, 3, Paint()..color = const Color(0xFFE0B0FF));
  }
  // The dome of the seal.
  c.drawArc(const Rect.fromLTWH(-150, -150, 300, 300), math.pi, math.pi, false,
      Paint()
        ..color = Color.fromRGBO(190, 120, 255, 0.25 + 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = softBlur(4));
}

/// A Tàng Bảo Đồ spot: a red X dug into the ground, glinting.
void drawDigMark(Canvas c, double x, double y, double t) {
  final pulse = 0.5 + 0.5 * math.sin(t * 4);
  c.save();
  c.translate(x, y);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 90, height: 34),
      Paint()
        ..color = Color.fromRGBO(255, 200, 80, 0.15 + 0.15 * pulse)
        ..maskFilter = softBlur(8));
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 56, height: 22), _fill(0x553A2414));
  final x1 = Paint()
    ..color = const Color(0xFFD8302A)
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  c.drawLine(const Offset(-18, -8), const Offset(18, 8), x1);
  c.drawLine(const Offset(-18, 8), const Offset(18, -8), x1);
  // A spade stuck in the ground beside it.
  c.drawLine(const Offset(26, -2), const Offset(36, -46), _line(0xFF6A4A2A, 3));
  c.drawPath(Path()
    ..moveTo(20, -2)
    ..lineTo(32, -2)
    ..lineTo(28, 12)
    ..close(), _fill(0xFFB8B8C0));
  c.restore();
}

/// The dig spot is off screen: an arrow by the hero's feet pointing there.
void drawDigArrow(Canvas c, double hx, double hy, double tx, double ty, double t) {
  final a = math.atan2(ty - hy, tx - hx);
  final r = 70 + math.sin(t * 5) * 5;
  c.save();
  c.translate(hx + math.cos(a) * r, hy - 20 + math.sin(a) * r * 0.6);
  c.rotate(a);
  final path = Path()
    ..moveTo(14, 0)
    ..lineTo(-8, -10)
    ..lineTo(-3, 0)
    ..lineTo(-8, 10)
    ..close();
  c.drawPath(path, _fill(0xEEFFD34A));
  c.drawPath(path, _line(0xFF7A3A10, 1.5));
  c.restore();
}

/// Darkness over the cells of [w] the hero has not seen, in [view].
void drawFog(Canvas c, World w, Rect view) {
  final c0 = (view.left / fogCell).floor().clamp(0, fogCols - 1);
  final c1 = (view.right / fogCell).floor().clamp(0, fogCols - 1);
  final r0 = (view.top / fogCell).floor().clamp(0, fogRows - 1);
  final r1 = (view.bottom / fogCell).floor().clamp(0, fogRows - 1);
  final path = Path();
  var any = false;
  for (var r = r0; r <= r1; r++) {
    for (var col = c0; col <= c1; col++) {
      if (w.fog[r * fogCols + col]) continue;
      any = true;
      path.addRect(Rect.fromLTWH(col * fogCell - 30, r * fogCell - 30, fogCell + 60, fogCell + 60));
    }
  }
  if (!any) return;
  c.drawPath(
      path,
      Paint()
        ..color = const Color(0xF20A0810)
        ..maskFilter = softBlur(36));
}
