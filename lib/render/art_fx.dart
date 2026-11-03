import 'dart:math' as math;
import 'dart:ui';

import '../core/hanh.dart';
import '../core/items.dart';
import '../core/world.dart';
import 'art_figures.dart';
import 'quality.dart';

/// Colour of the rebirth aura after [n] rebirths: jade, sky, violet,
/// crimson, then gold.
int rebirthColor(int n) => const [
      0xFF5AE0A0,
      0xFF5AC8FF,
      0xFFB06AFF,
      0xFFFF5A6A,
      0xFFFFD34A,
    ][(n - 1).clamp(0, 4)];

/// The aura under a reborn hero, drawn at the feet before the figure: a
/// pillar of soft light, a turning ring of runes and rising motes. It grows
/// with each rebirth.
void drawRebirthAura(Canvas c, int n, double t) {
  if (n <= 0) return;
  final colr = Color(rebirthColor(n));
  final k = 0.85 + n * 0.06;
  // Light pillar behind the body.
  c.drawOval(
      Rect.fromCenter(center: const Offset(0, -34), width: 46 * k, height: 84),
      Paint()
        ..color = colr.withValues(alpha: 0.16 + 0.05 * math.sin(t * 2))
        ..maskFilter = softBlur(14));
  // Ground glow and ring.
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 62 * k, height: 22 * k),
      Paint()
        ..color = colr.withValues(alpha: 0.28)
        ..maskFilter = softBlur(6));
  final ring = Paint()
    ..color = colr.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 56 * k, height: 19 * k), ring);
  // Runes turning on the ring; a second, counter-turning ring from the
  // third rebirth on.
  for (var r = 0; r < (n >= 3 ? 2 : 1); r++) {
    final dir = r == 0 ? 1.0 : -1.0;
    final rw = (r == 0 ? 28 : 20) * k, rh = (r == 0 ? 9.5 : 6.8) * k;
    final count = 6 + n;
    for (var i = 0; i < count; i++) {
      final a = dir * t * 0.8 + i * math.pi * 2 / count;
      final p = Offset(math.cos(a) * rw, math.sin(a) * rh);
      final s = 1.6 + (math.sin(a) + 1) * 0.6;
      final d = Path()
        ..moveTo(p.dx, p.dy - s * 1.6)
        ..lineTo(p.dx + s, p.dy)
        ..lineTo(p.dx, p.dy + s * 1.6)
        ..lineTo(p.dx - s, p.dy)
        ..close();
      c.drawPath(d, Paint()..color = colr.withValues(alpha: 0.6 + 0.4 * (math.sin(a) + 1) / 2));
    }
  }
  // Motes drifting up.
  for (var i = 0; i < 4 + n * 2; i++) {
    final ph = (t * 0.45 + i * 0.37) % 1;
    final x = math.sin(i * 2.3 + t * 0.7) * 20 * k;
    c.drawCircle(Offset(x, -ph * 70), 1.6 * (1 - ph) + 0.6,
        Paint()..color = colr.withValues(alpha: 0.8 * (1 - ph)));
  }
}

const _gold = 0xFFFFD34A;
const _fire = 0xFFFF7A2A;
const _ice = 0xFF9FE3FF;
const _poison = 0xFF8CE05A;
const _earth = 0xFFC9A15A;

Paint _glow(int argb, double alpha, double blur) => Paint()
  ..color = Color(argb).withValues(alpha: alpha.clamp(0, 1))
  ..maskFilter = softBlur(blur);

Paint _a(int argb, double alpha) =>
    Paint()..color = Color(argb).withValues(alpha: alpha.clamp(0, 1));

Paint _stroke(int argb, double alpha, double w) => Paint()
  ..color = Color(argb).withValues(alpha: alpha.clamp(0, 1))
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

/// Effects that sit on the ground, drawn before the actors.
bool isGroundFx(String k) => const {
      'quake', 'buddha', 'fireRing', 'healWater', 'potionHp', 'potionMp',
      'swordOrbitGround',
    }.contains(k);

