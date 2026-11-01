import 'dart:math' as math;
import 'dart:ui';

import '../core/content.dart';
import '../core/scenery.dart';
import 'art_figures.dart';
import 'art_landmarks.dart';
import 'quality.dart';

class Palette {
  const Palette(this.ground, this.light, this.dark, this.edge, {this.night = 0});
  final int ground, light, dark, edge;

  /// 0..1 darkness laid over the scene (caves).
  final double night;
}

const palettes = <MapTheme, Palette>{
  MapTheme.grass: Palette(0xFF6E9B4A, 0xFF86B25A, 0xFF557A38, 0xFF2E4A22),
  MapTheme.bamboo: Palette(0xFF5F7A4C, 0xFF748F58, 0xFF4A6340, 0xFF263A22),
  MapTheme.cave: Palette(0xFF4E443B, 0xFF5E5348, 0xFF3A322B, 0xFF1A1612,
      night: 0.25),
  MapTheme.desert: Palette(0xFFD8B878, 0xFFE8CC90, 0xFFC4A262, 0xFF8A6A3A),
  MapTheme.snow: Palette(0xFFE4ECF2, 0xFFF6FAFC, 0xFFC6D4E0, 0xFF7A90A6),
  MapTheme.volcano: Palette(0xFF4A3530, 0xFF5E423A, 0xFF33241F, 0xFF1A0E0A,
      night: 0.1),
  MapTheme.fortress: Palette(0xFF4C4A52, 0xFF5C5A62, 0xFF3A3840, 0xFF1A1A20,
      night: 0.12),
  MapTheme.cloud: Palette(0xFF7E9A8C, 0xFF98B2A4, 0xFF66806F, 0xFF2E3E3A),
  MapTheme.summit: Palette(0xFF9A928A, 0xFFB0A89E, 0xFF807870, 0xFF3A3430),
  MapTheme.abyss: Palette(0xFF3A2E44, 0xFF4A3A56, 0xFF2A2032, 0xFF0E0A14, night: 0.3),
  MapTheme.sea: Palette(0xFFD8C690, 0xFFE8D8A6, 0xFFB8AC80, 0xFF3A6A78),
};

void drawGround(Canvas c, Scenery s, Rect view, double w, double h, double t) {
  final pal = palettes[s.theme]!;
  // Outside the playfield.
  c.drawRect(view.inflate(10), fillOf(pal.edge));
  c.drawRect(Rect.fromLTWH(0, 0, w, h), fillOf(pal.ground));
  for (final p in s.patches) {
    if (p.x + p.rx < view.left || p.x - p.rx > view.right ||
        p.y + p.ry < view.top || p.y - p.ry > view.bottom) {
      continue;
    }
    final colr = p.shade > 0 ? pal.light : pal.dark;
    c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: p.rx * 2, height: p.ry * 2),
        Paint()..color = Color(colr).withValues(alpha: 0.35 + p.shade.abs() * 0.3));
  }
  if (s.theme == MapTheme.fortress) _tiles(c, view, w, h, pal);
  _paths(c, s, view, pal);
  if (s.theme == MapTheme.sea) _shore(c, view, w, t);
  for (final d in s.decals) {
    if (d.x < view.left - 30 || d.x > view.right + 30 ||
        d.y < view.top - 30 || d.y > view.bottom + 30) {
      continue;
    }
    _decal(c, d, pal, t);
  }
  // Border hedge so the edge reads as a wall, not a void.
  final edge = Paint()
    ..color = Color(pal.edge).withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 40
    ..maskFilter = softBlur(14);
  c.drawRect(Rect.fromLTWH(0, 0, w, h), edge);
}

/// Worn trails: a soft dark band with a lighter tread down the middle.
void _paths(Canvas c, Scenery s, Rect view, Palette pal) {
  final snow = s.theme == MapTheme.snow;
  final outer = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 74
    ..color = Color(snow ? 0xFFB8C8D8 : pal.dark).withValues(alpha: 0.32)
    ..maskFilter = softBlur(10);
  final inner = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 40
    ..color = Color(snow ? 0xFFF8FCFF : shade(pal.light, 0.15)).withValues(alpha: 0.28);
  final area = view.inflate(200);
  for (final pts in s.paths) {
    final path = Path();
    var open = false;
    for (var i = 0; i < pts.length; i++) {
      final (x, y) = pts[i];
      final inView = area.contains(Offset(x, y)) ||
          (i + 1 < pts.length && area.contains(Offset(pts[i + 1].$1, pts[i + 1].$2)));
      if (!inView) {
        open = false;
        continue;
      }
      if (!open) {
        path.moveTo(x, y);
        open = true;
      } else {
        final (px, py) = pts[i - 1];
        path.quadraticBezierTo(px, py, (px + x) / 2, (py + y) / 2);
        path.lineTo(x, y);
      }
    }
    c.drawPath(path, outer);
    c.drawPath(path, inner);
  }
}

