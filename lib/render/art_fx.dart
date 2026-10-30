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
      if (f.kind == 'arcFire') {
        for (var i = 0; i < 6; i++) {
          final a = f.angle - f.spread / 2 + sweep * i / 5;
          c.drawCircle(Offset(f.x + math.cos(a) * r * 0.85, f.y - 24 + math.sin(a) * r * 0.85),
              6 * fade + 2, _a(0xFFFFB03A, 0.8 * fade));
        }
      }
    case 'quake':
      final r = f.radius * Curves.easeOut(p);
      c.drawOval(_flat(f.x, f.y, r), _stroke(_earth, fade, 10 * fade + 2));
      c.drawOval(_flat(f.x, f.y, r * 0.7), _a(0xFF8A6A3A, 0.35 * fade));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + 0.3;
        c.drawLine(Offset(f.x + math.cos(a) * r * 0.3, f.y + math.sin(a) * r * 0.15),
            Offset(f.x + math.cos(a) * r, f.y + math.sin(a) * r * 0.5),
            _stroke(0xFF5A3A1A, fade, 2.5));
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
    case 'bell':
      final pulse = 1 + math.sin(t * 6) * 0.03;
      final end = math.min(1.0, (f.life - f.t) * 2);
      final bell = Path()
        ..moveTo(f.x - 30 * pulse, f.y + 2)
        ..quadraticBezierTo(f.x - 32 * pulse, f.y - 70, f.x, f.y - 78 * pulse)
        ..quadraticBezierTo(f.x + 32 * pulse, f.y - 70, f.x + 30 * pulse, f.y + 2)
        ..close();
      c.drawPath(bell, _a(_gold, 0.16 * end));
      c.drawPath(bell, _stroke(_gold, 0.7 * end, 2));
      c.drawLine(Offset(f.x - 26, f.y - 20), Offset(f.x + 26, f.y - 20),
          _stroke(_gold, 0.5 * end, 1.5));
    case 'earthShield':
      final end = math.min(1.0, (f.life - f.t) * 2);
      for (var i = 0; i < 6; i++) {
        final a = t * 1.5 + i * math.pi / 3;
        final x = f.x + math.cos(a) * 30, y = f.y - 30 + math.sin(a) * 12;
        final hex = Path();
        for (var k = 0; k < 6; k++) {
          final ha = k * math.pi / 3;
          final px = x + math.cos(ha) * 7, py = y + math.sin(ha) * 7;
          k == 0 ? hex.moveTo(px, py) : hex.lineTo(px, py);
        }
        hex.close();
        c.drawPath(hex, _a(_earth, 0.6 * end));
        c.drawPath(hex, _stroke(0xFF6A4A2A, 0.8 * end, 1.2));
      }
      c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y - 30), width: 70, height: 80),
          _stroke(_earth, 0.35 * end, 2));
    case 'healWater' || 'potionHp' || 'potionMp':
      final colr = f.kind == 'potionMp' ? 0xFF6AA8FF : (f.kind == 'potionHp' ? 0xFFFF7A7A : 0xFF7CF0B0);
      for (var i = 0; i < 10; i++) {
        final a = i * 2.4;
        final rise = (p + i / 10) % 1;
        c.drawCircle(Offset(f.x + math.cos(a) * 18, f.y - rise * 70),
            3 * (1 - rise) + 1, _a(colr, fade));
      }
      c.drawOval(_flat(f.x, f.y, 28 * (0.6 + p)), _stroke(colr, 0.6 * fade, 2));
    case 'fireRing':
      final r = f.radius * Curves.easeOut(math.min(1, p * 1.8));
      c.drawOval(_flat(f.x, f.y, r), _glow(_fire, 0.5 * fade, 14));
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8 + p;
        final x = f.x + math.cos(a) * r, y = f.y + math.sin(a) * r * 0.5;
        final h = 18 * fade + 4 + math.sin(t * 20 + i) * 4;
        c.drawPath(
            Path()
              ..moveTo(x - 6, y)
              ..quadraticBezierTo(x, y - h * 1.6, x + 6, y)
              ..close(),
            _a(i.isEven ? 0xFFFFB03A : _fire, fade));
      }
    case 'fireDash':
      final dx = f.x2 - f.x, dy = f.y2 - f.y;
      for (var i = 0; i < 14; i++) {
        final k = i / 13;
        if (k > p * 2.2) break;
        final x = f.x + dx * k, y = f.y + dy * k;
        c.drawCircle(Offset(x, y - 20), 18 * fade + 4, _glow(_fire, 0.6 * fade, 10));
        c.drawCircle(Offset(x, y - 20), 8 * fade + 2, _a(0xFFFFE08A, fade));
      }
    case 'swordOrbit':
      for (var i = 0; i < 4; i++) {
        final a = t * 6 + i * math.pi / 2;
        final x = f.x + math.cos(a) * f.radius * 0.75;
        final y = f.y - 26 + math.sin(a) * f.radius * 0.35;
        c.save();
        c.translate(x, y);
        c.rotate(a + math.pi / 2);
        c.drawPath(
            Path()
              ..moveTo(-14, -1.8)
              ..lineTo(14, 0)
              ..lineTo(-14, 1.8)
              ..close(),
            _a(0xFFF0F6FF, 0.95));
        c.drawRect(const Rect.fromLTRB(-16, -4, -14, 4), _a(_earth, 1));
        c.drawCircle(Offset.zero, 9, _glow(0xFFFFF3C4, 0.35, 6));
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
    case 'dart' || 'knife' || 'needle':
      final len = pr.fx == 'needle' ? 10.0 : 14.0;
      c.drawLine(Offset(-len * 1.8, 0), Offset.zero, _stroke(colr, 0.35, 3));
      c.drawPath(
          Path()
            ..moveTo(-len * 0.5, -2.2)
            ..lineTo(len * 0.6, 0)
            ..lineTo(-len * 0.5, 2.2)
            ..close(),
          _a(0xFFE8F0E0, 1));
      c.drawCircle(Offset(-len * 0.5, 0), 1.6, _a(0xFF7A3A8A, 1));
    case 'poisonPalm':
      c.drawCircle(Offset.zero, pr.radius + 6, _glow(_poison, 0.5, 10));
      c.drawCircle(Offset.zero, pr.radius * 0.7, _a(_poison, 0.9));
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(-10.0 - i * 9, math.sin(t * 20 + i) * 4), 6.0 - i, _a(_poison, 0.5 - i * 0.1));
      }
    case 'iceBlade':
      c.drawCircle(Offset.zero, 18, _glow(_ice, 0.45, 9));
      c.drawPath(
          Path()
            ..moveTo(-22, 0)
            ..lineTo(-6, -6)
            ..lineTo(18, 0)
            ..lineTo(-6, 6)
            ..close(),
          _a(0xFFE8F8FF, 0.95));
      c.drawLine(const Offset(-20, 0), const Offset(16, 0), _stroke(_ice, 1, 1.5));
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
      c.rotate(t * 12);
      final r = pr.radius;
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
        c.drawCircle(Offset(mx, my), 30, _glow(_fire, 0.8, 16));
        c.drawCircle(Offset(mx, my), 18, _a(0xFF5A2A1A, 1));
        c.drawCircle(Offset(mx - 4, my - 4), 9, _a(0xFFFFB03A, 1));
        for (var i = 1; i < 6; i++) {
          c.drawCircle(Offset(mx + i * 14.0, my - i * 22.0), 14.0 - i * 2, _a(_fire, 0.5 - i * 0.08));
        }
      } else {
        final f = (1 - after / 0.6).clamp(0.0, 1.0);
        c.drawOval(_flat(z.x, z.y, r * (0.6 + after)), _glow(_fire, 0.9 * f, 22));
        c.drawOval(_flat(z.x, z.y, r * 0.7), _a(0xFFFFE08A, 0.7 * f));
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final d = r * (0.3 + after * 1.6);
          c.drawCircle(Offset(z.x + math.cos(a) * d, z.y + math.sin(a) * d * 0.5 - after * 60),
              6 * f, _a(0xFFFFB03A, f));
        }
      }
    case 'spikes':
      if (z.t < z.delay) return;
      final f = (1 - after / 0.5).clamp(0.0, 1.0);
      final rise = math.min(1.0, after * 10);
      c.drawOval(_flat(z.x, z.y, r * 0.8), _a(0xFF5A3A1A, 0.4 * f));
      for (var i = -1; i <= 1; i++) {
        final h = (40 - i.abs() * 12) * rise * (0.4 + 0.6 * f);
        c.drawPath(
            Path()
              ..moveTo(z.x + i * 14 - 9, z.y)
              ..lineTo(z.x + i * 15.0, z.y - h)
              ..lineTo(z.x + i * 14 + 9, z.y)
              ..close(),
            _a(0xFF9A7A4A, f * 0.9 + 0.1));
        c.drawLine(Offset(z.x + i * 15.0, z.y - h), Offset(z.x + i * 14 - 4, z.y),
            _stroke(0xFFC9A15A, f, 1.4));
      }
    default:
      break;
  }
}

void drawDrop(Canvas c, Drop d, double t) {
  final bob = math.sin(t * 4 + d.x) * 2;
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
  if (it.rarity.index >= Rarity.rare.index) {
    c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - 40), width: 6, height: 80),
        _glow(colr, 0.35 + 0.15 * math.sin(t * 5), 6));
  }
  c.drawCircle(Offset(d.x, d.y - 6 + bob), 12, _glow(colr, 0.6, 8));
  c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(d.x, d.y - 6 + bob), width: 14, height: 12),
      const Radius.circular(3)), _a(0xFF6A4A2A, 1));
  c.drawRect(Rect.fromCenter(center: Offset(d.x, d.y - 9 + bob), width: 14, height: 2.5),
      _a(colr, 1));
}