void drawFx(Canvas c, Fx f, double t) {
  final p = (f.t / f.life).clamp(0.0, 1.0);
  final fade = 1 - p;
  switch (f.kind) {
    case 'staff' || 'saber' || 'arcGold' || 'arcFire':
      final colr = switch (f.kind) {
        'arcGold' => _gold,
        'arcFire' => _fire,
        'saber' => 0xFFFFE6C0,
        _ => 0xFFFFF2C0,
      };
      final big = f.kind.startsWith('arc');
      final sweep = f.spread * (0.4 + 0.6 * Curves.easeOut(math.min(1, p * 2.5)));
      final r = f.radius * (big ? 0.95 : 0.85);
      final rect = Rect.fromCircle(center: Offset(f.x, f.y - 24), radius: r);
      final path = Path()
        ..addArc(rect, f.angle - f.spread / 2, sweep)
        ..arcTo(Rect.fromCircle(center: Offset(f.x, f.y - 24), radius: r * 0.62),
            f.angle - f.spread / 2 + sweep, -sweep, false)
        ..close();
      c.drawPath(path, _a(colr, 0.55 * fade));
      c.drawPath(path, _glow(colr, 0.5 * fade, 6));
      c.drawArc(rect, f.angle - f.spread / 2, sweep, false,
          _stroke(0xFFFFFFFF, 0.9 * fade, big ? 4 : 2.5));
      if (f.color != 0) {
        // The sect's element trails the swing: a coloured edge and an
        // after-image a step behind.
        c.drawArc(Rect.fromCircle(center: Offset(f.x, f.y - 24), radius: r * 1.06), f.angle - f.spread / 2, sweep,
            false, _stroke(f.color, 0.8 * fade, 3.2));
        if (!liteGraphics) {
          c.drawArc(Rect.fromCircle(center: Offset(f.x, f.y - 24), radius: r * 1.1), f.angle - f.spread / 2,
              sweep * 0.7, false, _glow(f.color, 0.45 * fade, 5)..style = PaintingStyle.stroke..strokeWidth = 7);
        }
      }
      if (big) {
        // Skill swings: a wide blaze of light behind the blade, two
        // after-images and sparks thrown off the tip.
        final cy = f.y - 24;
        c.drawPath(path, _glow(colr, 0.55 * fade, 16));
        for (var k = 1; k <= 2; k++) {
          final rk = r * (1 + 0.12 * k);
          c.drawArc(Rect.fromCircle(center: Offset(f.x, cy), radius: rk), f.angle - f.spread / 2, sweep * (1 - 0.18 * k),
              false, _stroke(colr, (0.55 - 0.18 * k) * fade, 6.0 - k * 1.5));
        }
        final tipA = f.angle - f.spread / 2 + sweep;
        _sparks(c, f.x + math.cos(tipA) * r, cy + math.sin(tipA) * r, 10, 60, f.kind == 'arcFire' ? 0xFFFFD08A : 0xFFFFF3C4, p,
            salt: f.x);
      }
      if (f.kind == 'arcGold') {
        // Golden glyph-strokes riding the arc.
        for (var i = 0; i < 5; i++) {
          final a = f.angle - f.spread / 2 + sweep * (i + 0.5) / 5;
          final rr = r * (0.8 + 0.1 * (i % 2));
          final x = f.x + math.cos(a) * rr, y = f.y - 24 + math.sin(a) * rr;
          c.drawCircle(Offset(x, y), 7 * fade + 2, _glow(0xFFFFF3C4, 0.8 * fade, 5));
          c.drawLine(Offset(x - 5, y), Offset(x + 5, y), _stroke(0xFFFFFFFF, fade, 2));
          c.drawLine(Offset(x, y - 5), Offset(x, y + 5), _stroke(0xFFFFFFFF, fade, 2));
        }
      }
      if (f.kind == 'arcFire') {
        // Flames licking up along the cut.
        for (var i = 0; i < 9; i++) {
          final a = f.angle - f.spread / 2 + sweep * i / 8;
          final rr = r * (0.72 + 0.2 * _h(i));
          final x = f.x + math.cos(a) * rr, y = f.y - 24 + math.sin(a) * rr;
          _flame(c, x, y + 8, 7 * fade + 3, (26 + 14 * _h(i, 3)) * fade + 6, i.isEven ? _fire : 0xFFFFB03A, 0.9 * fade, t, i);
          _flame(c, x, y + 6, 3 * fade + 1.5, (14 + 8 * _h(i, 4)) * fade + 3, 0xFFFFF0B0, fade, t, i + 3);
        }
      }
    case 'quake':
      // The ground heaves: a dust ring, a second shock behind it, jagged
      // cracks, and rocks thrown up that fall back.
      final r = f.radius * Curves.easeOut(p);
      c.drawOval(_flat(f.x, f.y, r * 1.05), _glow(0xFFB89A6A, 0.45 * fade, 14));
      c.drawOval(_flat(f.x, f.y, r * 0.7), _a(0xFF8A6A3A, 0.4 * fade));
      c.drawOval(_flat(f.x, f.y, r), _stroke(_earth, fade, 12 * fade + 2));
      c.drawOval(_flat(f.x, f.y, r * 0.62), _stroke(0xFFE8D0A0, 0.8 * fade, 4 * fade + 1));
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 + 0.3;
        c.drawPath(_crack(f.x, f.y, a, f.radius * (0.7 + 0.3 * _h(i)) * math.min(1, p * 3), i),
            _stroke(0xFF4A2E14, fade, 3.2)..style = PaintingStyle.stroke);
      }
      for (var i = 0; i < (liteGraphics ? 6 : 12); i++) {
        final a = _h(i, 5) * math.pi * 2;
        final d = f.radius * (0.25 + 0.6 * _h(i, 6)) * Curves.easeOut(p);
        final up = math.sin(math.min(1, p * 1.4) * math.pi) * (40 + 50 * _h(i, 7));
        final x = f.x + math.cos(a) * d, y = f.y + math.sin(a) * d * 0.5 - up;
        final s = 4 + 5 * _h(i, 8);
        c.save();
        c.translate(x, y);
        c.rotate(p * 8 * (_h(i, 9) - 0.5));
        c.drawPath(
            Path()
              ..moveTo(-s, -s * 0.4)
              ..lineTo(-s * 0.2, -s)
              ..lineTo(s, -s * 0.3)
              ..lineTo(s * 0.6, s * 0.7)
              ..lineTo(-s * 0.7, s * 0.6)
              ..close(),
            _a(i.isEven ? 0xFF8A6A3A : 0xFFB8946A, fade));
        c.restore();
      }
    case 'buddha':
      final r = f.radius * Curves.easeOut(math.min(1, p * 1.6));
      c.drawOval(_flat(f.x, f.y, r), _glow(_gold, 0.45 * fade, 18));
      c.drawOval(_flat(f.x, f.y, r), _stroke(_gold, fade, 5));
      c.drawOval(_flat(f.x, f.y, r * 0.65), _stroke(0xFFFFF3C4, fade, 2));
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6 + t;
        c.drawLine(Offset(f.x, f.y - 40),
            Offset(f.x + math.cos(a) * r, f.y - 40 + math.sin(a) * r * 0.6),
            _stroke(0xFFFFF3C4, 0.5 * fade, 3));
      }
      c.drawCircle(Offset(f.x, f.y - 46), 30 * (1 - p * 0.5), _glow(0xFFFFF8E0, fade, 14));
      // A pillar of light and lotus petals rising out of it.
      c.drawRect(Rect.fromLTRB(f.x - 26 * fade, f.y - 220 * math.min(1, p * 3), f.x + 26 * fade, f.y),
          _glow(0xFFFFF3C4, 0.5 * fade, 12));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + p * 2;
        final d = r * (0.3 + 0.5 * p);
        final x = f.x + math.cos(a) * d, y = f.y + math.sin(a) * d * 0.5 - p * 90 * (0.6 + _h(i));
        c.save();
        c.translate(x, y);
        c.rotate(a);
        c.drawOval(const Rect.fromLTRB(-8, -3.5, 8, 3.5), _a(i.isEven ? 0xFFFFE8B0 : 0xFFFFC8D8, 0.9 * fade));
        c.restore();
      }
    case 'bell':
      // Kim Chung Tráo: a great golden bell drops over the hero with a
      // ring, then hums; runes turn round its rim.
      final pulse = 1 + math.sin(t * 6) * 0.025;
      final end = math.min(1.0, (f.life - f.t) * 2);
      final drop = Curves.easeOut(math.min(1.0, f.t * 5));
      final top = f.y - 108 * pulse - (1 - drop) * 80;
      final w = 46 * pulse, base = f.y + 6 - (1 - drop) * 80;
      final bell = Path()
        ..moveTo(f.x - w - 6, base)
        ..quadraticBezierTo(f.x - w + 2, base - 24, f.x - w + 4, base - 50)
        ..quadraticBezierTo(f.x - w + 6, top + 4, f.x, top)
        ..quadraticBezierTo(f.x + w - 6, top + 4, f.x + w - 4, base - 50)
        ..quadraticBezierTo(f.x + w - 2, base - 24, f.x + w + 6, base)
        ..close();
      c.drawPath(bell, _glow(_gold, 0.2 * end, 14));
      c.drawPath(bell, _a(0xFFFFE08A, 0.1 * end));
      c.drawPath(bell, _stroke(0xFFFFE8A0, 0.85 * end, 2.5));
      // Bands and studs.
      for (final k in const [0.3, 0.62]) {
        final y = base - (base - top) * k;
        c.drawLine(Offset(f.x - w * (1.02 - k * 0.3), y), Offset(f.x + w * (1.02 - k * 0.3), y),
            _stroke(_gold, 0.7 * end, 3));
      }
      for (var i = -2; i <= 2; i++) {
        c.drawCircle(Offset(f.x + i * w * 0.32, base - (base - top) * 0.46), 2.6, _a(0xFFFFF3C4, 0.8 * end));
      }
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(f.x, top - 6), width: 16, height: 12), const Radius.circular(5)),
          _stroke(_gold, 0.8 * end, 2.5));
      // Rim of turning runes.
      for (var i = 0; i < 10; i++) {
        final a = t * 1.6 + i * math.pi / 5;
        final x = f.x + math.cos(a) * (w + 10), y = base + math.sin(a) * 9;
        c.drawCircle(Offset(x, y), 2.4 + (math.sin(a) + 1), _a(0xFFFFF3C4, (0.4 + 0.3 * (math.sin(a) + 1)) * end));
      }
      // The clang when it lands.
      if (f.t > 0.18 && f.t < 0.7) {
        final k = (f.t - 0.18) / 0.52;
        c.drawOval(_flat(f.x, base, 50 + 90 * k), _stroke(0xFFFFF3C4, 1 - k, 5 * (1 - k) + 1));
        c.drawPath(bell, _a(0xFFFFFFFF, 0.35 * (1 - k)));
      }
    case 'earthShield':
      // Stone plates rise from the ground and circle the hero inside an
      // amber dome.
      final end = math.min(1.0, (f.life - f.t) * 2);
      final rise = Curves.easeOut(math.min(1.0, f.t * 3));
      final dome = Rect.fromCenter(center: Offset(f.x, f.y - 34), width: 92, height: 100);
      c.drawOval(dome, _glow(0xFFE8B860, 0.18 * end, 12));
      c.drawOval(dome, _a(0xFFE8C880, 0.1 * end));
      c.drawOval(dome, _stroke(0xFFE8C880, 0.55 * end, 2));
      c.drawOval(_flat(f.x, f.y, 50), _stroke(_earth, 0.6 * end, 3));
      for (var i = 0; i < 8; i++) {
        final a = t * 1.3 + i * math.pi / 4;
        final front = math.sin(a) > 0;
        final x = f.x + math.cos(a) * 44, y = f.y - 26 + math.sin(a) * 14 + (1 - rise) * 40;
        final s = 9.0 * (front ? 1.15 : 0.9);
        final hex = Path();
        for (var k = 0; k < 6; k++) {
          final ha = k * math.pi / 3 + math.pi / 6;
          final px = x + math.cos(ha) * s, py = y + math.sin(ha) * s * 1.2;
          k == 0 ? hex.moveTo(px, py) : hex.lineTo(px, py);
        }
        hex.close();
        c.drawPath(hex, _a(front ? 0xFFC9A15A : 0xFF9A7A4A, (front ? 0.9 : 0.55) * end * rise));
        c.drawPath(hex, _stroke(0xFF5A3A1A, 0.9 * end * rise, 1.4));
        c.drawLine(Offset(x - s * 0.4, y - s * 0.3), Offset(x + s * 0.2, y + s * 0.4), _stroke(0xFF6A4A2A, 0.6 * end * rise, 1));
      }
      if (f.t < 0.5) {
        _sparks(c, f.x, f.y, 10, 70, 0xFFB89A6A, f.t / 0.5, lift: 30, salt: 3);
      }
    case 'healWater' || 'potionHp' || 'potionMp':
      if (f.kind == 'healWater') {
        // A ribbon of water spirals up round the hero, a lotus opens at
        // the feet and droplets fall back as light.
        c.drawOval(_flat(f.x, f.y, 44 + 20 * p), _glow(0xFF7CF0B0, 0.45 * fade, 10));
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final open = Curves.easeOut(math.min(1.0, p * 3));
          c.save();
          c.translate(f.x + math.cos(a) * 20 * open, f.y + math.sin(a) * 8 * open);
          c.rotate(a);
          c.drawOval(Rect.fromCenter(center: const Offset(12, 0), width: 26 * open, height: 9), _a(0xFFBFF8E0, 0.75 * fade));
          c.restore();
        }
        for (var s = 0; s < 2; s++) {
          final path = Path();
          for (var k = 0; k <= 24; k++) {
            final u = k / 24;
            final a = u * math.pi * 4 + t * 5 + s * math.pi;
            final x = f.x + math.cos(a) * (30 - u * 8), y = f.y - u * 110 * math.min(1, p * 2.5) + math.sin(a) * 9;
            k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          c.drawPath(path, _stroke(s == 0 ? 0xFF7CF0B0 : 0xFF9FE3FF, 0.8 * fade, 4 * fade + 1.5));
          if (!liteGraphics) c.drawPath(path, _glow(0xFF7CF0B0, 0.5 * fade, 6)..style = PaintingStyle.stroke..strokeWidth = 8);
        }
        for (var i = 0; i < 6; i++) {
          final rise = (p * 1.4 + i / 6) % 1;
          final x = f.x + (_h(i) - 0.5) * 60, y = f.y - 20 - rise * 90;
          final s = 4.5 * (1 - rise) + 1.5;
          c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 2.4, height: s * 0.8), _a(0xFFE8FFF0, fade * (1 - rise)));
          c.drawRect(Rect.fromCenter(center: Offset(x, y), width: s * 0.8, height: s * 2.4), _a(0xFFE8FFF0, fade * (1 - rise)));
        }
        return;
      }
      final colr = f.kind == 'potionMp' ? 0xFF6AA8FF : (f.kind == 'potionHp' ? 0xFFFF7A7A : 0xFF7CF0B0);
      for (var i = 0; i < 10; i++) {
        final a = i * 2.4;
        final rise = (p + i / 10) % 1;
        c.drawCircle(Offset(f.x + math.cos(a) * 18, f.y - rise * 70),
            3 * (1 - rise) + 1, _a(colr, fade));
      }
      c.drawOval(_flat(f.x, f.y, 28 * (0.6 + p)), _stroke(colr, 0.6 * fade, 2));
    case 'fireRing':
      // A wall of fire racing outward, scorched ground inside, embers up.
      final r = f.radius * Curves.easeOut(math.min(1, p * 1.8));
      c.drawOval(_flat(f.x, f.y, r), _a(0xFF3A1A0A, 0.25 * fade));
      c.drawOval(_flat(f.x, f.y, r), _glow(_fire, 0.6 * fade, 16));
      c.drawOval(_flat(f.x, f.y, r), _stroke(0xFFFFE08A, 0.9 * fade, 3));
      final n = liteGraphics ? 14 : 24;
      for (var i = 0; i < n; i++) {
        final a = i * math.pi * 2 / n + p;
        final x = f.x + math.cos(a) * r, y = f.y + math.sin(a) * r * 0.5;
        final h = (30 + 16 * _h(i)) * fade + 6;
        _flame(c, x, y, 9 * fade + 3, h, i.isEven ? _fire : 0xFFFF5A2A, 0.95 * fade, t, i);
        _flame(c, x, y, 5 * fade + 1.5, h * 0.6, 0xFFFFD08A, fade, t, i + 5);
      }
      for (var i = 0; i < 10; i++) {
        final up = (p * 1.6 + i / 10) % 1;
        final a = _h(i, 2) * math.pi * 2;
        c.drawCircle(Offset(f.x + math.cos(a) * r * 0.9, f.y + math.sin(a) * r * 0.45 - up * 80), 2.6 * (1 - up) + 0.6,
            _a(0xFFFFD08A, fade * (1 - up)));
      }
    case 'fireDash':
      // A comet of flame: blazing trail, after-images of fire and embers
      // left burning on the path.
      final dx = f.x2 - f.x, dy = f.y2 - f.y;
      final len = math.sqrt(dx * dx + dy * dy);
      final head = math.min(1.0, p * 2.2);
      final ux = len > 0 ? dx / len : 1.0, uy = len > 0 ? dy / len : 0.0;
      final trail = Path()
        ..moveTo(f.x - uy * 6, f.y - 20 + ux * 6)
        ..lineTo(f.x + dx * head - uy * 22, f.y - 20 + dy * head + ux * 22)
        ..lineTo(f.x + dx * head + ux * 26, f.y - 20 + dy * head + uy * 26)
        ..lineTo(f.x + dx * head + uy * 22, f.y - 20 + dy * head - ux * 22)
        ..lineTo(f.x + uy * 6, f.y - 20 - ux * 6)
        ..close();
      c.drawPath(trail, _glow(_fire, 0.6 * fade, 14));
      c.drawPath(trail, _a(0xFFFF7A2A, 0.55 * fade));
      for (var i = 0; i < 16; i++) {
        final k = i / 15;
        if (k > head) break;
        final x = f.x + dx * k, y = f.y + dy * k;
        _flame(c, x + (_h(i) - 0.5) * 16, y + 4, 7 * fade + 2, (22 + 18 * _h(i, 1)) * fade * (0.4 + 0.6 * k) + 4,
            i.isEven ? _fire : 0xFFFFB03A, 0.9 * fade, t, i);
      }
      c.drawCircle(Offset(f.x + dx * head, f.y - 20 + dy * head), 22 * fade + 6, _glow(0xFFFFE08A, fade, 10));
      _sparks(c, f.x + dx * head, f.y - 20 + dy * head, 12, 70, 0xFFFFD08A, p, lift: 20, salt: 9);
    case 'swordOrbit':
      // A ring of light on the ground and blades sweeping round it, each
      // with a fading wake.
      c.drawOval(_flat(f.x, f.y, f.radius * 0.8), _stroke(0xFFFFF3C4, 0.35, 2));
      c.drawOval(_flat(f.x, f.y, f.radius * 0.8), _glow(0xFFFFF3C4, 0.12, 10));
      for (var i = 0; i < 4; i++) {
        final a0 = t * 6 + i * math.pi / 2;
        final wake = Path();
        for (var k = 0; k <= 8; k++) {
          final a = a0 - k * 0.09;
          final x = f.x + math.cos(a) * f.radius * 0.75, y = f.y - 26 + math.sin(a) * f.radius * 0.35;
          k == 0 ? wake.moveTo(x, y) : wake.lineTo(x, y);
        }
        c.drawPath(wake, _stroke(0xFFFFF3C4, 0.45, 6));
        if (!liteGraphics) c.drawPath(wake, _glow(_gold, 0.35, 6)..style = PaintingStyle.stroke..strokeWidth = 10);
      }
      for (var i = 0; i < 4; i++) {
        final a = t * 6 + i * math.pi / 2;
        final x = f.x + math.cos(a) * f.radius * 0.75;
        final y = f.y - 26 + math.sin(a) * f.radius * 0.35;
        c.save();
        c.translate(x, y);
        c.rotate(a + math.pi / 2);
        c.drawPath(
            Path()
              ..moveTo(-20, -2.6)
              ..lineTo(21, 0)
              ..lineTo(-20, 2.6)
              ..close(),
            _a(0xFFF0F6FF, 0.95));
        c.drawLine(const Offset(-18, 0), const Offset(18, 0), _stroke(0xFFB8C8D8, 0.9, 0.8));
        c.drawRect(const Rect.fromLTRB(-23, -5.5, -20, 5.5), _a(_earth, 1));
        c.drawRect(const Rect.fromLTRB(-29, -1.8, -23, 1.8), _a(0xFF6A4A2A, 1));
        c.drawCircle(Offset.zero, 13, _glow(0xFFFFF3C4, 0.4, 8));
        c.restore();
      }
    case 'iceNova':
      // A white flash, then a ring of ice spikes racing outward.
      final r = f.radius * Curves.easeOut(math.min(1, p * 1.5));
      c.drawOval(_flat(f.x, f.y, r), _a(0xFFDFF6FF, 0.35 * fade));
      c.drawOval(_flat(f.x, f.y, r), _glow(_ice, 0.6 * fade, 18));
      c.drawCircle(Offset(f.x, f.y - 40), 70 * (1 - p), _glow(0xFFFFFFFF, 0.8 * fade, 24));
      for (var ring = 0; ring < 2; ring++) {
        final rr = r * (ring == 0 ? 1 : 0.6);
        final n = ring == 0 ? 22 : 14;
        for (var i = 0; i < n; i++) {
          final a = i * math.pi * 2 / n + ring * 0.2;
          final x = f.x + math.cos(a) * rr, y = f.y + math.sin(a) * rr * 0.5;
          final h = (ring == 0 ? 46 : 34) * (0.4 + 0.6 * fade);
          c.drawPath(
              Path()
                ..moveTo(x - 8, y)
                ..lineTo(x, y - h)
                ..lineTo(x + 8, y)
                ..close(),
              _a(i.isEven ? 0xFFBFE8FF : 0xFFFFFFFF, 0.95 * fade + 0.05));
        }
      }
      c.drawOval(_flat(f.x, f.y, r), _stroke(0xFFFFFFFF, fade, 4));
    case 'swordStorm':
      // Two counter-turning rings of flying swords.
      final end = math.min(1.0, (f.life - f.t) * 2);
      c.drawOval(_flat(f.x, f.y, f.radius), _glow(0xFFFFF3C4, 0.22 * end, 16));
      c.drawOval(_flat(f.x, f.y, f.radius), _stroke(_gold, 0.5 * end, 2));
      for (var ring = 0; ring < 2; ring++) {
        final n = ring == 0 ? 8 : 6;
        final rr = f.radius * (ring == 0 ? 0.85 : 0.5);
        final dir = ring == 0 ? 1.0 : -1.4;
        for (var i = 0; i < n; i++) {
          final a = t * 5 * dir + i * math.pi * 2 / n;
          final x = f.x + math.cos(a) * rr;
          final y = f.y - 26 + math.sin(a) * rr * 0.4;
          c.save();
          c.translate(x, y);
          c.rotate(a + math.pi / 2 * dir);
          c.drawPath(
              Path()
                ..moveTo(-16, -2)
                ..lineTo(16, 0)
                ..lineTo(-16, 2)
                ..close(),
              _a(0xFFF0F6FF, 0.95 * end));
          c.drawRect(const Rect.fromLTRB(-19, -5, -16, 5), _a(_gold, end));
          c.drawCircle(Offset.zero, 10, _glow(0xFFFFF3C4, 0.4 * end, 7));
          c.restore();
        }
      }
    case 'snowStorm':
      final r = f.radius;
      c.drawOval(_flat(f.x, f.y, r), _a(_ice, 0.12));
      // Frost on the ground and the wind wheeling round the hero.
      c.drawOval(_flat(f.x, f.y, r), _stroke(0xFFDFF6FF, 0.5, 2));
      c.drawOval(_flat(f.x, f.y, r * 0.95), _glow(_ice, 0.18, 12));
      for (var w = 0; w < 3; w++) {
        final rr = r * (0.45 + w * 0.22);
        final a0 = t * (2.4 - w * 0.5) + w * 2.1;
        c.drawArc(Rect.fromCenter(center: Offset(f.x, f.y - 30 - w * 10), width: rr * 2, height: rr * 0.8), a0, 2.2, false,
            _stroke(0xFFFFFFFF, 0.45, 3 - w * 0.6));
        c.drawArc(Rect.fromCenter(center: Offset(f.x, f.y - 30 - w * 10), width: rr * 2, height: rr * 0.8), a0 + math.pi, 1.6,
            false, _stroke(0xFFBFE8FF, 0.35, 2.2));
      }
      for (var i = 0; i < (liteGraphics ? 8 : 16); i++) {
        final a = t * 2.6 + i * 0.9;
        final rr = r * (0.2 + 0.75 * _h(i));
        final x = f.x + math.cos(a) * rr, y = f.y - 20 - 60 * _h(i, 1) + math.sin(a) * rr * 0.4;
        final s = 2 + 2.5 * _h(i, 2);
        final flake = _stroke(0xFFFFFFFF, 0.9, 1.2);
        for (var k = 0; k < 3; k++) {
          final fa = k * math.pi / 3 + t * 3;
          c.drawLine(Offset(x - math.cos(fa) * s, y - math.sin(fa) * s), Offset(x + math.cos(fa) * s, y + math.sin(fa) * s), flake);
        }
      }
      for (var i = 0; i < 18; i++) {
        final seed = i * 97.0;
        final fall = (t * 1.6 + i / 18) % 1;
        final ox = math.sin(seed) * r * 0.9, oy = math.cos(seed * 1.3) * r * 0.45;
        final x = f.x + ox, y = f.y + oy - (1 - fall) * 120;
        c.drawLine(Offset(x - 3, y - 10), Offset(x, y), _stroke(0xFFFFFFFF, 0.9, 2.5));
        if (fall > 0.85) {
          c.drawCircle(Offset(f.x + ox, f.y + oy), 5, _a(_ice, 0.6));
        }
      }
    default:
      if (f.kind.startsWith('spark_')) {
        final colr = _projColor(f.kind.substring(6));
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + f.x;
          final d = 4 + p * 16;
          c.drawCircle(Offset(f.x + math.cos(a) * d, f.y + math.sin(a) * d),
              2.6 * fade + 0.5, _a(colr, fade));
        }
        c.drawCircle(Offset(f.x, f.y), 8 * fade, _glow(colr, fade, 5));
      }
  }
}