/// Đông Hải: the sea along the north edge, waves running up the sand.
void _shore(Canvas c, Rect view, double w, double t) {
  if (view.top > 140) return;
  final left = math.max(0.0, view.left - 20), right = math.min(w, view.right + 20);
  c.drawRect(Rect.fromLTRB(left, view.top - 20, right, 40), fillOf(0xFF3A8AA8));
  c.drawRect(Rect.fromLTRB(left, view.top - 20, right, -40), fillOf(0xFF2A6A8A));
  for (var k = 0; k < 3; k++) {
    final phase = t * 0.6 + k * 2.1;
    final reach = 40 + 22 * math.sin(phase) + k * 8;
    final path = Path()..moveTo(left, reach);
    for (var x = left; x <= right + 30; x += 30) {
      path.lineTo(x, reach + math.sin(x / 70 + phase * 2) * 6);
    }
    path
      ..lineTo(right, -60)
      ..lineTo(left, -60)
      ..close();
    c.drawPath(path, fillOf(k == 0 ? 0x553A8AA8 : (k == 1 ? 0x445AB8D0 : 0x33A8E0F0)));
    final foam = Path()..moveTo(left, reach);
    for (var x = left; x <= right + 30; x += 30) {
      foam.lineTo(x, reach + math.sin(x / 70 + phase * 2) * 6);
    }
    c.drawPath(foam, lineOf(0xCCF4FCFF, 2.4 - k * 0.6));
  }
}

void _tiles(Canvas c, Rect view, double w, double h, Palette pal) {
  final p = lineOf(pal.dark, 1.5);
  const step = 80.0;
  final x0 = (math.max(0, view.left) / step).floor() * step;
  final y0 = (math.max(0, view.top) / step).floor() * step;
  for (var x = x0; x <= math.min(w, view.right); x += step) {
    c.drawLine(Offset(x, math.max(0, view.top)), Offset(x, math.min(h, view.bottom)), p);
  }
  for (var y = y0; y <= math.min(h, view.bottom); y += step) {
    c.drawLine(Offset(math.max(0, view.left), y), Offset(math.min(w, view.right), y), p);
  }
}

