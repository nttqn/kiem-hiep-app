import 'dart:math' as math;
import 'dart:ui';

import '../core/content.dart';
import '../core/hanh.dart';
import 'art_figures.dart';

/// Chibi-style figures: big heads, dark outlines, two-tone shading, wide
/// sleeves and cloth that trails behind. Same local frame as
/// [drawHuman]: feet at (0, 0), facing right, about 66 units tall.

const int _ink = 0xFF2A1810;

final Paint _o = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;
final Paint _f = Paint()..isAntiAlias = true;
final Paint _g = Paint()..isAntiAlias = true;

Paint _outline(double w) => _o
  ..color = col(_ink)
  ..strokeWidth = w;

/// Flat fill.
Paint _flat(int argb) => _f..color = col(argb);

/// Lit from the upper left: lighter top-left, darker bottom-right.
Paint _lit(int argb, Rect r, {double light = 0.22, double dark = 0.28}) => _g
  ..shader = Gradient.linear(
    r.topLeft,
    r.bottomRight,
    [col(shade(argb, light)), col(argb), col(shade(argb, -dark))],
    const [0, 0.45, 1],
  );

/// Outline then fill: the cartoon look.
void _shape(Canvas c, Path p, Paint fill, {double ow = 2.2}) {
  c.drawPath(p, _outline(ow));
  c.drawPath(p, fill);
}

/// A thick limb drawn as a rounded line with an outline.
void _limb(Canvas c, Offset a, Offset b, int argb, double w) {
  c.drawLine(a, b, _outline(w + 2.4));
  c.drawLine(
      a,
      b,
      _o
        ..color = col(argb)
        ..strokeWidth = w);
}

/// Wide sleeve from shoulder [a] to cuff [b], widening from [w0] to [w1].
Path _sleevePath(Offset a, Offset b, double w0, double w1) {
  final d = b - a;
  final len = math.max(0.001, d.distance);
  final n = Offset(-d.dy / len, d.dx / len);
  return Path()
    ..moveTo(a.dx + n.dx * w0, a.dy + n.dy * w0)
    ..lineTo(b.dx + n.dx * w1, b.dy + n.dy * w1)
    ..quadraticBezierTo(b.dx + d.dx / len * 3, b.dy + d.dy / len * 3,
        b.dx - n.dx * w1, b.dy - n.dy * w1)
    ..lineTo(a.dx - n.dx * w0, a.dy - n.dy * w0)
    ..close();
}

// ------------------------------------------------------------------ human

void drawChibi(Canvas c, HumanLook k,
    {double walk = 0,
    bool moving = false,
    double attack = 0,
    bool cast = false,
    double t = 0,
    bool hurt = false}) {
  final step = moving ? math.sin(walk * 1.7) : 0.0;
  final bob = moving ? (math.cos(walk * 3.4) * 1.6).abs() : math.sin(t * 2.2) * 0.6;
  // Cloth trails behind when running and breathes when standing.
  final trail = moving ? -3.5 : 0.0;
  final wind = math.sin(t * 6 + walk) * (moving ? 1.6 : 0.7);
  var lift = 0.0;
  if (k.zombie) lift = moving ? math.sin(walk * 1.7).abs() * 8 : 0;
  c.save();
  c.translate(0, -lift - bob);

  const hx = 1.5, hy = -47.0, hr = 12.5;

  // ---- back layer: cape, long hair, sash and headband tails
  if (k.cape != 0) {
    final p = Path()
      ..moveTo(-7, -38)
      ..lineTo(6, -38)
      ..quadraticBezierTo(4, -20, 2 + trail, -6)
      ..quadraticBezierTo(-10 + trail * 2, -2 + wind, -16 + trail * 2.5, -10 + wind)
      ..close();
    _shape(c, p, _lit(k.cape, const Rect.fromLTRB(-16, -38, 6, -4)));
  }
  if (k.hair == Hair.long) {
    final p = Path()
      ..moveTo(hx - 9, hy - 6)
      ..quadraticBezierTo(hx - 17 + trail, hy + 12, hx - 13 + trail * 1.5, hy + 26 + wind)
      ..quadraticBezierTo(hx - 6 + trail, hy + 22, hx - 2, hy + 6)
      ..close();
    _shape(c, p, _lit(k.hairColor, Rect.fromLTRB(hx - 17, hy - 6, hx, hy + 26), light: 0.3));
  }
  if (k.hair == Hair.topknot || k.hair == Hair.bun) {
    // A tail from the topknot, flicking behind.
    final p = Path()
      ..moveTo(hx - 5, hy - 13)
      ..quadraticBezierTo(hx - 15 + trail, hy - 9 + wind, hx - 17 + trail * 1.4, hy + 2 + wind)
      ..quadraticBezierTo(hx - 11, hy - 4, hx - 3, hy - 9)
      ..close();
    if (!k.female || k.hair == Hair.topknot) {
      _shape(c, p, _flat(shade(k.hairColor, 0.08)), ow: 1.8);
    }
  }
  if (k.band != 0) {
    for (var i = 0; i < 2; i++) {
      final p = Path()
        ..moveTo(hx - 10, hy - 5)
        ..quadraticBezierTo(hx - 17 + trail, hy - 2 + wind * (1 + i * 0.5) + i * 3,
            hx - 22 + trail * 1.6, hy + 2 + wind * (1.5 + i) + i * 4)
        ..lineTo(hx - 21 + trail * 1.6, hy + 5 + wind * (1.5 + i) + i * 4)
        ..quadraticBezierTo(hx - 15, hy + 1 + i * 3, hx - 9, hy - 2)
        ..close();
      _shape(c, p, _flat(shade(k.band, -0.08 * i)), ow: 1.6);
    }
  }
  // Sash tails.
  final sash = Path()
    ..moveTo(-6, -23)
    ..quadraticBezierTo(-11 + trail, -16 + wind, -14 + trail * 1.8, -8 + wind * 1.4)
    ..lineTo(-10 + trail * 1.8, -7 + wind * 1.4)
    ..quadraticBezierTo(-8 + trail, -14, -3, -22)
    ..close();
  _shape(c, sash, _flat(shade(k.trim, -0.12)), ow: 1.6);

  // ---- legs
  final legs = k.zombie ? 0.0 : step * 5;
  _limb(c, const Offset(-3, -15), Offset(-3 - legs, -3), shade(k.pants, -0.15), 5.5);
  _boot(c, Offset(-3 - legs, -1.5), k);
  _limb(c, const Offset(3, -15), Offset(3 + legs, -3), k.pants, 5.5);
  _boot(c, Offset(3 + legs, -1.5), k);

  // ---- back arm (sleeve)
  final swing = moving && !k.zombie ? -step * 5 : 0.0;
  final bShoulder = const Offset(-5, -34);
  final bHand = k.zombie ? const Offset(13, -33) : Offset(-8 + swing, -21);
  _shape(c, _sleevePath(bShoulder, bHand, 3, 5.5),
      _flat(shade(k.robe, -0.25)), ow: 2);
  _hand(c, bHand + (k.zombie ? const Offset(2, 0) : const Offset(0, 2)), k.skin);

  // ---- robe skirt
  final hem = k.longRobe ? -6.0 : -13.0;
  final flare = k.longRobe ? 12.5 : 10.5;
  final waist = k.female ? 6.0 : 7.5;
  final sk = moving ? step * 1.2 : 0.0;
  final skirt = Path()
    ..moveTo(-waist, -26)
    ..lineTo(waist, -26)
    ..quadraticBezierTo(flare - 2, (hem - 26) / 2, flare + sk, hem)
    ..quadraticBezierTo(2 + sk, hem + 3, -flare + trail + sk, hem - 1 + wind * 0.5)
    ..quadraticBezierTo(-flare + 3, (hem - 26) / 2, -waist, -26)
    ..close();
  _shape(c, skirt, _lit(k.robe, Rect.fromLTRB(-flare, -26, flare, hem)));
  // Front panel split and hem band.
  c.drawLine(Offset(4, -24), Offset(5.5 + sk, hem + 1), _outline(1.4));
  c.drawLine(Offset(-flare + trail + sk + 1.5, hem - 1.5), Offset(flare + sk - 1, hem - 1.5),
      _o
        ..color = col(k.trim)
        ..strokeWidth = 2.2);

  // ---- torso
  final torso = Path()
    ..moveTo(-8.5, -37)
    ..quadraticBezierTo(0, -40.5, 8.5, -37)
    ..quadraticBezierTo(9.5, -30, waist + 0.5, -24)
    ..lineTo(-waist - 0.5, -24)
    ..quadraticBezierTo(-9.5, -30, -8.5, -37)
    ..close();
  _shape(c, torso, _lit(k.robe, const Rect.fromLTRB(-9, -40, 9, -24)));
  // Cross collar: undershirt V and lapel.
  final v = Path()
    ..moveTo(-1.5, -38.5)
    ..lineTo(5.5, -38)
    ..lineTo(2.5, -31)
    ..close();
  c.drawPath(v, _flat(0xFFF4ECDC));
  c.drawLine(const Offset(-2.5, -38.5), const Offset(5, -27), _outline(3.6));
  c.drawLine(const Offset(-2.5, -38.5), const Offset(5, -27),
      _o
        ..color = col(k.trim)
        ..strokeWidth = 2.2);
  // Belt with a knot.
  final belt = Path()..addRRect(RRect.fromLTRBR(-waist - 1, -27, waist + 1, -23, const Radius.circular(1.5)));
  _shape(c, belt, _flat(k.trim), ow: 1.6);
  c.drawCircle(const Offset(3.5, -25), 2.2, _outline(1.4));
  c.drawCircle(const Offset(3.5, -25), 2.2, _flat(shade(k.trim, 0.2)));

  // ---- head
  // Neck.
  c.drawRect(const Rect.fromLTRB(-1.5, -38, 4, -34), _flat(shade(k.skin, -0.18)));
  final skin = k.zombie ? 0xFFA8C0A0 : k.skin;
  final face = Path()..addOval(Rect.fromCircle(center: const Offset(hx, hy), radius: hr));
  _shape(c, face,
      _lit(skin, const Rect.fromLTRB(hx - hr, hy - hr, hx + hr, hy + hr), light: 0.12, dark: 0.12));
  // Ear.
  // Ear at the back of the head (three-quarter view facing right).
  const ear = Rect.fromLTRB(hx - 13, hy - 1.5, hx - 8.5, hy + 5);
  c.drawOval(ear, _outline(1.4));
  c.drawOval(ear, _flat(shade(skin, -0.08)));
  c.drawArc(ear.deflate(1.3), -1.2, 2.4, false, _o
    ..color = col(shade(skin, -0.3))
    ..strokeWidth = 0.9);
  _face(c, k, hx, hy, attack, t, hurt);
  _hairFront(c, k, hx, hy, hr, t);

  // ---- front arm + weapon
  double hxA, hyA, wAng;
  if (k.zombie) {
    hxA = 17;
    hyA = -33;
    wAng = 0;
  } else if (cast && attack > 0) {
    hxA = 11 + 7 * attack;
    hyA = -33;
    wAng = -0.3;
  } else if (attack > 0) {
    final a = 1 - attack;
    final s = -2.4 + 3.1 * (1 - (1 - a) * (1 - a));
    hxA = 3 + math.cos(s) * 12;
    hyA = -33 + math.sin(s) * 12;
    wAng = s;
  } else {
    hxA = 8 + (moving ? step * 4 : 0);
    hyA = -22;
    wAng = _restAngle(k.weapon);
  }
  final hand = Offset(hxA, hyA);
  final longW = k.weapon == Weapon.staff || k.weapon == Weapon.spear;
  if (longW) _chibiWeapon(c, k, hand, wAng);
  _shape(c, _sleevePath(const Offset(4, -34), hand, 3, 5.5),
      _lit(k.robe, Rect.fromPoints(const Offset(4, -34), hand)), ow: 2);

  if (!longW) _chibiWeapon(c, k, hand, wAng);
  _hand(c, hand, k.skin);
  c.restore();
}

