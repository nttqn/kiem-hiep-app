import 'dart:math' as math;

import 'content.dart';
import 'hanh.dart';
import 'hero.dart';
import 'items.dart';
import 'scenery.dart';
import 'sects.dart';

const double heroRadius = 18;

class Dot {
  Dot(this.kind, this.perTick, this.until, this.next);
  final Status kind;
  final double perTick;
  final double until;
  double next;
}

/// Shared state of anything that walks and bleeds.
abstract class Actor {
  Actor(this.x, this.y, this.radius);
  double x, y;
  final double radius;
  double hp = 1, maxHp = 1;

  /// Last facing (1 right, -1 left) and aim unit vector.
  double face = 1;
  double aimX = 1, aimY = 0;
  double walk = 0;
  bool moving = false;

  /// 1 right after an attack, falls to 0.
  double attackAnim = 0;
  double hurt = 0;
  double slowUntil = 0, slowPct = 0, stunUntil = 0;
  double kx = 0, ky = 0;
  final List<Dot> dots = [];

  bool get alive => hp > 0;
}

enum MobState { idle, wander, chase, leash }

class Mob extends Actor {
  Mob(this.uid, this.def, this.level, double x, double y)
      : homeX = x,
        homeY = y,
        super(x, y, (def.body == Body.quad ? 24 : 20) * def.size) {
    maxHp = mobHpAt(level) * def.hp;
    hp = maxHp;
    atk = mobAtkAt(level) * def.atk;
    defense = mobDefAt(level) * def.def;
  }

  final int uid;
  final MobDef def;
  final int level;
  double homeX, homeY;
  MobState state = MobState.idle;
  double attackCd = 0.8;
  double wanderT = 0;
  double tx = 0, ty = 0;
  late double atk;
  late double defense;
  double respawnAt = -1;
  double bossCd = 5;
  int camp = -1;
}

class Proj {
  Proj({
    required this.fromHero,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxDist,
    required this.radius,
    required this.fx,
    required this.power,
    this.pierce = false,
    this.status = Status.none,
    this.statusPower = 0,
    this.statusTime = 0,
    this.skill = false,
    this.knock = 0,
  });

  final bool fromHero;
  double x, y;
  final double vx, vy;
  final double maxDist;
  double dist = 0;
  final double radius;
  final String fx;

  /// Hero missiles: attack multiple. Monster missiles: raw damage.
  final double power;
  final bool pierce;
  final Status status;
  final double statusPower, statusTime;
  final bool skill;
  final double knock;
  final Set<int> hit = {};
  bool dead = false;
  double get angle => math.atan2(vy, vx);
}

/// A circle that hurts after [delay], once or [ticks] times.
class Zone {
  Zone({
    required this.fromHero,
    required this.x,
    required this.y,
    required this.r,
    required this.delay,
    required this.ticks,
    required this.interval,
    required this.power,
    required this.fx,
    this.status = Status.none,
    this.statusPower = 0,
    this.statusTime = 0,
    this.knock = 0,
  }) : life = delay + interval * math.max(0, ticks - 1) + 0.4;

  final bool fromHero;
  final double x, y, r;
  final double life;
  final double delay;
  int ticks;
  final double interval;
  final double power;
  final String fx;
  final Status status;
  final double statusPower, statusTime;
  final double knock;
  double t = 0;
  double next = 0;
}

/// Pure visuals the renderer animates and drops.
class Fx {
  Fx(this.kind, this.x, this.y,
      {this.life = 0.4,
      this.angle = 0,
      this.radius = 0,
      this.spread = 0,
      this.x2 = 0,
      this.y2 = 0,
      this.onHero = false});
  final String kind;
  double x, y;
  final double life;
  final double angle, radius, spread;
  final double x2, y2;
  final bool onHero;
  double t = 0;
}

class FloatText {
  FloatText(this.x, this.y, this.text, this.color,
      {this.big = false, this.small = false});
  final double x, y;
  final String text;
  final int color;
  final bool big;

  /// Damage-over-time ticks and EXP: printed small to cut clutter.
  final bool small;
  double t = 0;
}

class Drop {
  Drop(this.x, this.y, {this.item, this.gold = 0, this.potion = 0});
  double x, y;
  final Item? item;
  final int gold;

  /// 1 HP potion, 2 MP potion.
  final int potion;
  double t = 0;
  bool flying = false;
  bool taken = false;
}

enum EvKind { notice, heroDied, wave, cleared, failed, boss, loot, shake }

class GameEvent {
  GameEvent(this.kind, {this.text = '', this.color = 0xFFFFF3C4,
      this.big = false, this.value = 0});
  final EvKind kind;
  final String text;
  final int color;
  final bool big;
  final double value;
}

/// What the player (or the autopilot) asks for this frame.
class Controls {
  double moveX = 0, moveY = 0;
  bool attack = false;

  /// Skill indexes tapped since the last update.
  final List<int> skills = [];
  bool hpPot = false, mpPot = false;
}

class Player extends Actor {
  Player(double x, double y) : super(x, y, heroRadius);
  double mp = 1;
  final List<double> cd = List.filled(6, 0);
  double basicCd = 0;
  double potCd = 0;
  double guardUntil = 0, guardPct = 0;
  double shield = 0, shieldUntil = 0;
  double hotPerSec = 0, hotUntil = 0;
  double auraUntil = 0, auraNext = 0, auraInterval = 0;
  SkillDef? aura;
  int auraLv = 1;
  double dashT = 0, dashVx = 0, dashVy = 0;
  final Set<int> dashHit = {};
  SkillDef? dashSkill;
  int dashLv = 1;
  double regenT = 0;
  double lastHurt = -99;
}

enum WorldMode { field, dungeon }