Rect _flat(double x, double y, double r) =>
    Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r);

/// A stable pseudo-random 0..1 for particle [i] of an effect.
double _h(int i, [double salt = 0]) {
  final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// One tongue of flame standing on (x, y).
void _flame(Canvas c, double x, double y, double w, double h, int colr, double alpha, double t, int i) {
  final sway = math.sin(t * 14 + i * 1.7) * w * 0.35;
  c.drawPath(
      Path()
        ..moveTo(x - w, y)
        ..quadraticBezierTo(x - w * 0.9, y - h * 0.55, x + sway, y - h)
        ..quadraticBezierTo(x + w * 0.9, y - h * 0.55, x + w, y)
        ..quadraticBezierTo(x, y + w * 0.4, x - w, y)
        ..close(),
      _a(colr, alpha));
}

/// [n] sparks flying out from (x, y) over the effect's life [p].
void _sparks(Canvas c, double x, double y, int n, double reach, int colr, double p, {double lift = 0, double salt = 0}) {
  if (liteGraphics) n = n ~/ 2;
  final fade = 1 - p;
  for (var i = 0; i < n; i++) {
    final a = _h(i, salt) * math.pi * 2;
    final d = reach * (0.35 + 0.65 * _h(i, salt + 1)) * Curves.easeOut(p);
    final px = x + math.cos(a) * d, py = y + math.sin(a) * d * 0.55 - lift * p + 40 * p * p;
    final s = (1.4 + _h(i, salt + 2) * 2.2) * fade + 0.4;
    c.drawLine(Offset(px, py), Offset(px - math.cos(a) * s * 3, py - math.sin(a) * s * 1.6),
        _stroke(colr, fade, s));
  }
}

/// A jagged crack from (x, y) at angle [a], [len] long on the flat ground.
Path _crack(double x, double y, double a, double len, int seed) {
  final path = Path()..moveTo(x, y);
  var px = x, py = y;
  const steps = 4;
  for (var k = 1; k <= steps; k++) {
    final jig = (_h(seed * 7 + k) - 0.5) * 0.7;
    px = x + math.cos(a + jig) * len * k / steps;
    py = y + math.sin(a + jig) * len * k / steps * 0.5;
    path.lineTo(px, py);
  }
  return path;
}

int _projColor(String kind) {
  if (kind.startsWith('mob_') || kind.startsWith('pet_')) {
    return switch (kind.substring(4)) {
      'kim' => 0xFFF0D060,
      'moc' => 0xFF8CE05A,
      'thuy' => 0xFF7FD4FF,
      'hoa' => 0xFFFF7A3A,
      _ => 0xFFD0A060,
    };
  }
  return switch (kind) {
    'dart' || 'knife' || 'needle' => 0xFFD8F0C8,
    'poisonPalm' => _poison,
    'waterOrb' => 0xFF7FD4FF,
    'iceBlade' => _ice,
    'swordQi' => 0xFFFFF3C4,
    'taiji' => 0xFFFFFFFF,
    _ => 0xFFFFFFFF,
  };
}

void drawProj(Canvas c, Proj pr, double t) {
  final colr = _projColor(pr.fx);
  c.save();
  c.translate(pr.x, pr.y);
  c.rotate(pr.angle);
  switch (pr.fx) {
    case 'knife' || 'needle':
      // Skill throws: a poison-green streak and glint behind each blade.
      final len = pr.fx == 'needle' ? 13.0 : 20.0;
      c.drawLine(Offset(-len * 3.2, 0), Offset.zero, _glow(_poison, 0.55, 5)..strokeWidth = 7);
      c.drawLine(Offset(-len * 3.2, 0), Offset.zero, _stroke(0xFFE8FFD0, 0.6, 2));
      c.drawCircle(Offset.zero, len * 0.7, _glow(_poison, 0.5, 6));
      c.drawPath(
          Path()
            ..moveTo(-len * 0.6, -3.2)
            ..lineTo(len * 0.7, 0)
            ..lineTo(-len * 0.6, 3.2)
            ..close(),
          _a(0xFFF0F8E8, 1));
      c.drawLine(Offset(-len * 0.5, 0), Offset(len * 0.6, 0), _stroke(_poison, 0.9, 1.2));
      c.drawCircle(Offset(-len * 0.65, 0), 2.4, _a(0xFF7A3A8A, 1));
      if (pr.fx == 'needle') {
        final tw = 0.6 + 0.4 * math.sin(t * 30 + pr.x);
        c.drawLine(const Offset(-4, -8), const Offset(4, 8), _stroke(0xFFFFFFFF, tw, 1.2));
        c.drawLine(const Offset(-4, 8), const Offset(4, -8), _stroke(0xFFFFFFFF, tw, 1.2));
      }
    case 'dart':
      const len = 14.0;
      c.drawLine(const Offset(-len * 1.8, 0), Offset.zero, _stroke(colr, 0.35, 3));
      c.drawPath(
          Path()
            ..moveTo(-len * 0.5, -2.2)
            ..lineTo(len * 0.6, 0)
            ..lineTo(-len * 0.5, 2.2)
            ..close(),
          _a(0xFFE8F0E0, 1));
      c.drawCircle(Offset(-len * 0.5, 0), 1.6, _a(0xFF7A3A8A, 1));
    case 'poisonPalm':
      // A green palm print of qi pushing forward, dripping venom.
      final r = pr.radius + 4;
      c.drawCircle(Offset.zero, r + 12, _glow(_poison, 0.55, 12));
      for (var i = 0; i < 6; i++) {
        final k = i / 6;
        c.drawCircle(Offset(-14.0 - i * 10, math.sin(t * 18 + i) * 5), (r * 0.6) * (1 - k) + 1.5,
            _a(i.isEven ? _poison : 0xFF5AA83A, 0.55 * (1 - k)));
      }
      c.save();
      c.rotate(math.pi / 2);
      final s = r / 16;
      c.scale(s);
      final palm = Paint()..color = const Color(0xFFB8F08A).withValues(alpha: 0.95);
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-13, -6, 13, 16), const Radius.circular(8)), palm);
      for (var i = 0; i < 4; i++) {
        final x = -10.0 + i * 6.7;
        final h = i == 1 || i == 2 ? 20.0 : 16.0;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x - 3, -6 - h, x + 3, -3), const Radius.circular(3)), palm);
      }
      c.save();
      c.translate(-13, 6);
      c.rotate(-0.8);
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-3, -14, 3, 0), const Radius.circular(3)), palm);
      c.restore();
      c.drawCircle(const Offset(0, 4), 6, _a(0xFF4A8A2A, 0.8));
      c.restore();
      for (var i = 0; i < 3; i++) {
        final fall = (t * 2 + i / 3) % 1;
        c.drawCircle(Offset(-10.0 - i * 12, 8 + fall * 14), 2.6 * (1 - fall) + 0.8, _a(_poison, 0.9 * (1 - fall)));
      }
    case 'iceBlade':
      // A crescent of ice with a frosty wake of glittering shards.
      c.drawCircle(Offset.zero, 26, _glow(_ice, 0.5, 12));
      for (var i = 0; i < 6; i++) {
        final x = -16.0 - i * 9, y = math.sin(t * 16 + i * 1.3) * 7;
        final s = 3.2 - i * 0.4;
        c.drawPath(
            Path()
              ..moveTo(x, y - s)
              ..lineTo(x + s * 0.7, y)
              ..lineTo(x, y + s)
              ..lineTo(x - s * 0.7, y)
              ..close(),
            _a(0xFFFFFFFF, 0.9 - i * 0.13));
      }
      c.drawPath(
          Path()
            ..moveTo(-8, -22)
            ..quadraticBezierTo(26, -10, 22, 0)
            ..quadraticBezierTo(26, 10, -8, 22)
            ..quadraticBezierTo(10, 8, 10, 0)
            ..quadraticBezierTo(10, -8, -8, -22)
            ..close(),
          _a(0xFFE8F8FF, 0.95));
      c.drawPath(
          Path()
            ..moveTo(-4, -16)
            ..quadraticBezierTo(20, -6, 18, 0)
            ..quadraticBezierTo(20, 6, -4, 16),
          _stroke(_ice, 1, 2));
      c.drawLine(const Offset(-30, 0), const Offset(12, 0), _stroke(0xFFFFFFFF, 0.8, 1.4));
    case 'swordQi':
      c.drawArc(Rect.fromCircle(center: const Offset(-8, 0), radius: 16), -1.2, 2.4, false,
          _stroke(colr, 0.95, 4));
      c.drawArc(Rect.fromCircle(center: const Offset(-8, 0), radius: 16), -1.2, 2.4, false,
          Paint()
            ..color = Color(colr).withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..maskFilter = softBlur(5));
    case 'taiji':
      final r = pr.radius;
      // A wake of light and a bát quái ring turning the other way.
      c.drawLine(Offset(-r * 3.5, 0), Offset.zero, _glow(0xFFFFF3C4, 0.5, 8)..strokeWidth = r * 1.2);
      c.save();
      c.rotate(-t * 4);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final x = math.cos(a) * (r + 12), y = math.sin(a) * (r + 12);
        c.save();
        c.translate(x, y);
        c.rotate(a);
        for (var k = 0; k < 3; k++) {
          final broken = (i >> k) & 1 == 1;
          final yy = -3.0 + k * 3;
          if (broken) {
            c.drawLine(Offset(yy, -4), Offset(yy, -1), _stroke(_gold, 0.9, 1.6));
            c.drawLine(Offset(yy, 1), Offset(yy, 4), _stroke(_gold, 0.9, 1.6));
          } else {
            c.drawLine(Offset(yy, -4), Offset(yy, 4), _stroke(_gold, 0.9, 1.6));
          }
        }
        c.restore();
      }
      c.drawCircle(Offset.zero, r + 12, _stroke(0xFFFFF3C4, 0.5, 1.2));
      c.restore();
      c.rotate(t * 12);
      c.drawCircle(Offset.zero, r + 6, _glow(0xFFFFF3C4, 0.5, 8));
      c.drawCircle(Offset.zero, r, _a(0xFFFFFFFF, 1));
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), math.pi / 2, math.pi, true,
          _a(0xFF1A1A22, 1));
      c.drawCircle(Offset(0, -r / 2), r / 2, _a(0xFF1A1A22, 1));
      c.drawCircle(Offset(0, r / 2), r / 2, _a(0xFFFFFFFF, 1));
      c.drawCircle(Offset(0, -r / 2), r / 7, _a(0xFFFFFFFF, 1));
      c.drawCircle(Offset(0, r / 2), r / 7, _a(0xFF1A1A22, 1));
    default:
      // Orbs: water orb and every monster missile.
      c.drawCircle(Offset.zero, pr.radius + 6, _glow(colr, 0.55, 8));
      c.drawCircle(Offset.zero, pr.radius * 0.75, _a(colr, 0.95));
      c.drawCircle(Offset(-2, -2), pr.radius * 0.3, _a(0xFFFFFFFF, 0.8));
      c.drawLine(Offset(-pr.radius * 2.5, 0), Offset(-pr.radius, 0), _stroke(colr, 0.4, pr.radius));
  }
  c.restore();
}