void _boot(Canvas c, Offset at, HumanLook k) {
  final p = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: at + const Offset(1.2, 0), width: 8.5, height: 4.6),
      const Radius.circular(2.3)));
  _shape(c, p, _flat(0xFF2A1E18), ow: 1.6);
  c.drawLine(at + const Offset(-2.6, -2.4), at + const Offset(3, -2.4),
      _o
        ..color = col(shade(k.trim, 0.1))
        ..strokeWidth = 1.4);
}

void _hand(Canvas c, Offset at, int skin) {
  c.drawCircle(at, 2.9, _outline(1.6));
  c.drawCircle(at, 2.9, _flat(skin));
}

void _face(Canvas c, HumanLook k, double hx, double hy, double attack, double t,
    bool hurt) {
  if (k.mask) {
    // Masked: only fierce eyes over the cloth.
    final p = Path()
      ..moveTo(hx - 3, hy + 1)
      ..quadraticBezierTo(hx + 8, hy - 0.5, hx + 12.5, hy + 0.5)
      ..quadraticBezierTo(hx + 11, hy + 9, hx + 2, hy + 11.5)
      ..quadraticBezierTo(hx - 4, hy + 8, hx - 3, hy + 1)
      ..close();
    _shape(c, p, _flat(shade(k.robe, -0.35)), ow: 1.5);
  }
  final blink = (t % 3.7) < 0.12 && !hurt;
  final fierce = attack > 0 || k.zombie;
  // Two eyes in three-quarter view: the near one bigger.
  for (final e in const [(7.2, 1.15), (1.4, 0.92)]) {
    final ex = hx + e.$1, ey = hy - 1.2, s = e.$2;
    if (blink || hurt) {
      final p = _o
        ..color = col(_ink)
        ..strokeWidth = 1.5;
      if (hurt) {
        c.drawLine(Offset(ex - 1.6 * s, ey - 1.6 * s), Offset(ex + 1.6 * s, ey + 1.6 * s), p);
        c.drawLine(Offset(ex - 1.6 * s, ey + 1.6 * s), Offset(ex + 1.6 * s, ey - 1.6 * s), p);
      } else {
        c.drawArc(Rect.fromCenter(center: Offset(ex, ey), width: 4 * s, height: 2.5 * s), 0,
            math.pi, false, p);
      }
      continue;
    }
    final white = Rect.fromCenter(center: Offset(ex, ey), width: 4.4 * s, height: 5.6 * s);
    c.drawOval(white, _flat(k.zombie ? 0xFFE8E8C8 : 0xFFFFFFFF));
    final iris = Rect.fromCenter(center: Offset(ex + 0.5 * s, ey + 0.4 * s),
        width: 3.4 * s, height: 4.4 * s);
    c.drawOval(iris, _flat(k.zombie ? 0xFF8A9A70 : 0xFF3A2418));
    c.drawCircle(Offset(ex + 0.6 * s, ey + 0.6 * s), 1.2 * s, _flat(0xFF100806));
    c.drawCircle(Offset(ex - 0.3 * s, ey - 0.9 * s), 0.9 * s, _flat(0xFFFFFFFF));
    c.drawOval(white, _o
      ..color = col(_ink)
      ..strokeWidth = 1.1);
    // Brow: angled down at the nose when fighting.
    final by = ey - 4.2 * s;
    c.drawLine(Offset(ex - 2.2 * s, by - (fierce ? 0.2 : 0.6)),
        Offset(ex + 2.3 * s, by + (fierce ? 1.4 : -0.2) * (e.$1 > 5 ? 1 : -1)),
        _o
          ..color = col(k.hairColor == 0xFF1E1A18 ? _ink : shade(k.hairColor, -0.3))
          ..strokeWidth = 1.4 * s);
  }
  if (k.mask) return;
  // Blush and mouth.
  c.drawOval(Rect.fromCenter(center: Offset(hx + 8.5, hy + 4), width: 3.6, height: 1.8),
      _flat(0x66F08A80));
  final mouth = _o
    ..color = col(0xFF7A3020)
    ..strokeWidth = 1.2;
  if (hurt || attack > 0.4) {
    c.drawOval(Rect.fromCenter(center: Offset(hx + 6, hy + 6.5), width: 2.6, height: 2.2),
        _flat(0xFF7A3020));
  } else {
    c.drawArc(Rect.fromCenter(center: Offset(hx + 6, hy + 5.5), width: 3, height: 2), 0.2,
        math.pi - 0.4, false, mouth);
  }
}