class World {
  World.field(this.hero, this.map, {int? seed})
      : mode = WorldMode.field,
        dungeon = null,
        width = map.width,
        height = map.height,
        rng = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch),
        scenery = Scenery.generate(map.theme, map.width, map.height,
            map.id.hashCode),
        player = Player(220, map.height / 2) {
    _init();
    _buildCamps();
  }

  World.dungeon(this.hero, DungeonDef d, {int? seed})
      : mode = WorldMode.dungeon,
        dungeon = d,
        map = d.map,
        width = 1700,
        height = 1150,
        rng = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch),
        scenery = Scenery.generate(d.map.theme, 1700, 1150, d.id.hashCode,
            arena: true),
        player = Player(300, 1150 / 2) {
    _init();
  }

  final HeroData hero;
  final MapDef map;
  final DungeonDef? dungeon;
  final WorldMode mode;
  final double width, height;
  final math.Random rng;
  final Scenery scenery;
  final Player player;

  final List<Mob> mobs = [];
  final List<Proj> projs = [];
  final List<Zone> zones = [];
  final List<Fx> fx = [];
  final List<FloatText> texts = [];
  final List<Drop> drops = [];
  final List<GameEvent> events = [];
  final Controls input = Controls();

  double time = 0;
  bool auto = false;

  /// Manual movement pauses the autopilot for a moment.
  double manualUntil = 0;
  Mob? target;
  int _uid = 0;
  Stats get st => hero.stats;
  SectDef get sect => hero.sect;

  // Field.
  final List<_Camp> _camps = [];
  Mob? boss;
  double bossRespawnAt = -1;

  // Dungeon.
  int wave = -1;
  double waveGap = 1.5;
  bool bossWave = false;
  bool finished = false;
  double finishTime = 0;
  List<String> rewardLines = const [];

  void _init() {
    hero.recompute();
    player.maxHp = st.maxHp;
    player.hp = st.maxHp;
    player.mp = st.maxMp;
  }

  // ------------------------------------------------------------ setup

  void _buildCamps() {
    final r = math.Random(map.id.hashCode);
    final points = <List<double>>[];
    var tries = 0;
    while (points.length < 13 && tries < 2000) {
      tries++;
      final x = 600 + r.nextDouble() * (width - 1000);
      final y = 220 + r.nextDouble() * (height - 440);
      if (points.any((p) => _d2(p[0], p[1], x, y) < 400 * 400)) continue;
      points.add([x, y]);
    }
    points.sort((a, b) => a[0].compareTo(b[0]));
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final frac = ((p[0] - 600) / (width - 1000)).clamp(0.0, 1.0);
      final lv = (map.minLv + (map.maxLv - map.minLv) * frac).round();
      // The map's first monster (the first quest's target) lives near the
      // gate and the toughest one deeper in, with some mixing.
      final kind = (frac * 2.2 + r.nextDouble() * 0.9)
          .floor()
          .clamp(0, map.mobs.length - 1);
      final def = mobById[map.mobs[i < 2 ? 0 : kind]]!;
      final camp = _Camp(p[0], p[1], def, lv, 4 + r.nextInt(3));
      _camps.add(camp);
      for (var k = 0; k < camp.count; k++) {
        _spawnInCamp(_camps.length - 1);
      }
    }
    _spawnBoss();
  }

  void _spawnInCamp(int ci) {
    final c = _camps[ci];
    final a = rng.nextDouble() * math.pi * 2;
    final d = rng.nextDouble() * 120;
    final lv = (c.level + rng.nextInt(3) - 1).clamp(map.minLv, map.maxLv);
    final m = Mob(_uid++, c.def, lv, c.x + math.cos(a) * d,
        c.y + math.sin(a) * d)
      ..camp = ci;
    mobs.add(m);
  }

  void _spawnBoss() {
    final def = mobById[map.boss]!;
    final m = Mob(_uid++, def, map.maxLv, width - 320, height / 2);
    boss = m;
    mobs.add(m);
  }

  void _spawnWave() {
    final d = dungeon!;
    wave++;
    if (wave >= d.waves.length) {
      bossWave = true;
      final def = mobById[map.boss]!;
      final m = Mob(_uid++, def, d.level + 1, width * 0.72, height / 2)
        ..state = MobState.chase;
      mobs.add(m);
      boss = m;
      events.add(GameEvent(EvKind.boss, text: '${def.name} xuất hiện!',
          color: 0xFFFF6A4A, big: true));
      return;
    }
    events.add(GameEvent(EvKind.wave,
        text: 'Đợt ${wave + 1}/${d.waves.length}', big: true));
    _pending = d.waves[wave];
    _pendingT = 0;
  }

  /// Wave monsters still to arrive; they trickle in rather than all at
  /// once, which no low-level ranged hero could survive.
  int _pending = 0;
  double _pendingT = 0;

  void _trickle(double dt) {
    if (_pending <= 0) return;
    _pendingT -= dt;
    if (_pendingT > 0) return;
    _pendingT = 0.3;
    _pending--;
    final d = dungeon!;
    double x, y;
    do {
      x = 80 + rng.nextDouble() * (width - 160);
      y = 80 + rng.nextDouble() * (height - 160);
    } while (_d2(x, y, player.x, player.y) < 300 * 300 ||
        _d2(x, y, player.x, player.y) > 700 * 700);
    final def = mobById[map.mobs[rng.nextInt(map.mobs.length)]]!;
    final m = Mob(_uid++, def, d.level, x, y)..state = MobState.chase;
    m.maxHp *= 1.2;
    m.hp = m.maxHp;
    mobs.add(m);
    fx.add(Fx('spark_mob_${def.hanh.name}', x, y - 20, life: 0.4));
  }

  // ------------------------------------------------------------ loop

  void update(double dt) {
    if (finished) return;
    time += dt;
    hero.playSeconds += dt;
    if (mode == WorldMode.dungeon) _updateDungeon(dt);
    if (mode == WorldMode.field) _updateField();
    if (player.alive) {
      _updatePlayer(dt);
    }
    for (final m in mobs) {
      _updateMob(m, dt);
    }
    _updateProjs(dt);
    _updateZones(dt);
    _updateDrops(dt);
    _tickDots(player, dt, null);
    for (final f in fx) {
      f.t += dt;
      if (f.onHero) {
        f.x = player.x;
        f.y = player.y;
      }
    }
    fx.removeWhere((f) => f.t >= f.life);
    for (final t in texts) {
      t.t += dt;
    }
    texts.removeWhere((t) => t.t > 1.0);
    if (mode == WorldMode.dungeon) {
      mobs.removeWhere((m) => !m.alive && m.hurt <= 0);
    }
    for (final n in hero.notices) {
      events.add(GameEvent(EvKind.notice, text: n.text, color: n.color,
          big: n.big));
    }
    hero.notices.clear();
  }

  void _updateField() {
    for (final m in mobs) {
      if (m.alive || m.respawnAt < 0 || time < m.respawnAt) continue;
      if (m == boss) continue;
      // Respawn out of sight so camps do not pop in on top of the hero.
      final c = _camps[m.camp];
      if (_d2(c.x, c.y, player.x, player.y) < 420 * 420) {
        m.respawnAt = time + 3;
        continue;
      }
      m.respawnAt = -2;
    }
    final dead = mobs.where((m) => m.respawnAt == -2).toList();
    for (final m in dead) {
      mobs.remove(m);
      _spawnInCamp(m.camp);
    }
    if (boss != null && !boss!.alive && bossRespawnAt > 0 &&
        time >= bossRespawnAt) {
      mobs.remove(boss);
      bossRespawnAt = -1;
      _spawnBoss();
      events.add(GameEvent(EvKind.boss,
          text: '${boss!.def.name} đã xuất hiện ở phía đông!',
          color: 0xFFFF6A4A, big: true));
    }
  }

  void _updateDungeon(double dt) {
    final d = dungeon!;
    if (time > d.timeLimit && !finished) {
      finished = true;
      events.add(GameEvent(EvKind.failed, text: 'Hết giờ!'));
      return;
    }
    _trickle(dt);
    final aliveCount = mobs.where((m) => m.alive).length + _pending;
    if (aliveCount == 0) {
      if (bossWave) {
        if (!finished) {
          finished = true;
          finishTime = time;
          final stars = d.starsFor(time);
          rewardLines = hero.dungeonReward(d, stars, rng);
          hero.onDungeonClear(d.id, stars, rng);
          events.add(GameEvent(EvKind.cleared, value: stars.toDouble()));
        }
        return;
      }
      waveGap -= dt;
      if (waveGap <= 0) {
        waveGap = 2;
        _spawnWave();
      }
    }
  }

  // ------------------------------------------------------------ player

  void _updatePlayer(double dt) {
    final p = player;
    p.maxHp = st.maxHp;
    for (var i = 0; i < 6; i++) {
      if (p.cd[i] > 0) p.cd[i] -= dt;
    }
    if (p.basicCd > 0) p.basicCd -= dt;
    if (p.potCd > 0) p.potCd -= dt;
    if (p.attackAnim > 0) p.attackAnim = math.max(0, p.attackAnim - dt * 3);
    if (p.hurt > 0) p.hurt -= dt;
    // Regen, faster out of combat.
    final calm = time - p.lastHurt > 5;
    p.hp = math.min(p.maxHp,
        p.hp + st.hpRegen * (calm ? 4 : 1) * dt + _hot(dt));
    p.mp = math.min(st.maxMp, p.mp + st.mpRegen * (calm ? 2 : 1) * dt);
    if (time > p.shieldUntil) p.shield = 0;

    if (p.dashT > 0) {
      _stepDash(dt);
      return;
    }
    if (time < p.stunUntil) return;

    final c = input;
    final manual = c.moveX.abs() + c.moveY.abs() > 0.05;
    if (manual) manualUntil = time + 1.2;
    final autoOn = auto && !manual && time >= manualUntil;
    if (autoOn) _autopilot();

    if (c.hpPot) _usePotion(true);
    if (c.mpPot) _usePotion(false);
    c.hpPot = false;
    c.mpPot = false;

    for (final i in c.skills) {
      _cast(i);
    }
    c.skills.clear();

    var mx = c.moveX, my = c.moveY;
    final kiting = autoOn && _kite;
    _kite = false;
    if (!manual && !kiting && (c.attack || autoOn)) {
      final t = _pickTarget(
          sect.basic == BasicKind.melee ? 260 : sect.basicRange + 60);
      if (t != null) {
        target = t;
        final reach = sect.basic == BasicKind.melee
            ? sect.basicRange + t.radius * 0.5
            : sect.basicRange;
        final d = _dist(p.x, p.y, t.x, t.y);
        if (d > reach) {
          mx = (t.x - p.x) / d;
          my = (t.y - p.y) / d;
        } else {
          _aimAt(t.x, t.y);
          if (c.attack || autoOn) _basicAttack(t);
        }
      } else if (c.attack) {
        _basicAttack(null);
      }
    }
    if (autoOn && (kiting || (mx == 0 && my == 0)) && _autoMoveX != 0) {
      mx = _autoMoveX;
      my = _autoMoveY;
    }
    _autoMoveX = 0;
    _autoMoveY = 0;

    final len = math.sqrt(mx * mx + my * my);
    if (len > 0.05) {
      final sp = st.move * math.min(1, len) * _slowMul(p);
      p.x += mx / len * sp * dt;
      p.y += my / len * sp * dt;
      p.aimX = mx / len;
      p.aimY = my / len;
      if (mx.abs() > 0.1) p.face = mx.sign;
      p.walk += dt * sp / 28;
      p.moving = true;
    } else {
      p.moving = false;
    }
    _clamp(p);
  }

  double _hot(double dt) {
    if (time > player.hotUntil) return 0;
    return player.hotPerSec * dt;
  }

  void _clamp(Actor a) {
    a.x = a.x.clamp(40, width - 40);
    a.y = a.y.clamp(60, height - 40);
  }

  double _slowMul(Actor a) => time < a.slowUntil ? 1 - a.slowPct : 1;

  void _aimAt(double x, double y) {
    final p = player;
    final d = _dist(p.x, p.y, x, y);
    if (d < 1) return;
    p.aimX = (x - p.x) / d;
    p.aimY = (y - p.y) / d;
    if (p.aimX.abs() > 0.15) p.face = p.aimX.sign;
  }

  Mob? _pickTarget(double range) {
    final p = player;
    if (target != null && target!.alive &&
        _d2(target!.x, target!.y, p.x, p.y) < (range + 80) * (range + 80)) {
      return target;
    }
    Mob? best;
    var bd = range * range;
    for (final m in mobs) {
      if (!m.alive) continue;
      final d = _d2(m.x, m.y, p.x, p.y);
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
  }

  void _basicAttack(Mob? t) {
    final p = player;
    if (p.basicCd > 0) return;
    final melee = sect.basic == BasicKind.melee;
    p.basicCd = (melee ? 0.72 : 0.82) / st.aspd;
    p.attackAnim = 1;
    if (melee) {
      final ang = math.atan2(p.aimY, p.aimX);
      fx.add(Fx(sect.basicFx, p.x, p.y, life: 0.22, angle: ang,
          radius: sect.basicRange + 10, spread: 1.6));
      var hitAny = false;
      for (final m in mobs) {
        if (!m.alive) continue;
        if (_inArc(m, ang, sect.basicRange + m.radius, 1.6)) {
          _hitMob(m, 1.0);
          hitAny = true;
        }
      }
      _sfx(hitAny ? 'hit' : 'swing');
    } else {
      final ang = t != null
          ? math.atan2(t.y - p.y, t.x - p.x)
          : math.atan2(p.aimY, p.aimX);
      _fire(ang, 560, sect.basicRange + 30, 14, sect.basicFx, 1.1);
      _sfx('shoot');
    }
  }

  bool _inArc(Mob m, double ang, double range, double spread) {
    final p = player;
    final dx = m.x - p.x, dy = m.y - p.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > range) return false;
    if (d < m.radius + heroRadius) return true;
    var diff = (math.atan2(dy, dx) - ang).abs() % (math.pi * 2);
    if (diff > math.pi) diff = math.pi * 2 - diff;
    return diff <= spread / 2;
  }

  void _fire(double ang, double speed, double maxDist, double radius,
      String kind, double power,
      {bool pierce = false,
      Status status = Status.none,
      double statusPower = 0,
      double statusTime = 0,
      bool skill = false,
      double knock = 0}) {
    final p = player;
    projs.add(Proj(
      fromHero: true,
      x: p.x + math.cos(ang) * 20,
      y: p.y - 26 + math.sin(ang) * 20,
      vx: math.cos(ang) * speed,
      vy: math.sin(ang) * speed,
      maxDist: maxDist,
      radius: radius,
      fx: kind,
      power: power,
      pierce: pierce,
      status: status,
      statusPower: statusPower,
      statusTime: statusTime,
      skill: skill,
      knock: knock,
    ));
  }

  /// Whether skill [i] could fire right now.
  bool ready(int i) {
    final s = sect.skills[i];
    return !s.isPassive &&
        hero.skillLv[i] > 0 &&
        player.cd[i] <= 0 &&
        player.mp >= s.mpAt(hero.skillLv[i]);
  }

  void _cast(int i) {
    if (!ready(i) || !player.alive) return;
    final s = sect.skills[i];
    final lv = hero.skillLv[i];
    final p = player;
    p.mp -= s.mpAt(lv);
    p.cd[i] = s.cooldown * (1 - st.cdr);
    p.attackAnim = 1;
    final pw = s.powerAt(lv);
    final reach = math.max(s.range, s.radius) + 80;
    final t = _pickTarget(reach);
    if (t != null) _aimAt(t.x, t.y);
    final ang = math.atan2(p.aimY, p.aimX);
    _sfx(s.fx);
    switch (s.kind) {
      case SkillKind.arc:
        fx.add(Fx(s.fx, p.x, p.y, life: 0.3, angle: ang, radius: s.range,
            spread: s.spread));
        for (final m in mobs) {
          if (m.alive && _inArc(m, ang, s.range + m.radius, s.spread)) {
            _hitSkill(m, s, pw);
          }
        }
      case SkillKind.nova:
        fx.add(Fx(s.fx, p.x, p.y, life: 0.55, radius: s.radius));
        _shake(s.radius > 200 ? 8 : 4);
        for (final m in mobs) {
          if (m.alive &&
              _d2(m.x, m.y, p.x, p.y) < _sq(s.radius + m.radius)) {
            _hitSkill(m, s, pw);
          }
        }
      case SkillKind.projectile:
        for (var k = 0; k < s.count; k++) {
          final a = s.count == 1
              ? ang
              : ang - s.spread / 2 + s.spread * k / (s.count - 1);
          _fire(a, 600, s.range, s.radius > 0 ? s.radius : 16, s.fx, pw,
              pierce: s.pierce,
              status: s.status,
              statusPower: s.statusPower,
              statusTime: s.statusTime,
              skill: true,
              knock: s.knock);
        }
      case SkillKind.radial:
        for (var k = 0; k < s.count; k++) {
          final a = ang + math.pi * 2 * k / s.count;
          _fire(a, 560, s.range, 16, s.fx, pw,
              pierce: s.pierce, skill: true);
        }
      case SkillKind.ground:
        double gx, gy;
        if (t != null && _dist(p.x, p.y, t.x, t.y) <= s.range + 60) {
          gx = t.x;
          gy = t.y;
        } else {
          gx = p.x + p.aimX * s.range * 0.6;
          gy = p.y + p.aimY * s.range * 0.6;
        }
        zones.add(Zone(
          fromHero: true,
          x: gx,
          y: gy,
          r: s.radius,
          delay: s.delay,
          ticks: s.ticks,
          interval: s.ticks > 1 ? s.duration / s.ticks : 0,
          power: pw,
          fx: s.fx,
          status: s.status,
          statusPower: s.statusPower,
          statusTime: s.statusTime,
          knock: s.knock,
        ));
      case SkillKind.line:
        for (var k = 0; k < s.count; k++) {
          final d = s.range * (k + 1) / s.count;
          zones.add(Zone(
            fromHero: true,
            x: p.x + math.cos(ang) * d,
            y: p.y + math.sin(ang) * d,
            r: s.radius,
            delay: 0.06 + k * 0.07,
            ticks: 1,
            interval: 0,
            power: pw,
            fx: s.fx,
            status: s.status,
            statusTime: s.statusTime,
          ));
        }
      case SkillKind.dash:
        p.dashT = 0.24;
        p.dashVx = math.cos(ang) * s.range / 0.24;
        p.dashVy = math.sin(ang) * s.range / 0.24;
        p.dashHit.clear();
        p.dashSkill = s;
        p.dashLv = lv;
        fx.add(Fx(s.fx, p.x, p.y, life: 0.45, angle: ang, radius: s.range,
            x2: p.x + math.cos(ang) * s.range,
            y2: p.y + math.sin(ang) * s.range));
      case SkillKind.aura:
        p.aura = s;
        p.auraLv = lv;
        p.auraInterval = s.duration / s.ticks;
        p.auraUntil = time + s.duration;
        p.auraNext = time;
        fx.add(Fx(s.fx, p.x, p.y, life: s.duration, radius: s.radius,
            onHero: true));
      case SkillKind.guard:
        p.guardPct = math.min(0.7, pw);
        p.guardUntil = time + s.duration;
        fx.add(Fx(s.fx, p.x, p.y, life: s.duration, onHero: true));
      case SkillKind.heal:
        final amount = pw * p.maxHp;
        p.hp = math.min(p.maxHp, p.hp + amount);
        p.hotPerSec = amount / s.duration;
        p.hotUntil = time + s.duration;
        _text(p.x, p.y - 60, '+${amount.round()}', 0xFF7CF08A, big: true);
        fx.add(Fx(s.fx, p.x, p.y, life: 1.0, onHero: true));
      case SkillKind.shield:
        p.shield = pw * p.maxHp;
        p.shieldUntil = time + s.duration;
        fx.add(Fx(s.fx, p.x, p.y, life: s.duration, onHero: true));
      case SkillKind.passive:
        break;
    }
  }

  void _stepDash(double dt) {
    final p = player;
    final step = math.min(dt, p.dashT);
    p.dashT -= step;
    p.x += p.dashVx * step;
    p.y += p.dashVy * step;
    p.moving = true;
    p.walk += dt * 10;
    _clamp(p);
    final s = p.dashSkill!;
    for (final m in mobs) {
      if (!m.alive || p.dashHit.contains(m.uid)) continue;
      if (_d2(m.x, m.y, p.x, p.y) < _sq(s.radius + m.radius)) {
        p.dashHit.add(m.uid);
        _hitSkill(m, s, s.powerAt(p.dashLv));
      }
    }
  }

  void _usePotion(bool hp) {
    final p = player;
    if (p.potCd > 0) return;
    if (hp) {
      if (hero.hpPots <= 0 || p.hp >= p.maxHp) return;
      hero.hpPots--;
      final v = p.maxHp * potionHeal;
      p.hp = math.min(p.maxHp, p.hp + v);
      _text(p.x, p.y - 60, '+${v.round()}', 0xFF7CF08A);
      fx.add(Fx('potionHp', p.x, p.y, life: 0.6, onHero: true));
    } else {
      if (hero.mpPots <= 0 || p.mp >= st.maxMp) return;
      hero.mpPots--;
      p.mp = math.min(st.maxMp, p.mp + st.maxMp * potionHeal * 1.4);
      fx.add(Fx('potionMp', p.x, p.y, life: 0.6, onHero: true));
    }
    p.potCd = potionCooldown;
    _sfx('potion');
  }

  // ------------------------------------------------------------ autopilot

  double _autoMoveX = 0, _autoMoveY = 0;
  bool _kite = false;

  void _autopilot() {
    final p = player;
    // Potions first.
    if (p.hp < p.maxHp * 0.42) input.hpPot = true;
    if (p.mp < st.maxMp * 0.22) input.mpPot = true;

    final near = _autoTarget();
    if (near != null) target = near;
    var count = 0;
    for (final m in mobs) {
      if (m.alive && _d2(m.x, m.y, p.x, p.y) < 200 * 200) count++;
    }

    // Skills, biggest first.
    for (final i in const [4, 2, 1, 0]) {
      if (!ready(i)) continue;
      final s = sect.skills[i];
      final use = switch (s.kind) {
        SkillKind.guard || SkillKind.shield =>
          count >= 2 || p.hp < p.maxHp * 0.75,
        SkillKind.heal => p.hp < p.maxHp * 0.6,
        SkillKind.nova || SkillKind.aura => _countNear(s.radius) >=
            (i == 4 ? 2 : 1),
        SkillKind.dash => near != null &&
            _dist(p.x, p.y, near.x, near.y) < s.range,
        _ => near != null &&
            _dist(p.x, p.y, near.x, near.y) <
                math.max(s.range, s.radius) + 20,
      };
      if (use) {
        input.skills.add(i);
        break;
      }
    }

    if (near != null) {
      // Ranged heroes step back from melee monsters between shots.
      if (sect.basic == BasicKind.ranged) {
        Mob? close;
        var cd = 80.0 * 80;
        for (final m in mobs) {
          if (!m.alive || m.def.ranged || m.state != MobState.chase) continue;
          final d = _d2(m.x, m.y, p.x, p.y);
          if (d < cd) {
            cd = d;
            close = m;
          }
        }
        if (close != null && (p.basicCd > 0.1 || count >= 2)) {
          _flee(close);
          return;
        }
      }
      // Close in; the basic attack takes over once in reach.
      _walkTo(near.x, near.y);
      return;
    }
    // Pick up loot nearby.
    Drop? loot;
    var ld = 600.0 * 600;
    for (final d in drops) {
      if (d.taken || d.flying) continue;
      final dd = _d2(d.x, d.y, p.x, p.y);
      if (dd < ld) {
        ld = dd;
        loot = d;
      }
    }
    if (loot != null) {
      _walkTo(loot.x, loot.y);
      return;
    }
    // Head for the nearest living monster, quest targets preferred.
    final quest = _questTarget;
    Mob? best;
    var bd = double.infinity;
    for (final m in mobs) {
      if (!m.alive || _avoid(m)) continue;
      var d = _d2(m.x, m.y, p.x, p.y);
      if (m.def.id == quest) d *= 0.02;
      if (m.level > hero.level + 4) d *= 4;
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    if (best != null) _walkTo(best.x, best.y);
  }

  /// Whether the autopilot should leave this monster alone for now.
  bool _avoid(Mob m) =>
      m.def.boss &&
      mode == WorldMode.field &&
      m.state != MobState.chase &&
      m.def.id != hero.currentMain?.target &&
      hero.level < map.maxLv;

  /// Nearest worthwhile monster within reach of a fight; ones already
  /// hitting the hero count as closer.
  Mob? _autoTarget() {
    final p = player;
    if (target != null && target!.alive &&
        _d2(target!.x, target!.y, p.x, p.y) < 500 * 500) {
      return target;
    }
    // While a kill quest's monsters live on this map, only they and
    // whatever is already attacking count: the autopilot does the quest.
    final quest = _questTarget;
    final hunt = quest != null && mobs.any((m) => m.alive && m.def.id == quest);
    Mob? best;
    var bd = 600.0 * 600;
    for (final m in mobs) {
      if (!m.alive || _avoid(m)) continue;
      if (hunt && m.def.id != quest && m.state != MobState.chase) continue;
      var d = _d2(m.x, m.y, p.x, p.y);
      if (m.state == MobState.chase) d *= 0.5;
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
  }

  /// Monster id the current main quest wants killed, if any.
  String? get _questTarget {
    final q = hero.currentMain;
    if (q == null || hero.mainLocked) return null;
    if (q.type != QuestType.kill && q.type != QuestType.boss) return null;
    return q.target;
  }

  void _flee(Mob m) {
    final p = player;
    var dx = p.x - m.x, dy = p.y - m.y;
    final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    dx /= d;
    dy /= d;
    // Slide along walls instead of pinning against them.
    if ((p.x < 120 && dx < 0) || (p.x > width - 120 && dx > 0)) dx = 0;
    if ((p.y < 140 && dy < 0) || (p.y > height - 120 && dy > 0)) dy = 0;
    if (dx.abs() + dy.abs() < 0.3) {
      // Cornered: run toward the middle of the map.
      dx = (width / 2 - p.x).sign * 0.5;
      dy = (height / 2 - p.y).sign;
    }
    _kite = true;
    _autoMoveX = dx;
    _autoMoveY = dy;
  }

  int _countNear(double r) {
    var n = 0;
    for (final m in mobs) {
      if (m.alive &&
          _d2(m.x, m.y, player.x, player.y) < _sq(r + m.radius - 10)) {
        n++;
      }
    }
    return n;
  }

  void _walkTo(double x, double y) {
    final d = _dist(player.x, player.y, x, y);
    if (d < 4) return;
    _autoMoveX = (x - player.x) / d;
    _autoMoveY = (y - player.y) / d;
  }

  // ------------------------------------------------------------ damage

  void _hitSkill(Mob m, SkillDef s, double pw) {
    _hitMob(m, pw,
        skill: true,
        status: s.status,
        statusPower: s.statusPower,
        statusTime: s.statusTime,
        knock: s.knock);
  }

  void _hitMob(Mob m, double mult,
      {bool skill = false,
      Status status = Status.none,
      double statusPower = 0,
      double statusTime = 0,
      double knock = 0}) {
    if (!m.alive) return;
    var dmg = st.atk * mult * (skill ? 1 + st.skillDmg : 1);
    dmg *= hanhFactor(hero.hanh, m.def.hanh);
    final crit = rng.nextDouble() < st.crit;
    if (crit) dmg *= st.critDmg;
    dmg *= 1 - mitigation(m.defense, hero.level);
    dmg *= 0.9 + rng.nextDouble() * 0.2;
    _damageMob(m, dmg, crit ? 0xFFFFD34A : 0xFFFFFFFF, big: crit);
    if (!m.alive) return;
    if (m.state != MobState.chase) _aggro(m);
    switch (status) {
      case Status.slow:
        m.slowUntil = time + statusTime;
        m.slowPct = statusPower;
      case Status.stun:
        // Bosses shrug most of it off.
        m.stunUntil = time + statusTime * (m.def.boss ? 0.3 : 1);
      case Status.poison || Status.burn:
        final per = st.atk * statusPower * 0.5 * (1 + st.dotPct);
        m.dots.removeWhere((d) => d.kind == status);
        m.dots.add(Dot(status, per, time + statusTime, time + 0.5));
      case Status.none:
        break;
    }
    if (knock > 0 && !m.def.boss) {
      final d = math.max(1, _dist(player.x, player.y, m.x, m.y));
      m.kx = (m.x - player.x) / d * knock * 4;
      m.ky = (m.y - player.y) / d * knock * 4;
    }
  }

  void _damageMob(Mob m, double dmg, int color,
      {bool big = false, bool small = false}) {
    m.hp -= dmg;
    m.hurt = 0.15;
    _text(m.x + (rng.nextDouble() - 0.5) * 20, m.y - 40 * m.def.size - 10,
        dmg.round().toString(), color,
        big: big, small: small);
    if (m.hp <= 0) _kill(m);
  }

  void _aggro(Mob m) {
    m.state = MobState.chase;
    if (m.camp < 0) return;
    // At most two close friends join in, so a whole camp never piles on.
    var n = 0;
    for (final o in mobs) {
      if (n >= 2) break;
      if (o.alive && o.camp == m.camp && o.state != MobState.chase &&
          _d2(o.x, o.y, m.x, m.y) < 150 * 150) {
        o.state = MobState.chase;
        n++;
      }
    }
  }

  void _kill(Mob m) {
    m.hp = 0;
    m.hurt = 0.6;
    m.dots.clear();
    if (target == m) target = null;
    _sfx(m.def.boss ? 'bossDie' : 'die');
    final xp = mobExpAt(m.level) *
        m.def.exp *
        expLevelFactor(hero.level, m.level);
    _text(m.x, m.y - 70, '+${xp.round()} EXP', 0xFFB8E0FF, small: true);
    hero.onKill(m.def, rng);
    hero.gainExp(xp);
    if (mode == WorldMode.field) {
      if (m == boss) {
        bossRespawnAt = time + 150;
      } else {
        m.respawnAt = time + 9 + rng.nextDouble() * 6;
      }
    }
    _rollDrops(m);
    if (m.def.boss) _shake(10);
  }

  void _rollDrops(Mob m) {
    double jx() => (rng.nextDouble() - 0.5) * 60;
    final goldChance = m.def.boss ? 1.0 : 0.5;
    if (rng.nextDouble() < goldChance) {
      final g = ((1 + m.level * 0.4) *
              (0.7 + rng.nextDouble() * 0.6) *
              (m.def.boss ? 15 : 1))
          .round();
      drops.add(Drop(m.x + jx(), m.y + jx(), gold: g));
    }
    final items = m.def.boss ? 2 : (rng.nextDouble() < 0.075 ? 1 : 0);
    for (var i = 0; i < items; i++) {
      final it = makeItem(
        slot: Slot.values[rng.nextInt(Slot.values.length)],
        level: math.min(maxLevel, m.level),
        rarity: rollRarity(rng, boss: m.def.boss),
        sect: sect,
        rng: rng,
      );
      drops.add(Drop(m.x + jx(), m.y + jx(), item: it));
    }
    if (rng.nextDouble() < 0.04) {
      drops.add(Drop(m.x + jx(), m.y + jx(), potion: rng.nextBool() ? 1 : 2));
    }
  }

  void _hurtHero(double raw, Hanh from) {
    final p = player;
    if (!p.alive || p.dashT > 0) return;
    if (rng.nextDouble() < st.dodge) {
      _text(p.x, p.y - 60, 'Né', 0xFFB8E0FF);
      return;
    }
    var dmg = raw * hanhFactor(from, hero.hanh);
    dmg *= 1 - mitigation(st.def, hero.level);
    if (time < p.guardUntil) dmg *= 1 - p.guardPct;
    dmg *= 0.9 + rng.nextDouble() * 0.2;
    if (p.shield > 0) {
      final take = math.min(p.shield, dmg);
      p.shield -= take;
      dmg -= take;
    }
    p.lastHurt = time;
    if (dmg <= 0) return;
    p.hp -= dmg;
    p.hurt = 0.18;
    _text(p.x + (rng.nextDouble() - 0.5) * 16, p.y - 64, '-${dmg.round()}',
        0xFFFF5A4A);
    if (p.hp <= 0) {
      p.hp = 0;
      _sfx('heroDie');
      if (mode == WorldMode.dungeon) {
        finished = true;
        events.add(GameEvent(EvKind.failed, text: 'Trọng thương!'));
      } else {
        events.add(GameEvent(EvKind.heroDied));
      }
    }
  }

  /// Field death: back on your feet at the map entrance, EXP docked.
  void revive() {
    final p = player;
    final loss = (hero.expNeeded * 0.03).round();
    hero.exp = math.max(0, hero.exp - loss);
    p.hp = p.maxHp;
    p.mp = st.maxMp;
    p.x = 220;
    p.y = height / 2;
    p.dots.clear();
    p.stunUntil = 0;
    target = null;
    for (final m in mobs) {
      if (m.state == MobState.chase) m.state = MobState.leash;
    }
  }

  void _tickDots(Actor a, double dt, Mob? m) {
    if (a.dots.isEmpty) return;
    // A tick can kill, and killing clears the list.
    for (final d in List<Dot>.of(a.dots)) {
      if (time >= d.next && time <= d.until + 0.01) {
        d.next += 0.5;
        if (m != null && m.alive) {
          _damageMob(m, d.perTick * (1 - mitigation(m.defense, hero.level)),
              d.kind == Status.poison ? 0xFF9CF06A : 0xFFFF9A4A,
              small: true);
        }
      }
    }
    a.dots.removeWhere((d) => time > d.until);
  }

  // ------------------------------------------------------------ monsters

  void _updateMob(Mob m, double dt) {
    if (m.hurt > 0) m.hurt -= dt;
    if (!m.alive) return;
    if (m.attackAnim > 0) m.attackAnim = math.max(0, m.attackAnim - dt * 3);
    _tickDots(m, dt, m);
    if (!m.alive) return;
    // Knockback slides.
    if (m.kx.abs() + m.ky.abs() > 1) {
      m.x += m.kx * dt;
      m.y += m.ky * dt;
      m.kx *= math.pow(0.002, dt).toDouble();
      m.ky *= math.pow(0.002, dt).toDouble();
      _clamp(m);
    }
    if (time < m.stunUntil) {
      m.moving = false;
      return;
    }
    if (m.attackCd > 0) m.attackCd -= dt;
    final p = player;
    final dp = _dist(m.x, m.y, p.x, p.y);
    final home = _dist(m.x, m.y, m.homeX, m.homeY);

    switch (m.state) {
      case MobState.idle || MobState.wander:
        if (p.alive && dp < (m.def.boss ? 260 : 220)) {
          _aggro(m);
          break;
        }
        m.wanderT -= dt;
        if (m.wanderT <= 0) {
          m.wanderT = 2 + rng.nextDouble() * 4;
          if (rng.nextDouble() < 0.5) {
            m.state = MobState.idle;
          } else {
            m.state = MobState.wander;
            final a = rng.nextDouble() * math.pi * 2;
            final r = rng.nextDouble() * 110;
            m.tx = m.homeX + math.cos(a) * r;
            m.ty = m.homeY + math.sin(a) * r;
          }
        }
        if (m.state == MobState.wander) {
          _moveMob(m, m.tx, m.ty, m.def.speed * 0.4, dt);
        } else {
          m.moving = false;
        }
      case MobState.leash:
        _moveMob(m, m.homeX, m.homeY, m.def.speed * 1.4, dt);
        m.hp = math.min(m.maxHp, m.hp + m.maxHp * 0.3 * dt);
        if (home < 20) {
          m.state = MobState.idle;
          m.hp = m.maxHp;
        }
      case MobState.chase:
        if (!p.alive ||
            (mode == WorldMode.field && home > 650 && dp > 200)) {
          m.state = MobState.leash;
          break;
        }
        if (m.def.boss) _bossSkill(m, dt);
        final reach = m.def.ranged
            ? m.def.range
            : m.radius + heroRadius + 14;
        if (dp > reach * 0.9) {
          _moveMob(m, p.x, p.y, m.def.speed, dt);
        } else {
          m.moving = false;
          if (p.x != m.x) m.face = (p.x - m.x).sign;
        }
        if (dp <= reach && m.attackCd <= 0) {
          m.attackCd = m.def.attackCd * (0.85 + rng.nextDouble() * 0.3);
          m.attackAnim = 1;
          if (m.def.ranged) {
            final a = math.atan2(p.y - m.y, p.x - m.x);
            projs.add(Proj(
              fromHero: false,
              x: m.x,
              y: m.y - 30 * m.def.size,
              vx: math.cos(a) * 320,
              vy: math.sin(a) * 320,
              maxDist: m.def.range + 80,
              radius: 12,
              fx: 'mob_${m.def.hanh.name}',
              power: m.atk,
            ));
          } else {
            _hurtHero(m.atk, m.def.hanh);
          }
        }
    }
  }

  void _bossSkill(Mob m, double dt) {
    m.bossCd -= dt;
    if (m.bossCd > 0) return;
    m.bossCd = 6.5 + rng.nextDouble() * 2;
    // A telegraphed slam on the hero's spot: walk out of the red circle.
    zones.add(Zone(
      fromHero: false,
      x: player.x,
      y: player.y,
      r: 120 + 20 * m.def.size,
      delay: 1.1,
      ticks: 1,
      interval: 0,
      power: m.atk * 2.2,
      fx: 'bossSlam_${m.def.hanh.name}',
    ));
  }

  void _moveMob(Mob m, double x, double y, double speed, double dt) {
    final d = _dist(m.x, m.y, x, y);
    if (d < 3) {
      m.moving = false;
      return;
    }
    var vx = (x - m.x) / d, vy = (y - m.y) / d;
    // Keep a little apart from neighbours.
    for (final o in mobs) {
      if (o == m || !o.alive) continue;
      final dx = m.x - o.x, dy = m.y - o.y;
      final dd = dx * dx + dy * dy;
      final min = (m.radius + o.radius) * 0.9;
      if (dd < min * min && dd > 0.01) {
        final l = math.sqrt(dd);
        vx += dx / l * 0.8;
        vy += dy / l * 0.8;
      }
    }
    final l = math.sqrt(vx * vx + vy * vy);
    final sp = speed * _slowMul(m) * dt;
    m.x += vx / l * sp;
    m.y += vy / l * sp;
    if (vx.abs() > 0.1) m.face = vx.sign;
    m.walk += sp / 22;
    m.moving = true;
    _clamp(m);
  }

  // ------------------------------------------------------------ missiles

  void _updateProjs(double dt) {
    for (final pr in projs) {
      final sx = pr.vx * dt, sy = pr.vy * dt;
      pr.x += sx;
      pr.y += sy;
      pr.dist += math.sqrt(sx * sx + sy * sy);
      if (pr.dist >= pr.maxDist) pr.dead = true;
      if (pr.dead) continue;
      // Missiles fly at chest height; collide against feet + 26.
      final cy = pr.y + 26;
      if (pr.fromHero) {
        for (final m in mobs) {
          if (!m.alive || pr.hit.contains(m.uid)) continue;
          if (_d2(m.x, m.y, pr.x, cy) < _sq(m.radius + pr.radius)) {
            pr.hit.add(m.uid);
            _hitMob(m, pr.power,
                skill: pr.skill,
                status: pr.status,
                statusPower: pr.statusPower,
                statusTime: pr.statusTime,
                knock: pr.knock);
            fx.add(Fx('spark_${pr.fx}', pr.x, pr.y, life: 0.25));
            if (!pr.pierce) {
              pr.dead = true;
              break;
            }
          }
        }
      } else if (player.alive &&
          _d2(player.x, player.y, pr.x, cy) <
              _sq(heroRadius + pr.radius)) {
        pr.dead = true;
        _hurtHero(pr.power, _hanhOfFx(pr.fx));
        fx.add(Fx('spark_${pr.fx}', pr.x, pr.y, life: 0.25));
      }
    }
    projs.removeWhere((p) => p.dead);
  }

  Hanh _hanhOfFx(String fx) {
    for (final h in Hanh.values) {
      if (fx.endsWith(h.name)) return h;
    }
    return Hanh.kim;
  }

  void _updateZones(double dt) {
    for (final z in zones) {
      z.t += dt;
      if (z.ticks <= 0 || z.t < z.delay) continue;
      if (z.t - z.delay < z.next) continue;
      z.next += z.interval > 0 ? z.interval : 999;
      z.ticks--;
      if (z.fromHero) {
        if (z.interval == 0) _shake(z.r > 160 ? 7 : 3);
        for (final m in mobs) {
          if (m.alive && _d2(m.x, m.y, z.x, z.y) < _sq(z.r + m.radius)) {
            _hitMob(m, z.power,
                skill: true,
                status: z.status,
                statusPower: z.statusPower,
                statusTime: z.statusTime,
                knock: z.knock);
          }
        }
      } else {
        _shake(6);
        if (_d2(player.x, player.y, z.x, z.y) < _sq(z.r + heroRadius)) {
          _hurtHero(z.power, _hanhOfFx(z.fx));
        }
      }
    }
    zones.removeWhere((z) => z.t > z.life);

    // Hero aura ticks.
    final p = player;
    final a = p.aura;
    if (a != null && time <= p.auraUntil && time >= p.auraNext) {
      p.auraNext += p.auraInterval;
      for (final m in mobs) {
        if (m.alive && _d2(m.x, m.y, p.x, p.y) < _sq(a.radius + m.radius)) {
          _hitSkill(m, a, a.powerAt(p.auraLv));
        }
      }
    }
  }

  // ------------------------------------------------------------ loot

  void _updateDrops(double dt) {
    final p = player;
    for (final d in drops) {
      d.t += dt;
      if (d.taken) continue;
      final dd = _dist(d.x, d.y, p.x, p.y);
      if (!d.flying && d.t > 0.5 && dd < 150) d.flying = true;
      if (d.flying) {
        final sp = math.min(dd, (500 + d.t * 200) * dt);
        if (dd > 1) {
          d.x += (p.x - d.x) / dd * sp;
          d.y += (p.y - d.y) / dd * sp;
        }
        if (dd < 16) _take(d);
      }
    }
    drops.removeWhere((d) => d.taken || d.t > 90);
  }

  void _take(Drop d) {
    d.taken = true;
    if (d.gold > 0) {
      hero.gold += d.gold;
      _text(player.x, player.y - 80, '+${d.gold} lượng', 0xFFFFD34A);
      _sfx('coin');
    }
    if (d.potion == 1) {
      hero.hpPots++;
      _text(player.x, player.y - 80, '+1 Kim Sang Dược', 0xFFFF8A8A);
    }
    if (d.potion == 2) {
      hero.mpPots++;
      _text(player.x, player.y - 80, '+1 Ngưng Thần Đan', 0xFF8AB8FF);
    }
    final it = d.item;
    if (it != null) {
      final kept = hero.addItem(it);
      events.add(GameEvent(EvKind.loot,
          text: kept
              ? 'Nhặt được ${it.name} [${it.rarity.label}]'
              : 'Đã bán ${it.name} (+${it.sellPrice} lượng)',
          color: it.rarity.color));
      _sfx('loot');
    }
  }

  // ------------------------------------------------------------ helpers

  /// Sound cue names the screen turns into audio.
  final List<String> sounds = [];
  void _sfx(String name) {
    if (sounds.length < 8) sounds.add(name);
  }

  void _shake(double v) => events.add(GameEvent(EvKind.shake, value: v));

  void _text(double x, double y, String s, int color,
      {bool big = false, bool small = false}) {
    if (texts.length > 60) texts.removeAt(0);
    // Stagger so bursts of numbers do not print on top of each other.
    texts.add(FloatText(x + (rng.nextDouble() - 0.5) * 30,
        y - rng.nextDouble() * 18, s, color,
        big: big, small: small));
  }

  int get aliveMobs => mobs.where((m) => m.alive).length + _pending;

  double get timeLeft =>
      dungeon == null ? 0 : math.max(0, dungeon!.timeLimit - time);
}

class _Camp {
  _Camp(this.x, this.y, this.def, this.level, this.count);
  final double x, y;
  final MobDef def;
  final int level;
  final int count;
}

double _sq(double v) => v * v;
double _d2(double ax, double ay, double bx, double by) =>
    (ax - bx) * (ax - bx) + (ay - by) * (ay - by);
double _dist(double ax, double ay, double bx, double by) =>
    math.sqrt(_d2(ax, ay, bx, by));