void drawZone(Canvas c, Zone z, double t) {
  final pre = z.delay > 0 ? (z.t / z.delay).clamp(0.0, 1.0) : 1.0;
  final after = math.max(0.0, z.t - z.delay);
  final r = z.r;
  if (!z.fromHero) {
    // Boss telegraph: a red circle that fills before it lands.
    if (z.t < z.delay) {
      c.drawOval(_flat(z.x, z.y, r), _a(0xFFE8303A, 0.15 + 0.1 * math.sin(t * 20)));
      c.drawOval(_flat(z.x, z.y, r * pre), _a(0xFFE8303A, 0.3));
      c.drawOval(_flat(z.x, z.y, r), _stroke(0xFFFF5A4A, 0.9, 2.5));
    } else {
      final f = (1 - after / 0.4).clamp(0.0, 1.0);
      c.drawOval(_flat(z.x, z.y, r * (1 + after)), _glow(0xFFFF5A3A, 0.6 * f, 16));
      c.drawOval(_flat(z.x, z.y, r), _stroke(0xFFFFB08A, f, 6 * f));
    }
    return;
  }
  switch (z.fx) {
    case 'poisonCloud' || 'venomCloud':
      final venom = z.fx == 'venomCloud';
      final end = ((z.life - z.t) * 2).clamp(0.0, 1.0);
      final cloud = venom ? 0xFF7A3AC0 : _poison;
      for (var i = 0; i < (venom ? 14 : 9); i++) {
        final a = i * 0.7 + t * 0.4;
        final d = (i % 3) * r * 0.32;
        c.drawCircle(Offset(z.x + math.cos(a) * d, z.y + math.sin(a) * d * 0.5 - 14),
            r * 0.42, _glow(i.isEven || !venom ? cloud : _poison, (venom ? 0.2 : 0.16) * end, 14));
      }
      for (var i = 0; i < (venom ? 12 : 6); i++) {
        final rise = (t * 0.7 + i / 6) % 1;
        c.drawCircle(Offset(z.x + math.sin(i * 3.0) * r * 0.6, z.y - rise * 50),
            (venom ? 6 : 4) * (1 - rise), _a(venom ? 0xFFD8A8FF : 0xFFCFF0A0, 0.8 * end));
      }
      if (venom) c.drawOval(_flat(z.x, z.y, r), _stroke(0xFFB06AFF, 0.6 * end, 2));
      if (!venom) {
        // A poisoned stain on the ground, bubbles swelling and popping,
        // and wisps curling up.
        final grow = math.min(1.0, z.t * 3);
        c.drawOval(_flat(z.x, z.y, r * grow), _a(0xFF3A6A1A, 0.3 * end));
        c.drawOval(_flat(z.x, z.y, r * grow), _stroke(_poison, 0.55 * end, 2));
        c.drawOval(_flat(z.x, z.y, r * 0.95), _glow(_poison, 0.22 * end, 14));
        for (var i = 0; i < (liteGraphics ? 5 : 10); i++) {
          final cyc = (t * 0.9 + _h(i)) % 1;
          final a = _h(i, 1) * math.pi * 2, d = r * 0.8 * _h(i, 2);
          final x = z.x + math.cos(a) * d, y = z.y + math.sin(a) * d * 0.5;
          final s = (4 + 6 * _h(i, 3)) * cyc;
          if (cyc < 0.9) {
            c.drawCircle(Offset(x, y - s * 0.6), s, _stroke(0xFFCFF0A0, 0.8 * end, 1.4));
            c.drawCircle(Offset(x - s * 0.3, y - s), s * 0.25, _a(0xFFFFFFFF, 0.6 * end));
          } else {
            _sparks(c, x, y - 6, 5, 18, 0xFFCFF0A0, (cyc - 0.9) * 10, salt: i.toDouble());
          }
        }
        for (var i = 0; i < 4; i++) {
          final rise = (t * 0.5 + i / 4) % 1;
          final x = z.x + (_h(i, 5) - 0.5) * r * 1.2;
          final path = Path()..moveTo(x, z.y - 4);
          for (var k = 1; k <= 6; k++) {
            path.lineTo(x + math.sin(t * 3 + k + i) * 8, z.y - 4 - k * 12 * rise - k * 4);
          }
          c.drawPath(path, _stroke(0xFFA8E07A, 0.45 * end * (1 - rise), 3));
        }
      }
    case 'buddhaPalm':
      if (z.t < z.delay) {
        // A giant golden palm drops from the sky onto its shadow.
        c.drawOval(_flat(z.x, z.y, r * (0.3 + pre * 0.7)), _a(0xFF000000, 0.25 * pre));
        c.drawOval(_flat(z.x, z.y, r), _stroke(_gold, 0.6, 2));
        final k = 1 - Curves.easeIn(pre);
        final px = z.x, py = z.y - 40 - 520 * k;
        final s = r / 120;
        c.save();
        c.translate(px, py);
        c.scale(s);
        c.drawCircle(const Offset(0, -40), 70, _glow(_gold, 0.7, 26));
        final palm = RRect.fromRectAndRadius(const Rect.fromLTRB(-34, -50, 34, 10), const Radius.circular(18));
        c.drawRRect(palm, _a(0xFFF3C04A, 1));
        for (var i = 0; i < 4; i++) {
          final x = -27.0 + i * 18;
          final h = i == 1 || i == 2 ? 62.0 : 52.0;
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x - 7, -50 - h, x + 7, -44), const Radius.circular(7)),
              _a(0xFFF8D060, 1));
        }
        c.save();
        c.translate(-36, -14);
        c.rotate(-0.7);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-8, -40, 8, 0), const Radius.circular(8)),
            _a(0xFFF8D060, 1));
        c.restore();
        c.drawCircle(const Offset(0, -22), 9, _a(0xFFFFF3C4, 0.9));
        c.restore();
      } else {
        final f = (1 - after / 0.7).clamp(0.0, 1.0);
        c.drawOval(_flat(z.x, z.y, r * (0.7 + after * 1.2)), _glow(_gold, 0.8 * f, 24));
        c.drawOval(_flat(z.x, z.y, r), _a(0xFFFFF3C4, 0.45 * f));
        c.drawOval(_flat(z.x, z.y, r * (0.4 + after * 1.5)), _stroke(0xFFFFFFFF, f, 6 * f + 1));
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8;
          c.drawLine(Offset(z.x + math.cos(a) * r * 0.3, z.y + math.sin(a) * r * 0.15),
              Offset(z.x + math.cos(a) * r * (0.9 + after), z.y + math.sin(a) * r * (0.45 + after * 0.5)),
              _stroke(0xFFFFE08A, 0.8 * f, 4));
        }
      }
    case 'fireLine':
      if (z.t < z.delay) return;
      // A pillar of fire bursting out of the ground.
      final f = (1 - after / 0.7).clamp(0.0, 1.0);
      final rise = math.min(1.0, after * 6);
      c.drawOval(_flat(z.x, z.y, r * 0.9), _glow(_fire, 0.7 * f, 18));
      c.drawOval(_flat(z.x, z.y, r * 0.55), _a(0xFFFFE08A, 0.6 * f));
      final h = 150 * rise * (0.5 + 0.5 * f);
      for (var i = 0; i < 3; i++) {
        final w = r * (0.55 - i * 0.15);
        final colr = const [_fire, 0xFFFFB03A, 0xFFFFF0B0][i];
        c.drawPath(
            Path()
              ..moveTo(z.x - w, z.y)
              ..quadraticBezierTo(z.x - w * 0.6 + math.sin(t * 18 + i) * 6, z.y - h * 0.6, z.x, z.y - h * (1 - i * 0.18))
              ..quadraticBezierTo(z.x + w * 0.6 + math.cos(t * 16 + i) * 6, z.y - h * 0.6, z.x + w, z.y)
              ..close(),
            _a(colr, f * 0.9));
      }
      for (var i = 0; i < 5; i++) {
        final up = (after * 1.5 + i / 5) % 1;
        c.drawCircle(Offset(z.x + math.sin(i * 2.1) * r * 0.4, z.y - up * h * 1.2), 4 * (1 - up), _a(0xFFFFE08A, f));
      }
    case 'iceField':
      if (z.t < z.delay) {
        c.drawOval(_flat(z.x, z.y, r * pre), _a(_ice, 0.3));
      } else {
        final f = (1 - after / 0.5).clamp(0.0, 1.0);
        c.drawOval(_flat(z.x, z.y, r), _a(0xFFDFF6FF, 0.5 * f));
        c.drawOval(_flat(z.x, z.y, r * 1.1), _glow(_ice, 0.55 * f, 16));
        // Frost cracks across the ice and a cold mist rolling off it.
        for (var i = 0; i < 8; i++) {
          c.drawPath(_crack(z.x, z.y, i * math.pi / 4 + 0.2, r * 0.95, i + 20),
              _stroke(0xFFFFFFFF, 0.8 * f, 1.6)..style = PaintingStyle.stroke);
        }
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + after;
          c.drawCircle(Offset(z.x + math.cos(a) * r * (0.7 + after), z.y + math.sin(a) * r * 0.35 - 8 - after * 20),
              r * 0.28, _glow(0xFFEAF8FF, 0.35 * f, 12));
        }
        _sparks(c, z.x, z.y - 20, 12, r, 0xFFFFFFFF, math.min(1, after * 2), lift: 30, salt: z.x);
        for (var i = 0; i < 10; i++) {
          final a = i * 0.63;
          final d = (i.isEven ? 0.4 : 0.8) * r;
          final x = z.x + math.cos(a) * d, y = z.y + math.sin(a) * d * 0.5;
          final h = 34 * math.min(1, after * 8) * (0.5 + f * 0.5);
          c.drawPath(
              Path()
                ..moveTo(x - 7, y)
                ..lineTo(x, y - h)
                ..lineTo(x + 7, y)
                ..close(),
              _a(0xFFBFE8FF, 0.9 * f + 0.1));
        }
        c.drawOval(_flat(z.x, z.y, r), _stroke(0xFFFFFFFF, f, 3));
      }
    case 'meteor':
      if (z.t < z.delay) {
        c.drawOval(_flat(z.x, z.y, r * (0.4 + pre * 0.6)), _a(_fire, 0.25));
        c.drawOval(_flat(z.x, z.y, r), _stroke(_fire, 0.7, 2));
        // The rock comes in from the upper right.
        final k = 1 - pre;
        final mx = z.x + 260 * k, my = z.y - 420 * k - 20;
        // A flaming tail streaming back up the path.
        final tail = Path()
          ..moveTo(mx - 22, my + 8)
          ..quadraticBezierTo(mx + 60, my - 70, mx + 150, my - 250)
          ..quadraticBezierTo(mx + 70, my - 90, mx + 22, my - 12)
          ..close();
        c.drawPath(tail, _glow(_fire, 0.6, 14));
        c.drawPath(tail, _a(0xFFFFB03A, 0.55));
        c.drawCircle(Offset(mx, my), 42, _glow(_fire, 0.85, 18));
        c.drawCircle(Offset(mx, my), 24, _a(0xFF5A2A1A, 1));
        c.drawCircle(Offset(mx - 5, my - 5), 13, _a(0xFFFFB03A, 1));
        c.drawCircle(Offset(mx - 8, my - 8), 6, _a(0xFFFFF0B0, 1));
        for (var i = 1; i < 7; i++) {
          c.drawCircle(Offset(mx + i * 16.0 + math.sin(t * 20 + i) * 4, my - i * 26.0), 16.0 - i * 2, _a(_fire, 0.55 - i * 0.07));
        }
      } else {
        // Impact: a white flash, a ring of shock, a scorched crater with
        // glowing cracks, flames and burning rocks thrown out.
        final f = (1 - after / 0.6).clamp(0.0, 1.0);
        if (after < 0.12) c.drawCircle(Offset(z.x, z.y - 30), r * 1.2, _glow(0xFFFFF8E0, 1 - after / 0.12, 30));
        c.drawOval(_flat(z.x, z.y, r * (0.6 + after)), _glow(_fire, 0.9 * f, 22));
        c.drawOval(_flat(z.x, z.y, r * 0.75), _a(0xFF2A140A, 0.55 * f));
        for (var i = 0; i < 9; i++) {
          c.drawPath(_crack(z.x, z.y, i * math.pi * 2 / 9 + 0.3, r * 0.9, i + 40),
              _stroke(0xFFFFB03A, f, 2.4)..style = PaintingStyle.stroke);
        }
        c.drawOval(_flat(z.x, z.y, r * (0.5 + after * 2.2)), _stroke(0xFFFFE08A, f, 8 * f + 1));
        for (var i = 0; i < 10; i++) {
          final a = i * math.pi / 5 + 0.2;
          _flame(c, z.x + math.cos(a) * r * 0.55, z.y + math.sin(a) * r * 0.28, 10 * f + 2, (40 + 30 * _h(i)) * f + 4,
              i.isEven ? _fire : 0xFFFFB03A, f, t, i);
        }
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final d = r * (0.3 + after * 1.6);
          final up = math.sin(math.min(1.0, after * 1.6) * math.pi) * 70;
          c.drawCircle(Offset(z.x + math.cos(a) * d, z.y + math.sin(a) * d * 0.5 - up),
              6 * f + 1, _a(i.isEven ? 0xFFFFB03A : 0xFF5A2A1A, f));
        }
      }
    case 'spikes':
      if (z.t < z.delay) return;
      final f = (1 - after / 0.5).clamp(0.0, 1.0);
      final rise = math.min(1.0, after * 10);
      // Rock spears burst out of a cracked patch, with dust and chips.
      c.drawOval(_flat(z.x, z.y, r), _glow(0xFFB89A6A, 0.4 * f, 12));
      c.drawOval(_flat(z.x, z.y, r * 0.8), _a(0xFF5A3A1A, 0.45 * f));
      for (var i = 0; i < 5; i++) {
        c.drawPath(_crack(z.x, z.y, i * math.pi * 2 / 5 + z.x, r, i + 60), _stroke(0xFF3A2410, f, 2)..style = PaintingStyle.stroke);
      }
      for (var i = -2; i <= 2; i++) {
        final h = (62 - i.abs() * 14) * rise * (0.4 + 0.6 * f);
        final x = z.x + i * 13.0, w = 10 - i.abs() * 1.5;
        final y = z.y + (i.isEven ? 0 : 4);
        c.drawPath(
            Path()
              ..moveTo(x - w, y)
              ..lineTo(x - w * 0.3, y - h * 0.6)
              ..lineTo(x + i * 1.5, y - h)
              ..lineTo(x + w, y)
              ..close(),
            _a(i.isEven ? 0xFF9A7A4A : 0xFF8A6A3A, f * 0.9 + 0.1));
        c.drawPath(
            Path()
              ..moveTo(x + i * 1.5, y - h)
              ..lineTo(x + w, y)
              ..lineTo(x + w * 0.3, y)
              ..close(),
            _a(0xFF5A3A1A, (f * 0.9 + 0.1) * 0.6));
        c.drawLine(Offset(x + i * 1.5, y - h), Offset(x - w * 0.5, y), _stroke(0xFFE8C88A, f, 1.4));
      }
      _sparks(c, z.x, z.y - 10, 10, r * 1.3, 0xFFB89A6A, math.min(1.0, after * 2), lift: 40, salt: z.x);
    default:
      break;
  }
}

