import 'dart:math' as math;
import 'dart:ui';

import '../core/content.dart';
import '../core/hanh.dart';
import 'art_chibi.dart';

/// Figures are drawn in local units with the feet at (0, 0), facing right;
/// the caller flips and scales the canvas. A humanoid is about 64 tall.

enum Hair { bald, topknot, bun, long, hood, turban, zombieHat, crown, straw }

enum Weapon { none, staff, saber, bigSaber, sword, darts, dagger, spear }

class HumanLook {
  const HumanLook({
    required this.skin,
    required this.robe,
    required this.trim,
    required this.pants,
    this.hairColor = 0xFF1E1A18,
    this.hair = Hair.topknot,
    this.weapon = Weapon.none,
    this.blade = 0xFFD8DEE4,
    this.female = false,
    this.mask = false,
    this.band = 0,
    this.cape = 0,
    this.longRobe = true,
    this.zombie = false,
    this.glow = 0,
  });

  final int skin, robe, trim, pants, hairColor;
  final Hair hair;
  final Weapon weapon;
  final int blade;
  final bool female;
  final bool mask;

  /// Headband colour, 0 for none.
  final int band;

  /// Cape colour, 0 for none.
  final int cape;
  final bool longRobe;
  final bool zombie;

  /// Weapon glow colour (rare gear), 0 for none.
  final int glow;
}

/// Current flash (0..1) toward white applied to every colour, for hits.
double _flash = 0;
double _alpha = 1;

Color col(int argb) {
  var c = Color(argb);
  if (_flash > 0) c = Color.lerp(c, const Color(0xFFFFFFFF), _flash)!;
  if (_alpha < 1) c = c.withValues(alpha: c.a * _alpha);
  return c;
}

void setTint({double flash = 0, double alpha = 1}) {
  _flash = flash.clamp(0, 1);
  _alpha = alpha.clamp(0, 1);
}

final Paint _fill = Paint()..isAntiAlias = true;
final Paint _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint fillOf(int argb) => _fill..color = col(argb);
Paint lineOf(int argb, double w) => _line
  ..color = col(argb)
  ..strokeWidth = w;

int shade(int argb, double f) {
  final c = Color(argb);
  int ch(double v) =>
      (f < 0 ? v * (1 + f) : v + (1 - v) * f).clamp(0.0, 1.0) * 255 ~/ 1;
  return (c.a * 255).round() << 24 |
      ch(c.r) << 16 |
      ch(c.g) << 8 |
      ch(c.b);
}

void drawShadow(Canvas c, double rx, {double alpha = 0.28}) {
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: rx * 0.7),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha * _alpha));
}

// ------------------------------------------------------------------ human

