import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/content.dart';
import '../core/world.dart';
import 'quality.dart';

/// Battle particles drawn over the world: sparks where hits land, a star
/// on a crit, monsters scattering into ink motes, a flash and rings when a
/// boss falls, dust and footprints behind the running hero. Everything is
/// kept here (the world only leaves [VfxCue]s), so the simulation and its
/// tests never see it. Chế độ máy yếu spawns about a third as much.
enum _K { spark, mote, ring, star, flash, dust }

class _P {
  _P(this.k, this.x, this.y, this.vx, this.vy, this.life, this.color, this.size);
  final _K k;
  double x, y, vx, vy;
  final double life;
  final int color;
  final double size;
  double age = 0;
}

class _Print {
  _Print(this.x, this.y, this.angle);
  final double x, y, angle;
  double age = 0;
}

/// Where a light falls at night: world position, reach and colour.
class Light {
  const Light(this.x, this.y, this.radius, this.color);
  final double x, y, radius;
  final int color;
}

class Vfx {
  final List<_P> _ps = [];
  final List<_Print> _prints = [];
  final math.Random _r = math.Random(5);
  static const int _cap = 280;

  double _lastX = double.nan, _lastY = 0, _stride = 0, _dustIn = 0;
  bool _left = false;

  int _n(int full) => liteGraphics ? math.max(1, full ~/ 3) : full;

  void _add(_P p) {
    if (_ps.length >= _cap) _ps.removeAt(0);
    _ps.add(p);
  }

  double _rnd(double a, double b) => a + _r.nextDouble() * (b - a);

  /// Turns the world's cues into particles and clears them.
  void take(List<VfxCue> cues) {
    for (final q in cues) {
      switch (q.kind) {
        case CueKind.hit:
          for (var i = 0; i < _n(4); i++) {
            final a = _rnd(0, math.pi * 2), sp = _rnd(110, 240);
            _add(_P(_K.spark, q.x, q.y, math.cos(a) * sp, math.sin(a) * sp - 60, _rnd(0.15, 0.28), q.color, 1.6));
          }
          if (!liteGraphics) _add(_P(_K.ring, q.x, q.y, 0, 0, 0.18, 0xFFFFF6E0, 16));
        case CueKind.crit:
          for (var i = 0; i < _n(9); i++) {
            final a = _rnd(0, math.pi * 2), sp = _rnd(160, 340);
            _add(_P(_K.spark, q.x, q.y, math.cos(a) * sp, math.sin(a) * sp - 80, _rnd(0.2, 0.36), q.color, 2.2));
          }
          _add(_P(_K.star, q.x, q.y, 0, 0, 0.22, q.color, 30));
          _add(_P(_K.ring, q.x, q.y, 0, 0, 0.26, q.color, 30));
        case CueKind.death:
          // The monster scatters into motes of its own colour and ink.
          for (var i = 0; i < _n((10 * q.size).round()); i++) {
            final a = _rnd(0, math.pi * 2), sp = _rnd(20, 90) * q.size;
            _add(_P(_K.mote, q.x + _rnd(-14, 14) * q.size, q.y + _rnd(-18, 12) * q.size, math.cos(a) * sp,
                math.sin(a) * sp * 0.5 - _rnd(30, 80), _rnd(0.6, 1.1), i.isEven ? q.color : 0xFF2A1A20,
                _rnd(2.5, 5.5) * math.sqrt(q.size)));
          }
          _add(_P(_K.ring, q.x, q.y + 18 * q.size, 0, 0, 0.35, 0xCCFFF0D8, 26 * q.size));
        case CueKind.bossDeath:
          _add(_P(_K.flash, q.x, q.y, 0, 0, 0.7, 0xFFFFF3C4, 260));
          for (var k = 0; k < 3; k++) {
            _add(_P(_K.ring, q.x, q.y + 20, 0, 0, 0.5 + k * 0.2, k.isEven ? 0xFFFFD34A : q.color, 70 + k * 50));
          }
          for (var i = 0; i < _n(36); i++) {
            final a = _rnd(0, math.pi * 2), sp = _rnd(40, 200);
            _add(_P(_K.mote, q.x + _rnd(-30, 30), q.y + _rnd(-40, 20), math.cos(a) * sp, math.sin(a) * sp * 0.6 - 90,
                _rnd(0.9, 1.6), i % 3 == 0 ? 0xFFFFD34A : q.color, _rnd(3, 7)));
          }
          for (var i = 0; i < _n(18); i++) {
            final a = _rnd(0, math.pi * 2), sp = _rnd(250, 480);
            _add(_P(_K.spark, q.x, q.y, math.cos(a) * sp, math.sin(a) * sp, _rnd(0.3, 0.55), 0xFFFFE08A, 2.6));
          }
      }
    }
    cues.clear();
  }