void _hairFront(Canvas c, HumanLook k, double hx, double hy, double hr, double t) {
  final hc = k.hairColor;
  Rect box(double pad) => Rect.fromLTRB(hx - hr - pad, hy - hr - pad, hx + hr, hy);
  // Cap of hair over the crown and back of the head, with bangs.
  Path cap({bool long = false}) => Path()
    ..moveTo(hx + 11.5, hy - 2.5)
    ..quadraticBezierTo(hx + 12, hy - 13.5, hx + 1, hy - 13.8)
    ..quadraticBezierTo(hx - 12, hy - 13, hx - 12.8, hy + (long ? 8 : 3))
    ..lineTo(hx - 7, hy + (long ? 6 : 2))
    ..lineTo(hx - 5.5, hy - 4)
    // Bangs: three points over the forehead.
    ..lineTo(hx - 1, hy - 7.5)
    ..lineTo(hx + 1.5, hy - 2.5)
    ..lineTo(hx + 4, hy - 7)
    ..lineTo(hx + 7, hy - 2)
    ..lineTo(hx + 8.5, hy - 6)
    ..close();
  switch (k.hair) {
    case Hair.bald:
      // Shine and ordination dots.
      c.drawOval(Rect.fromCenter(center: Offset(hx - 3, hy - 8), width: 6, height: 3),
          _flat(0x55FFFFFF));
      for (final d in const [Offset(-2, -10.5), Offset(1.5, -11.5), Offset(5, -10.5)]) {
        c.drawCircle(Offset(hx + d.dx, hy + d.dy), 0.9, _flat(0xFFB07040));
      }
    case Hair.topknot || Hair.bun || Hair.long || Hair.crown:
      _shape(c, cap(long: k.hair == Hair.long),
          _lit(hc, box(0), light: 0.35, dark: 0.1), ow: 2);
      // Shine streak.
      c.drawArc(Rect.fromCircle(center: Offset(hx, hy - 3), radius: 9), -2.6, 0.9, false,
          _o
            ..color = col(shade(hc, 0.45))
            ..strokeWidth = 1.3);
      if (k.hair == Hair.topknot || k.hair == Hair.bun) {
        final big = k.hair == Hair.bun ? 5.2 : 4.4;
        final knot = Offset(hx - 3, hy - 15);
        c.drawCircle(knot, big, _outline(1.8));
        c.drawCircle(knot, big, _flat(shade(hc, 0.1)));
        c.drawLine(knot + Offset(-big - 1, 1.5), knot + Offset(big + 1, -1),
            _o
              ..color = col(k.hair == Hair.bun ? 0xFFE8C547 : 0xFFD8C090)
              ..strokeWidth = 1.6);
      }
      if (k.hair == Hair.long) {
        // Hair ornament.
        c.drawCircle(Offset(hx - 6, hy - 10), 2.2, _outline(1.2));
        c.drawCircle(Offset(hx - 6, hy - 10), 2.2, _flat(0xFF7FDBFF));
        // Side lock in front of the ear.
        final p = Path()
          ..moveTo(hx - 6, hy - 3)
          ..quadraticBezierTo(hx - 7, hy + 6, hx - 4, hy + 11)
          ..lineTo(hx - 2.5, hy + 4)
          ..close();
        _shape(c, p, _flat(hc), ow: 1.4);
      }
      if (k.hair == Hair.crown) {
        final p = Path()
          ..moveTo(hx - 6, hy - 11)
          ..lineTo(hx - 4, hy - 20)
          ..lineTo(hx - 0.5, hy - 13)
          ..lineTo(hx + 2.5, hy - 22)
          ..lineTo(hx + 5, hy - 13)
          ..lineTo(hx + 8.5, hy - 20)
          ..lineTo(hx + 9, hy - 10)
          ..close();
        _shape(c, p, _lit(0xFFE8C547, Rect.fromLTRB(hx - 6, hy - 22, hx + 9, hy - 10)), ow: 1.6);
        c.drawCircle(Offset(hx + 2, hy - 13.5), 1.6, _flat(0xFFB3261E));
      }
    case Hair.hood:
      final p = Path()
        ..moveTo(hx + 12, hy + 2)
        ..quadraticBezierTo(hx + 13, hy - 15, hx, hy - 15)
        ..quadraticBezierTo(hx - 15, hy - 14, hx - 13, hy + 10)
        ..lineTo(hx - 4, hy + 12)
        ..lineTo(hx - 3, hy - 4)
        ..quadraticBezierTo(hx + 4, hy - 8, hx + 11, hy - 3)
        ..close();
      _shape(c, p, _lit(shade(k.robe, -0.15), box(3)), ow: 2);
    case Hair.turban:
      final p = Path()..addOval(Rect.fromLTRB(hx - 12, hy - 17, hx + 12, hy - 3));
      _shape(c, p, _lit(k.trim, Rect.fromLTRB(hx - 12, hy - 17, hx + 12, hy - 3)), ow: 2);
      c.drawLine(Offset(hx - 10, hy - 6), Offset(hx + 11, hy - 10), _outline(1.2));
      c.drawCircle(Offset(hx + 6, hy - 10), 1.8, _flat(0xFFE84B3A));
    case Hair.zombieHat:
      final brim = Path()..addRRect(RRect.fromLTRBR(hx - 13, hy - 12, hx + 14, hy - 8, const Radius.circular(2)));
      final top = Path()..addRRect(RRect.fromLTRBR(hx - 8, hy - 21, hx + 9, hy - 10, const Radius.circular(3)));
      _shape(c, top, _lit(0xFF2A2A3A, Rect.fromLTRB(hx - 8, hy - 21, hx + 9, hy - 10)), ow: 1.8);
      _shape(c, brim, _flat(0xFF1A1A22), ow: 1.8);
      c.drawCircle(Offset(hx, hy - 22), 2.4, _flat(0xFFB3261E));
      // Talisman.
      final tal = Path()..addRect(Rect.fromLTRB(hx + 4, hy - 9, hx + 9, hy + 7));
      _shape(c, tal, _flat(0xFFE8D24A), ow: 1.2);
      c.drawLine(Offset(hx + 6.5, hy - 6), Offset(hx + 6.5, hy + 4),
          _o
            ..color = col(0xFFB3261E)
            ..strokeWidth = 1);
    case Hair.straw:
      final p = Path()
        ..moveTo(hx - 17, hy - 4)
        ..lineTo(hx + 1, hy - 20)
        ..lineTo(hx + 19, hy - 4)
        ..quadraticBezierTo(hx + 1, hy, hx - 17, hy - 4)
        ..close();
      _shape(c, p, _lit(0xFFD8B870, Rect.fromLTRB(hx - 17, hy - 20, hx + 19, hy)), ow: 2);
  }
  if (k.band != 0) {
    // Across the forehead, just above the brows, curving round the head.
    final band = Path()
      ..moveTo(hx - 11.5, hy - 4)
      ..quadraticBezierTo(hx + 1, hy - 9.5, hx + 12.2, hy - 6.5);
    c.drawPath(band, _outline(5));
    c.drawPath(
        band,
        _o
          ..color = col(k.band)
          ..strokeWidth = 3);
    c.drawCircle(Offset(hx + 4, hy - 7.6), 1.5, _flat(0xFFE8C547));
  }
}

double _restAngle(Weapon w) => switch (w) {
      Weapon.staff => -1.35,
      Weapon.spear => -1.3,
      Weapon.saber || Weapon.bigSaber => -0.95,
      Weapon.sword => 0.95,
      Weapon.dagger => 1.2,
      _ => 0.0,
    };