/// [attack] runs 1 → 0 after a strike; [cast] true poses a ranged throw.
void drawHuman(Canvas c, HumanLook k,
    {double walk = 0,
    bool moving = false,
    double attack = 0,
    bool cast = false,
    double t = 0}) {
  final step = moving ? math.sin(walk * 1.7) : 0.0;
  final bob = moving ? (math.cos(walk * 3.4) * 1.2).abs() : math.sin(t * 2) * 0.4;
  var lift = 0.0;
  if (k.zombie) {
    // Cương thi hop with stiff legs.
    lift = moving ? (math.sin(walk * 1.7)).abs() * 7 : 0;
  }
  c.save();
  c.translate(0, -lift - bob);
  final legs = k.zombie ? 0.0 : step * 6;

  if (k.cape != 0) {
    final sway = math.sin(t * 3 + walk) * 2;
    final p = Path()
      ..moveTo(-6, -44)
      ..lineTo(6, -44)
      ..lineTo(4 - 6 + sway, -10)
      ..quadraticBezierTo(-10 + sway, -6, -16 + sway, -12)
      ..close();
    c.drawPath(p, fillOf(k.cape));
  }

  // Legs.
  c.drawLine(Offset(-3, -20), Offset(-3 - legs, -2), lineOf(k.pants, 6));
  c.drawLine(Offset(3, -20), Offset(3 + legs, -2), lineOf(shade(k.pants, 0.12), 6));
  c.drawOval(Rect.fromCenter(center: Offset(-3 - legs + 1.5, -1), width: 8, height: 4),
      fillOf(0xFF1A1410));
  c.drawOval(Rect.fromCenter(center: Offset(3 + legs + 1.5, -1), width: 8, height: 4),
      fillOf(0xFF1A1410));

  // Back arm.
  final armSwing = moving && !k.zombie ? -step * 5 : 0.0;
  if (k.zombie) {
    c.drawLine(Offset(-4, -41), Offset(12, -40), lineOf(shade(k.robe, -0.2), 5));
  } else {
    c.drawLine(Offset(-5, -41), Offset(-7 + armSwing, -27),
        lineOf(shade(k.robe, -0.2), 5));
    c.drawCircle(Offset(-7 + armSwing, -26), 2.6, fillOf(k.skin));
  }

  // Robe.
  final hem = k.longRobe ? -9.0 : -19.0;
  final flare = k.longRobe ? 12.0 : 10.0;
  final sway = moving ? step * 1.5 : 0.0;
  final waist = k.female ? 6.5 : 8.0;
  final robe = Path()
    ..moveTo(-8, -45)
    ..quadraticBezierTo(0, -48, 8, -45)
    ..lineTo(waist, -30)
    ..lineTo(flare + sway, hem)
    ..quadraticBezierTo(0 + sway, hem + 3, -flare + sway, hem)
    ..lineTo(-waist, -30)
    ..close();
  c.drawPath(robe, fillOf(k.robe));
  // Lapel and hem trim.
  c.drawLine(Offset(-3, -46), Offset(4, -32), lineOf(k.trim, 2.4));
  c.drawLine(Offset(-flare + sway + 1, hem - 1), Offset(flare + sway - 1, hem - 1),
      lineOf(k.trim, 2.2));
  // Sash.
  c.drawRect(Rect.fromLTRB(-waist - 0.5, -32, waist + 0.5, -28), fillOf(k.trim));
  c.drawLine(Offset(-2, -29), Offset(-4 + sway, -20), lineOf(k.trim, 2));

  // Head.
  const hy = -54.0;
  if (k.hair == Hair.long) {
    final p = Path()
      ..moveTo(-8, hy - 2)
      ..quadraticBezierTo(-11, hy + 14, -6 + sway, hy + 20)
      ..lineTo(0, hy + 6)
      ..close();
    c.drawPath(p, fillOf(k.hairColor));
  }
  c.drawRect(Rect.fromLTRB(-2.5, hy + 5, 3.5, hy + 9), fillOf(shade(k.skin, -0.1)));
  c.drawCircle(const Offset(1, hy), 8, fillOf(k.zombie ? 0xFF9FB89A : k.skin));
  _hair(c, k, hy);
  // Eye.
  if (k.hair != Hair.hood || !k.mask) {
    c.drawCircle(Offset(5, hy - 0.5), 1.3, fillOf(0xFF1A1410));
  }
  if (k.female) {
    c.drawCircle(Offset(6.2, hy + 3.4), 0.9, fillOf(0xFFC0584A));
  }
  if (k.mask) {
    final p = Path()
      ..moveTo(-1, hy + 1)
      ..lineTo(9.4, hy + 0.5)
      ..lineTo(7, hy + 7)
      ..lineTo(0, hy + 8)
      ..close();
    c.drawPath(p, fillOf(shade(k.robe, -0.35)));
  }
  if (k.zombie) {
    // Talisman on the forehead.
    c.drawRect(Rect.fromLTRB(4, hy - 7, 8, hy + 5), fillOf(0xFFE8D24A));
    c.drawLine(Offset(6, hy - 5), Offset(6, hy + 3), lineOf(0xFFB3261E, 0.9));
  }

  // Front arm + weapon.
  double hx, hyH, wAng;
  if (k.zombie) {
    hx = 15;
    hyH = -41;
    wAng = 0;
  } else if (cast && attack > 0) {
    hx = 9 + 8 * attack;
    hyH = -40;
    wAng = -0.3;
  } else if (attack > 0) {
    // Raised behind the head, then down across the body.
    final a = 1 - attack;
    final swing = -2.3 + 3.0 * Curves.easeOut(a);
    hx = 4 + math.cos(swing) * 12;
    hyH = -42 + math.sin(swing) * 12;
    wAng = swing;
  } else {
    hx = 7 + (moving ? step * 4 : 0);
    hyH = -28;
    wAng = _idleAngle(k.weapon);
  }
  _weapon(c, k, hx, hyH, wAng, attack, behind: true);
  c.drawLine(Offset(4, -41), Offset(hx, hyH), lineOf(k.robe, 5));
  c.drawCircle(Offset(hx, hyH), 2.8, fillOf(k.skin));
  _weapon(c, k, hx, hyH, wAng, attack, behind: false);
  c.restore();
}

class Curves {
  static double easeOut(double t) => 1 - (1 - t) * (1 - t);
}

double _idleAngle(Weapon w) => switch (w) {
      Weapon.staff => -1.35,
      Weapon.spear => -1.3,
      Weapon.saber || Weapon.bigSaber => -0.9,
      Weapon.sword => 0.9,
      Weapon.dagger => 1.2,
      _ => 0.0,
    };