  /// Dust behind the hero on dry ground; footprints on snow, sand and beach.
  void trail(Player p, MapTheme theme, int dustColor, double dt) {
    if (_lastX.isNaN) {
      _lastX = p.x;
      _lastY = p.y;
    }
    final dx = p.x - _lastX, dy = p.y - _lastY;
    final step = math.sqrt(dx * dx + dy * dy);
    _lastX = p.x;
    _lastY = p.y;
    if (!p.moving || step <= 0 || step > 60) return;
    final prints = theme == MapTheme.snow || theme == MapTheme.desert || theme == MapTheme.sea || theme == MapTheme.canyon;
    if (prints) {
      _stride += step;
      if (_stride >= 26) {
        _stride = 0;
        _left = !_left;
        final a = math.atan2(dy, dx);
        final side = _left ? 1.0 : -1.0;
        _prints.add(_Print(p.x - math.sin(a) * 5 * side, p.y + math.cos(a) * 5 * side, a));
        if (_prints.length > 60) _prints.removeAt(0);
      }
    }
    final dusty = theme != MapTheme.snow && theme != MapTheme.cloud;
    if (dusty && !liteGraphics) {
      _dustIn -= dt;
      if (_dustIn <= 0) {
        _dustIn = 0.13;
        _add(_P(_K.dust, p.x - p.face * 8 + _rnd(-4, 4), p.y - 2, -p.face * _rnd(10, 30), _rnd(-14, -4),
            _rnd(0.45, 0.7), dustColor, _rnd(5, 8)));
      }
    }
  }

  void update(double dt) {
    if (dt <= 0) return;
    for (final p in _ps) {
      p.age += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      switch (p.k) {
        case _K.spark:
          p.vy += 520 * dt;
          p.vx *= 1 - 3 * dt;
        case _K.mote:
          p.vx *= 1 - 1.8 * dt;
          p.vy -= 20 * dt;
        case _K.dust:
          p.vx *= 1 - 2 * dt;
        default:
          break;
      }
    }
    _ps.removeWhere((p) => p.age >= p.life);
    for (final f in _prints) {
      f.age += dt;
    }
    _prints.removeWhere((f) => f.age > 5);
  }

  final Paint _paint = Paint()..isAntiAlias = true;

  /// Footprints lie on the ground, under everything standing.
  void drawGround(Canvas c, int inkColor) {
    for (final f in _prints) {
      final a = (1 - f.age / 5) * 0.35;
      c.save();
      c.translate(f.x, f.y);
      c.rotate(f.angle);
      c.drawOval(const Rect.fromLTRB(-4, -2.2, 4, 2.2), _paint..color = Color(inkColor).withValues(alpha: a));
      c.restore();
    }
  }

