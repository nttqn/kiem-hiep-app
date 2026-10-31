import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/alchemy.dart';
import '../core/content.dart';
import '../core/fishing.dart';
import '../core/hanh.dart';
import '../core/scenery.dart';
import '../core/sects.dart';
import '../core/world.dart';
import 'art_chibi.dart';
import 'art_figures.dart';
import 'art_fx.dart';
import 'art_scenery.dart';
import 'quality.dart';

/// Rough head height of each body plan, for bars and labels.
double mobTop(MobDef d) => switch (d.body) {
      Body.quad => 42,
      Body.human => 70,
      Body.serpent => 36,
      Body.bug => 34,
      Body.flyer => 66,
      Body.brute => 72,
    } *
    d.size;

class WorldRenderer {
  /// Dev build only: no damage numbers or monster bars (clean thumbnails).
  static bool debugClean = false;

  /// World units visible top to bottom (the player's Tầm nhìn).
  double get viewHeight => viewSpan;
  double camX = 0, camY = 0;
  double _camVX = 0, _camVY = 0;

  /// Camera lag behind the hero, in seconds.
  static const double camSmooth = 0.16;

  /// One step of a critically damped spring from [cur] toward [to].
  static (double, double) _follow(double cur, double to, double vel, double dt) {
    const omega = 2 / camSmooth;
    final x = omega * dt;
    final decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
    final change = cur - to;
    final temp = (vel + omega * change) * dt;
    return (to + (change + temp) * decay, (vel - omega * temp) * decay);
  }
  bool _placed = false;
  double shake = 0;
  final math.Random _r = math.Random(3);

  final Map<String, TextPainter> _texts = {};

  TextPainter _label(String s, int color, double size, {bool bold = true}) {
    final key = '$s|$color|$size';
    final hit = _texts[key];
    if (hit != null) return hit;
    if (_texts.length > 400) _texts.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'BeVietnam',
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: Color(color),
          shadows: const [
            Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 1.5),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _texts[key] = tp;
    return tp;
  }