void _hair(Canvas c, HumanLook k, double hy) {
  final hc = k.hairColor;
  switch (k.hair) {
    case Hair.bald:
      // Monk: ordination dots.
      c.drawCircle(Offset(-1, hy - 5), 0.9, fillOf(0xFFB07040));
      c.drawCircle(Offset(2, hy - 6.5), 0.9, fillOf(0xFFB07040));
    case Hair.topknot:
      c.drawArc(Rect.fromCircle(center: Offset(1, hy), radius: 8.4), math.pi,
          math.pi, true, fillOf(hc));
      c.drawRect(Rect.fromLTRB(-7.4, hy - 2, -2, hy + 4), fillOf(hc));
      c.drawCircle(Offset(-1, hy - 9.5), 3.4, fillOf(hc));
      c.drawLine(Offset(-5, hy - 9.5), Offset(3, hy - 9.5), lineOf(0xFFD8C090, 1));
    case Hair.bun:
      c.drawArc(Rect.fromCircle(center: Offset(1, hy), radius: 8.4), math.pi,
          math.pi, true, fillOf(hc));
      c.drawRect(Rect.fromLTRB(-7.4, hy - 2, -2, hy + 5), fillOf(hc));
      c.drawCircle(Offset(-2, hy - 10), 4.2, fillOf(hc));
      c.drawLine(Offset(-8, hy - 12), Offset(4, hy - 8), lineOf(0xFFE8C547, 1.2));
    case Hair.long:
      c.drawArc(Rect.fromCircle(center: Offset(1, hy), radius: 8.5), math.pi * 0.95,
          math.pi * 1.1, true, fillOf(hc));
      c.drawRect(Rect.fromLTRB(-7.6, hy - 2, -1, hy + 6), fillOf(hc));
      c.drawCircle(Offset(-1, hy - 9), 3, fillOf(hc));
      c.drawCircle(Offset(-1, hy - 9), 1.4, fillOf(0xFF7FDBFF));
    case Hair.hood:
      final p = Path()
        ..moveTo(-9, hy + 7)
        ..quadraticBezierTo(-11, hy - 12, 2, hy - 10.5)
        ..quadraticBezierTo(11, hy - 9, 9.5, hy - 1)
        ..lineTo(4, hy - 3)
        ..lineTo(-2, hy + 8)
        ..close();
      c.drawPath(p, fillOf(shade(k.robe, -0.25)));
    case Hair.turban:
      c.drawOval(Rect.fromLTRB(-8.5, hy - 12, 9.5, hy - 2), fillOf(k.trim));
      c.drawLine(Offset(-8, hy - 4), Offset(9, hy - 6), lineOf(shade(k.trim, -0.3), 1.2));
    case Hair.zombieHat:
      c.drawRect(Rect.fromLTRB(-9, hy - 9, 11, hy - 6), fillOf(0xFF1A1A22));
      c.drawRect(Rect.fromLTRB(-6, hy - 15, 8, hy - 8), fillOf(0xFF2A2A3A));
      c.drawCircle(Offset(1, hy - 16), 2, fillOf(0xFFB3261E));
    case Hair.crown:
      c.drawArc(Rect.fromCircle(center: Offset(1, hy), radius: 8.4), math.pi,
          math.pi, true, fillOf(hc));
      final p = Path()
        ..moveTo(-6, hy - 7)
        ..lineTo(-4, hy - 15)
        ..lineTo(-1, hy - 9)
        ..lineTo(2, hy - 17)
        ..lineTo(4, hy - 9)
        ..lineTo(7, hy - 15)
        ..lineTo(8, hy - 7)
        ..close();
      c.drawPath(p, fillOf(0xFFE8C547));
      c.drawCircle(Offset(2, hy - 10), 1.5, fillOf(0xFFB3261E));
    case Hair.straw:
      final p = Path()
        ..moveTo(-13, hy - 3)
        ..lineTo(1, hy - 15)
        ..lineTo(15, hy - 3)
        ..close();
      c.drawPath(p, fillOf(0xFFCDAE6A));
      c.drawLine(Offset(-13, hy - 3), Offset(15, hy - 3), lineOf(0xFF8A6A3A, 1.2));
  }
  if (k.band != 0) {
    c.drawLine(Offset(-7.5, hy - 3), Offset(8.6, hy - 3.5), lineOf(k.band, 2.4));
    c.drawLine(Offset(-7.5, hy - 3), Offset(-12, hy + 1 + math.sin(_t) * 1.5),
        lineOf(k.band, 1.6));
  }
}

double _t = 0;
void setClock(double t) => _t = t;