void drawDrop(Canvas c, Drop d, double t) {
  // Loot pops up out of the fallen monster and lands with a little bounce.
  final pop = d.t < 0.42
      ? math.sin(d.t / 0.42 * math.pi) * 28
      : (d.t < 0.6 ? math.sin((d.t - 0.42) / 0.18 * math.pi) * 6 : 0.0);
  final bob = math.sin(t * 4 + d.x) * 2 - pop;
  if (d.gold > 0) {
    c.drawOval(Rect.fromCenter(center: Offset(d.x, d.y + 2), width: 14, height: 5),
        _a(0xFF000000, 0.25));
    for (var i = 0; i < 3; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(d.x - 3.0 + i * 3, d.y - 2 - i * 2.0 + bob),
          width: 10, height: 5), _a(i.isEven ? 0xFFFFD34A : 0xFFE8B030, 1));
    }
    return;
  }
  final gem = d.gem;
  if (gem != null) {
    final colr = gem.hanh.color;
    final y = d.y - 8 + bob;
    c.drawCircle(Offset(d.x, y), 12, _glow(colr, 0.6, 7));
    final p = Path()
      ..moveTo(d.x, y - 8)
      ..lineTo(d.x + 6, y - 2)
      ..lineTo(d.x, y + 7)
      ..lineTo(d.x - 6, y - 2)
      ..close();
    c.drawPath(p, _a(colr, 1));
    c.drawPath(p, _stroke(0xFFFFFFFF, 0.9, 1.2));
    c.drawLine(Offset(d.x - 6, y - 2), Offset(d.x + 6, y - 2), _stroke(0xFFFFFFFF, 0.6, 1));
    return;
  }
  if (d.potion > 0) {
    final colr = d.potion == 1 ? 0xFFE84B4A : 0xFF4A7AE8;
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(d.x, d.y - 6 + bob), width: 9, height: 12),
        const Radius.circular(3)), _a(colr, 1));
    c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - 13 + bob), width: 4, height: 3),
        _a(0xFF8A6A3A, 1));
    return;
  }
  final it = d.item!;
  final colr = it.color;
  final grand = it.rarity.index >= Rarity.epic.index || it.golden;
  if (it.rarity.index >= Rarity.rare.index) {
    // A beam of its colour: taller and wider the rarer, so good loot is
    // seen from across the screen.
    final h = grand ? 150.0 : 80.0;
    c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - h / 2), width: grand ? 12 : 6, height: h),
        _glow(colr, 0.35 + 0.15 * math.sin(t * 5), grand ? 9 : 6));
    if (grand) {
      c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - h / 2), width: 3, height: h),
          _a(0xFFFFFFFF, 0.55 + 0.25 * math.sin(t * 7)));
      // Motes drifting up the beam and a ring turning on the ground.
      for (var i = 0; i < 5; i++) {
        final u = (t * 0.6 + i / 5) % 1;
        c.drawCircle(Offset(d.x + math.sin(t * 3 + i * 2) * 7, d.y - 8 - u * h), 2.2 * (1 - u) + 0.6,
            _a(i.isEven ? 0xFFFFFFFF : colr, 1 - u));
      }
      c.save();
      c.translate(d.x, d.y + 2);
      c.scale(1, 0.38);
      c.rotate(t * 1.6);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 20), 0, math.pi * 1.4, false, _stroke(colr, 0.8, 2.2));
      c.restore();
    }
  }
  c.drawCircle(Offset(d.x, d.y - 6 + bob), 12, _glow(colr, 0.6, 8));
  c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(d.x, d.y - 6 + bob), width: 14, height: 12),
      const Radius.circular(3)), _a(0xFF6A4A2A, 1));
  c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - 9 + bob), width: 14, height: 2.5),
      _a(colr, 1));
}