void _chibiWeapon(Canvas c, HumanLook k, Offset hand, double ang) {
  c.save();
  c.translate(hand.dx, hand.dy);
  c.rotate(ang);
  if (k.glow != 0) {
    c.drawRect(
        const Rect.fromLTRB(-2, -4, 34, 4),
        Paint()
          ..color = col(k.glow).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }
  switch (k.weapon) {
    case Weapon.staff:
      _limb(c, const Offset(-20, 0), const Offset(34, 0), 0xFF8A5A2A, 3.2);
      for (final x in const [-20.0, 31.0]) {
        final cap = Path()..addRRect(RRect.fromLTRBR(x, -2.6, x + 5, 2.6, const Radius.circular(1.2)));
        _shape(c, cap, _flat(0xFFE8C547), ow: 1.4);
      }
      c.drawLine(const Offset(-6, -2.2), const Offset(-6, 2.2), _outline(1));
    case Weapon.spear:
      _limb(c, const Offset(-18, 0), const Offset(36, 0), 0xFF6A4A2A, 2.4);
      final tip = Path()
        ..moveTo(36, -3.6)
        ..lineTo(48, 0)
        ..lineTo(36, 3.6)
        ..close();
      _shape(c, tip, _lit(k.blade, const Rect.fromLTRB(36, -4, 48, 4)), ow: 1.4);
      c.drawCircle(const Offset(35, 2), 3, _flat(0xFFB3261E));
    case Weapon.saber || Weapon.bigSaber:
      final b = k.weapon == Weapon.bigSaber ? 1.35 : 1.1;
      _limb(c, const Offset(-5, 0), const Offset(3, 0), 0xFF3A2A1A, 3);
      final guard = Path()..addOval(const Rect.fromLTRB(1.5, -4, 5, 4));
      _shape(c, guard, _flat(0xFFC9A040), ow: 1.2);
      final blade = Path()
        ..moveTo(5, -2.4 * b)
        ..lineTo(24 * b, -3.6 * b)
        ..quadraticBezierTo(31 * b, -2 * b, 28 * b, 3.4 * b)
        ..lineTo(5, 2.6 * b)
        ..close();
      _shape(c, blade, _lit(k.blade, Rect.fromLTRB(5, -4 * b, 31 * b, 4 * b), light: 0.4), ow: 1.6);
      c.drawLine(Offset(6, -1.2 * b), Offset(24 * b, -2.2 * b),
          _o
            ..color = col(0xFFFFFFFF)
            ..strokeWidth = 0.9);
      // Red tassel on the pommel.
      c.drawLine(const Offset(-5, 0), Offset(-9, 4 + math.sin(ang * 3) * 1.5),
          _o
            ..color = col(0xFFD8302A)
            ..strokeWidth = 1.8);
    case Weapon.sword:
      _limb(c, const Offset(-5, 0), const Offset(2, 0), 0xFF3A2A1A, 2.6);
      final guard = Path()..addRRect(RRect.fromLTRBR(1, -4.2, 3.6, 4.2, const Radius.circular(1)));
      _shape(c, guard, _flat(0xFFC9A040), ow: 1.2);
      final blade = Path()
        ..moveTo(4, -1.7)
        ..lineTo(31, -1.2)
        ..lineTo(35, 0)
        ..lineTo(31, 1.2)
        ..lineTo(4, 1.7)
        ..close();
      _shape(c, blade, _lit(k.blade, const Rect.fromLTRB(4, -2, 35, 2), light: 0.4), ow: 1.4);
      c.drawLine(const Offset(5, 0), const Offset(30, 0),
          _o
            ..color = col(shade(k.blade, -0.25))
            ..strokeWidth = 0.6);
      c.drawLine(const Offset(-5, 0), Offset(-10, 5 + math.sin(ang * 3) * 1.5),
          _o
            ..color = col(0xFFD8302A)
            ..strokeWidth = 1.8);
    case Weapon.dagger:
      final blade = Path()
        ..moveTo(1, -2)
        ..lineTo(15, 0)
        ..lineTo(1, 2)
        ..close();
      _shape(c, blade, _lit(k.blade, const Rect.fromLTRB(1, -2, 15, 2), light: 0.4), ow: 1.3);
      _limb(c, const Offset(-4, 0), const Offset(1, 0), 0xFF2A1A10, 2.4);
    case Weapon.darts:
      for (var i = 0; i < 3; i++) {
        c.save();
        c.rotate(-0.45 + i * 0.45);
        final p = Path()
          ..moveTo(3, -1.3)
          ..lineTo(13, 0)
          ..lineTo(3, 1.3)
          ..close();
        _shape(c, p, _flat(k.blade), ow: 1.1);
        c.restore();
      }
    case Weapon.none:
      break;
  }
  c.restore();
}

// ------------------------------------------------------------------ quad

/// Chibi four-legged beasts: wolves, boars, the fire wolf and the kỳ lân.
void drawQuadChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final v = d.variant;
  final boar = v == 'boar';
  final kylin = v == 'kylin';
  final fire = v == 'fireWolf' || kylin;
  final step = moving ? math.sin(walk * 2.2) * 4 : 0.0;
  final lunge = attack > 0 ? math.sin(attack * math.pi) * 6 : 0.0;
  final breathe = math.sin(t * 3) * 0.6;
  final legH = boar ? 7.0 : 10.0;
  final by = -legH - 9 + breathe * 0.3;
  c.save();
  c.translate(lunge, 0);

  // Tail.
  final wag = math.sin(t * (moving ? 10 : 4)) * 3;
  if (boar) {
    c.drawPath(
        Path()
          ..moveTo(-17, by - 3)
          ..quadraticBezierTo(-23, by - 9 + wag, -21, by - 1),
        _outline(2));
  } else {
    final tail = Path()
      ..moveTo(-15, by - 4)
      ..quadraticBezierTo(-27, by - 14 + wag, -31, by - 4 + wag)
      ..quadraticBezierTo(-25, by - 1, -15, by + 2)
      ..close();
    _shape(c, tail, _lit(fire ? d.c2 : d.c1, Rect.fromLTRB(-31, by - 14, -15, by + 2)));
    final tip = Path()
      ..moveTo(-26, by - 9 + wag)
      ..quadraticBezierTo(-32, by - 8 + wag, -31, by - 4 + wag)
      ..quadraticBezierTo(-28, by - 4, -26, by - 9 + wag)
      ..close();
    c.drawPath(tip, _flat(fire ? 0xFFFFD34A : d.c2));
  }

  // Far legs.
  final far = shade(d.c1, -0.3);
  _limb(c, Offset(-10, by + 4), Offset(-10 - step, -2), far, 5);
  _limb(c, Offset(10, by + 4), Offset(10 + step, -2), far, 5);

  // Body.
  final body = Path()..addOval(Rect.fromCenter(center: Offset(0, by), width: 36, height: boar ? 24 : 20));
  _shape(c, body, _lit(d.c1, Rect.fromCenter(center: Offset(0, by), width: 36, height: 24)));
  // Belly.
  c.drawOval(Rect.fromCenter(center: Offset(2, by + 5), width: 24, height: 7), _flat(shade(d.c2, -0.05)));
  if (boar) {
    for (var i = 0; i < 6; i++) {
      final x = -12 + i * 4.5;
      c.drawLine(Offset(x, by - 10), Offset(x - 2, by - 15), _outline(2.4));
      c.drawLine(Offset(x, by - 10), Offset(x - 2, by - 15),
          _o
            ..color = col(d.c2)
            ..strokeWidth = 1.2);
    }
  }
  if (v == 'tiger') {
    // Stripes across the back.
    for (var i = 0; i < 4; i++) {
      final x = -11 + i * 6.0;
      c.drawPath(
          Path()
            ..moveTo(x, by - 9)
            ..quadraticBezierTo(x + 2.5, by - 3, x, by + 3),
          _o
            ..color = col(d.c3)
            ..strokeWidth = 2.2);
    }
  }
  if (kylin) {
    for (var i = 0; i < 4; i++) {
      final s = Path()..addArc(Rect.fromCircle(center: Offset(-10 + i * 6.0, by - 1), radius: 3.2), 0, math.pi);
      c.drawPath(s, _o
        ..color = col(shade(d.c1, 0.35))
        ..strokeWidth = 1.2);
    }
  }
  // Near legs with paws.
  for (final lx in const [-6.0, 13.0]) {
    final dx = lx < 0 ? step : -step;
    _limb(c, Offset(lx, by + 4), Offset(lx + dx, -2.5), d.c1, 5.5);
    final paw = Path()..addOval(Rect.fromCenter(center: Offset(lx + dx + 1.2, -1.5), width: 7, height: 4));
    _shape(c, paw, _flat(boar ? 0xFF2A1E18 : shade(d.c2, -0.1)), ow: 1.4);
  }

  // Head.
  final hx = 18.0, hy = by - (boar ? 3 : 8);
  if (fire || v == 'wolf') {
    // Ruff / flame mane behind the head.
    final ruff = Path();
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (0.55 + i * 0.16);
      final r = 12 + (i.isEven ? 3 : 0) + (fire ? math.sin(t * 12 + i) * 1.5 : 0);
      final p = Offset(hx - 3 + math.cos(a) * r, hy + 2 + math.sin(a) * -r);
      i == 0 ? ruff.moveTo(p.dx, p.dy) : ruff.lineTo(p.dx, p.dy);
    }
    ruff.lineTo(hx - 2, hy + 9);
    ruff.close();
    _shape(c, ruff, _flat(fire ? (kylin ? d.c3 : 0xFFFF9A3D) : d.c2), ow: 1.8);
  }
  if (!boar) {
    // Ears.
    for (final e in const [-5.0, 1.0]) {
      final ear = Path()
        ..moveTo(hx + e - 3, hy - 6)
        ..lineTo(hx + e - 1, hy - 17)
        ..lineTo(hx + e + 4, hy - 7)
        ..close();
      _shape(c, ear, _flat(e < 0 ? shade(d.c1, -0.2) : d.c1), ow: 1.6);
      c.drawPath(
          Path()
            ..moveTo(hx + e - 1.5, hy - 7.5)
            ..lineTo(hx + e - 0.6, hy - 13)
            ..lineTo(hx + e + 2, hy - 8),
          _flat(0xFFE8A0A0));
    }
  }
  final head = Path()..addOval(Rect.fromCircle(center: Offset(hx, hy), radius: 10));
  _shape(c, head, _lit(d.c1, Rect.fromCircle(center: Offset(hx, hy), radius: 10)));
  // Snout.
  final snout = Path()
    ..addRRect(RRect.fromLTRBR(hx + 3, hy - 1, hx + (boar ? 15 : 16), hy + 7, const Radius.circular(4)));
  _shape(c, snout, _flat(boar ? shade(d.c1, 0.2) : d.c2), ow: 1.8);
  if (boar) {
    c.drawCircle(Offset(hx + 12.5, hy + 2), 1, _flat(_ink));
    c.drawCircle(Offset(hx + 12.5, hy + 4.5), 1, _flat(_ink));
    final tusk = Path()
      ..moveTo(hx + 9, hy + 6)
      ..quadraticBezierTo(hx + 13, hy + 6, hx + 13, hy + 1)
      ..lineTo(hx + 11, hy + 5)
      ..close();
    _shape(c, tusk, _flat(d.c3), ow: 1.2);
  } else {
    c.drawCircle(Offset(hx + 15.5, hy + 1.5), 2, _flat(_ink));
    // Mouth, open on the bite.
    if (attack > 0.3) {
      c.drawPath(
          Path()
            ..moveTo(hx + 6, hy + 5)
            ..lineTo(hx + 15, hy + 5)
            ..lineTo(hx + 12, hy + 9)
            ..close(),
          _flat(0xFF8A1A1A));
      c.drawLine(Offset(hx + 9, hy + 5), Offset(hx + 10, hy + 7.5), _o
        ..color = col(0xFFFFFFFF)
        ..strokeWidth = 1.2);
    }
  }
  if (kylin) {
    final horn = Path()
      ..moveTo(hx - 1, hy - 8)
      ..quadraticBezierTo(hx + 2, hy - 18, hx + 7, hy - 20)
      ..quadraticBezierTo(hx + 3, hy - 14, hx + 3, hy - 8)
      ..close();
    _shape(c, horn, _lit(0xFFE8C547, Rect.fromLTRB(hx - 1, hy - 20, hx + 7, hy - 8)), ow: 1.6);
  }
  // Eye: fierce slant with a glint.
  final eyeC = fire ? 0xFFFFE04A : (d.hanh.index == 2 ? 0xFF7FD4FF : 0xFFFFF4D0);
  final eye = Path()
    ..moveTo(hx + 1, hy - 3)
    ..lineTo(hx + 7.5, hy - 4.5)
    ..quadraticBezierTo(hx + 7, hy + 0.5, hx + 3, hy + 0.5)
    ..close();
  _shape(c, eye, _flat(eyeC), ow: 1.2);
  c.drawCircle(Offset(hx + 4.8, hy - 1.8), 1.4, _flat(_ink));
  c.drawCircle(Offset(hx + 4.2, hy - 2.5), 0.6, _flat(0xFFFFFFFF));
  c.drawLine(Offset(hx, hy - 5), Offset(hx + 8, hy - 6.5), _outline(1.6));

  if (fire) {
    for (var i = 0; i < 4; i++) {
      final fx = -10.0 + i * 7, fy = by - 11 - (math.sin(t * 10 + i)).abs() * 3;
      c.drawPath(
          Path()
            ..moveTo(fx - 3, fy + 3)
            ..quadraticBezierTo(fx, fy - 7, fx + 3, fy + 3)
            ..close(),
          _flat(i.isEven ? 0xEEFFB03A : 0xEEFF6A2A));
    }
  }
  c.restore();
}