void _weapon(Canvas c, HumanLook k, double x, double y, double ang, double attack,
    {required bool behind}) {
  final w = k.weapon;
  // Long weapons pass behind the hand; small ones in front.
  final isBehind = w == Weapon.staff || w == Weapon.spear;
  if (behind != isBehind) return;
  c.save();
  c.translate(x, y);
  c.rotate(ang);
  if (k.glow != 0) {
    final g = Paint()
      ..color = col(k.glow).withValues(alpha: 0.45 * _alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    c.drawRect(const Rect.fromLTRB(-2, -3, 30, 3), g);
  }
  switch (w) {
    case Weapon.staff:
      c.drawLine(const Offset(-18, 0), const Offset(34, 0), lineOf(0xFF8A5A2A, 3.4));
      c.drawLine(const Offset(30, 0), const Offset(35, 0), lineOf(0xFFE8C547, 4));
      c.drawLine(const Offset(-19, 0), const Offset(-14, 0), lineOf(0xFFE8C547, 4));
    case Weapon.spear:
      c.drawLine(const Offset(-16, 0), const Offset(36, 0), lineOf(0xFF6A4A2A, 2.6));
      final p = Path()
        ..moveTo(36, -3.4)
        ..lineTo(46, 0)
        ..lineTo(36, 3.4)
        ..close();
      c.drawPath(p, fillOf(k.blade));
      c.drawCircle(const Offset(35, 0), 2.2, fillOf(0xFFB3261E));
    case Weapon.saber || Weapon.bigSaber:
      final big = w == Weapon.bigSaber ? 1.35 : 1.0;
      c.drawLine(const Offset(-4, 0), const Offset(3, 0), lineOf(0xFF3A2A1A, 3));
      c.drawLine(const Offset(3, -3.5), const Offset(3, 3.5), lineOf(0xFFB08A3A, 2));
      final p = Path()
        ..moveTo(4, -2.4 * big)
        ..lineTo(24 * big, -3.2 * big)
        ..quadraticBezierTo(29 * big, -1.5 * big, 27 * big, 3 * big)
        ..lineTo(4, 2.6 * big)
        ..close();
      c.drawPath(p, fillOf(k.blade));
      c.drawLine(Offset(5, -1.2 * big), Offset(23 * big, -1.8 * big),
          lineOf(shade(k.blade, 0.4), 0.8));
    case Weapon.sword:
      c.drawLine(const Offset(-5, 0), const Offset(2, 0), lineOf(0xFF3A2A1A, 2.6));
      c.drawLine(const Offset(2, -4), const Offset(2, 4), lineOf(0xFFB08A3A, 2));
      final p = Path()
        ..moveTo(3, -1.6)
        ..lineTo(29, -1.1)
        ..lineTo(33, 0)
        ..lineTo(29, 1.1)
        ..lineTo(3, 1.6)
        ..close();
      c.drawPath(p, fillOf(k.blade));
      c.drawLine(const Offset(-5, 0), const Offset(-9, 4), lineOf(0xFFB3261E, 1.2));
    case Weapon.dagger:
      final p = Path()
        ..moveTo(1, -1.8)
        ..lineTo(14, 0)
        ..lineTo(1, 1.8)
        ..close();
      c.drawPath(p, fillOf(k.blade));
      c.drawLine(const Offset(-3, 0), const Offset(1, 0), lineOf(0xFF2A1A10, 2.4));
    case Weapon.darts:
      for (var i = 0; i < 3; i++) {
        c.save();
        c.rotate(-0.4 + i * 0.4);
        final p = Path()
          ..moveTo(3, -1)
          ..lineTo(11, 0)
          ..lineTo(3, 1)
          ..close();
        c.drawPath(p, fillOf(k.blade));
        c.restore();
      }
    case Weapon.none:
      break;
  }
  c.restore();
}

// ------------------------------------------------------------------ mobs

/// Draws any monster at local origin (feet), facing right, unscaled
/// (the caller applies [MobDef.size]).
/// [chibi] picks the new outlined style where a body plan has one.
void drawMob(Canvas c, MobDef d,
    {double walk = 0,
    bool moving = false,
    double attack = 0,
    double t = 0,
    bool chibi = true}) {
  switch (d.body) {
    case Body.quad:
      if (chibi) {
        drawQuadChibi(c, d, walk: walk, moving: moving, attack: attack, t: t);
      } else {
        _quad(c, d, walk, moving, attack, t);
      }
    case Body.human:
      (chibi ? drawChibi : drawHuman)(c, _humanFor(d),
          walk: walk, moving: moving, attack: attack, cast: d.ranged, t: t);
    case Body.serpent:
      chibi
          ? drawSerpentChibi(c, d, walk: walk, moving: moving, attack: attack, t: t)
          : _serpent(c, d, walk, moving, attack, t);
    case Body.bug:
      if (d.variant == 'scorpion') {
        chibi
            ? drawScorpionChibi(c, d, walk: walk, moving: moving, attack: attack, t: t)
            : _scorpion(c, d, walk, moving, attack, t);
      } else {
        chibi
            ? drawSpiderChibi(c, d, walk: walk, moving: moving, attack: attack, t: t)
            : _spider(c, d, walk, moving, attack, t);
      }
    case Body.flyer:
      chibi
          ? drawFlyerChibi(c, d, walk: walk, moving: moving, attack: attack, t: t)
          : _flyer(c, d, walk, moving, attack, t);
    case Body.brute:
      chibi
          ? drawBruteChibi(c, d, walk: walk, moving: moving, attack: attack, t: t)
          : _brute(c, d, walk, moving, attack, t);
  }
}

final Map<String, HumanLook> _humanCache = {};

HumanLook _humanFor(MobDef d) => _humanCache.putIfAbsent(d.id, () {
      switch (d.variant) {
        case 'zombie':
          return HumanLook(
              skin: 0xFF9FB89A, robe: d.c1, trim: 0xFFB3261E, pants: 0xFF1A1A22,
              hair: Hair.zombieHat, zombie: true);
        case 'darts':
          return HumanLook(
              skin: 0xFFE0B48A, robe: d.c1, trim: d.c3, pants: d.c2,
              hair: Hair.hood, mask: true, weapon: Weapon.darts, longRobe: false);
        case 'dagger':
          return HumanLook(
              skin: 0xFFD8A880, robe: d.c1, trim: d.c3, pants: d.c2,
              hair: Hair.hood, mask: true, weapon: Weapon.dagger, longRobe: false);
        case 'spear':
          return HumanLook(
              skin: 0xFFC08A5A, robe: d.c1, trim: d.c2, pants: 0xFF4A3420,
              hair: Hair.turban, weapon: Weapon.spear, blade: d.c3, longRobe: false);
        case 'bigSaber':
          return HumanLook(
              skin: 0xFFC8946A, robe: d.c1, trim: d.c2, pants: 0xFF2A2018,
              hair: Hair.topknot, band: d.c2, weapon: Weapon.bigSaber,
              blade: d.c3, cape: 0xFF5A1A14, longRobe: false);
        case 'demonLord':
          return HumanLook(
              skin: 0xFFE0C0B0, robe: d.c1, trim: d.c3, pants: d.c2,
              hairColor: 0xFFE8E8F0, hair: Hair.crown, weapon: Weapon.sword,
              blade: 0xFFFF4A4A, cape: 0xFF1A0A0A, glow: 0xFFFF2A2A);
        default:
          return HumanLook(
              skin: 0xFFC8946A, robe: d.c1, trim: d.c2, pants: 0xFF2A2018,
              hair: d.id == 'cultist' ? Hair.hood : Hair.topknot,
              band: d.id == 'cultist' ? 0 : 0xFF3A2A1A, weapon: Weapon.saber,
              blade: d.c3, longRobe: false);
      }
    });

void _quad(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final v = d.variant;
  final boar = v == 'boar';
  final kylin = v == 'kylin';
  final fire = v == 'fireWolf' || kylin;
  final legLen = boar ? 9.0 : 13.0;
  final step = moving ? math.sin(walk * 2.2) * 5 : 0.0;
  final lunge = attack > 0 ? math.sin(attack * math.pi) * 6 : 0.0;
  final by = -legLen - 8;
  c.save();
  c.translate(lunge, 0);
  // Tail.
  final tail = Path()
    ..moveTo(-18, by - 2)
    ..quadraticBezierTo(-30, by - 10 + math.sin(t * 6) * 3, -32, by + 2);
  c.drawPath(tail, lineOf(boar ? d.c2 : d.c1, boar ? 2 : 5));
  if (fire) {
    c.drawCircle(Offset(-32, by), 4 + math.sin(t * 12), fillOf(0xFFFFB03A));
  }
  // Far legs.
  final legC = shade(d.c1, -0.25);
  c.drawLine(Offset(-12, by + 4), Offset(-12 - step, -1), lineOf(legC, 4.5));
  c.drawLine(Offset(12, by + 4), Offset(12 + step, -1), lineOf(legC, 4.5));
  // Body.
  c.drawOval(Rect.fromCenter(center: Offset(0, by), width: 40, height: boar ? 24 : 18),
      fillOf(d.c1));
  c.drawOval(Rect.fromCenter(center: Offset(2, by + 4), width: 28, height: 8),
      fillOf(d.c2));
  if (boar) {
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(-10 + i * 5.0, by - 11), Offset(-12 + i * 5.0, by - 15),
          lineOf(d.c2, 1.6));
    }
  }
  if (kylin) {
    for (var i = 0; i < 4; i++) {
      c.drawCircle(Offset(-10 + i * 6.0, by - 2), 3, fillOf(shade(d.c1, 0.25)));
    }
  }
  // Near legs.
  c.drawLine(Offset(-8, by + 4), Offset(-8 + step, -1), lineOf(d.c1, 5));
  c.drawLine(Offset(15, by + 4), Offset(15 - step, -1), lineOf(d.c1, 5));
  // Head.
  final hx = 21.0, hy = by - (boar ? 2 : 6);
  if (fire || v == 'wolf') {
    // Mane / ruff.
    c.drawCircle(Offset(hx - 6, hy + 1), 9,
        fillOf(fire ? (kylin ? d.c3 : d.c2) : d.c2));
  }
  c.drawCircle(Offset(hx, hy), 8, fillOf(d.c1));
  final snout = Path()
    ..moveTo(hx + 3, hy - 3)
    ..lineTo(hx + (boar ? 13 : 14), hy + 1)
    ..lineTo(hx + 3, hy + 5)
    ..close();
  c.drawPath(snout, fillOf(boar ? shade(d.c1, 0.15) : d.c1));
  c.drawCircle(Offset(hx + (boar ? 12.5 : 13.5), hy + 1), 1.8, fillOf(0xFF1A1410));
  if (boar) {
    c.drawLine(Offset(hx + 9, hy + 4), Offset(hx + 12, hy - 1), lineOf(d.c3, 2));
  } else {
    // Ears.
    final ear = Path()
      ..moveTo(hx - 4, hy - 5)
      ..lineTo(hx - 2, hy - 14)
      ..lineTo(hx + 2, hy - 6)
      ..close();
    c.drawPath(ear, fillOf(shade(d.c1, -0.15)));
  }
  if (kylin) {
    c.drawLine(Offset(hx, hy - 7), Offset(hx + 4, hy - 17), lineOf(0xFFE8C547, 2.6));
  }
  // Eye.
  c.drawCircle(Offset(hx + 3, hy - 2), 1.6,
      fillOf(fire ? 0xFFFFE04A : (d.hanh == Hanh.thuy ? 0xFF3FA7E0 : 0xFF1A1410)));
  if (fire) {
    for (var i = 0; i < 3; i++) {
      final fx = -8.0 + i * 8, fy = by - 10 - math.sin(t * 10 + i) * 2;
      c.drawCircle(Offset(fx, fy), 3, fillOf(0xCCFF8A3D));
    }
  }
  c.restore();
}