void _decal(Canvas c, Decal d, Palette pal, double t) {
  final x = d.x, y = d.y, s = d.s;
  switch (d.kind) {
    case 'tuft':
      final p = lineOf(shade(pal.dark, -0.15), 1.6);
      c.drawLine(Offset(x, y), Offset(x - 3 * s, y - 7 * s), p);
      c.drawLine(Offset(x + 2, y), Offset(x + 2, y - 9 * s), p);
      c.drawLine(Offset(x + 4, y), Offset(x + 7 * s, y - 6 * s), p);
    case 'snowTuft':
      final p = lineOf(0xFF9AB0C0, 1.4);
      c.drawLine(Offset(x, y), Offset(x - 3 * s, y - 6 * s), p);
      c.drawLine(Offset(x + 3, y), Offset(x + 5 * s, y - 6 * s), p);
    case 'flower':
      final colr = const [0xFFF0E070, 0xFFF08AA0, 0xFFFFFFFF, 0xFFB08AF0][d.v % 4];
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        c.drawCircle(Offset(x + math.cos(a) * 2.6 * s, y + math.sin(a) * 2.6 * s),
            1.8 * s, fillOf(colr));
      }
      c.drawCircle(Offset(x, y), 1.4 * s, fillOf(0xFFE8A030));
    case 'pebble':
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 9 * s, height: 5 * s),
          fillOf(shade(pal.dark, -0.1)));
      c.drawOval(Rect.fromCenter(center: Offset(x - 1, y - 1), width: 6 * s, height: 3 * s),
          fillOf(shade(pal.light, 0.1)));
    case 'leaf':
      c.save();
      c.translate(x, y);
      c.rotate(d.v * 0.37);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 10 * s, height: 3 * s),
          fillOf(d.v.isEven ? 0xFF8A9A4A : 0xFF6A5A3A));
      c.restore();
    case 'bones':
      final p = lineOf(0xFFD8D0C0, 2);
      c.drawLine(Offset(x - 6 * s, y), Offset(x + 6 * s, y - 2), p);
      c.drawCircle(Offset(x + 9 * s, y - 3), 3.5 * s, fillOf(0xFFD8D0C0));
    case 'puddle':
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 30 * s, height: 12 * s),
          fillOf(0x553A6A8A));
    case 'crack':
      final glow = identical(palettes[MapTheme.volcano], pal);
      final p = lineOf(glow ? 0x99E85A2A : shade(pal.dark, -0.3), glow ? 1.6 : 1.4);
      // A jagged split, wider than tall so it lies flat on the ground.
      final k = d.v.isEven ? 1.0 : -1.0;
      c.drawLine(Offset(x - 16 * s, y - 1 * k), Offset(x - 5 * s, y + 2 * k), p);
      c.drawLine(Offset(x - 5 * s, y + 2 * k), Offset(x + 3 * s, y - 1 * k), p);
      c.drawLine(Offset(x + 3 * s, y - 1 * k), Offset(x + 15 * s, y + 1.5 * k), p);
      c.drawLine(Offset(x - 5 * s, y + 2 * k), Offset(x - 3 * s, y + 6 * k), p);
    case 'ember':
      final a = 0.5 + 0.5 * math.sin(t * 3 + d.v);
      c.drawCircle(Offset(x, y), 2.4 * s,
          Paint()..color = Color.fromRGBO(255, 140, 50, a));
    case 'ripple':
      final p = lineOf(shade(pal.dark, -0.05), 1.4);
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 30 * s, height: 8 * s),
          math.pi, math.pi, false, p);
    case 'skull':
      c.drawCircle(Offset(x, y - 2), 4 * s, fillOf(0xFFE8E0D0));
      c.drawCircle(Offset(x - 1.4 * s, y - 2), 1 * s, fillOf(0xFF3A3020));
      c.drawCircle(Offset(x + 1.4 * s, y - 2), 1 * s, fillOf(0xFF3A3020));
    case 'icePatch':
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 40 * s, height: 14 * s),
          fillOf(0x88BFE8FF));
    case 'tile':
      c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 30 * s, height: 18 * s),
          fillOf(0x22000000));
    case 'blood':
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 18 * s, height: 8 * s),
          fillOf(0x885A0A0A));
    case 'mist':
      // A slow drifting wisp of cloud lying on the ground.
      final dx = math.sin(t * 0.25 + d.v) * 18;
      c.drawOval(
          Rect.fromCenter(center: Offset(x + dx, y), width: 150 * s, height: 40 * s),
          Paint()
            ..color = Color.fromRGBO(240, 246, 248, 0.3 + 0.08 * math.sin(t * 0.5 + d.v))
            ..maskFilter = softBlur(16));
    case 'shell':
      c.save();
      c.translate(x, y);
      c.rotate(d.v * 0.6);
      final shellPath = Path()
        ..moveTo(0, 3 * s)
        ..lineTo(-5 * s, -2 * s)
        ..quadraticBezierTo(0, -7 * s, 5 * s, -2 * s)
        ..close();
      c.drawPath(shellPath, fillOf(d.v.isEven ? 0xFFF4E2D0 : 0xFFF0B8A8));
      final rib = lineOf(0x66A07860, 0.8);
      for (final k in const [-3.0, 0.0, 3.0]) {
        c.drawLine(Offset(0, 3 * s), Offset(k * s, -4 * s), rib);
      }
      c.restore();
    case 'starfish':
      final arm = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5 + d.v * 0.3;
        final r = (i.isEven ? 6.5 : 2.6) * s;
        final o = Offset(x + math.cos(a) * r, y + math.sin(a) * r * 0.7);
        if (i == 0) {
          arm.moveTo(o.dx, o.dy);
        } else {
          arm.lineTo(o.dx, o.dy);
        }
      }
      arm.close();
      c.drawPath(arm, fillOf(d.v % 3 == 0 ? 0xFFE8704A : 0xFFF0A040));
    case 'tidePool':
      // Shallow water left by the tide, its edge glinting.
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 70 * s, height: 26 * s), fillOf(0x885AA8C0));
      c.drawOval(Rect.fromCenter(center: Offset(x - 4, y - 2), width: 50 * s, height: 16 * s), fillOf(0x6680D0E0));
      final glint = 0.3 + 0.3 * math.sin(t * 2 + d.v);
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: 70 * s, height: 26 * s), math.pi * 1.1, 0.9, false,
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, glint)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    case 'petal':
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(x + i * 6 * s, y + (i - 1) * 3 * s);
        c.rotate(d.v * 0.5 + i);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 5 * s, height: 3 * s),
            fillOf(i.isEven ? 0xFFF4A8BC : 0xFFFFD0DC));
        c.restore();
      }
  }
}