// ------------------------------------------------------------------ helpers

/// Overlapping circles outlined only on their combined silhouette.
void _blob(Canvas c, List<(Offset, double)> parts, List<Paint> fills, {double ow = 2.2}) {
  final ink = Paint()
    ..isAntiAlias = true
    ..color = col(_ink);
  for (final (p, r) in parts) {
    c.drawCircle(p, r + ow / 2, ink);
  }
  for (var i = 0; i < parts.length; i++) {
    c.drawCircle(parts[i].$1, parts[i].$2, fills[i % fills.length]);
  }
}

/// A fierce little eye with a slanted lid and a glint.
void _beastEye(Canvas c, Offset at, double s, int iris, {bool slit = false}) {
  final eye = Path()
    ..moveTo(at.dx - 2.6 * s, at.dy - 0.6 * s)
    ..lineTo(at.dx + 2.8 * s, at.dy - 1.8 * s)
    ..quadraticBezierTo(at.dx + 2.4 * s, at.dy + 2.2 * s, at.dx - 1.4 * s, at.dy + 1.8 * s)
    ..close();
  _shape(c, eye, _flat(iris), ow: 1.1);
  if (slit) {
    c.drawLine(Offset(at.dx + 0.4 * s, at.dy - 1.2 * s), Offset(at.dx + 0.2 * s, at.dy + 1.6 * s),
        _o
          ..color = col(_ink)
          ..strokeWidth = 1.1 * s);
  } else {
    c.drawCircle(Offset(at.dx + 0.4 * s, at.dy + 0.2 * s), 1.1 * s, _flat(_ink));
  }
  c.drawCircle(Offset(at.dx - 0.4 * s, at.dy - 0.5 * s), 0.5 * s, _flat(0xFFFFFFFF));
}

// ------------------------------------------------------------------ serpent

void drawSerpentChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final wave = walk * 2.5 + t * 2.2;
  final rise = attack > 0 ? math.sin(attack * math.pi) * 9 : 0.0;
  final parts = <(Offset, double)>[];
  for (var i = 0; i < 12; i++) {
    final f = i / 11;
    // Coiled low at the tail, rearing up toward the head like a cobra.
    final x = -26 + f * 34 + (f > 0.7 ? (f - 0.7) * 12 : 0);
    final y = -5 + math.sin(wave + f * 5.5) * 4 * (1 - f) - math.pow(f, 2.6) * (30 + rise);
    parts.add((Offset(x, y), 2.6 + f * 4.6));
  }
  _blob(c, parts, [_lit(d.c1, const Rect.fromLTRB(-30, -30, 18, 0))]);
  // Belly scales and back diamonds.
  for (var i = 1; i < parts.length - 1; i++) {
    final (p, r) = parts[i];
    c.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.45), width: r * 1.3, height: r * 0.6),
        _flat(shade(d.c2, 0.1)));
    if (i.isEven) {
      final dm = Path()
        ..moveTo(p.dx, p.dy - r * 0.75)
        ..lineTo(p.dx + r * 0.4, p.dy - r * 0.35)
        ..lineTo(p.dx, p.dy + 0.05)
        ..lineTo(p.dx - r * 0.4, p.dy - r * 0.35)
        ..close();
      c.drawPath(dm, _flat(shade(d.c1, -0.3)));
    }
  }
  final hp = parts.last.$1;
  final hx = hp.dx + 4, hy = hp.dy - 5;
  final dragon = d.variant == 'dragon';
  if (dragon) {
    // Mane fins down the back, antlers and long whiskers.
    for (var i = 3; i < parts.length - 1; i += 2) {
      final (p, r) = parts[i];
      final fin = Path()
        ..moveTo(p.dx - r * 0.6, p.dy - r * 0.7)
        ..lineTo(p.dx - r * 0.2, p.dy - r * 1.6)
        ..lineTo(p.dx + r * 0.5, p.dy - r * 0.8)
        ..close();
      _shape(c, fin, _flat(d.c3), ow: 1.4);
    }
    final horn = _o
      ..color = col(d.c3)
      ..strokeWidth = 2.2;
    for (final k in [-1.0, 1.0]) {
      final bx = hx - 3 + k * 2;
      c.drawPath(
          Path()
            ..moveTo(bx, hy - 5)
            ..lineTo(bx - 6, hy - 15)
            ..moveTo(bx - 3, hy - 10)
            ..lineTo(bx + 1, hy - 14),
          horn);
    }
    final whisk = math.sin(t * 3) * 2;
    c.drawPath(
        Path()
          ..moveTo(hx + 8, hy + 2)
          ..quadraticBezierTo(hx + 16, hy + 6 + whisk, hx + 20, hy + 1 + whisk)
          ..moveTo(hx + 8, hy + 3)
          ..quadraticBezierTo(hx + 12, hy + 10 - whisk, hx + 18, hy + 11 - whisk),
        _o
          ..color = col(d.c3)
          ..strokeWidth = 1.2);
  }
  if (d.boss && !dragon) {
    // Cobra hood behind the head.
    final hood = Path()
      ..moveTo(hx - 3, hy - 9)
      ..quadraticBezierTo(hx - 16, hy - 4, hx - 8, hy + 12)
      ..quadraticBezierTo(hx - 3, hy + 6, hx, hy + 2)
      ..close();
    _shape(c, hood, _lit(d.c2, Rect.fromLTRB(hx - 16, hy - 9, hx, hy + 12)));
    c.drawCircle(Offset(hx - 8, hy + 1), 2, _flat(d.c3));
  }
  final hr = Rect.fromCenter(center: Offset(hx, hy), width: 20, height: 14);
  _shape(c, Path()..addOval(hr), _lit(d.c1, hr));
  c.drawOval(Rect.fromCenter(center: Offset(hx + 3, hy + 3.5), width: 11, height: 3.5),
      _flat(shade(d.c2, 0.15)));
  _beastEye(c, Offset(hx + 3, hy - 2), 1.1, d.boss ? d.c3 : 0xFFFFE04A, slit: !dragon);
  if (!dragon && ((t * 3).floor().isEven || attack > 0)) {
    final tg = Path()
      ..moveTo(hx + 9, hy + 1.5)
      ..lineTo(hx + 15, hy + 1.5)
      ..lineTo(hx + 17, hy - 0.5)
      ..moveTo(hx + 15, hy + 1.5)
      ..lineTo(hx + 17, hy + 3.5);
    c.drawPath(
        tg,
        _o
          ..color = col(0xFFE84B3A)
          ..strokeWidth = 1.2);
  }
}