void _serpent(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final wave = walk * 2.5 + t * 2;
  final rise = attack > 0 ? math.sin(attack * math.pi) * 8 : 0.0;
  // Coils from tail to head.
  for (var i = 0; i < 9; i++) {
    final f = i / 8;
    final x = -26 + f * 40;
    final y = -6 + math.sin(wave + f * 5) * 4 * (1 - f * 0.6) - f * f * (14 + rise);
    final r = 3 + f * 4;
    c.drawCircle(Offset(x, y), r, fillOf(i.isEven ? d.c1 : shade(d.c1, 0.12)));
    if (i % 2 == 1) {
      c.drawCircle(Offset(x, y + r * 0.4), r * 0.5, fillOf(d.c2));
    }
  }
  final hy = -20.0 - rise, hx = 17.0;
  c.drawOval(Rect.fromCenter(center: Offset(hx, hy), width: 16, height: 10), fillOf(d.c1));
  c.drawCircle(Offset(hx + 3, hy - 2), 1.6, fillOf(d.boss ? d.c3 : 0xFFFFE04A));
  if ((t * 3).floor().isEven) {
    c.drawLine(Offset(hx + 8, hy + 1), Offset(hx + 14, hy + 1), lineOf(0xFFE84B3A, 1.2));
  }
  if (d.boss) {
    // Hood.
    final p = Path()
      ..moveTo(hx - 6, hy - 4)
      ..quadraticBezierTo(hx - 14, hy + 8, hx - 4, hy + 10)
      ..lineTo(hx, hy)
      ..close();
    c.drawPath(p, fillOf(d.c2));
  }
}