  void draw(Canvas c) {
    for (final p in _ps) {
      final u = p.age / p.life, fade = 1 - u;
      switch (p.k) {
        case _K.spark:
          final len = 0.035;
          c.drawLine(
              Offset(p.x, p.y),
              Offset(p.x - p.vx * len, p.y - p.vy * len),
              _paint
                ..color = Color(p.color).withValues(alpha: fade)
                ..strokeWidth = p.size
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke);
        case _K.mote:
          c.drawCircle(Offset(p.x, p.y), p.size * (0.4 + fade * 0.6),
              _paint
                ..style = PaintingStyle.fill
                ..color = Color(p.color).withValues(alpha: fade * 0.9));
        case _K.dust:
          c.drawCircle(Offset(p.x, p.y), p.size * (1 + u * 1.4),
              _paint
                ..style = PaintingStyle.fill
                ..color = Color(p.color).withValues(alpha: fade * 0.32));
        case _K.ring:
          c.drawOval(
              Rect.fromCenter(center: Offset(p.x, p.y), width: p.size * 2 * (0.3 + u), height: p.size * (0.3 + u)),
              _paint
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 * fade + 0.5
                ..color = Color(p.color).withValues(alpha: fade * 0.8));
        case _K.star:
          final r = p.size * (0.5 + u * 0.8);
          final star = Path();
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4 + 0.3;
            final rr = i.isEven ? r : r * 0.22;
            final o = Offset(p.x + math.cos(a) * rr, p.y + math.sin(a) * rr);
            if (i == 0) {
              star.moveTo(o.dx, o.dy);
            } else {
              star.lineTo(o.dx, o.dy);
            }
          }
          star.close();
          c.drawPath(
              star,
              _paint
                ..style = PaintingStyle.fill
                ..color = Color.lerp(const Color(0xFFFFFFFF), Color(p.color), u)!.withValues(alpha: fade));
        case _K.flash:
          if (liteGraphics) {
            c.drawCircle(Offset(p.x, p.y), p.size * (0.4 + u),
                _paint
                  ..style = PaintingStyle.fill
                  ..color = Color(p.color).withValues(alpha: fade * 0.25));
          } else {
            c.drawCircle(
                Offset(p.x, p.y),
                p.size * (0.4 + u),
                Paint()
                  ..shader = RadialGradient(colors: [
                    Color(p.color).withValues(alpha: fade * 0.75),
                    Color(p.color).withValues(alpha: 0),
                  ]).createShader(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.size * (0.4 + u))));
          }
      }
    }
  }

  /// Lights cast by the particles themselves (a boss's last flash).
  Iterable<Light> lights() sync* {
    for (final p in _ps) {
      if (p.k == _K.flash) yield Light(p.x, p.y, p.size * (1 - p.age / p.life) + 60, p.color);
    }
  }
}

/// Darkness over the screen with holes where [lights] fall ([toScreen]
/// maps world to screen), then a soft coloured glow from each.
void drawNight(Canvas c, Size size, double darkness, Iterable<Light> lights, Offset Function(double, double) toScreen,
    double zoom) {
  final rect = Offset.zero & size;
  c.saveLayer(rect, Paint());
  c.drawRect(rect, Paint()..color = Color.fromRGBO(6, 10, 30, darkness));
  final cut = Paint()..blendMode = BlendMode.dstOut;
  final glows = <(Offset, double, int)>[];
  for (final l in lights) {
    final o = toScreen(l.x, l.y);
    final r = l.radius * zoom;
    if (o.dx < -r || o.dy < -r || o.dx > size.width + r || o.dy > size.height + r) continue;
    cut.shader = RadialGradient(
      colors: const [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: o, radius: r));
    c.drawCircle(o, r, cut);
    glows.add((o, r, l.color));
  }
  c.restore();
  final glow = Paint()..blendMode = BlendMode.screen;
  for (final (o, r, colr) in glows) {
    glow.shader = RadialGradient(colors: [
      Color(colr).withValues(alpha: 0.12 * darkness * 1.5),
      Color(colr).withValues(alpha: 0),
    ]).createShader(Rect.fromCircle(center: o, radius: r * 0.8));
    c.drawCircle(o, r * 0.8, glow);
  }
}

/// Ink for footprints and dust by land.
int dustOf(MapTheme t) => switch (t) {
      MapTheme.desert || MapTheme.sea => 0xFFB8A070,
      MapTheme.canyon => 0xFFA0603A,
      MapTheme.volcano || MapTheme.abyss || MapTheme.bloodSea => 0xFF4A3A36,
      MapTheme.snow => 0xFF8AA0B8,
      MapTheme.cave || MapTheme.fortress => 0xFF6A6058,
      _ => 0xFF8A7A5A,
    };

/// Light a standing prop gives off at night, if any: (height, reach, colour).
(double, double, int)? propLight(String kind) => switch (kind) {
      'lantern' => (44, 130, 0xFFFFB050),
      'brazier' => (34, 150, 0xFFFF8A3D),
      'vent' || 'lavaRock' => (14, 110, 0xFFFF5A2A),
      'crystal' || 'iceCrystal' => (24, 90, 0xFF8AE0FF),
      'lm_shrine' || 'lm_temple' => (40, 150, 0xFFFFC060),
      _ => null,
    };

/// Seconds the camera shows a boss arriving.
const double bossIntroTime = 1.6;