// ------------------------------------------------------------------ bugs

void drawSpiderChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final step = moving ? walk * 3 : t * 0.5;
  for (var side = 0; side < 2; side++) {
    for (var i = 0; i < 4; i++) {
      final ph = math.sin(step + i * 1.4 + side * math.pi) * 3;
      final bx = -3.0 + i * 3.5, by = -11.0;
      final kx = bx + (i - 1.5) * 7 + ph, ky = by - 10;
      final fx = bx + (i - 1.5) * 11.5 + ph;
      final colr = side == 0 ? shade(d.c1, -0.25) : d.c1;
      _limb(c, Offset(bx, by), Offset(kx, ky), colr, 2.4);
      _limb(c, Offset(kx, ky), Offset(fx, -1), colr, 2);
    }
  }
  const abdR = Rect.fromLTRB(-20, -24, 2, -6);
  _shape(c, Path()..addOval(abdR), _lit(d.c1, abdR, light: 0.3));
  // Hourglass mark.
  final mark = Path()
    ..moveTo(-12, -20)
    ..lineTo(-6, -20)
    ..lineTo(-9, -15)
    ..lineTo(-6, -10)
    ..lineTo(-12, -10)
    ..lineTo(-9, -15)
    ..close();
  c.drawPath(mark, _flat(d.c2));
  const headR = Rect.fromLTRB(-2.5, -19.5, 12.5, -4.5);
  _shape(c, Path()..addOval(headR), _lit(shade(d.c1, 0.12), headR));
  // Eyes: two big, two small.
  for (final e in const [(7.5, -14.5, 2.4), (3.8, -14.8, 2.0), (9.5, -11.0, 1.2), (6.0, -10.5, 1.1)]) {
    c.drawCircle(Offset(e.$1, e.$2), e.$3 + 0.6, _flat(_ink));
    c.drawCircle(Offset(e.$1, e.$2), e.$3, _flat(0xFFE8303A));
    c.drawCircle(Offset(e.$1 - e.$3 * 0.3, e.$2 - e.$3 * 0.3), e.$3 * 0.35, _flat(0xFFFFFFFF));
  }
  // Fangs, spread on the bite.
  final open = attack > 0 ? 1.5 : 0.0;
  for (final s in const [-1.0, 1.0]) {
    final f = Path()
      ..moveTo(9 + s * 1.5, -7.5)
      ..lineTo(10.5 + s * (2 + open), -3.5)
      ..lineTo(11 + s * 0.6, -7)
      ..close();
    _shape(c, f, _flat(0xFFEDE6D0), ow: 1);
  }
}

void drawScorpionChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final step = moving ? walk * 3 : 0.0;
  for (var i = 0; i < 3; i++) {
    final ph = math.sin(step + i * 1.7) * 3;
    _limb(c, Offset(-7.0 + i * 6, -8), Offset(-11.0 + i * 7 + ph, -1), shade(d.c1, -0.25), 2.2);
  }
  // Segmented body as one outlined blob.
  _blob(c, [
    for (var i = 0; i < 4; i++) (Offset(-8.0 + i * 6, -10), i == 0 ? 4.5 : 5.5),
  ], [
    _lit(d.c1, const Rect.fromLTRB(-14, -16, 14, -4))
  ]);
  for (var i = 0; i < 3; i++) {
    c.drawArc(Rect.fromCircle(center: Offset(-5.0 + i * 6, -10), radius: 5), -2.2, 1.4, false,
        _o
          ..color = col(shade(d.c1, -0.3))
          ..strokeWidth = 1);
  }
  // Tail arching over the back; strikes forward on attack.
  final strike = attack > 0 ? math.sin(attack * math.pi) : 0.0;
  final tail = <(Offset, double)>[];
  var px = -11.0, py = -12.0;
  for (var i = 0; i < 5; i++) {
    final a = -math.pi * 0.5 - i * 0.48 + strike * 0.7;
    px += math.cos(a) * -6.8;
    py += math.sin(a) * 6.8;
    tail.add((Offset(px, py), 4.8 - i * 0.4));
  }
  _blob(c, tail, [_flat(d.c1), _flat(shade(d.c1, 0.12))], ow: 2);
  final sting = Path()
    ..moveTo(px - 2, py - 2)
    ..quadraticBezierTo(px + 7, py - 2, px + 5, py + 6)
    ..quadraticBezierTo(px + 3, py + 1, px - 2, py + 2)
    ..close();
  _shape(c, sting, _flat(d.boss ? d.c3 : shade(d.c2, -0.2)), ow: 1.6);
  // Claws.
  final open = math.sin(t * 5) * 0.2 + 0.3 + strike * 0.3;
  for (final s in const [-1.0, 1.0]) {
    _limb(c, Offset(11, -10 + s * 2), Offset(17, -12 + s * 3), s < 0 ? shade(d.c1, -0.2) : d.c1, 2.6);
    c.save();
    c.translate(17, -12 + s * 3);
    final upper = Path()
      ..moveTo(0, -1)
      ..quadraticBezierTo(5, -6 - open * 6, 10, -1)
      ..lineTo(4, 0)
      ..close();
    final lower = Path()
      ..moveTo(0, 1)
      ..quadraticBezierTo(5, 5 + open * 5, 9, 2)
      ..lineTo(3, 1)
      ..close();
    _shape(c, upper, _lit(d.c1, const Rect.fromLTRB(0, -8, 10, 0)), ow: 1.6);
    _shape(c, lower, _flat(shade(d.c1, -0.12)), ow: 1.6);
    c.restore();
  }
  _beastEye(c, const Offset(13, -12.5), 0.8, d.boss ? d.c3 : 0xFFFFE04A);
}

// ------------------------------------------------------------------ flyers

void drawFlyerChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final hover = -38 + math.sin(t * 3 + walk * 0.3) * 4;
  c.save();
  c.translate(0, hover);
  switch (d.variant) {
    case 'bat':
      final flap = math.sin(t * 16);
      for (final s in const [-1.0, 1.0]) {
        final up = -10 - flap * 9;
        final wing = Path()
          ..moveTo(s * 3, -2)
          ..quadraticBezierTo(s * 12, up, s * 24, up + 4)
          ..quadraticBezierTo(s * 21, 0, s * 18, 3)
          ..quadraticBezierTo(s * 15, -1, s * 12, 3)
          ..quadraticBezierTo(s * 9, 0, s * 4, 4)
          ..close();
        _shape(c, wing, _flat(s < 0 ? shade(d.c1, -0.25) : d.c1), ow: 1.8);
        for (final k in const [12.0, 18.0]) {
          c.drawLine(Offset(s * 3, -2), Offset(s * k, k == 12 ? 3 : 2),
              _o
                ..color = col(shade(d.c1, -0.4))
                ..strokeWidth = 0.9);
        }
      }
      for (final s in const [-1.0, 1.0]) {
        final ear = Path()
          ..moveTo(s * 2, -6)
          ..lineTo(s * 5.5, -13)
          ..lineTo(s * 6, -4)
          ..close();
        _shape(c, ear, _flat(d.c1), ow: 1.4);
      }
      const br = Rect.fromLTRB(-7, -7.5, 7, 7.5);
      _shape(c, Path()..addOval(br), _lit(d.c1, br, light: 0.3));
      c.drawOval(Rect.fromCenter(center: const Offset(0, 3), width: 8, height: 6), _flat(shade(d.c1, 0.2)));
      for (final s in const [-1.0, 1.0]) {
        c.drawCircle(Offset(s * 2.8, -1.5), 2.2, _flat(_ink));
        c.drawCircle(Offset(s * 2.8, -1.5), 1.6, _flat(d.c2));
        c.drawCircle(Offset(s * 2.8 - 0.5, -2), 0.5, _flat(0xFFFFFFFF));
        final fang = Path()
          ..moveTo(s * 1.4, 3)
          ..lineTo(s * 1.9, 5.5)
          ..lineTo(s * 2.6, 3)
          ..close();
        c.drawPath(fang, _flat(0xFFFFFFFF));
      }
    case 'ghost':
      final sway = math.sin(t * 4) * 3;
      c.drawCircle(
          const Offset(0, -4),
          16,
          Paint()
            ..color = col(d.c2).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      final body = Path()
        ..moveTo(-11, 0)
        ..quadraticBezierTo(-12, -22, 0, -21)
        ..quadraticBezierTo(12, -22, 11, 0)
        ..quadraticBezierTo(9 + sway, 10, 4 + sway * 1.5, 18)
        ..lineTo(1 + sway, 11)
        ..lineTo(-2 + sway * 2, 20)
        ..lineTo(-5 + sway, 10)
        ..quadraticBezierTo(-9, 8, -11, 0)
        ..close();
      c.drawPath(
          body,
          _o
            ..color = col(shade(d.c1, -0.5))
            ..strokeWidth = 2);
      c.drawPath(
          body,
          _g
            ..shader = Gradient.linear(const Offset(0, -22), const Offset(0, 20),
                [col(shade(d.c1, 0.3)), col(d.c1).withValues(alpha: 0.55 * col(d.c1).a)]));
      c.drawOval(Rect.fromCenter(center: const Offset(1, -10), width: 15, height: 11), _flat(0xCC1A1428));
      for (final s in const [-1.0, 1.0]) {
        c.drawCircle(
            Offset(1 + s * 3.2, -10),
            2.4,
            Paint()
              ..color = col(d.c2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        c.drawCircle(Offset(1 + s * 3.2, -10), 1.2, _flat(0xFFFFFFFF));
      }
      final reach = attack > 0 ? 5.0 : 0.0;
      c.drawPath(
          Path()
            ..moveTo(9, -4)
            ..quadraticBezierTo(15 + reach, -2, 17 + reach, 4),
          _o
            ..color = col(shade(d.c1, 0.2))
            ..strokeWidth = 3);
    default:
      // Wisp: a living flame with a grumpy little face.
      c.drawCircle(
          const Offset(0, -4),
          18,
          Paint()
            ..color = col(d.c1).withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      final flick = math.sin(t * 9) * 3, flick2 = math.cos(t * 7) * 2;
      final flame = Path()
        ..moveTo(-11, 2)
        ..quadraticBezierTo(-13, -12, -5, -16)
        ..quadraticBezierTo(-4, -22, -1 + flick, -27)
        ..quadraticBezierTo(2, -18, 5, -17 + flick2)
        ..quadraticBezierTo(8, -21, 9 + flick2, -23)
        ..quadraticBezierTo(14, -10, 11, 2)
        ..quadraticBezierTo(0, 13, -11, 2)
        ..close();
      c.drawPath(
          flame,
          _o
            ..color = col(shade(d.c1, -0.45))
            ..strokeWidth = 2);
      c.drawPath(
          flame,
          _g
            ..shader = Gradient.linear(const Offset(0, -26), const Offset(0, 10),
                [col(d.c2), col(d.c1), col(shade(d.c1, -0.2))], const [0, 0.55, 1]));
      c.drawOval(Rect.fromCenter(center: const Offset(0, -1), width: 13, height: 12), _flat(shade(d.c2, 0.3)));
      for (final s in const [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(s * 2.8, -2.5), width: 2.6, height: 3.6), _flat(0xFF1A1A2A));
        c.drawCircle(Offset(s * 2.8 - 0.4, -3.3), 0.55, _flat(0xFFFFFFFF));
        c.drawLine(Offset(s * 1.5, -5.6), Offset(s * 4.4, -6.4),
            _o
              ..color = col(0xFF1A1A2A)
              ..strokeWidth = 1);
      }
      c.drawArc(Rect.fromCenter(center: const Offset(0, 2), width: 4, height: 3), 0.2, math.pi - 0.4, false,
          _o
            ..color = col(0xFF1A1A2A)
            ..strokeWidth = 1);
  }
  c.restore();
}

// ------------------------------------------------------------------ brutes

void drawBruteChibi(Canvas c, MobDef d,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  final step = moving ? math.sin(walk * 1.6) * 4 : 0.0;
  final golem = d.variant == 'golem';
  final yeti = d.variant == 'yeti';
  final smash = attack > 0 ? math.sin(attack * math.pi) : 0.0;
  final breathe = math.sin(t * 2.4) * 0.8;
  final fur = golem ? shade(d.c1, -0.1) : d.c1;

  // Legs and feet.
  _limb(c, const Offset(-6, -16), Offset(-6 - step, -3), shade(fur, -0.25), 7.5);
  _limb(c, const Offset(6, -16), Offset(6 + step, -3), fur, 7.5);
  for (final x in [-6 - step, 6 + step]) {
    final foot = Path()..addOval(Rect.fromCenter(center: Offset(x + 1.5, -1.5), width: 11, height: 5));
    _shape(c, foot, _flat(golem ? shade(d.c1, -0.3) : shade(d.c2, -0.1)), ow: 1.6);
  }
  // Back arm.
  _limb(c, const Offset(-11, -38), Offset(-15, -15 + step), shade(fur, -0.25), 8.5);
  final bFist = Path()..addOval(Rect.fromCircle(center: Offset(-15, -13 + step), radius: 5.5));
  _shape(c, bFist, _flat(shade(golem ? d.c1 : d.c2, -0.25)), ow: 1.8);

  // Torso.
  if (golem) {
    for (final r in [
      Rect.fromLTRB(-16, -50 + breathe, 2, -32),
      Rect.fromLTRB(-2, -51 + breathe, 16, -34),
      const Rect.fromLTRB(-15, -34, 15, -15),
    ]) {
      _shape(c, Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(5))),
          _lit(d.c1, r, light: 0.25, dark: 0.35));
    }
    // Glowing lava seams.
    final glow = 0.6 + 0.4 * math.sin(t * 3);
    final seam = Path()
      ..moveTo(-10, -45)
      ..lineTo(-4, -37)
      ..lineTo(-7, -27)
      ..lineTo(2, -21)
      ..moveTo(7, -45)
      ..lineTo(10, -36)
      ..lineTo(6, -26);
    c.drawPath(
        seam,
        Paint()
          ..color = col(d.c2).withValues(alpha: 0.6 * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.drawPath(
        seam,
        _o
          ..color = col(shade(d.c2, 0.3))
          ..strokeWidth = 1.8);
  } else {
    final torso = Rect.fromLTRB(-17, -51 + breathe, 17, -14);
    _shape(c, Path()..addOval(torso), _lit(fur, torso));
    if (yeti) {
      // Fur tufts along the outline.
      for (var i = 0; i < 7; i++) {
        final a = math.pi * (0.75 + i * 0.22);
        final p = Offset(math.cos(a) * 17, -33 + math.sin(a) * 18);
        final tuft = Path()
          ..moveTo(p.dx - 3, p.dy)
          ..lineTo(p.dx + math.cos(a) * 5, p.dy + math.sin(a) * 5)
          ..lineTo(p.dx + 3, p.dy)
          ..close();
        _shape(c, tuft, _flat(fur), ow: 1.4);
      }
    }
    c.drawOval(Rect.fromLTRB(-9, -42 + breathe, 11, -19), _flat(d.c2));
  }

  // Head.
  const hx = 5.0, hy = -53.0;
  if (d.boss || yeti) {
    for (final s in const [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(hx + s * 4 - 2, hy - 6)
        ..quadraticBezierTo(hx + s * 10, hy - 14, hx + s * 8, hy - 20)
        ..quadraticBezierTo(hx + s * 6, hy - 12, hx + s * 4 + 2, hy - 6)
        ..close();
      _shape(c, horn,
          _lit(d.boss ? d.c3 : 0xFFDCD0B8, const Rect.fromLTRB(hx - 10, hy - 20, hx + 10, hy - 6)),
          ow: 1.6);
    }
  }
  final headR = Rect.fromCircle(center: const Offset(hx, hy), radius: golem ? 9 : 10);
  _shape(
      c,
      golem
          ? (Path()..addRRect(RRect.fromRectAndRadius(headR, const Radius.circular(4))))
          : (Path()..addOval(headR)),
      _lit(golem ? shade(d.c1, 0.1) : fur, headR));
  if (!golem) {
    // Muzzle, nose, mouth, eye and a heavy brow.
    _shape(c, Path()..addOval(Rect.fromCenter(center: const Offset(hx + 4, hy + 2.5), width: 12, height: 10)),
        _flat(d.c2),
        ow: 1.4);
    c.drawOval(Rect.fromCenter(center: const Offset(hx + 8, hy + 1), width: 3, height: 2), _flat(_ink));
    if (attack > 0.3) {
      c.drawOval(Rect.fromCenter(center: const Offset(hx + 6, hy + 5.5), width: 5, height: 3.5),
          _flat(0xFF6A1A1A));
    } else {
      c.drawLine(const Offset(hx + 3, hy + 5), const Offset(hx + 8, hy + 5), _outline(1.2));
    }
    _beastEye(c, const Offset(hx + 4.5, hy - 3.5), 1, yeti ? 0xFF7FD4FF : 0xFFFFD34A);
    c.drawLine(const Offset(hx + 1, hy - 6.5), const Offset(hx + 8.5, hy - 5.5), _outline(2));
  } else {
    for (final x in const [hx + 1.5, hx + 6.5]) {
      c.drawCircle(
          Offset(x, hy - 1),
          2.6,
          Paint()
            ..color = col(d.c2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      c.drawCircle(Offset(x, hy - 1), 1.3, _flat(0xFFFFF0A0));
    }
  }

  // Front arm, raised for the smash.
  final fist = Offset(13 + smash * 8, -15 - smash * 32);
  _limb(c, const Offset(10, -40), fist, fur, 9);
  final fr = Rect.fromCircle(center: fist, radius: 6.5);
  _shape(c, Path()..addOval(fr), _lit(golem ? d.c1 : d.c2, fr));
}

// ------------------------------------------------------------------ pets

// Stand-in monster definitions so the four-legged pets reuse the beast art.
const _petTiger = MobDef(
    id: 'petTiger', name: 'Hắc Hổ', hanh: Hanh.moc, body: Body.quad,
    c1: 0xFF2E2A2A, c2: 0xFFE8DCC8, c3: 0xFFE8A030, variant: 'tiger');
const _petFox = MobDef(
    id: 'petFox', name: 'Tuyết Hồ', hanh: Hanh.thuy, body: Body.quad,
    c1: 0xFFF4F8FC, c2: 0xFFC8E4F4, variant: 'wolf');
const _petKylin = MobDef(
    id: 'petKylin', name: 'Kỳ Lân Con', hanh: Hanh.hoa, body: Body.quad,
    c1: 0xFFD8402E, c2: 0xFFFFC34A, c3: 0xFF3AD0C0, variant: 'kylin');
const _petDragon = MobDef(
    id: 'petDragon', name: 'Tiểu Bạch Long', hanh: Hanh.kim, body: Body.serpent,
    c1: 0xFFF0F2F4, c2: 0xFFC8D8E8, c3: 0xFFFFC34A, variant: 'dragon');

/// Draws a pet by its look at the local origin, facing right.
void drawPetChibi(Canvas c, String look,
    {double walk = 0, bool moving = false, double attack = 0, double t = 0}) {
  switch (look) {
    case 'tiger':
      drawQuadChibi(c, _petTiger, walk: walk, moving: moving, attack: attack, t: t);
    case 'fox':
      drawQuadChibi(c, _petFox, walk: walk, moving: moving, attack: attack, t: t);
    case 'kylin':
      drawQuadChibi(c, _petKylin, walk: walk, moving: moving, attack: attack, t: t);
    case 'dragon':
      drawSerpentChibi(c, _petDragon, walk: walk, moving: moving, attack: attack, t: t);
    case 'crane':
      _crane(c, walk, moving, attack, t);
    case 'turtle':
      _turtle(c, walk, moving, attack, t);
  }
}

void _crane(Canvas c, double walk, bool moving, double attack, double t) {
  final step = moving ? math.sin(walk * 2) * 3 : 0.0;
  final flap = moving ? math.sin(t * 9) * 0.5 + 0.5 : 0.15 + math.sin(t * 2) * 0.05;
  // Thin legs.
  for (final s in const [-1.0, 1.0]) {
    c.drawLine(Offset(-2 + s * 2, -16), Offset(-2 + s * 2 + s * step, 0), _outline(2.6));
    c.drawLine(Offset(-2 + s * 2, -16), Offset(-2 + s * 2 + s * step, 0),
        _o
          ..color = col(0xFF3A3A3A)
          ..strokeWidth = 1.2);
  }
  // Back wing, raised when flapping.
  final wing = Path()
    ..moveTo(-6, -24)
    ..quadraticBezierTo(-20, -30 - flap * 14, -30, -22 - flap * 18)
    ..quadraticBezierTo(-20, -18, -6, -18)
    ..close();
  _shape(c, wing, _flat(0xFFE8ECF0), ow: 1.6);
  c.drawPath(
      Path()
        ..moveTo(-30, -22 - flap * 18)
        ..quadraticBezierTo(-25, -21 - flap * 10, -20, -19),
      _o
        ..color = col(0xFF1A1A1A)
        ..strokeWidth = 3);
  // Body.
  const body = Rect.fromLTRB(-14, -28, 8, -14);
  _shape(c, Path()..addOval(body), _lit(0xFFFFFFFF, body, light: 0.0, dark: 0.12));
  // Black tail feathers.
  _shape(
      c,
      Path()
        ..moveTo(-12, -24)
        ..lineTo(-20, -18)
        ..lineTo(-11, -17)
        ..close(),
      _flat(0xFF1A1A1A),
      ow: 1.2);
  // S-shaped neck up to the head; it lunges on attack.
  final lunge = attack > 0 ? math.sin(attack * math.pi) * 6 : 0.0;
  final neck = Path()
    ..moveTo(4, -24)
    ..quadraticBezierTo(14 + lunge, -30, 8 + lunge, -40)
    ..quadraticBezierTo(4 + lunge, -48, 10 + lunge, -50);
  c.drawPath(neck, _outline(5));
  c.drawPath(
      neck,
      _o
        ..color = col(0xFFFFFFFF)
        ..strokeWidth = 3.2);
  final hx = 11 + lunge, hy = -50.0;
  c.drawCircle(Offset(hx, hy), 4.6, _outline(1.6));
  c.drawCircle(Offset(hx, hy), 4.6, _flat(0xFFFFFFFF));
  c.drawCircle(Offset(hx - 1, hy - 3.6), 2.4, _flat(0xFFD8302A)); // red crown
  c.drawCircle(Offset(hx + 1.6, hy - 0.6), 1.1, _flat(_ink));
  // Long beak.
  _shape(
      c,
      Path()
        ..moveTo(hx + 3.5, hy - 1.2)
        ..lineTo(hx + 13, hy + 0.6)
        ..lineTo(hx + 3.5, hy + 1.6)
        ..close(),
      _flat(0xFFC8A040),
      ow: 1.1);
}

void _turtle(Canvas c, double walk, bool moving, double attack, double t) {
  final step = moving ? math.sin(walk * 2.4) * 2.5 : 0.0;
  // Stubby legs.
  for (final lx in const [-9.0, 7.0]) {
    final dx = lx < 0 ? step : -step;
    final leg = Path()..addOval(Rect.fromCenter(center: Offset(lx + dx, -3), width: 7, height: 6));
    _shape(c, leg, _flat(0xFF6A8A4A), ow: 1.4);
  }
  // Head pokes out further on attack.
  final out = attack > 0 ? math.sin(attack * math.pi) * 5 : math.sin(t * 1.5) * 0.8;
  final head = Path()..addOval(Rect.fromCenter(center: Offset(15 + out, -10), width: 11, height: 9));
  _shape(c, head, _lit(0xFF7A9A5A, Rect.fromCenter(center: Offset(15 + out, -10), width: 11, height: 9)), ow: 1.6);
  c.drawCircle(Offset(18 + out, -11.5), 1.2, _flat(_ink));
  c.drawCircle(Offset(17.6 + out, -12), 0.45, _flat(0xFFFFFFFF));
  // Domed shell with a hex pattern and a gold rim.
  const shell = Rect.fromLTRB(-16, -22, 12, -3);
  final dome = Path()
    ..moveTo(-16, -5)
    ..quadraticBezierTo(-16, -23, -2, -23)
    ..quadraticBezierTo(12, -23, 12, -5)
    ..close();
  _shape(c, dome, _lit(0xFF3A5A3A, shell, light: 0.25, dark: 0.3));
  final hexP = _o
    ..color = col(0xFF8AB06A)
    ..strokeWidth = 1.1;
  for (final cx in const [-9.0, -2.0, 5.0]) {
    final hex = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3;
      final p = Offset(cx + math.cos(a) * 3.6, -13 + math.sin(a) * 3.2);
      k == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    c.drawPath(hex, hexP);
  }
  c.drawLine(const Offset(-16, -5), const Offset(12, -5), _outline(3.4));
  c.drawLine(const Offset(-16, -5), const Offset(12, -5),
      _o
        ..color = col(0xFFE8C547)
        ..strokeWidth = 2);
}