  void render(Canvas c, Size size, World w, double t, double dt) {
    setClock(t);
    final zoom = size.height / viewHeight;
    final halfW = size.width / 2 / zoom, halfH = size.height / 2 / zoom;
    final p = w.player;
    final tx = p.x, ty = p.y - 30;
    if (!_placed) {
      camX = tx;
      camY = ty;
      _placed = true;
    }
    // A critically damped spring: no jolt when the hero starts or stops.
    final (fx, vx) = _follow(camX, tx, _camVX, dt);
    final (fy, vy) = _follow(camY, ty, _camVY, dt);
    final cx = w.width > halfW * 2 ? fx.clamp(halfW, w.width - halfW) : w.width / 2;
    final cy = w.height > halfH * 2
        ? fy.clamp(halfH - 100, w.height - halfH + 30)
        : w.height / 2;
    _camVX = cx == fx ? vx : 0;
    _camVY = cy == fy ? vy : 0;
    camX = cx.toDouble();
    camY = cy.toDouble();
    var sx = 0.0, sy = 0.0;
    if (shake > 0.2) {
      sx = (_r.nextDouble() - 0.5) * shake;
      sy = (_r.nextDouble() - 0.5) * shake;
      shake *= math.pow(0.004, dt).toDouble();
    } else {
      shake = 0;
    }

    c.save();
    c.translate(size.width / 2, size.height / 2);
    c.scale(zoom);
    c.translate(-camX + sx, -camY + sy);
    final view = Rect.fromLTRB(camX - halfW, camY - halfH, camX + halfW, camY + halfH);

    drawGround(c, w.scenery, view, w.width, w.height, t);
    if (w.hasPond && view.inflate(160).contains(Offset(w.pondX, w.pondY))) {
      _drawPond(c, w.pondX, w.pondY, w.map.theme, t, w.nearPond);
    }
    for (final f in w.fx) {
      if (isGroundFx(f.kind)) drawFx(c, f, t);
    }
    for (final z in w.zones) {
      drawZone(c, z, t);
    }
    for (final n in w.herbs) {
      if (w.time >= n.readyAt && view.inflate(40).contains(Offset(n.x, n.y))) _drawHerb(c, n, t);
    }
    for (final d in w.drops) {
      if (view.inflate(40).contains(Offset(d.x, d.y))) drawDrop(c, d, t);
    }
    final tg = w.target;
    if (tg != null && tg.alive) {
      final r = tg.radius * 1.5 + 4;
      c.drawOval(Rect.fromCenter(center: Offset(tg.x, tg.y), width: r * 2, height: r * 0.8),
          Paint()
            ..color = Color.fromRGBO(255, 80, 60, 0.7 + 0.3 * math.sin(t * 8))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Everything that stands, sorted by feet.
    final items = <_Drawable>[];
    final pad = view.inflate(120);
    for (final pr in w.scenery.props) {
      if (pad.contains(Offset(pr.x, pr.y))) items.add(_Drawable(pr.y, prop: pr));
    }
    for (final m in w.mobs) {
      if (!m.alive && m.hurt <= 0) continue;
      if (pad.contains(Offset(m.x, m.y))) items.add(_Drawable(m.y, mob: m));
    }
    if (p.alive || p.hurt > 0) items.add(_Drawable(p.y, hero: true));
    final pt = w.pet;
    if (pt != null) items.add(_Drawable(pt.y, pet: true));
    final comp = w.companion;
    if (comp != null) items.add(_Drawable(comp.y, companion: true));
    items.sort((a, b) => a.y.compareTo(b.y));
    for (final it in items) {
      if (it.prop != null) {
        _drawProp(c, it.prop!, p, t);
      } else if (it.mob != null) {
        _drawMob(c, it.mob!, t);
      } else if (it.pet) {
        _drawPet(c, pt!, t);
      } else if (it.companion) {
        _drawCompanion(c, comp!, t);
      } else {
        _drawHero(c, w, t);
      }
    }

    for (final pr in w.projs) {
      drawProj(c, pr, t);
    }
    for (final f in w.fx) {
      if (!isGroundFx(f.kind)) drawFx(c, f, t);
    }
    for (final m in w.mobs) {
      if (!m.alive || !pad.contains(Offset(m.x, m.y))) continue;
      final show = m == tg || m.hp < m.maxHp || m.big;
      if (show && !debugClean) _mobBar(c, m, m == tg);
    }
    // Chế độ máy yếu draws only the newest few numbers.
    final texts = debugClean
        ? const <FloatText>[]
        : (liteGraphics && w.texts.length > 8 ? w.texts.sublist(w.texts.length - 8) : w.texts);
    for (final ft in texts) {
      final rise = ft.t * 46;
      final a = ft.t < 0.7 ? 1.0 : (1 - (ft.t - 0.7) / 0.3);
      final pop = ft.big ? 1 + math.max(0.0, 0.3 - ft.t) * 2 : 1.0;
      // Fade in four steps so the text cache stays small.
      final q = ((a.clamp(0.0, 1.0) * 4).ceil() * 63).clamp(0, 255);
      final tp = _label(ft.text, q << 24 | (ft.color & 0xFFFFFF), ft.big ? 19 : (ft.small ? 10.5 : 14));
      c.save();
      c.translate(ft.x, ft.y - rise);
      c.scale(pop);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
    c.restore();

    final night = palettes[w.scenery.theme]!.night;
    if (night > 0) {
      final ctr = Offset(size.width / 2 + (p.x - camX) * zoom,
          size.height / 2 + (p.y - 30 - camY) * zoom);
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x00000000),
              Color.fromRGBO(0, 0, 10, night),
              Color.fromRGBO(0, 0, 10, math.min(0.85, night * 2.6)),
            ],
            stops: const [0.25, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: ctr, radius: size.width * 0.62)),
      );
    }
  }

  void _drawProp(Canvas c, Prop pr, Player p, double t) {
    // See-through when the hero walks behind it.
    // An offscreen layer per prop is too much for Chế độ máy yếu.
    final behind = !liteGraphics &&
        p.y < pr.y &&
        p.y > pr.y - propHeight(pr) - 10 &&
        (p.x - pr.x).abs() < propHalfWidth(pr) + 10;
    if (behind) {
      c.saveLayer(Rect.fromCircle(center: Offset(pr.x, pr.y - 40), radius: 140),
          Paint()..color = const Color.fromRGBO(0, 0, 0, 0.45));
    }
    drawProp(c, pr, t);
    if (behind) c.restore();
  }

  void _drawMob(Canvas c, Mob m, double t) {
    final d = m.def;
    final dying = !m.alive;
    c.save();
    c.translate(m.x, m.y + (dying ? (0.6 - m.hurt) * 10 : 0));
    setTint(alpha: dying ? m.hurt / 0.6 : 1);
    // Elites: a pulsing gold ring and a bigger body.
    final size = d.size * (m.elite ? 1.3 : 1);
    if (m.elite && !dying) {
      final pulse = 0.5 + 0.5 * math.sin(t * 4 + m.uid);
      c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: m.radius * 3.4, height: m.radius * 1.3),
          Paint()
            ..color = Color.fromRGBO(255, 196, 64, 0.35 + 0.3 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    drawShadow(c, m.radius * 1.1 * (d.body == Body.flyer ? 0.6 : 1) * (m.elite ? 1.3 : 1));
    final rival = m.rival;
    if (rival != null && !dying) drawRebirthAura(c, rival.rebirths, t);
    c.scale(m.face * size, size);
    setTint(
      flash: !dying && m.hurt > 0 ? m.hurt / 0.15 * 0.5 : 0,
      alpha: dying ? m.hurt / 0.6 : 1,
    );
    if (rival != null) {
      drawChibi(c, rivalLook(rival),
          walk: m.walk, moving: m.moving, attack: m.attackAnim, cast: d.ranged, t: t, hurt: dying);
    } else {
      drawMob(c, d, walk: m.walk, moving: m.moving, attack: m.attackAnim, t: t + m.uid);
    }
    if (t < m.stunUntil && m.alive) {
      c.scale(1 / size);
      for (var i = 0; i < 3; i++) {
        final a = t * 6 + i * 2.1;
        c.drawCircle(Offset(math.cos(a) * 10, -mobTop(d) / d.size - 6 + math.sin(a) * 3),
            2.2, Paint()..color = const Color(0xFFFFE04A));
      }
    }
    setTint();
    c.restore();
    if (m.alive && t < m.slowUntil) {
      c.drawOval(Rect.fromCenter(center: Offset(m.x, m.y), width: m.radius * 2.4, height: m.radius),
          Paint()..color = const Color(0x557FD4FF));
    }
    for (final dot in m.dots.where((_) => !liteGraphics)) {
      final colr = dot.kind.name == 'poison' ? const Color(0xAA8CE05A) : const Color(0xAAFF8A3D);
      for (var i = 0; i < 2; i++) {
        final rise = (t * 1.5 + i * 0.5 + m.uid * 0.13) % 1;
        c.drawCircle(Offset(m.x + math.sin(i * 3 + m.uid.toDouble()) * 10,
            m.y - mobTop(d) * (0.3 + rise * 0.6)), 3 * (1 - rise) + 1,
            Paint()..color = colr);
      }
    }
  }

  void _drawHero(Canvas c, World w, double t) {
    final p = w.player;
    final h = w.hero;
    c.save();
    c.translate(p.x, p.y);
    drawRebirthAura(c, h.rebirths, t);
    drawShadow(c, 16);
    // Hero halo so they stand out in a crowd.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 16),
        Paint()
          ..color = Color(h.hanh.color).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    c.scale(p.face, 1);
    setTint(flash: p.hurt > 0 ? p.hurt / 0.18 * 0.6 : 0, alpha: p.alive ? 1 : 0.5);
    final mount = h.ridingMount;
    if (mount != null) {
      drawMount(c, mount, walk: p.walk, moving: p.moving, t: t);
      c.translate(0, -mountSeatOf(mount));
    }
    drawChibi(c, lookOfHero(h),
        walk: p.walk,
        // A rider sits still while the mount runs.
        moving: p.moving && mount == null,
        attack: p.attackAnim,
        cast: h.sect.basic.name == 'ranged',
        t: t,
        hurt: p.hurt > 0.05 || !p.alive);
    setTint();
    c.restore();
  }

  /// The fishing pond: water by the map's theme in a rim of stones, reeds
  /// and a small jetty; it glints when the hero is close enough to cast.
  void _drawPond(Canvas c, double x, double y, MapTheme theme, double t, bool near) {
    final (water, deep, rim) = switch (theme) {
      MapTheme.cave => (const Color(0xFF2E6A72), const Color(0xFF16363C), const Color(0xFF4A4A52)),
      MapTheme.desert => (const Color(0xFF3FA8B8), const Color(0xFF1E6A7A), const Color(0xFFC8A868)),
      MapTheme.snow => (const Color(0xFF9CD4EA), const Color(0xFF3A7A9A), const Color(0xFFE8F2F8)),
      MapTheme.volcano => (const Color(0xFFD86A3A), const Color(0xFF8A2A1A), const Color(0xFF4A3A36)),
      MapTheme.cloud => (const Color(0xFFA8DCEC), const Color(0xFF5A9ABA), const Color(0xFFDCE6EE)),
      MapTheme.fortress => (const Color(0xFF3A5A6A), const Color(0xFF1A2A36), const Color(0xFF5A5A62)),
      _ => (const Color(0xFF4A9AB8), const Color(0xFF22587A), const Color(0xFF8A8A7A)),
    };
    const rx = pondRx, ry = pondRy;
    final o = Offset(x, y);
    c.drawOval(Rect.fromCenter(center: o + const Offset(0, 6), width: rx * 2 + 30, height: ry * 2 + 22),
        Paint()..color = const Color(0x33000000));
    c.drawOval(Rect.fromCenter(center: o, width: rx * 2 + 18, height: ry * 2 + 14), Paint()..color = rim);
    final r = math.Random(7);
    final stone = Paint()..color = Color.lerp(rim, const Color(0xFF000000), 0.25)!;
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * math.pi * 2 + r.nextDouble() * 0.2;
      c.drawOval(
          Rect.fromCenter(
              center: o + Offset(math.cos(a) * (rx + 8), math.sin(a) * (ry + 6)),
              width: 12 + r.nextDouble() * 8,
              height: 7 + r.nextDouble() * 4),
          stone);
    }
    final pool = Rect.fromCenter(center: o, width: rx * 2, height: ry * 2);
    c.drawOval(
        pool,
        Paint()
          ..shader = RadialGradient(colors: [deep, water], stops: const [0.1, 1])
              .createShader(pool));
    if (theme == MapTheme.snow) {
      // A frozen sheet with a hole cut for the line.
      c.drawOval(pool.deflate(4), Paint()..color = const Color(0xCCEAF6FC));
      c.drawOval(Rect.fromCenter(center: o + const Offset(20, 2), width: 54, height: 26), Paint()..color = deep);
    }
    // Ripples drifting outward.
    for (var k = 0; k < 3; k++) {
      final ph = (t * 0.35 + k / 3) % 1;
      c.drawOval(
          Rect.fromCenter(center: o + const Offset(20, 2), width: 20 + ph * 70, height: 8 + ph * 28),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, 0.35 * (1 - ph))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }
    if (theme == MapTheme.volcano || theme == MapTheme.cloud) {
      // Steam off a hot spring, mist over the cloud pool.
      for (var k = 0; k < 4; k++) {
        final ph = (t * 0.25 + k / 4) % 1;
        c.drawCircle(o + Offset(-40 + k * 26.0, -ph * 50), 10 + ph * 12,
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.22 * (1 - ph)));
      }
    } else if (theme != MapTheme.snow) {
      // Lily pads and reeds.
      final pad = Paint()..color = const Color(0xFF3F8A3A);
      c.drawOval(Rect.fromCenter(center: o + const Offset(-46, -10), width: 22, height: 10), pad);
      c.drawOval(Rect.fromCenter(center: o + const Offset(-30, 16), width: 16, height: 8), pad);
      c.drawCircle(o + const Offset(-46, -12), 3, Paint()..color = const Color(0xFFF2A8C8));
      final reed = Paint()
        ..color = const Color(0xFF5A7A2A)
        ..strokeWidth = 2;
      for (var k = 0; k < 5; k++) {
        final bx = x + rx - 6 + k * 5.0, by = y - 4 + (k % 2) * 6.0;
        final sway = math.sin(t * 1.5 + k) * 3;
        c.drawLine(Offset(bx, by), Offset(bx + sway, by - 26 - k % 3 * 6), reed);
      }
    }
    // The jetty on the near bank, where the hero stands to cast.
    final plank = Paint()..color = const Color(0xFF8A5A32);
    final line = Paint()
      ..color = const Color(0xFF4A2E18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var k = 0; k < 4; k++) {
      final pr = Rect.fromLTWH(x - 72 + k * 9.0, y - ry - 18 + k * 9.0, 40, 8);
      c.drawRect(pr, plank);
      c.drawRect(pr, line);
    }
    if (near) {
      final a = 0.5 + 0.5 * math.sin(t * 5);
      c.drawOval(pool.inflate(10),
          Paint()
            ..color = Color.fromRGBO(255, 211, 74, 0.35 + 0.4 * a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  /// A herb plant: leaves round a glowing bud in the herb's colour.
  void _drawHerb(Canvas c, HerbNode n, double t) {
    final colr = Color(herbColors[n.tier]);
    final sway = math.sin(t * 2 + n.x) * 2;
    final glow = 0.5 + 0.5 * math.sin(t * 3 + n.y);
    c.save();
    c.translate(n.x, n.y);
    c.scale(1.4);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 34, height: 12),
        Paint()..color = colr.withValues(alpha: 0.18 + 0.12 * glow));
    final leaf = Paint()..color = const Color(0xFF3F8A3A);
    final edge = Paint()
      ..color = const Color(0xFF1E3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final a in const [-0.9, -0.3, 0.4, 1.0]) {
      final tip = Offset(math.sin(a) * 13 + sway * 0.5, -6 - math.cos(a) * 9);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(tip.dx * 0.4 - 4, tip.dy * 0.6, tip.dx, tip.dy)
        ..quadraticBezierTo(tip.dx * 0.4 + 4, tip.dy * 0.4, 0, 0);
      c.drawPath(path, leaf);
      c.drawPath(path, edge);
    }
    c.drawLine(Offset.zero, Offset(sway, -18), edge..strokeWidth = 1.6);
    c.drawCircle(Offset(sway, -20), 11, Paint()..color = colr.withValues(alpha: 0.2 + 0.25 * glow));
    c.drawCircle(Offset(sway, -20), 4.5, Paint()..color = colr);
    c.drawCircle(Offset(sway, -20), 4.5, edge..strokeWidth = 1.2);
    c.drawCircle(Offset(sway - 1.4, -21.5), 1.4, Paint()..color = const Color(0xCCFFFFFF));
    c.restore();
  }

  void _drawPet(Canvas c, PetActor pt, double t) {
    c.save();
    c.translate(pt.x, pt.y);
    drawShadow(c, 11);
    // A soft ring in the pet's phase colour marks it as the hero's.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 30, height: 10),
        Paint()
          ..color = Color(pt.def.hanh.color).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    c.scale(pt.face * 0.7, 0.7);
    drawPetChibi(c, pt.def.look, walk: pt.walk, moving: pt.moving, attack: pt.attackAnim, t: t);
    c.restore();
  }

  void _drawCompanion(Canvas c, CompanionActor a, double t) {
    final d = a.def;
    c.save();
    c.translate(a.x, a.y);
    drawShadow(c, 15);
    // A ring in their phase colour and their name mark them as a friend.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 13),
        Paint()
          ..color = Color(d.hanh.color).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    if (!debugClean) {
      final tp = _label(d.name, 0xFFB8F0C8, 10.5);
      tp.paint(c, Offset(-tp.width / 2, -86));
    }
    c.scale(a.face, 1);
    drawChibi(c, companionLook(d, a.bond),
        walk: a.walk,
        moving: a.moving,
        attack: a.attackAnim,
        cast: d.sect.basic == BasicKind.ranged,
        t: t + 1.3);
    c.restore();
  }

  void _mobBar(Canvas c, Mob m, bool targeted) {
    final d = m.def;
    final wdt = m.big ? 70.0 : 40.0;
    final y = m.y - mobTop(d) * (m.elite ? 1.3 : 1) - 12;
    final r = Rect.fromLTWH(m.x - wdt / 2, y, wdt, m.big ? 6 : 4.5);
    c.drawRect(r.inflate(1.2), Paint()..color = const Color(0xCC1A1410));
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * (m.hp / m.maxHp).clamp(0, 1), r.height),
        Paint()..color = m.big ? const Color(0xFFE8503A) : const Color(0xFFD8403A));
    if (targeted || m.big) {
      final tp = _label(m.elite ? '★ ${m.eliteName} · ${m.level}' : '${d.name} · ${m.level}',
          m.elite ? 0xFFFFD34A : (d.boss ? 0xFFFFB08A : 0xFFFFF3C4), m.big ? 13 : 11);
      tp.paint(c, Offset(m.x - tp.width / 2, y - tp.height - 1));
      // Hanh pip.
      c.drawCircle(Offset(m.x - tp.width / 2 - 7, y - tp.height / 2 - 1), 4,
          Paint()..color = Color(d.hanh.color));
    }
  }
}

class _Drawable {
  _Drawable(this.y, {this.prop, this.mob, this.hero = false, this.pet = false, this.companion = false});
  final double y;
  final Prop? prop;
  final Mob? mob;
  final bool hero;
  final bool pet;
  final bool companion;
}