/// Tall scenery, drawn at its foot point sorted with the actors.
void drawProp(Canvas c, Prop p, double t) {
  if (p.kind.startsWith('lm_')) {
    drawLandmark(c, p, t);
    return;
  }
  c.save();
  c.translate(p.x, p.y);
  c.scale(p.s);
  final v = p.v;
  switch (p.kind) {
    case 'tree' || 'tree2':
      drawShadow(c, 30);
      c.drawRect(const Rect.fromLTRB(-4, -34, 4, 0), fillOf(0xFF5A3A22));
      final base = p.kind == 'tree' ? 0xFF3E7A30 : 0xFF4E8A3A;
      final sway = math.sin(t * 0.8 + v) * 1.5;
      c.drawCircle(Offset(-12 + sway, -42), 18, fillOf(shade(base, -0.15)));
      c.drawCircle(Offset(12 + sway, -44), 17, fillOf(shade(base, -0.1)));
      c.drawCircle(Offset(sway, -60), 20, fillOf(base));
      c.drawCircle(Offset(-6 + sway, -66), 9, fillOf(shade(base, 0.2)));
      if (v % 3 == 0) {
        for (var i = 0; i < 4; i++) {
          c.drawCircle(Offset(-10.0 + i * 7 + sway, -48.0 - (i % 2) * 12), 2.4,
              fillOf(0xFFF08AA0));
        }
      }
    case 'bush':
      drawShadow(c, 20);
      c.drawCircle(const Offset(-8, -9), 10, fillOf(0xFF3E6A2E));
      c.drawCircle(const Offset(8, -10), 10, fillOf(0xFF3E6A2E));
      c.drawCircle(const Offset(0, -15), 11, fillOf(0xFF4E7E3A));
    case 'rock':
      drawShadow(c, 22);
      final p = Path()
        ..moveTo(-20, 0)
        ..lineTo(-16, -16)
        ..lineTo(-2, -24)
        ..lineTo(14, -18)
        ..lineTo(20, 0)
        ..close();
      c.drawPath(p, fillOf(0xFF7A7470));
      c.drawLine(const Offset(-2, -24), const Offset(2, -6), lineOf(0xFF5A5450, 1.6));
      c.drawPath(
          Path()
            ..moveTo(-16, -16)
            ..lineTo(-2, -24)
            ..lineTo(0, -16)
            ..close(),
          fillOf(0xFF9A948E));
    case 'snowRock':
      drawShadow(c, 22);
      final p = Path()
        ..moveTo(-20, 0)
        ..lineTo(-16, -16)
        ..lineTo(-2, -24)
        ..lineTo(14, -18)
        ..lineTo(20, 0)
        ..close();
      c.drawPath(p, fillOf(0xFF7A8A9A));
      c.drawPath(
          Path()
            ..moveTo(-17, -14)
            ..lineTo(-2, -25)
            ..lineTo(15, -17)
            ..lineTo(4, -14)
            ..close(),
          fillOf(0xFFF6FAFC));
    case 'bamboo':
      drawShadow(c, 18);
      for (var i = 0; i < 4; i++) {
        final x = -10.0 + i * 7 + (v % 5);
        final hgt = 80.0 + ((v >> i) % 30);
        final sway = math.sin(t * 1.1 + i + v) * 3;
        final stalk = lineOf(i.isEven ? 0xFF6A4A6E : 0xFF7E5A80, 4);
        c.drawLine(Offset(x, 0), Offset(x + sway, -hgt), stalk);
        for (var k = 1; k < 5; k++) {
          final ky = -hgt * k / 5;
          c.drawLine(Offset(x - 2.5 + sway * k / 5, ky), Offset(x + 2.5 + sway * k / 5, ky),
              lineOf(0xFF4A2E4E, 1.4));
        }
        for (var k = 0; k < 3; k++) {
          c.save();
          c.translate(x + sway, -hgt + k * 10);
          c.rotate((k.isEven ? -1 : 1) * 0.9 + sway * 0.05);
          c.drawOval(const Rect.fromLTRB(0, -2.5, 18, 2.5), fillOf(0xFF5E8A3A));
          c.restore();
        }
      }
    case 'stalagmite':
      drawShadow(c, 16);
      final p = Path()
        ..moveTo(-12, 0)
        ..lineTo(-3, -50 - (v % 20))
        ..lineTo(2, -38)
        ..lineTo(5, -56 - (v % 14))
        ..lineTo(13, 0)
        ..close();
      c.drawPath(p, fillOf(0xFF6A5E52));
      c.drawLine(Offset(-3, -48.0 - (v % 20)), const Offset(-6, -4), lineOf(0xFF8A7E70, 2));
    case 'crystal':
      drawShadow(c, 14);
      final colr = v.isEven ? 0xFF9C6AF0 : 0xFF5AD0F0;
      final glow = Paint()
        ..color = Color(colr).withValues(alpha: 0.3 + 0.15 * math.sin(t * 2 + v))
        ..maskFilter = softBlur(12);
      c.drawCircle(const Offset(0, -18), 22, glow);
      for (var i = -1; i <= 1; i++) {
        final hgt = 28.0 - i.abs() * 8;
        final p = Path()
          ..moveTo(i * 8 - 4.0, 0)
          ..lineTo(i * 10.0, -hgt)
          ..lineTo(i * 8 + 4.0, 0)
          ..close();
        c.drawPath(p, fillOf(colr));
        c.drawLine(Offset(i * 10.0, -hgt), Offset(i * 8.0, -2), lineOf(shade(colr, 0.5), 1));
      }
    case 'deadTree' || 'burntTree':
      drawShadow(c, 18);
      final colr = p.kind == 'deadTree' ? 0xFF7A5A3A : 0xFF2A1E1A;
      final l = lineOf(colr, 5);
      c.drawLine(Offset.zero, const Offset(2, -50), l);
      l.strokeWidth = 3;
      c.drawLine(const Offset(1, -30), const Offset(-16, -46), l);
      c.drawLine(const Offset(2, -40), const Offset(16, -58), l);
      c.drawLine(const Offset(-10, -40), const Offset(-12, -54), l);
      if (p.kind == 'burntTree') {
        c.drawCircle(const Offset(16, -58), 2.4 + math.sin(t * 5 + v) * 0.6,
            fillOf(0xFFFF6A2A));
      }
    case 'rockSpire':
      drawShadow(c, 22);
      final p = Path()
        ..moveTo(-18, 0)
        ..lineTo(-12, -40)
        ..lineTo(-4, -70)
        ..lineTo(8, -60)
        ..lineTo(14, -30)
        ..lineTo(18, 0)
        ..close();
      c.drawPath(p, fillOf(0xFFB08850));
      for (var i = 1; i < 4; i++) {
        c.drawLine(Offset(-14.0 + i, -i * 16.0), Offset(14.0 - i, -i * 16.0 + 2),
            lineOf(0xFF8A6A3A, 1.6));
      }
    case 'pillar':
      drawShadow(c, 18);
      c.drawRect(const Rect.fromLTRB(-11, -70, 11, 0), fillOf(0xFF8A847A));
      c.drawRect(const Rect.fromLTRB(-15, -76, 15, -68), fillOf(0xFF9A948A));
      c.drawRect(const Rect.fromLTRB(-14, -6, 14, 0), fillOf(0xFF7A746A));
      c.drawLine(const Offset(-4, -66), const Offset(-4, -8), lineOf(0xFF6A645A, 1.6));
      c.drawLine(const Offset(5, -66), const Offset(5, -8), lineOf(0xFF6A645A, 1.6));
      if (v % 2 == 0) {
        // Broken top.
        c.drawPath(
            Path()
              ..moveTo(-15, -76)
              ..lineTo(-2, -82)
              ..lineTo(6, -74)
              ..close(),
            fillOf(0xFF9A948A));
      }
    case 'mistPine':
      drawShadow(c, 24);
      c.drawRect(const Rect.fromLTRB(-4, -16, 4, 0), fillOf(0xFF4A3220));
      for (var i = 0; i < 3; i++) {
        final y = -14.0 - i * 20;
        final wdt = 28.0 - i * 7;
        c.drawPath(
            Path()
              ..moveTo(-wdt, y)
              ..lineTo(0, y - 32)
              ..lineTo(wdt, y)
              ..close(),
            fillOf(i.isEven ? 0xFF2A4A3E : 0xFF345A4A));
        c.drawPath(
            Path()
              ..moveTo(-wdt * 0.2, y - 6)
              ..lineTo(0, y - 32)
              ..lineTo(wdt * 0.9, y - 2)
              ..close(),
            fillOf(0x332A1A10));
      }
      // A ribbon of cloud around the trunk.
      final drift = math.sin(t * 0.4 + v) * 6;
      c.drawOval(
          Rect.fromCenter(center: Offset(drift, -22), width: 70, height: 14),
          Paint()
            ..color = const Color(0x55F2F6F8)
            ..maskFilter = softBlur(6));
    case 'plum':
      drawShadow(c, 26);
      final bark = lineOf(0xFF3A2620, 6);
      c.drawLine(Offset.zero, const Offset(-4, -30), bark);
      bark.strokeWidth = 4;
      c.drawLine(const Offset(-4, -30), const Offset(10, -52), bark);
      c.drawLine(const Offset(-4, -30), const Offset(-20, -46), bark);
      bark.strokeWidth = 2.5;
      c.drawLine(const Offset(10, -52), const Offset(4, -70), bark);
      c.drawLine(const Offset(10, -52), const Offset(26, -62), bark);
      c.drawLine(const Offset(-20, -46), const Offset(-26, -62), bark);
      final sway = math.sin(t * 0.8 + v) * 1.2;
      const spots = [
        Offset(4, -72), Offset(26, -64), Offset(-26, -64), Offset(12, -56),
        Offset(-14, -50), Offset(-2, -62), Offset(18, -70), Offset(-20, -58),
      ];
      for (var i = 0; i < spots.length; i++) {
        final o = spots[i] + Offset(sway, 0);
        c.drawCircle(o, 6.5, fillOf(i.isEven ? 0xFFF08AA6 : 0xFFF8B8C8));
        c.drawCircle(o + const Offset(-1.5, -1.5), 2.2, fillOf(0xFFFFE6EC));
      }
    case 'swordStone':
      drawShadow(c, 22);
      final p = Path()
        ..moveTo(-20, 0)
        ..lineTo(-15, -14)
        ..lineTo(-2, -20)
        ..lineTo(14, -14)
        ..lineTo(20, 0)
        ..close();
      c.drawPath(p, fillOf(0xFF7A746E));
      c.drawPath(
          Path()
            ..moveTo(-15, -14)
            ..lineTo(-2, -20)
            ..lineTo(0, -12)
            ..close(),
          fillOf(0xFF9A948E));
      // The blade sunk in the rock, hilt up.
      c.drawRect(const Rect.fromLTRB(-2, -56, 2, -16), fillOf(0xFFCFD6DE));
      c.drawLine(const Offset(0, -56), const Offset(0, -18), lineOf(0xFFFFFFFF, 0.8));
      c.drawRect(const Rect.fromLTRB(-9, -60, 9, -56), fillOf(0xFFC8962A));
      c.drawRect(const Rect.fromLTRB(-1.8, -72, 1.8, -60), fillOf(0xFF5A2A1A));
      c.drawCircle(const Offset(0, -74), 3, fillOf(0xFFC8962A));
      final glint = 0.5 + 0.5 * math.sin(t * 2.5 + v);
      c.drawCircle(
          const Offset(0, -40),
          10,
          Paint()
            ..color = Color.fromRGBO(200, 230, 255, 0.25 * glint)
            ..maskFilter = softBlur(8));
    case 'pine':
      drawShadow(c, 24);
      c.drawRect(const Rect.fromLTRB(-4, -16, 4, 0), fillOf(0xFF5A3A22));
      for (var i = 0; i < 3; i++) {
        final y = -14.0 - i * 20;
        final wdt = 28.0 - i * 7;
        c.drawPath(
            Path()
              ..moveTo(-wdt, y)
              ..lineTo(0, y - 32)
              ..lineTo(wdt, y)
              ..close(),
            fillOf(0xFF2E5A4A));
        c.drawPath(
            Path()
              ..moveTo(-wdt * 0.6, y - 12)
              ..lineTo(0, y - 32)
              ..lineTo(wdt * 0.6, y - 12)
              ..close(),
            fillOf(0xFFF2F6FA));
      }
    case 'iceCrystal':
      drawShadow(c, 16);
      for (var i = -1; i <= 1; i++) {
        final hgt = 44.0 - i.abs() * 14;
        c.drawPath(
            Path()
              ..moveTo(i * 9 - 5.0, 0)
              ..lineTo(i * 12.0, -hgt)
              ..lineTo(i * 9 + 5.0, 0)
              ..close(),
            fillOf(0xCCBFE8FF));
        c.drawLine(Offset(i * 12.0, -hgt), Offset(i * 9.0, 0), lineOf(0xFFFFFFFF, 1.2));
      }
    case 'lavaRock':
      drawShadow(c, 22);
      final p = Path()
        ..moveTo(-20, 0)
        ..lineTo(-14, -20)
        ..lineTo(0, -28)
        ..lineTo(16, -16)
        ..lineTo(20, 0)
        ..close();
      c.drawPath(p, fillOf(0xFF2E2220));
      final glow = 0.6 + 0.4 * math.sin(t * 2 + v);
      final crack = lineOf(0xFFFF6A2A, 2)
        ..color = Color.fromRGBO(255, 106, 42, glow);
      c.drawLine(const Offset(-8, -20), const Offset(-2, -6), crack);
      c.drawLine(const Offset(-2, -6), const Offset(8, -14), crack);
    case 'vent':
      drawShadow(c, 18);
      c.drawOval(const Rect.fromLTRB(-18, -8, 18, 4), fillOf(0xFF2A1A16));
      c.drawOval(const Rect.fromLTRB(-10, -5, 10, 1), fillOf(0xFFFF8A3D));
      for (var i = 0; i < 3; i++) {
        final ph = (t * 0.6 + i / 3 + v * 0.01) % 1;
        c.drawCircle(Offset(math.sin(ph * 6 + i) * 4, -10 - ph * 50), 6 + ph * 8,
            Paint()..color = Color.fromRGBO(90, 80, 80, 0.4 * (1 - ph)));
      }
    case 'lantern':
      drawShadow(c, 14);
      c.drawRect(const Rect.fromLTRB(-8, -8, 8, 0), fillOf(0xFF6A6460));
      c.drawRect(const Rect.fromLTRB(-3, -30, 3, -8), fillOf(0xFF7A7470));
      c.drawRect(const Rect.fromLTRB(-9, -44, 9, -30), fillOf(0xFF8A847E));
      c.drawRect(const Rect.fromLTRB(-5, -41, 5, -33),
          fillOf(0xFFFFB03A)..color = Color.fromRGBO(255, 176, 58, 0.7 + 0.3 * math.sin(t * 4 + v)));
      c.drawPath(
          Path()
            ..moveTo(-13, -44)
            ..lineTo(0, -54)
            ..lineTo(13, -44)
            ..close(),
          fillOf(0xFF5A5450));
    case 'banner':
      drawShadow(c, 10);
      c.drawLine(Offset.zero, const Offset(0, -90), lineOf(0xFF3A2A1A, 3));
      final wave = math.sin(t * 3 + v) * 3;
      c.drawPath(
          Path()
            ..moveTo(1, -88)
            ..lineTo(26 + wave, -86)
            ..lineTo(24 - wave, -40)
            ..lineTo(12, -46)
            ..lineTo(1, -40)
            ..close(),
          fillOf(0xFF8A0F1A));
      c.drawCircle(Offset(13 + wave * 0.5, -66), 6, fillOf(0xFF1A0A0A));
    case 'brazier':
      drawShadow(c, 14);
      c.drawLine(const Offset(-8, 0), const Offset(0, -22), lineOf(0xFF3A3434, 2.4));
      c.drawLine(const Offset(8, 0), const Offset(0, -22), lineOf(0xFF3A3434, 2.4));
      c.drawPath(
          Path()
            ..moveTo(-12, -24)
            ..lineTo(12, -24)
            ..lineTo(8, -16)
            ..lineTo(-8, -16)
            ..close(),
          fillOf(0xFF4A4444));
      for (var i = 0; i < 3; i++) {
        final f = math.sin(t * 9 + i * 2 + v) * 2;
        c.drawCircle(Offset(-5.0 + i * 5, -30 + f), 5 - i * 0.5, fillOf(0xDDFF8A3D));
      }
      c.drawCircle(Offset(0, -34 + math.sin(t * 7) * 2), 3, fillOf(0xFFFFE08A));
      final glow = Paint()
        ..color = const Color(0x55FF8A3D)
        ..maskFilter = softBlur(16);
      c.drawCircle(const Offset(0, -30), 22, glow);
    case 'palm':
      drawShadow(c, 26);
      // A leaning trunk in rings, fronds swaying, coconuts under them.
      final lean = v.isEven ? 1.0 : -1.0;
      final sway = math.sin(t * 0.9 + v) * 2;
      final top = Offset(lean * 14 + sway, -78);
      final trunk = Path()
        ..moveTo(-5, 0)
        ..quadraticBezierTo(lean * 2, -40, top.dx - 3, top.dy)
        ..lineTo(top.dx + 3, top.dy)
        ..quadraticBezierTo(lean * 8, -40, 5, 0)
        ..close();
      c.drawPath(trunk, fillOf(0xFF8A6A42));
      for (var i = 1; i < 7; i++) {
        final k = i / 7;
        final px = lean * 14 * k * k + sway * k;
        c.drawLine(Offset(px - 4.5, -78 * k), Offset(px + 4.5, -78 * k - 2), lineOf(0xFF6A4E30, 1.4));
      }
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + (i - 2.5) * 0.62 + math.sin(t * 1.1 + i + v) * 0.05;
        final end = top + Offset(math.cos(a) * 36, math.sin(a) * 18 + 14);
        final mid = top + Offset(math.cos(a) * 20, math.sin(a) * 16 - 2);
        final frond = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(mid.dx, mid.dy - 6, end.dx, end.dy)
          ..quadraticBezierTo(mid.dx, mid.dy + 4, top.dx, top.dy)
          ..close();
        c.drawPath(frond, fillOf(i.isEven ? 0xFF3E8A3A : 0xFF4E9E44));
      }
      for (final o in const [Offset(-3, 4), Offset(3, 5), Offset(0, 8)]) {
        c.drawCircle(top + o, 3.4, fillOf(0xFF6A4A22));
      }
    case 'coral':
      drawShadow(c, 18);
      final colr = const [0xFFF07A6A, 0xFFF0A0C0, 0xFFE8C060][v % 3];
      final cp = lineOf(colr, 4.5)..strokeCap = StrokeCap.round;
      c.drawLine(Offset.zero, const Offset(-2, -20), cp);
      c.drawLine(const Offset(-2, -12), const Offset(-12, -24), cp);
      c.drawLine(const Offset(-1, -16), const Offset(9, -30), cp);
      cp.strokeWidth = 3;
      c.drawLine(const Offset(-12, -24), const Offset(-14, -32), cp);
      c.drawLine(const Offset(9, -30), const Offset(14, -36), cp);
      c.drawLine(const Offset(-2, -20), const Offset(-1, -34), cp);
      for (final o in const [Offset(-14, -33), Offset(14, -37), Offset(-1, -35)]) {
        c.drawCircle(o, 2.4, fillOf(shade(colr, 0.25)));
      }
    case 'anchor':
      drawShadow(c, 18);
      final iron = lineOf(0xFF4A5058, 4)..strokeCap = StrokeCap.round;
      c.save();
      c.rotate(0.35 * (v.isEven ? 1 : -1));
      c.drawLine(const Offset(0, -2), const Offset(0, -36), iron);
      c.drawLine(const Offset(-9, -30), const Offset(9, -30), iron);
      c.drawCircle(const Offset(0, -40), 4, lineOf(0xFF4A5058, 2.6));
      c.drawArc(const Rect.fromLTRB(-14, -16, 14, 4), 0.2, math.pi - 0.4, false, iron);
      c.restore();
  }
  c.restore();
}

/// Rough visual height of a prop, used to fade ones in front of the hero.
double propHeight(Prop p) => switch (p.kind) {
      'lm_pagoda' || 'lm_buddha' || 'lm_gate' => 170 * p.s,
      'lm_shrine' || 'lm_pavilion' || 'lm_wreck' || 'lm_ruin' || 'lm_stele' => 120 * p.s,
      'tree' || 'tree2' || 'bamboo' || 'banner' || 'pillar' || 'pine' || 'mistPine' || 'plum' || 'palm' => 90 * p.s,
      'rockSpire' || 'stalagmite' || 'deadTree' || 'burntTree' || 'swordStone' => 60 * p.s,
      _ => 30 * p.s,
    };

double propHalfWidth(Prop p) => switch (p.kind) {
      'lm_wreck' || 'lm_ruin' || 'lm_gate' => 100 * p.s,
      'lm_shrine' || 'lm_pavilion' || 'lm_pagoda' || 'lm_buddha' => 70 * p.s,
      'lm_stele' => 40 * p.s,
      'tree' || 'tree2' || 'pine' || 'mistPine' || 'plum' || 'palm' => 34 * p.s,
      _ => 20 * p.s,
    };
