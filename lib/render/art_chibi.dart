import 'dart:math' as math;
import 'dart:ui';

import '../core/content.dart';
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
