import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/content.dart';
import '../core/hanh.dart';
import '../core/items.dart';
import '../core/scenery.dart';
import '../core/world.dart';
import 'art_figures.dart';
import 'art_fx.dart';
import 'art_scenery.dart';

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
  /// World units visible top to bottom.
  double viewHeight = 400;
  double camX = 0, camY = 0;
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
    final k = 1 - math.pow(0.0005, dt).toDouble();
    camX += (tx - camX) * k;
    camY += (ty - camY) * k;
    camX = w.width > halfW * 2 ? camX.clamp(halfW, w.width - halfW) : w.width / 2;
    camY = w.height > halfH * 2
        ? camY.clamp(halfH - 100, w.height - halfH + 30)
        : w.height / 2;
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
    for (final f in w.fx) {
      if (isGroundFx(f.kind)) drawFx(c, f, t);
    }
    for (final z in w.zones) {
      drawZone(c, z, t);
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
    items.sort((a, b) => a.y.compareTo(b.y));
    for (final it in items) {
      if (it.prop != null) {
        _drawProp(c, it.prop!, p, t);
      } else if (it.mob != null) {
        _drawMob(c, it.mob!, t);
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
      final show = m == tg || m.hp < m.maxHp || m.def.boss;
      if (show) _mobBar(c, m, m == tg);
    }
    for (final ft in w.texts) {
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
    final behind = p.y < pr.y &&
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
    drawShadow(c, m.radius * 1.1 * (d.body == Body.flyer ? 0.6 : 1));
    c.scale(m.face * d.size, d.size);
    setTint(
      flash: !dying && m.hurt > 0 ? m.hurt / 0.15 * 0.5 : 0,
      alpha: dying ? m.hurt / 0.6 : 1,
    );
    drawMob(c, d, walk: m.walk, moving: m.moving, attack: m.attackAnim, t: t + m.uid);
    if (t < m.stunUntil && m.alive) {
      c.scale(1 / d.size);
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
    for (final dot in m.dots) {
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
    final weapon = h.equip[Slot.weapon];
    final glow = weapon != null && weapon.rarity.index >= Rarity.rare.index
        ? weapon.rarity.color
        : 0;
    c.save();
    c.translate(p.x, p.y);
    drawShadow(c, 16);
    // Hero halo so they stand out in a crowd.
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 44, height: 16),
        Paint()
          ..color = Color(h.hanh.color).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    c.scale(p.face, 1);
    setTint(flash: p.hurt > 0 ? p.hurt / 0.18 * 0.6 : 0, alpha: p.alive ? 1 : 0.5);
    drawHuman(c, heroLook(h.hanh, female: h.female, glow: glow),
        walk: p.walk,
        moving: p.moving,
        attack: p.attackAnim,
        cast: h.sect.basic.name == 'ranged',
        t: t);
    setTint();
    c.restore();
  }

  void _mobBar(Canvas c, Mob m, bool targeted) {
    final d = m.def;
    final wdt = d.boss ? 70.0 : 40.0;
    final y = m.y - mobTop(d) - 12;
    final r = Rect.fromLTWH(m.x - wdt / 2, y, wdt, d.boss ? 6 : 4.5);
    c.drawRect(r.inflate(1.2), Paint()..color = const Color(0xCC1A1410));
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * (m.hp / m.maxHp).clamp(0, 1), r.height),
        Paint()..color = d.boss ? const Color(0xFFE8503A) : const Color(0xFFD8403A));
    if (targeted || d.boss) {
      final tp = _label('${d.name} · ${m.level}', d.boss ? 0xFFFFB08A : 0xFFFFF3C4,
          d.boss ? 13 : 11);
      tp.paint(c, Offset(m.x - tp.width / 2, y - tp.height - 1));
      // Hanh pip.
      c.drawCircle(Offset(m.x - tp.width / 2 - 7, y - tp.height / 2 - 1), 4,
          Paint()..color = Color(d.hanh.color));
    }
  }
}

class _Drawable {
  _Drawable(this.y, {this.prop, this.mob, this.hero = false});
  final double y;
  final Prop? prop;
  final Mob? mob;
  final bool hero;
}