void _spider(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final step = moving ? walk * 3 : 0.0;
  for (var side = 0; side < 2; side++) {
    for (var i = 0; i < 4; i++) {
      final ph = math.sin(step + i * 1.4 + side * math.pi) * 3;
      final bx = -4.0 + i * 4, by = -12.0;
      final kx = bx + (i - 1.5) * 7 + ph, ky = by - 9;
      final fx = bx + (i - 1.5) * 11 + ph, fy = -1.0;
      final colr = side == 0 ? shade(d.c1, -0.2) : d.c1;
      c.drawLine(Offset(bx, by), Offset(kx, ky), lineOf(colr, 2.2));
      c.drawLine(Offset(kx, ky), Offset(fx, fy), lineOf(colr, 2));
    }
  }
  c.drawOval(Rect.fromCenter(center: const Offset(-8, -15), width: 20, height: 16),
      fillOf(d.c1));
  c.drawOval(Rect.fromCenter(center: const Offset(-9, -17), width: 8, height: 6),
      fillOf(d.c2));
  c.drawCircle(const Offset(5, -13), 6, fillOf(shade(d.c1, 0.1)));
  for (var i = 0; i < 3; i++) {
    c.drawCircle(Offset(7 + i * 1.6, -15 + (i == 1 ? -1 : 0)), 1.1, fillOf(0xFFE84B3A));
  }
  if (attack > 0) {
    c.drawLine(const Offset(9, -11), Offset(13 + attack * 3, -8), lineOf(0xFFEEEEEE, 1.4));
  }
}

void _scorpion(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final step = moving ? walk * 3 : 0.0;
  for (var i = 0; i < 3; i++) {
    final ph = math.sin(step + i * 1.7) * 3;
    c.drawLine(Offset(-6.0 + i * 6, -8), Offset(-10.0 + i * 7 + ph, -1),
        lineOf(shade(d.c1, -0.25), 2.2));
  }
  // Segmented body.
  for (var i = 0; i < 4; i++) {
    c.drawOval(Rect.fromCenter(center: Offset(-8.0 + i * 6, -10), width: 10, height: 9),
        fillOf(i.isEven ? d.c1 : shade(d.c1, -0.1)));
  }
  // Tail arching over the back; strikes forward on attack.
  final strike = attack > 0 ? math.sin(attack * math.pi) : 0.0;
  var px = -12.0, py = -12.0;
  for (var i = 0; i < 5; i++) {
    final a = -math.pi * 0.55 - i * 0.42 + strike * 0.6;
    final nx = px + math.cos(a) * -6, ny = py + math.sin(a) * 6;
    c.drawCircle(Offset(nx, ny), 3.6 - i * 0.3, fillOf(i.isEven ? d.c1 : d.c2));
    px = nx;
    py = ny;
  }
  c.drawCircle(Offset(px + 3, py + 1), 2.6, fillOf(d.boss ? d.c3 : 0xFF2A1A0A));
  // Claws.
  final open = math.sin(t * 5) * 0.2 + 0.3;
  for (final s in [-1.0, 1.0]) {
    c.drawLine(Offset(12, -10 + s * 2), Offset(18, -12 + s * 3), lineOf(d.c1, 2.6));
    c.save();
    c.translate(18, -12 + s * 3);
    c.rotate(s * open);
    c.drawOval(const Rect.fromLTRB(0, -3, 8, 3), fillOf(shade(d.c1, 0.1)));
    c.restore();
  }
  c.drawCircle(const Offset(13, -12), 1.2, fillOf(0xFF1A0A0A));
}

void _flyer(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final hover = -38 + math.sin(t * 3 + walk * 0.3) * 4;
  switch (d.variant) {
    case 'bat':
      final flap = math.sin(t * 16) * 0.8;
      c.save();
      c.translate(0, hover);
      for (final s in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(s * 10, -10 - flap * 8, s * 22, -4 - flap * 10)
          ..lineTo(s * 17, 1)
          ..lineTo(s * 12, -1)
          ..lineTo(s * 8, 3)
          ..close();
        c.drawPath(p, fillOf(s < 0 ? shade(d.c1, -0.2) : d.c1));
      }
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 12), fillOf(d.c1));
      c.drawCircle(const Offset(2, -2), 1.3, fillOf(d.c2));
      c.drawCircle(const Offset(-2, -2), 1.3, fillOf(d.c2));
      c.restore();
    case 'ghost':
      c.save();
      c.translate(0, hover);
      final sway = math.sin(t * 4) * 3;
      final p = Path()
        ..moveTo(-9, 0)
        ..quadraticBezierTo(-10, -18, 0, -18)
        ..quadraticBezierTo(10, -18, 9, 0)
        ..quadraticBezierTo(6 + sway, 16, -2 + sway * 2, 22)
        ..quadraticBezierTo(-4, 10, -9, 0)
        ..close();
      c.drawPath(p, fillOf(0xAA000000 | (d.c1 & 0xFFFFFF)));
      c.drawCircle(const Offset(3, -9), 2, fillOf(d.c2));
      c.drawCircle(const Offset(-2, -9), 2, fillOf(d.c2));
      c.restore();
    default:
      // Wisp: a flame-ish spirit.
      c.save();
      c.translate(0, hover);
      final glow = Paint()
        ..color = col(d.c1).withValues(alpha: 0.35 * _alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      c.drawCircle(Offset.zero, 16, glow);
      final f = Path()
        ..moveTo(-9, 2)
        ..quadraticBezierTo(-10, -12, -2, -22 + math.sin(t * 9) * 3)
        ..quadraticBezierTo(2, -12, 5, -16 + math.cos(t * 7) * 2)
        ..quadraticBezierTo(11, -6, 9, 2)
        ..quadraticBezierTo(0, 12, -9, 2)
        ..close();
      c.drawPath(f, fillOf(d.c1));
      c.drawCircle(const Offset(0, -2), 5, fillOf(d.c2));
      c.drawCircle(const Offset(2, -3), 1.2, fillOf(0xFF1A1A2A));
      c.drawCircle(const Offset(-2, -3), 1.2, fillOf(0xFF1A1A2A));
      c.restore();
  }
}

void _brute(Canvas c, MobDef d, double walk, bool moving, double attack, double t) {
  final step = moving ? math.sin(walk * 1.6) * 4 : 0.0;
  final golem = d.variant == 'golem';
  final smash = attack > 0 ? math.sin(attack * math.pi) : 0.0;
  // Legs.
  c.drawLine(Offset(-6, -18), Offset(-6 - step, -2), lineOf(shade(d.c1, -0.2), 8));
  c.drawLine(Offset(6, -18), Offset(6 + step, -2), lineOf(d.c1, 8));
  // Back arm.
  c.drawLine(Offset(-10, -40), Offset(-14, -16 + step), lineOf(shade(d.c1, -0.2), 8));
  // Torso.
  if (golem) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-15, -48, 15, -16),
        const Radius.circular(5)), fillOf(d.c1));
    final crack = lineOf(d.c2, 2);
    c.drawLine(const Offset(-8, -44), const Offset(-2, -34), crack);
    c.drawLine(const Offset(-2, -34), const Offset(-6, -24), crack);
    c.drawLine(const Offset(6, -42), const Offset(9, -30), crack);
    final g = Paint()
      ..color = col(d.c2).withValues(alpha: 0.5 * _alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    c.drawCircle(const Offset(0, -34), 6, g);
  } else {
    c.drawOval(const Rect.fromLTRB(-16, -50, 16, -14), fillOf(d.c1));
    c.drawOval(const Rect.fromLTRB(-9, -42, 11, -20), fillOf(d.c2));
  }
  // Head.
  final hy = -52.0;
  c.drawCircle(Offset(4, hy), golem ? 8 : 9, fillOf(golem ? shade(d.c1, 0.1) : d.c1));
  if (!golem) {
    c.drawOval(Rect.fromCenter(center: Offset(8, hy + 2), width: 9, height: 7),
        fillOf(d.c2));
  }
  c.drawCircle(Offset(8, hy - 2), 1.6,
      fillOf(golem ? d.c2 : (d.variant == 'yeti' ? 0xFF3FA7E0 : 0xFFE84B3A)));
  if (d.boss) {
    for (var i = 0; i < 3; i++) {
      c.drawLine(Offset(-2.0 + i * 5, hy - 8), Offset(-3.0 + i * 5, hy - 15),
          lineOf(d.c3, 2.2));
    }
  }
  // Front arm, raised for the smash.
  final ax = 12 + smash * 8, ay = -16 - smash * 30;
  c.drawLine(const Offset(10, -42), Offset(ax, ay), lineOf(d.c1, 9));
  c.drawCircle(Offset(ax, ay), 6, fillOf(shade(d.c1, golem ? 0.1 : -0.1)));
}

/// Hero look for a sect; female variants swap the hair.
HumanLook heroLook(Hanh h, {bool female = false, int glow = 0}) {
  switch (h) {
    case Hanh.kim:
      return HumanLook(
          skin: 0xFFE8B888, robe: 0xFFE08A2E, trim: 0xFF9A2A1A, pants: 0xFF6A3A1A,
          hair: Hair.bald, weapon: Weapon.staff, female: female, glow: glow);
    case Hanh.moc:
      return HumanLook(
          skin: 0xFFE8BC92, robe: 0xFF2F5D3A, trim: 0xFF7A3A8A, pants: 0xFF1E2A22,
          hair: female ? Hair.long : Hair.topknot, mask: !female,
          weapon: Weapon.darts, blade: 0xFFB8E0A0, female: female,
          longRobe: false, glow: glow);
    case Hanh.thuy:
      return HumanLook(
          skin: 0xFFF2CCA8, robe: 0xFFDDEEF8, trim: 0xFF3F8FC8, pants: 0xFFE8F2F8,
          hair: female ? Hair.long : Hair.topknot, weapon: Weapon.sword,
          blade: 0xFFBFE8FF, female: female, glow: glow == 0 ? 0xFF7FDBFF : glow);
    case Hanh.hoa:
      return HumanLook(
          skin: 0xFFDCA47A, robe: 0xFFB3261E, trim: 0xFF2A1A1A, pants: 0xFF3A2A20,
          hair: female ? Hair.bun : Hair.topknot, band: 0xFFFFB03A,
          weapon: Weapon.saber, blade: 0xFFE8E0D8, female: female,
          longRobe: false, glow: glow);
    case Hanh.tho:
      return HumanLook(
          skin: 0xFFE8B888, robe: 0xFFC9A15A, trim: 0xFF2A3A5A, pants: 0xFF5A4A3A,
          hair: Hair.bun, weapon: Weapon.sword, blade: 0xFFF0E8C8,
          female: female, glow: glow);
  }
}
