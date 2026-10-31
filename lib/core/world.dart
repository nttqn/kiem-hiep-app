import 'dart:math' as math;

import 'alchemy.dart';
import 'arena.dart';
import 'companions.dart';
import 'content.dart';
import 'divine.dart';
import 'fishing.dart';
import 'gems.dart';
import 'gold_sets.dart';
import 'hanh.dart';
import 'hero.dart';
import 'items.dart';
import 'live_event.dart';
import 'manuals.dart';
import 'newbie.dart';
import 'nightmare.dart';
import 'pets.dart';
import 'realm.dart';
import 'scenery.dart';
import 'sects.dart';
import 'tang_bao.dart';
import 'weather.dart';
import 'world_boss.dart' show vnDayKey;

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

/// The hero's spirit beast following them around.
class PetActor {
  PetActor(this.def, this.x, this.y);
  final PetDef def;
  double x, y;
  double face = 1;
  double walk = 0;
  bool moving = false;
  double cd = 1;
  double attackAnim = 0;
}

/// The hiệp khách along with the hero: monsters ignore them; they pick the
/// hero's fights and use their sect's skills.
class CompanionActor {
  CompanionActor(this.def, this.bond, this.x, this.y)
      : skillCd = List.filled(def.sect.skills.length, 0);
  final CompanionDef def;
  final int bond;
  double x, y;
  double face = 1;
  double walk = 0;
  bool moving = false;
  double attackAnim = 0;
  double cd = 0.5;

  /// When each skill is ready again, and when any may be cast next.
  final List<double> skillCd;
  double next = 1.5;
}

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

  /// Set on a tinh anh: the quest or bounty key it answers to, and its name.
  String? eliteKey;
  String eliteName = '';
  bool get elite => eliteKey != null;

  /// A Dạ Yêu: a night-born monster of the field.
  bool nightborn = false;

  /// Set on a Lôi đài challenger, drawn as a hero of their sect.
  ArenaRival? rival;

  // A challenger's skill cooldowns, when it may cast next, and its guard.
  List<double> rivalCd = const [];
  double rivalNext = 1.5;
  double guardUntil = 0, guardPct = 0;

  /// Bosses and elites: bigger loot, a name bar, a screen shake.
  bool get big => def.boss || elite;

  /// Ma khí Cuồng bạo makes them run faster.
  double speedMul = 1;
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
    this.hanh,
  });

  final bool fromHero;

  /// Phase used for khắc bonuses; null means the hero's (pets use their own).
  final Hanh? hanh;
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
    this.visualOnly = false,
    this.hanh,
  }) : life = delay + interval * math.max(0, ticks - 1) + (fx == 'buddhaPalm' || fx == 'fireLine' ? 0.8 : 0.4);

  final bool fromHero;

  /// Phase for khắc bonuses on the hero's side; null means the hero's.
  final Hanh? hanh;

  /// Drawn like a hero skill but hits nothing (a challenger's skill art over
  /// its red telegraph).
  final bool visualOnly;
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

/// A medicinal plant on a field map: walk over it to pick it.
class HerbNode {
  HerbNode(this.x, this.y, this.tier);
  final double x, y;
  final int tier;

  /// World time when it can be picked again.
  double readyAt = 0;
}

class Drop {
  Drop(this.x, this.y, {this.item, this.gold = 0, this.potion = 0, this.gem});
  double x, y;
  final Item? item;
  final int gold;
  final Gem? gem;

  /// 1 HP potion, 2 MP potion.
  final int potion;
  double t = 0;
  bool flying = false;
  bool taken = false;
}

enum EvKind { notice, heroDied, wave, cleared, failed, boss, loot, shake, merchant }

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
  final List<double> cd = List.filled(7, 0);
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
    _plantHerbs();
  }

  World.dungeon(this.hero, DungeonDef d, {int? seed})
      : mode = WorldMode.dungeon,
        dungeon = d,
        map = d.map,
        width = d.isRealm ? realmWidth : 1700,
        height = d.isRealm ? realmHeight : 1150,
        rng = math.Random(seed ?? DateTime.now().millisecondsSinceEpoch),
        scenery = d.isRealm
            ? Scenery.generate(d.map.theme, realmWidth, realmHeight, d.id.hashCode ^ (seed ?? 0x5ea1))
            : Scenery.generate(d.map.theme, 1700, 1150, d.id.hashCode,
                arena: true),
        player = d.isRealm ? Player(RealmLayout.gateX, RealmLayout.gateY) : Player(300, 1150 / 2) {
    _init();
    if (d.isRealm) _buildRealm(seed ?? rng.nextInt(1 << 30));
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

  /// One tap on the attack button: keep fighting the nearest monsters, as
  /// if it were held, until the joystick moves or none is left in reach.
  bool engaged = false;

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

  /// Sky over a field map or bí cảnh (dungeon arenas stay clear and lit).
  Weather weather = Weather.clear;
  bool night = false;

  /// Dev build: force the sky.
  static Weather? debugWeather;
  static bool? debugNight;

  bool get _outdoors => mode == WorldMode.field || (dungeon?.isRealm ?? false);

  void _sky() {
    if (!_outdoors) return;
    weather = debugWeather ?? weatherOf(map.id, map.theme);
    night = debugNight ?? isNight();
  }

  void _init() {
    _sky();
    hero.recompute();
    player.maxHp = st.maxHp;
    player.hp = st.maxHp;
    player.mp = st.maxMp;
    skills = [for (var i = 0; i < sect.skills.length; i++) hero.castSkill(i)];
    if (debugPond && hasPond) {
      player.x = pondX - 40;
      player.y = pondY - pondRy - 40;
    }
    _spawnPet();
    _spawnCompanion();
  }

  /// The sect's skills as this hero casts them, bí kíp included (they are
  /// only changed in town).
  late final List<SkillDef> skills;

  // ------------------------------------------------------------ pond

  /// Screenshot aid for the dev build: start on the pond's bank.
  static bool debugPond = false;

  /// The fishing pond by the gate of a field map.
  // Cửu U Ma Vực has no fish of its own.
  bool get hasPond => mode == WorldMode.field && map.rebirths == 0;
  double get pondX => pondDx;
  double get pondY => height / 2 + pondDy;

  bool get nearPond =>
      hasPond && player.alive && _d2(player.x, player.y, pondX, pondY) < pondReach * pondReach;

  /// Keeps the hero on the bank.
  void _pondBank(Actor a) {
    final dx = (a.x - pondX) / (pondRx + a.radius * 0.5), dy = (a.y - pondY) / (pondRy + a.radius * 0.5);
    final d = math.sqrt(dx * dx + dy * dy);
    if (d >= 1) return;
    if (d < 1e-6) {
      a.y = pondY - pondRy - a.radius * 0.5;
      return;
    }
    a.x = pondX + dx / d * (pondRx + a.radius * 0.5);
    a.y = pondY + dy / d * (pondRy + a.radius * 0.5);
  }

  // ------------------------------------------------------------ ác mộng

  NmAffix? get affix => (dungeon?.isNightmare ?? false) ? NmAffix.values[dungeon!.affix] : null;

  /// A nightmare monster: its ma khí on top of the level and multiplier.
  void _nightmare(Mob m) {
    switch (affix) {
      case NmAffix.frenzy:
        m.atk *= 1.25;
        m.speedMul = 1.25;
      case NmAffix.fortified:
        m.maxHp *= 1.6;
        m.hp = m.maxHp;
      case NmAffix.volatile || NmAffix.chill || null:
        break;
    }
  }

  int _summons = 0;
  final List<Mob> _newMobs = [];
  final List<Zone> _newZones = [];

  /// The nightmare boss calls for help as it weakens.
  void _nightmareSummon(Mob m) {
    if (_summons >= nightmareSummonAt.length || m.hp > m.maxHp * nightmareSummonAt[_summons]) return;
    _summons++;
    final d = dungeon!;
    for (var k = 0; k < nightmareAdds; k++) {
      final a = math.pi * 2 * k / nightmareAdds;
      final def = mobById[map.mobs[rng.nextInt(map.mobs.length)]]!;
      final add = Mob(_uid++, def, d.level, m.x + math.cos(a) * 140, m.y + math.sin(a) * 100)
        ..state = MobState.chase;
      add.maxHp *= 1.2;
      add.hp = add.maxHp;
      _scale(add, d.mul);
      _nightmare(add);
      _clamp(add);
      _newMobs.add(add);
      fx.add(Fx('spark_mob_${def.hanh.name}', add.x, add.y - 20, life: 0.4));
    }
    events.add(GameEvent(EvKind.boss, text: '${m.def.name} gọi đồng bọn!', color: 0xFFFF6A4A, big: true));
  }

  // ------------------------------------------------------------ pet

  /// The companion out with the hero, if any.
  PetActor? pet;

  void _spawnPet() {
    final def = petById[hero.activePet];
    pet = def == null ? null : PetActor(def, player.x - 40, player.y + 10);
  }

  void _updatePet(double dt) {
    final pt = pet;
    if (pt == null) return;
    final p = player;
    if (pt.attackAnim > 0) pt.attackAnim = math.max(0, pt.attackAnim - dt * 3);
    // Trail a little behind the hero; jump to them if left far behind.
    final tx = p.x - 42 * p.face, ty = p.y + 14;
    final d = _dist(pt.x, pt.y, tx, ty);
    if (d > 420) {
      pt.x = tx;
      pt.y = ty;
    } else if (d > 8) {
      final sp = math.min(d, (st.move * 1.15 + d) * dt);
      pt.x += (tx - pt.x) / d * sp;
      pt.y += (ty - pt.y) / d * sp;
      if ((tx - pt.x).abs() > 2) pt.face = (tx - pt.x).sign;
      pt.walk += sp / 20;
      pt.moving = true;
    } else {
      pt.moving = false;
    }
    pt.cd -= dt;
    if (pt.cd > 0 || !p.alive) return;
    Mob? best;
    var bd = petRange * petRange;
    for (final m in mobs) {
      if (!m.alive) continue;
      final dd = _d2(m.x, m.y, pt.x, pt.y);
      if (dd < bd) {
        bd = dd;
        best = m;
      }
    }
    if (best == null) return;
    pt.cd = petAttackInterval;
    pt.attackAnim = 1;
    pt.face = (best.x - pt.x).sign == 0 ? pt.face : (best.x - pt.x).sign;
    final a = math.atan2(best.y - pt.y, best.x - pt.x);
    projs.add(Proj(
      fromHero: true,
      x: pt.x,
      y: pt.y - 22,
      vx: math.cos(a) * 480,
      vy: math.sin(a) * 480,
      maxDist: petRange + 60,
      radius: 11,
      fx: 'pet_${pt.def.hanh.name}',
      power: petPower(hero.petLevels[pt.def.id] ?? 1),
      hanh: pt.def.hanh,
    ));
  }

  // ------------------------------------------------------------ hiệp khách

  /// The hiệp khách along, if any (field and ordinary dungeons only).
  CompanionActor? companion;

  bool get _companionAllowed {
    final d = dungeon;
    return d == null || !(d.isTower || d.isWorldBoss || d.isArena);
  }

  void _spawnCompanion() {
    final def = companionById[hero.activeCompanion];
    companion = def == null || !_companionAllowed
        ? null
        : CompanionActor(def, hero.companionBonds[def.id] ?? 1, player.x - 34, player.y - 34);
  }

  void _updateCompanion(double dt) {
    final c = companion;
    if (c == null) return;
    final p = player;
    final s = c.def.sect;
    final melee = s.basic == BasicKind.melee;
    if (c.attackAnim > 0) c.attackAnim = math.max(0, c.attackAnim - dt * 3);
    c.cd -= dt;
    // Fight what the hero fights, or whatever is closing in on them.
    Mob? t = target != null && target!.alive && _d2(target!.x, target!.y, p.x, p.y) < 380 * 380 ? target : null;
    if (t == null) {
      var bd = 320.0 * 320;
      for (final m in mobs) {
        if (!m.alive || m.state != MobState.chase) continue;
        final d = _d2(m.x, m.y, p.x, p.y);
        if (d < bd) {
          bd = d;
          t = m;
        }
      }
    }
    if (!p.alive) t = null;
    // Walk into reach of the target, else keep beside the hero.
    var tx = p.x - 34 * p.face, ty = p.y - 34;
    var stop = 10.0;
    if (t != null) {
      tx = t.x;
      ty = t.y;
      stop = melee ? s.basicRange * 0.8 + t.radius : s.basicRange * 0.85;
    }
    final d = _dist(c.x, c.y, tx, ty);
    if (_dist(c.x, c.y, p.x, p.y) > 650) {
      c.x = p.x - 34 * p.face;
      c.y = p.y - 34;
      c.moving = false;
    } else if (d > stop) {
      final sp = math.min(d - stop, math.max(st.move, 200.0) * 1.1 * dt);
      c.x += (tx - c.x) / d * sp;
      c.y += (ty - c.y) / d * sp;
      if ((tx - c.x).abs() > 2) c.face = (tx - c.x).sign;
      c.walk += sp / 22;
      c.moving = true;
    } else {
      c.moving = false;
    }
    c.x = c.x.clamp(40, width - 40);
    c.y = c.y.clamp(60, height - 40);
    if (t == null) return;
    if ((t.x - c.x).abs() > 2) c.face = (t.x - c.x).sign;
    final dist = _dist(c.x, c.y, t.x, t.y);
    if (time >= c.next && _companionSkill(c, t, dist)) return;
    if (c.cd > 0 || dist > stop + 12) return;
    c.cd = companionHitCd;
    c.attackAnim = 1;
    final ang = math.atan2(t.y - c.y, t.x - c.x);
    final pw = companionHit(c.bond);
    if (melee) {
      fx.add(Fx(s.basicFx, c.x, c.y, life: 0.22, angle: ang, radius: s.basicRange + 10, spread: 1.6));
      for (final m in mobs) {
        if (m.alive && _inArcFrom(c.x, c.y, m, ang, s.basicRange + m.radius, 1.6)) {
          _hitMob(m, pw, as: c.def.hanh);
        }
      }
    } else {
      _fireFrom(c, ang, 560, s.basicRange + 30, 14, s.basicFx, pw);
    }
  }

  /// Casts one of [c]'s ready skills at [t] (some help the hero instead);
  /// false when none suits right now.
  bool _companionSkill(CompanionActor c, Mob t, double dist) {
    final s = c.def.sect;
    final p = player;
    final hp = p.hp / p.maxHp;
    final hurt = time - p.lastHurt < 3;
    final crowd = _countNearAt(c.x, c.y, 200);
    final ready = <int>[];
    companionSkillBond.forEach((i, need) {
      if (c.bond < need || i >= s.skills.length || time < c.skillCd[i]) return;
      final k = s.skills[i];
      final ok = switch (k.kind) {
        SkillKind.passive => false,
        SkillKind.heal => hp < 0.6,
        SkillKind.guard || SkillKind.shield => hurt && hp < 0.85,
        SkillKind.nova || SkillKind.aura => dist < k.radius + t.radius && (crowd >= 2 || t.big),
        _ => dist < math.max(k.range, k.radius) + 30,
      };
      if (ok && (!k.ultimate || crowd >= 3 || t.big)) ready.add(i);
    });
    if (ready.isEmpty) return false;
    final i = ready.firstWhere((k) => s.skills[k].ultimate, orElse: () => ready[rng.nextInt(ready.length)]);
    final k = s.skills[i];
    final lv = (hero.level ~/ 8).clamp(1, maxSkillLevel);
    final pw = k.powerAt(lv) * companionSkillMul(c.bond);
    final h = c.def.hanh;
    c.skillCd[i] = time + k.cooldown * companionSkillCd;
    c.next = time + 1.4 + rng.nextDouble();
    c.attackAnim = 1;
    final ang = math.atan2(t.y - c.y, t.x - c.x);
    _sfx(k.fx);
    if (k.ultimate) events.add(GameEvent(EvKind.notice, text: '${c.def.name}: ${k.name}!', color: h.color));
    void hit(Mob m, double power) => _hitMob(m, power,
        skill: true,
        status: k.status,
        statusPower: k.statusPower,
        statusTime: k.statusTime,
        knock: k.knock,
        as: h);
    void hitAround(double x, double y, double r, double power) {
      for (final m in mobs) {
        if (m.alive && _d2(m.x, m.y, x, y) < _sq(r + m.radius)) hit(m, power);
      }
    }

    Zone zone(double x, double y, double delay, int ticks) => Zone(
          fromHero: true,
          x: x,
          y: y,
          r: k.radius,
          delay: delay,
          ticks: ticks,
          interval: ticks > 1 ? k.duration / ticks : 0,
          power: pw,
          fx: k.fx,
          status: k.status,
          statusPower: k.statusPower,
          statusTime: k.statusTime,
          knock: k.knock,
          hanh: h,
        );

    switch (k.kind) {
      case SkillKind.arc:
        fx.add(Fx(k.fx, c.x, c.y, life: 0.3, angle: ang, radius: k.range, spread: k.spread));
        for (final m in mobs) {
          if (m.alive && _inArcFrom(c.x, c.y, m, ang, k.range + m.radius, k.spread)) hit(m, pw);
        }
      case SkillKind.nova:
        fx.add(Fx(k.fx, c.x, c.y, life: k.ultimate ? 1.0 : 0.55, radius: k.radius));
        hitAround(c.x, c.y, k.radius, pw);
      case SkillKind.aura:
        fx.add(Fx(k.fx, c.x, c.y, life: 1.2, radius: k.radius));
        hitAround(c.x, c.y, k.radius, pw * math.min(4, k.ticks) * 0.5);
      case SkillKind.projectile || SkillKind.radial:
        final n = math.max(1, k.count);
        for (var j = 0; j < n; j++) {
          final a = k.kind == SkillKind.radial
              ? ang + math.pi * 2 * j / n
              : (n == 1 ? ang : ang - k.spread / 2 + k.spread * j / (n - 1));
          _fireFrom(c, a, 600, k.range, k.radius > 0 ? k.radius : 16, k.fx, pw,
              pierce: k.pierce,
              status: k.status,
              statusPower: k.statusPower,
              statusTime: k.statusTime,
              skill: true,
              knock: k.knock);
        }
      case SkillKind.ground:
        zones.add(zone(t.x, t.y, k.delay, k.ticks));
      case SkillKind.line:
        for (var j = 0; j < k.count; j++) {
          final dd = k.range * (j + 1) / k.count;
          zones.add(zone(c.x + math.cos(ang) * dd, c.y + math.sin(ang) * dd, 0.06 + j * 0.07, 1));
        }
      case SkillKind.dash:
        final go = math.max(0.0, math.min(k.range, dist - t.radius));
        fx.add(Fx(k.fx, c.x, c.y, life: 0.45, angle: ang, radius: go,
            x2: c.x + math.cos(ang) * go, y2: c.y + math.sin(ang) * go));
        c.x += math.cos(ang) * go;
        c.y += math.sin(ang) * go;
        hitAround(c.x, c.y, k.radius + 20, pw);
      case SkillKind.heal:
        final amount = pw * p.maxHp;
        p.hp = math.min(p.maxHp, p.hp + amount);
        _text(p.x, p.y - 60, '+${amount.round()}', 0xFF7CF08A, big: true);
        fx.add(Fx(k.fx, p.x, p.y, life: 1.0, onHero: true));
      case SkillKind.guard:
        // Never weakens a stronger guard of the hero's own.
        if (time >= p.guardUntil || p.guardPct <= pw) {
          p.guardPct = math.min(0.4, pw);
          p.guardUntil = time + k.duration;
        }
        fx.add(Fx(k.fx, p.x, p.y, life: k.duration, onHero: true));
      case SkillKind.shield:
        p.shield = math.max(p.shield, pw * p.maxHp);
        p.shieldUntil = math.max(p.shieldUntil, time + k.duration);
        fx.add(Fx(k.fx, p.x, p.y, life: k.duration, onHero: true));
      case SkillKind.passive:
        break;
    }
    return true;
  }

  void _fireFrom(CompanionActor c, double ang, double speed, double maxDist, double radius, String kind,
      double power,
      {bool pierce = false,
      Status status = Status.none,
      double statusPower = 0,
      double statusTime = 0,
      bool skill = false,
      double knock = 0}) {
    projs.add(Proj(
      fromHero: true,
      x: c.x + math.cos(ang) * 20,
      y: c.y - 26 + math.sin(ang) * 20,
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
      hanh: c.def.hanh,
    ));
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

  /// Herb plants of the map's tier, scattered away from the gate.
  final List<HerbNode> herbs = [];

  // Cửu U Ma Vực grows the top tier, as the last map does.
  int get _herbTier => herbTierOfMap(map.rebirths > 0 ? maps.length - 1 : math.max(0, maps.indexOf(map)));

  void _plantHerbs() {
    final r = math.Random(map.id.hashCode ^ 0x5eed);
    for (var i = 0; i < herbNodes; i++) {
      herbs.add(HerbNode(450 + r.nextDouble() * (width - 800), 160 + r.nextDouble() * (height - 320), _herbTier));
    }
    if (debugHerbNear) herbs.add(HerbNode(player.x + 150, player.y - 30, _herbTier));
  }

  /// Screenshot aid for the dev build: a herb plant beside the gate.
  static bool debugHerbNear = false;

  void _updateHerbs() {
    final p = player;
    if (!p.alive) return;
    for (final n in herbs) {
      if (time < n.readyAt || _d2(n.x, n.y, p.x, p.y) > 46 * 46) continue;
      n.readyAt = time + herbRegrow;
      hero.addHerb(n.tier);
      hero.onHerbPicked();
      fx.add(Fx('potionHp', n.x, n.y, life: 0.5));
      events.add(GameEvent(EvKind.loot, text: 'Hái được ${herbNames[n.tier]}', color: herbColors[n.tier]));
      _sfx('loot');
    }
  }

  void _spawnInCamp(int ci) {
    final c = _camps[ci];
    final a = rng.nextDouble() * math.pi * 2;
    final d = rng.nextDouble() * 120;
    final lv = (c.level + rng.nextInt(3) - 1).clamp(map.minLv, map.maxLv);
    final m = Mob(_uid++, c.def, lv, c.x + math.cos(a) * d,
        c.y + math.sin(a) * d)
      ..camp = ci;
    _scale(m, map.mul);
    // At night some come back as Dạ Yêu: tougher, better paid.
    if (night && rng.nextDouble() < nightMobChance) {
      m.nightborn = true;
      m.maxHp *= nightMobHp;
      m.hp = m.maxHp;
      m.atk *= nightMobAtk;
    }
    mobs.add(m);
  }

  void _spawnBoss() {
    final def = mobById[map.boss]!;
    final m = Mob(_uid++, def, map.maxLv, width - 320, height / 2);
    _scale(m, map.mul);
    boss = m;
    mobs.add(m);
  }

  void _spawnWave() {
    final d = dungeon!;
    wave++;
    if (wave >= d.waves.length) {
      bossWave = true;
      if (d.isWorldBoss) {
        _spawnWorldBoss(d);
        return;
      }
      if (d.isArena) {
        _spawnRival(d.rival!);
        return;
      }
      // A tower floor without a boss is done once the wave is down.
      if (!d.boss) return;
      final def = mobById[map.boss]!;
      final m = Mob(_uid++, def, d.level + 1, width * 0.72, height / 2)
        ..state = MobState.chase;
      _scale(m, d.mul);
      if (d.isNightmare) {
        m.maxHp *= 1.5;
        m.hp = m.maxHp;
        _nightmare(m);
      }
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
    _scale(m, d.mul);
    _nightmare(m);
    mobs.add(m);
    fx.add(Fx('spark_mob_${def.hanh.name}', x, y - 20, life: 0.4));
  }

  /// Damage dealt to the Boss Thế Giới this run.
  double bossDamage = 0;

  /// The day's boss: level 99 defence for a fair score, effectively endless
  /// HP, and an attack matched to the hero's level so anyone can last a while.
  void _spawnWorldBoss(DungeonDef d) {
    final def = mobById[d.worldBoss]!;
    final m = Mob(_uid++, def, 99, width * 0.68, height / 2)..state = MobState.chase;
    m.maxHp = 1e13;
    m.hp = m.maxHp;
    m.atk = mobAtkAt(hero.level.clamp(1, 99)) * def.atk * 1.15;
    mobs.add(m);
    boss = m;
    events.add(GameEvent(EvKind.boss, text: '${def.name} giáng thế!', color: 0xFFFF6A4A, big: true));
  }

  /// Ends a Boss Thế Giới run (time up or knocked out) and pays for it.
  void _endWorldBoss() {
    if (finished) return;
    finished = true;
    finishTime = math.min(time, dungeon!.timeLimit);
    rewardLines = hero.worldBossReward(bossDamage.round(), rng);
    events.add(GameEvent(EvKind.cleared, value: 0));
  }

  /// HP potions drunk in this Lôi đài duel.
  int arenaPotsUsed = 0;

  /// The Lôi đài challenger: a hero-shaped boss whose toughness and hits
  /// follow the hero's own, scaled by how their power compares.
  void _spawnRival(ArenaRival r) {
    final def = MobDef(
      id: 'rival',
      name: r.name,
      hanh: r.hanh,
      body: Body.human,
      c1: r.hanh.color,
      c2: 0xFF2A2A2A,
      ranged: sectOf(r.hanh).basic == BasicKind.ranged,
      range: 300,
      speed: 150,
      attackCd: arenaRivalCd,
      boss: true,
    );
    final m = Mob(_uid++, def, hero.level, width * 0.68, height / 2)
      ..state = MobState.chase
      ..rival = r;
    final k = math.pow(r.power / math.max(1, hero.power), 1.2).toDouble();
    m.defense = mobDefAt(hero.level);
    // HP from the hero's own damage output, so an even duel lasts about the
    // same at every level.
    final atkEff = st.atk * (1 + st.crit * (st.critDmg - 1)) * st.aspd * (1 + st.skillDmg * 0.6);
    m.maxHp = atkEff * (1 - mitigation(m.defense, hero.level)) * arenaRivalHp * (0.8 + hero.level / 150) * k;
    m.hp = m.maxHp;
    // Per hit, so that the hero (without potions) lasts [arenaRivalKill]
    // seconds against an even rival with basic hits alone.
    final perSec = st.maxHp / arenaRivalKill * k;
    const hits = 1 / arenaRivalCd;
    m.atk = perSec / hits / (1 - mitigation(st.def, hero.level));
    mobs.add(m);
    boss = m;
    events.add(GameEvent(EvKind.boss, text: '${r.name} lên lôi đài!', color: 0xFFFF6A4A, big: true));
  }

  void _endArena(bool won) {
    if (finished) return;
    finished = true;
    finishTime = math.min(time, dungeon!.timeLimit);
    rewardLines = dungeon!.trial ? hero.sectTrialResult(won) : hero.arenaResult(won, dungeon!.rival!);
    events.add(won ? GameEvent(EvKind.cleared, value: 1) : GameEvent(EvKind.failed, text: 'Thua trận'));
  }

  /// Tower floors past level 99 make monsters tougher instead.
  void _scale(Mob m, double mul) {
    if (mul == 1) return;
    m.maxHp *= mul;
    m.hp = m.maxHp;
    m.atk *= mul;
  }

  // ------------------------------------------------------------ tàng bảo đồ

  /// The marked dig spot, if it is on this field map.
  TbdSpot? get digSpot {
    final s = hero.tbdSpot;
    return mode == WorldMode.field && s != null && s.mapId == map.id ? s : null;
  }

  bool get canReadMap => mode == WorldMode.field && hero.tbdMaps > 0 && hero.tbdSpot == null;

  final Set<int> _ambush = {};
  double _ambushX = 0, _ambushY = 0;

  /// Dev build: what the next dig turns up, and a spot marked beside the
  /// gate.
  static TbdOutcome? debugTbd;
  static bool debugTbdNear = false;

  /// Reads a Tàng Bảo Đồ: marks a spot well away from the hero.
  void readTreasureMap() {
    if (!canReadMap) return;
    final p = player;
    var x = 0.0, y = 0.0;
    for (var i = 0; i < 300; i++) {
      x = 300 + rng.nextDouble() * (width - 600);
      y = 220 + rng.nextDouble() * (height - 440);
      final far = _d2(x, y, p.x, p.y) >= tbdMinDistance * tbdMinDistance;
      final dry = !hasPond || _d2(x, y, pondX, pondY) > 320 * 320;
      if (far && dry) break;
    }
    if (debugTbdNear) {
      x = p.x + 220;
      y = p.y;
    }
    hero.tbdMaps--;
    hero.tbdSpot = TbdSpot(map.id, x, y);
    _sfx('loot');
    events.add(GameEvent(EvKind.notice,
        text: 'Tàng Bảo Đồ chỉ về phía ${compassWord(p.x, p.y, x, y)}: tìm dấu X trên bản đồ nhỏ',
        color: 0xFFFFD34A, big: true));
  }

  void _updateDig() {
    if (_ambush.isNotEmpty && !mobs.any((m) => _ambush.contains(m.uid) && m.alive)) {
      _ambush.clear();
      _tbdChest(_ambushX, _ambushY, math.min(hero.level, map.maxLv));
      events.add(GameEvent(EvKind.wave, text: 'Đã dẹp phục binh, rương báu là của bạn!', color: 0xFFFFD34A, big: true));
    }
    final s = digSpot;
    final p = player;
    if (s == null || !p.alive || _d2(s.x, s.y, p.x, p.y) > tbdDigRadius * tbdDigRadius) return;
    hero.tbdSpot = null;
    final lv = math.min(hero.level, map.maxLv);
    final o = debugTbd ?? rollTbd(rng);
    fx.add(Fx('quake', s.x, s.y, life: 0.6, radius: 90));
    _shake(5);
    switch (o) {
      case TbdOutcome.chest:
        _tbdChest(s.x, s.y, lv);
      case TbdOutcome.portal:
        _tbdChest(s.x, s.y, lv);
        hero.tbdPortal(vnDayKey());
        fx.add(Fx('buddha', s.x, s.y, life: 1, radius: 200));
        events.add(GameEvent(EvKind.wave,
            text: 'Cổng Bí cảnh hé mở! +1 lượt thám hiểm hôm nay', color: 0xFF8CE0C8, big: true));
      case TbdOutcome.ambush:
        _ambushX = s.x;
        _ambushY = s.y;
        for (var i = 0; i < tbdAmbushSize; i++) {
          final a = i * math.pi * 2 / tbdAmbushSize + rng.nextDouble() * 0.5;
          final def = mobById[map.mobs[rng.nextInt(map.mobs.length)]]!;
          final m = Mob(_uid++, def, lv, (s.x + math.cos(a) * 220).clamp(60.0, width - 60),
              (s.y + math.sin(a) * 160).clamp(80.0, height - 60))
            ..state = MobState.chase;
          _scale(m, map.mul);
          _ambush.add(m.uid);
          mobs.add(m);
          fx.add(Fx('spark_mob_${def.hanh.name}', m.x, m.y - 20, life: 0.4));
        }
        events.add(GameEvent(EvKind.boss, text: 'Phục binh! Hạ hết để lấy rương', color: 0xFFFF6A4A, big: true));
      case TbdOutcome.guardian:
        final def = mobById[map.mobs.last]!;
        final m = Mob(_uid++, def, lv + 1, s.x + 60, s.y)
          ..eliteKey = 'tbd_guard'
          ..eliteName = 'Hộ Bảo Tinh Anh'
          ..state = MobState.chase;
        m.maxHp *= 8 * map.mul;
        m.hp = m.maxHp;
        m.atk *= 1.4 * map.mul;
        mobs.add(m);
        events.add(GameEvent(EvKind.boss, text: 'Hộ Bảo Tinh Anh trỗi dậy canh giữ kho báu!', color: 0xFFFF6A4A, big: true));
    }
  }

  void _tbdChest(double x, double y, int lv) {
    final g = hero.tbdChestGold(lv);
    double j() => (rng.nextDouble() - 0.5) * 80;
    drops.add(Drop(x + j(), y + 30 + j() / 2,
        item: makeItem(
          slot: Slot.values[rng.nextInt(Slot.values.length)],
          level: math.min(maxLevel, lv),
          rarity: rollRarity(rng, boss: true),
          sect: sect,
          rng: rng,
        )));
    if (rng.nextDouble() < 0.5) {
      drops.add(Drop(x + j(), y + 30, gem: Gem(Hanh.values[rng.nextInt(5)], dropTier(lv, boss: true))));
    }
    hero.addHerb(_herbTier, 2);
    fx.add(Fx('buddha', x, y, life: 0.6, radius: 90));
    _sfx('loot');
    events.add(GameEvent(EvKind.loot, text: 'Đào được rương báu: +$g lượng', color: 0xFFFFD34A));
  }

  // ------------------------------------------------------------ bí cảnh

  /// This run's bí cảnh (null outside one).
  RealmLayout? realm;

  /// Fog cells uncovered (row by row), and how many.
  late final List<bool> fog = List.filled(fogCols * fogRows, false);
  int fogOpen = 0;

  double get explored => fogOpen / fog.length;

  bool revealedAt(double x, double y) {
    final c = (x / fogCell).floor().clamp(0, fogCols - 1);
    final r = (y / fogCell).floor().clamp(0, fogRows - 1);
    return fog[r * fogCols + c];
  }

  final Set<RealmBuff> realmBuffs = {};
  int chestsOpened = 0, pillarsLit = 0, captivesFreed = 0;
  bool get lairOpen => pillarsLit >= realmPillars;

  double _fogCheck = 0;
  double _nagAt = 0;
  double _realmEndAt = -1;

  void _buildRealm(int seed) {
    final d = dungeon!;
    final lay = RealmLayout.generate(seed, kinds: map.mobs.length, force: debugRealmEvent);
    realm = lay;
    // No tree may stand on a chest or a shrine.
    scenery.props.removeWhere((pr) => lay.pois.any((o) =>
        _d2(o.x, o.y, pr.x, pr.y) < (o.kind == PoiKind.lair ? 200 * 200 : 90 * 90)));
    for (final c in lay.camps) {
      _camps.add(_Camp(c.x, c.y, mobById[map.mobs[c.kind]]!, d.level, c.count));
      for (var k = 0; k < c.count; k++) {
        _spawnInCamp(_camps.length - 1);
      }
    }
    // Each trận nhãn has its Hộ Trận Sứ, a tinh anh of the land.
    for (final p in lay.of(PoiKind.pillar)) {
      final def = mobById[map.mobs[rng.nextInt(map.mobs.length)]]!;
      final m = Mob(_uid++, def, d.level + 1, p.x + 80, p.y + 20)
        ..eliteKey = 'realm_guard'
        ..eliteName = 'Hộ Trận Sứ';
      m.maxHp *= 6;
      m.hp = m.maxHp;
      m.atk *= 1.4;
      p.guard = m.uid;
      mobs.add(m);
    }
    _plantHerbs();
    // Screenshot aids for the dev build.
    for (final p in lay.of(PoiKind.pillar).take(debugRealmLit)) {
      mobs.removeWhere((m) => m.uid == p.guard);
      p.done = true;
      pillarsLit++;
    }
    if (lairOpen) _openLair();
    if (debugRealmWin && boss != null) {
      boss!.hp = 0;
      _realmEndAt = 0.5;
    }
    if (debugRealmNear.isNotEmpty) {
      final o = lay.pois.firstWhere((o) => o.kind.name == debugRealmNear, orElse: () => lay.lair);
      player
        ..x = o.x - 150
        ..y = o.y + 40;
    }
    _reveal();
  }

  /// Dev build: start next to a place of this [PoiKind] name, with this
  /// many trận nhãn already lit.
  static String debugRealmNear = '';
  static int debugRealmLit = 0;
  static bool debugRealmWin = false;
  static RealmEvent? debugRealmEvent;

  void _updateRealm(double dt) {
    final d = dungeon!;
    if (_realmEndAt >= 0) {
      // The master is down: a moment to pick up the spoils.
      if (time >= _realmEndAt) _endRealm();
      return;
    }
    if (time > d.timeLimit) {
      finished = true;
      events.add(GameEvent(EvKind.failed, text: 'Hết giờ!'));
      return;
    }
    if (time >= _fogCheck) {
      _fogCheck = time + 0.2;
      _reveal();
    }
    _touchPois();
    _realmEvents();
    final b = boss;
    if (b != null && !b.alive) _realmEndAt = time + 2.5;
  }

  bool _eventsTold = false;
  bool _starsFell = false;
  bool _wandererCame = false;
  late final double _starAt = starfallFrom + rng.nextDouble() * (starfallTo - starfallFrom);

  /// Mật thất: whether the hero has read the door, and the levers pulled
  /// in the right order so far.
  bool vaultHintKnown = false;
  int vaultStep = 0;
  Poi? _onLever;

  bool hasEvent(RealmEvent e) => realm?.events.contains(e) ?? false;

  String get vaultHint => realm!.vaultOrder.map((i) => vaultSymbols[i]).join(' → ');

  void _realmEvents() {
    if (!_eventsTold && time > 3) {
      _eventsTold = true;
      events.add(GameEvent(EvKind.notice,
          text: 'Biến cố: ${realm!.events.map((e) => e.label).join(' · ')}', color: 0xFFB8F0E0, big: true));
    }
    if (hasEvent(RealmEvent.starfall) && !_starsFell && time >= _starAt && player.alive) {
      _starsFell = true;
      for (var i = 0; i < starfallChests; i++) {
        final a = rng.nextDouble() * math.pi * 2, r = 250 + rng.nextDouble() * 400;
        final x = (player.x + math.cos(a) * r).clamp(150.0, width - 150);
        final y = (player.y + math.sin(a) * r * 0.75).clamp(180.0, height - 150);
        realm!.pois.add(Poi(PoiKind.star, x, y));
        fx.add(Fx('buddha', x, y, life: 0.7, radius: 70));
      }
      _shake(5);
      events.add(GameEvent(EvKind.wave, text: 'Mưa sao băng! Nhặt rương sao quanh bạn', color: 0xFFFFE08A, big: true));
    }
    if (hasEvent(RealmEvent.wanderer) && !_wandererCame && time >= wandererAt && player.alive) {
      _wandererCame = true;
      final a = rng.nextDouble() * math.pi * 2;
      final x = (player.x + math.cos(a) * 900).clamp(150.0, width - 150);
      final y = (player.y + math.sin(a) * 700).clamp(180.0, height - 150);
      final def = mobById[map.mobs.last]!;
      final m = Mob(_uid++, def, dungeon!.level + 2, x, y)
        ..eliteKey = 'realm_hunter'
        ..eliteName = 'Ma Đầu Lang Bạt'
        ..state = MobState.chase;
      m.maxHp *= 9;
      m.hp = m.maxHp;
      m.atk *= 1.5;
      mobs.add(m);
      events.add(GameEvent(EvKind.boss, text: 'Ma Đầu Lang Bạt đang truy đuổi bạn!', color: 0xFFFF6A4A, big: true));
    }
  }

  /// A lever pulled: right in turn lights it, wrong locks them all again.
  void _pullLever(Poi o) {
    final order = realm!.vaultOrder;
    if (o.index == order[vaultStep]) {
      o.done = true;
      vaultStep++;
      fx.add(Fx('buddha', o.x, o.y, life: 0.5, radius: 70));
      _sfx('loot');
      if (vaultStep >= order.length) {
        _openVault();
      } else {
        events.add(GameEvent(EvKind.loot, text: 'Cơ quan ${vaultSymbols[o.index]} đã mở ($vaultStep/3)', color: 0xFF9FE8FF));
      }
      return;
    }
    vaultStep = 0;
    for (final l in realm!.of(PoiKind.lever)) {
      l.done = false;
    }
    _shake(4);
    events.add(GameEvent(EvKind.notice,
        text: vaultHintKnown ? 'Sai thứ tự! Cơ quan khóa lại ($vaultHint)' : 'Sai thứ tự! Hãy đọc bia khắc trên cửa mật thất',
        color: 0xFFFF8A7A));
  }

  void _openVault() {
    final v = realm!.of(PoiKind.vault).first;
    v.done = true;
    final lv = dungeon!.level;
    final g = (realmChestGold(lv) * 3 * hero.goldMul).round();
    hero.gold += g;
    double j() => (rng.nextDouble() - 0.5) * 120;
    for (var i = 0; i < 3; i++) {
      drops.add(Drop(v.x + j(), v.y + 50 + j() / 3,
          item: makeItem(
            slot: Slot.values[rng.nextInt(Slot.values.length)],
            level: math.min(maxLevel, lv),
            rarity: i == 0 ? Rarity.epic : rollRarity(rng, boss: true),
            sect: sect,
            rng: rng,
          )));
    }
    drops.add(Drop(v.x + j(), v.y + 50, gem: Gem(Hanh.values[rng.nextInt(5)], math.min(maxDropTier, dropTier(lv, boss: true) + 1))));
    fx.add(Fx('buddha', v.x, v.y, life: 1, radius: 200));
    _shake(6);
    events.add(GameEvent(EvKind.wave, text: 'Mật thất đã mở! +$g lượng', color: 0xFFFFD34A, big: true));
  }

  void _openStar(Poi o) {
    o.done = true;
    final lv = dungeon!.level;
    final g = (realmChestGold(lv) * 0.5 * hero.goldMul).round();
    hero.gold += g;
    if (rng.nextDouble() < 0.35) {
      drops.add(Drop(o.x, o.y + 30, gem: Gem(Hanh.values[rng.nextInt(5)], dropTier(lv))));
    } else {
      drops.add(Drop(o.x, o.y + 30, potion: rng.nextBool() ? 1 : 2));
    }
    fx.add(Fx('buddha', o.x, o.y, life: 0.5, radius: 60));
    _sfx('loot');
    events.add(GameEvent(EvKind.loot, text: 'Rương sao: +$g lượng', color: 0xFFFFE08A));
  }

  void _endRealm() {
    finished = true;
    finishTime = time;
    final stars = realmStarsFor(boss: true, chests: chestsOpened, explored: explored);
    rewardLines = hero.realmReward(dungeon!, stars, rng);
    events.add(GameEvent(EvKind.cleared, value: stars.toDouble()));
  }

  /// Lifts the fog around the hero.
  void _reveal() {
    final p = player;
    final c0 = ((p.x - realmSight) / fogCell).floor().clamp(0, fogCols - 1);
    final c1 = ((p.x + realmSight) / fogCell).floor().clamp(0, fogCols - 1);
    final r0 = ((p.y - realmSight) / fogCell).floor().clamp(0, fogRows - 1);
    final r1 = ((p.y + realmSight) / fogCell).floor().clamp(0, fogRows - 1);
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final i = r * fogCols + c;
        if (fog[i]) continue;
        if (_d2((c + 0.5) * fogCell, (r + 0.5) * fogCell, p.x, p.y) > realmSight * realmSight) continue;
        fog[i] = true;
        fogOpen++;
      }
    }
  }

  void _nag(String text) {
    if (time < _nagAt) return;
    _nagAt = time + 4;
    events.add(GameEvent(EvKind.notice, text: text, color: 0xFFFFD34A));
  }

  /// Chests, trận nhãn, shrines and captives work by walking up to them.
  void _touchPois() {
    final p = player;
    if (!p.alive) return;
    // A lever works on stepping onto it, not on standing there.
    final lever = realm!.of(PoiKind.lever).where((o) => _d2(o.x, o.y, p.x, p.y) <= 64 * 64).firstOrNull;
    if (lever != _onLever) {
      _onLever = lever;
      if (lever != null && !lever.done && vaultStep < 3) _pullLever(lever);
    }
    for (final o in List<Poi>.of(realm!.pois)) {
      if (o.done || o.kind == PoiKind.lair || o.kind == PoiKind.lever) continue;
      if (_d2(o.x, o.y, p.x, p.y) > 64 * 64) continue;
      switch (o.kind) {
        case PoiKind.merchant:
          o.done = true;
          _sfx('loot');
          events.add(GameEvent(EvKind.merchant, text: 'Thương nhân bí ẩn'));
        case PoiKind.vault:
          if (!vaultHintKnown) {
            vaultHintKnown = true;
            events.add(GameEvent(EvKind.notice, text: 'Bia khắc trên cửa: $vaultHint', color: 0xFF9FE8FF, big: true));
          } else {
            _nag('Mở cơ quan theo thứ tự: $vaultHint');
          }
        case PoiKind.star:
          _openStar(o);
        case PoiKind.lever:
          break;
        case PoiKind.chest:
          _openChest(o);
        case PoiKind.pillar:
          if (mobs.any((m) => m.uid == o.guard && m.alive)) {
            _nag('Hạ Hộ Trận Sứ trước đã');
            continue;
          }
          o.done = true;
          pillarsLit++;
          fx.add(Fx('buddha', o.x, o.y, life: 0.8, radius: 160));
          _sfx('loot');
          events.add(GameEvent(EvKind.wave,
              text: 'Trận nhãn $pillarsLit/$realmPillars đã sáng', color: 0xFF9FE8FF, big: true));
          if (lairOpen) _openLair();
        case PoiKind.shrine:
          o.done = true;
          final b = RealmBuff.values[o.index];
          realmBuffs.add(b);
          fx.add(Fx('buddha', o.x, o.y, life: 0.8, radius: 120));
          _sfx('loot');
          events.add(GameEvent(EvKind.notice, text: 'Bia cổ ban phúc: ${b.label}', color: 0xFF8CE07A, big: true));
        case PoiKind.captive:
          if (mobs.any((m) => m.alive && _d2(m.x, m.y, o.x, o.y) < 240 * 240)) {
            _nag('Quái còn canh giữ, hãy dẹp chúng trước');
            continue;
          }
          o.done = true;
          captivesFreed++;
          final (who, line) = realmCaptiveLines[o.index];
          _sfx('loot');
          events.add(GameEvent(EvKind.notice, text: '$who: “$line”', color: 0xFFF3E6C8, big: true));
          for (final l in hero.realmCaptiveFreed(dungeon!.level)) {
            events.add(GameEvent(EvKind.loot, text: l, color: 0xFFFFD34A));
          }
        case PoiKind.lair:
          break;
      }
    }
  }

  void _openChest(Poi o) {
    o.done = true;
    chestsOpened++;
    final lv = dungeon!.level;
    final g = hero.realmChestOpened(lv);
    double j() => (rng.nextDouble() - 0.5) * 80;
    drops.add(Drop(o.x + j(), o.y + 34 + j() / 2,
        item: makeItem(
          slot: Slot.values[rng.nextInt(Slot.values.length)],
          level: math.min(maxLevel, lv),
          rarity: rollRarity(rng, boss: true),
          sect: sect,
          rng: rng,
        )));
    if (rng.nextDouble() < 0.5) {
      drops.add(Drop(o.x + j(), o.y + 34 + j() / 2, gem: Gem(Hanh.values[rng.nextInt(5)], dropTier(lv, boss: true))));
    }
    if (rng.nextDouble() < 0.3) drops.add(Drop(o.x + j(), o.y + 34 + j() / 2, potion: rng.nextBool() ? 1 : 2));
    hero.addHerb(_herbTier, 2);
    fx.add(Fx('buddha', o.x, o.y, life: 0.6, radius: 90));
    _sfx('loot');
    events.add(GameEvent(EvKind.loot,
        text: 'Rương báu $chestsOpened/$realmChests: +${g.toString()} lượng, +2 ${herbNames[_herbTier]}',
        color: 0xFFFFD34A));
  }

  /// All three trận nhãn lit: the seal breaks and the master comes out.
  void _openLair() {
    final l = realm!.lair;
    l.done = true;
    final def = mobById[map.boss]!;
    final m = Mob(_uid++, def, dungeon!.level + 2, l.x, l.y);
    m.maxHp *= 1.6;
    m.hp = m.maxHp;
    boss = m;
    mobs.add(m);
    fx.add(Fx('buddha', l.x, l.y, life: 1, radius: 260));
    _shake(8);
    events.add(GameEvent(EvKind.boss,
        text: 'Phong ấn đã phá! ${def.name} hiện thân ở phía đông', color: 0xFFFF6A4A, big: true));
  }

  /// Where the autopilot heads between fights: the nearest place of
  /// interest in sight, else the master once out, else the nearest fog.
  (double, double)? _realmWaypoint() {
    final p = player;
    (double, double)? best;
    var bd = double.infinity;
    final lay = realm!;
    for (final o in lay.pois) {
      if (o.done || o.kind == PoiKind.lair || !revealedAt(o.x, o.y)) continue;
      // The door first, to read the order; then the levers, in it.
      if (o.kind == PoiKind.vault && vaultHintKnown) continue;
      if (o.kind == PoiKind.lever && (!vaultHintKnown || o.index != lay.vaultOrder[vaultStep])) continue;
      final d = _d2(o.x, o.y, p.x, p.y);
      if (d < bd) {
        bd = d;
        best = (o.x, o.y);
      }
    }
    if (best != null) return best;
    final b = boss;
    if (b != null && b.alive) return (b.x, b.y);
    for (var i = 0; i < fog.length; i++) {
      if (fog[i]) continue;
      final x = (i % fogCols + 0.5) * fogCell, y = (i ~/ fogCols + 0.5) * fogCell;
      final d = _d2(x, y, p.x, p.y);
      if (d < bd) {
        bd = d;
        best = (x.clamp(80.0, width - 80), y.clamp(100.0, height - 80));
      }
    }
    return best;
  }

  // ------------------------------------------------------------ loop

  /// Screenshot aid for the dev build: fire the tuyệt kỹ whenever it is
  /// ready and a monster is close.
  static bool debugUltimate = false;

  double _dayCheck = 0;

  void update(double dt) {
    if (finished) return;
    time += dt;
    if (debugUltimate && sect.skills.length > 6 && ready(6) && _countNear(240) > 0) input.skills.add(6);
    hero.playSeconds += dt;
    // Mệt mỏi: the date is checked now and then, not every frame.
    if (time >= _dayCheck) {
      _dayCheck = time + 30;
      hero.fatigueRoll(vnDayKey());
      final wasNight = night;
      _sky();
      if (night != wasNight) {
        events.add(GameEvent(EvKind.notice,
            text: night ? 'Màn đêm buông xuống: Dạ Yêu bắt đầu xuất hiện' : 'Trời đã sáng',
            color: 0xFFB8C8F0, big: true));
      }
    }
    hero.tickFatigue(dt);
    if (hero.tickBuffs(dt)) player.maxHp = st.maxHp;
    if (mode == WorldMode.dungeon) _updateDungeon(dt);
    if (mode == WorldMode.field) {
      _updateField();
      _updateDig();
    }
    if (mode == WorldMode.field || realm != null) _updateHerbs();
    if (player.alive) {
      _updatePlayer(dt);
    }
    for (final m in mobs) {
      _updateMob(m, dt);
    }
    _updateProjs(dt);
    _updateZones(dt);
    _updateDrops(dt);
    _updatePet(dt);
    _updateCompanion(dt);
    _tickDots(player, dt, null);
    // Monsters and zones born mid-loop (a boss's adds, a body bursting).
    mobs.addAll(_newMobs);
    _newMobs.clear();
    zones.addAll(_newZones);
    _newZones.clear();
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

  double _eliteCheck = 0;
  final Map<String, double> _eliteAgain = {};

  /// Puts each tinh anh a quest or bounty wants on the map, at a camp away
  /// from the hero; a killed one that is still wanted returns after a while.
  void _spawnElites() {
    for (final w in hero.wantedElites(map.id)) {
      if (time < (_eliteAgain[w.key] ?? 0)) continue;
      if (mobs.any((m) => m.eliteKey == w.key && m.alive)) continue;
      final far = _camps.where((c) => _d2(c.x, c.y, player.x, player.y) > 500 * 500).toList();
      final c = far.isEmpty ? _camps[rng.nextInt(_camps.length)] : far[rng.nextInt(far.length)];
      final m = Mob(_uid++, mobById[w.mob]!, w.level, c.x + 50, c.y)
        ..eliteKey = w.key
        ..eliteName = w.name;
      m.maxHp *= w.hpMul;
      m.hp = m.maxHp;
      m.atk *= w.atkMul;
      mobs.add(m);
      events.add(GameEvent(EvKind.boss, text: 'Tinh anh ${w.name} xuất hiện!', color: 0xFFFFD34A, big: true));
    }
  }

  void _updateField() {
    if (time >= _eliteCheck) {
      _eliteCheck = time + 1;
      _spawnElites();
    }
    // Elites and an ambush do not respawn: clear them once they have faded.
    mobs.removeWhere((m) => (m.elite || (m.camp < 0 && m != boss)) && !m.alive && m.hurt <= 0);
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
    if (d.isRealm) {
      _updateRealm(dt);
      return;
    }
    if (d.isWorldBoss && time > d.timeLimit) {
      _endWorldBoss();
      return;
    }
    if (d.isArena && time > d.timeLimit) {
      _endArena(false);
      return;
    }
    if (time > d.timeLimit && !finished) {
      finished = true;
      events.add(GameEvent(EvKind.failed, text: 'Hết giờ!'));
      return;
    }
    _trickle(dt);
    final aliveCount = mobs.where((m) => m.alive).length + _pending;
    if (aliveCount == 0) {
      if (bossWave) {
        if (d.isArena) {
          _endArena(true);
          return;
        }
        if (!finished) {
          finished = true;
          finishTime = time;
          if (d.isTower) {
            rewardLines = hero.towerReward(d.floor, rng);
            events.add(GameEvent(EvKind.cleared, value: 3));
            return;
          }
          final stars = d.starsFor(time);
          if (d.isNightmare) {
            rewardLines = hero.nightmareReward(d, stars, rng);
            events.add(GameEvent(EvKind.cleared, value: stars.toDouble()));
            return;
          }
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
    for (var i = 0; i < p.cd.length; i++) {
      if (p.cd[i] > 0) p.cd[i] -= dt;
    }
    if (p.basicCd > 0) p.basicCd -= dt;
    if (p.potCd > 0) p.potCd -= dt;
    if (p.attackAnim > 0) p.attackAnim = math.max(0, p.attackAnim - dt * 3);
    if (p.hurt > 0) p.hurt -= dt;
    // Regen, faster out of combat.
    final calm = time - p.lastHurt > 5;
    p.hp = math.min(p.maxHp,
        p.hp + st.hpRegen * (calm ? 4 : 1) * dt + _hot(dt) +
            (realmBuffs.contains(RealmBuff.vigor) ? p.maxHp * 0.02 * dt : 0));
    p.mp = math.min(st.maxMp, p.mp + st.mpRegen * (calm ? 2 : 1) * dt);
    if (time > p.shieldUntil) p.shield = 0;

    if (p.dashT > 0) {
      _stepDash(dt);
      return;
    }
    if (time < p.stunUntil) return;

    final c = input;
    final manual = c.moveX.abs() + c.moveY.abs() > 0.05;
    if (manual) {
      manualUntil = time + 1.2;
      engaged = false;
    }
    final autoOn = auto && !manual && time >= manualUntil;
    if (autoOn) _autopilot();
    // Tân thủ hộ thể: a new hero drinks by themselves when nearly down.
    if (!autoOn && hero.level < newbieShieldLevel && hero.rebirths == 0 && p.hp < p.maxHp * newbieAutoPotion) {
      c.hpPot = true;
    }

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
    final fight = c.attack || engaged;
    if (!manual && !kiting && (fight || autoOn)) {
      final t = _pickTarget(
          sect.basic == BasicKind.melee ? 260 : sect.basicRange + 60);
      if (t == null) engaged = false;
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
          _basicAttack(t);
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
      final sp = st.move * math.min(1, len) * _slowMul(p) * (realmBuffs.contains(RealmBuff.swift) ? 1.3 : 1);
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
    if (hasPond) _pondBank(p);
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
    _goldBurst(t);
    _divineStrike(t);
  }

  double _burstReady = 0;
  double _divineReady = 0;

  /// Thần binh from level 5: now and then a basic attack calls down Thần
  /// Binh Giáng Thế, the hero's phase burst, on the target.
  void _divineStrike(Mob? t) {
    final lv = hero.divine;
    if (lv < divineStrikeLevel || t == null || !t.alive || time < _divineReady) return;
    if (rng.nextDouble() >= divineStrikeChance) return;
    _divineReady = time + divineStrikeCd;
    final look = goldSets.firstWhere((s) => s.hanh == hero.hanh, orElse: () => goldSets.first);
    zones.add(Zone(
      fromHero: true,
      x: t.x,
      y: t.y,
      r: divineStrikeRadius,
      delay: 0.15,
      ticks: 1,
      interval: 0,
      power: divineStrikePower(lv),
      fx: look.burstFx,
      hanh: hero.hanh,
    ));
    _text(t.x, t.y - 120, 'Thần Binh Giáng Thế', divineColor(lv));
  }

  /// A full Hoàng Kim set: now and then a basic attack sets off the set's
  /// phase burst around the target.
  void _goldBurst(Mob? t) {
    if (t == null || !t.alive || time < _burstReady) return;
    final set = fullGoldSet(goldPieces(hero.equip.values));
    if (set == null || rng.nextDouble() >= goldBurstChance) return;
    _burstReady = time + goldBurstCd;
    zones.add(Zone(
      fromHero: true,
      x: t.x,
      y: t.y,
      r: goldBurstRadius,
      delay: 0.15,
      ticks: 1,
      interval: 0,
      power: goldBurstPower,
      fx: set.burstFx,
      hanh: set.hanh,
    ));
    _text(t.x, t.y - 96, set.burst, goldItemColor);
  }

  bool _inArc(Mob m, double ang, double range, double spread) =>
      _inArcFrom(player.x, player.y, m, ang, range, spread);

  bool _inArcFrom(double ox, double oy, Mob m, double ang, double range, double spread) {
    final dx = m.x - ox, dy = m.y - oy;
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
    final s = skills[i];
    return !s.isPassive &&
        hero.skillLv[i] > 0 &&
        player.cd[i] <= 0 &&
        player.mp >= s.mpAt(hero.skillLv[i]);
  }

  void _cast(int i) {
    if (!ready(i) || !player.alive) return;
    final s = skills[i];
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
        fx.add(Fx(s.fx, p.x, p.y, life: s.ultimate ? 1.0 : 0.55, radius: s.radius));
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
              pierce: s.pierce,
              status: s.status,
              statusPower: s.statusPower,
              statusTime: s.statusTime,
              skill: true);
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
            statusPower: s.statusPower,
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
      if (dungeon?.isArena ?? false) {
        if (arenaPotsUsed >= arenaPotions) return;
        arenaPotsUsed++;
      }
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

    _wanted = hero.wantedMobs();
    final near = _autoTarget();
    if (near != null) target = near;
    var count = 0;
    for (final m in mobs) {
      if (m.alive && _d2(m.x, m.y, p.x, p.y) < 200 * 200) count++;
    }

    // Skills, biggest first; the tuyệt kỹ waits for a crowd or a boss.
    for (final i in const [6, 4, 2, 1, 0]) {
      if (i >= skills.length || !ready(i)) continue;
      final s = skills[i];
      if (s.ultimate && _countNear(260) < 3 && !(near?.def.boss ?? false)) continue;
      final use = switch (s.kind) {
        SkillKind.guard || SkillKind.shield =>
          count >= 2 || p.hp < p.maxHp * 0.75,
        SkillKind.heal => p.hp < p.maxHp * 0.6,
        SkillKind.nova || SkillKind.aura => _countNear(s.radius) >=
            (i >= 4 && !(near?.def.boss ?? false) ? 2 : 1),
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
    // Linh thảo grown back nearby, between fights.
    HerbNode? herb;
    var hd = 500.0 * 500;
    for (final n in herbs) {
      if (time < n.readyAt) continue;
      final dd = _d2(n.x, n.y, p.x, p.y);
      if (dd < hd) {
        hd = dd;
        herb = n;
      }
    }
    if (herb != null) {
      _walkTo(herb.x, herb.y);
      return;
    }
    // A Tàng Bảo Đồ spot to dig.
    final dig = digSpot;
    if (dig != null) {
      _walkTo(dig.x, dig.y);
      return;
    }
    // In a bí cảnh: on to the next find, or into the fog.
    if (realm != null) {
      final wp = _realmWaypoint();
      if (wp != null) {
        _walkTo(wp.$1, wp.$2);
        return;
      }
    }
    // Head for the nearest living monster, quest targets preferred.
    Mob? best;
    var bd = double.infinity;
    for (final m in mobs) {
      if (!m.alive || _avoid(m)) continue;
      var d = _d2(m.x, m.y, p.x, p.y);
      if (_isWanted(m)) d *= 0.02;
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
      !_wanted.contains(m.def.id) &&
      hero.level < map.maxLv;

  /// Monster ids the story quest and bounties want, refreshed each
  /// autopilot step.
  Set<String> _wanted = const {};

  bool _isWanted(Mob m) => m.elite || _wanted.contains(m.def.id);

  /// Nearest worthwhile monster within reach of a fight; ones already
  /// hitting the hero count as closer.
  Mob? _autoTarget() {
    final p = player;
    if (target != null && target!.alive &&
        _d2(target!.x, target!.y, p.x, p.y) < 500 * 500) {
      return target;
    }
    // While a quest's or bounty's monsters live on this map, only they and
    // whatever is already attacking count: the autopilot does the quest.
    final hunt = mobs.any((m) => m.alive && _isWanted(m));
    Mob? best;
    var bd = 600.0 * 600;
    for (final m in mobs) {
      if (!m.alive || _avoid(m)) continue;
      if (hunt && !_isWanted(m) && m.state != MobState.chase) continue;
      var d = _d2(m.x, m.y, p.x, p.y);
      if (m.state == MobState.chase) d *= 0.5;
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
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

  int _countNear(double r) => _countNearAt(player.x, player.y, r);

  int _countNearAt(double x, double y, double r) {
    var n = 0;
    for (final m in mobs) {
      if (m.alive && _d2(m.x, m.y, x, y) < _sq(r + m.radius - 10)) n++;
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
      double knock = 0,
      Hanh? as}) {
    if (!m.alive) return;
    var dmg = st.atk * mult * (skill ? 1 + st.skillDmg : 1);
    if (realmBuffs.contains(RealmBuff.power)) dmg *= 1.25;
    dmg *= hanhFactor(as ?? hero.hanh, m.def.hanh);
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
    if (m.rival != null && time < m.guardUntil) dmg *= 1 - m.guardPct;
    m.hp -= dmg;
    if (m == boss && (dungeon?.isWorldBoss ?? false)) bossDamage += dmg;
    if (m == boss && m.hp > 0 && affix != null) _nightmareSummon(m);
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
    _sfx(m.big ? 'bossDie' : 'die');
    // A beaten challenger pays through the duel result only.
    if (m.rival != null) {
      _shake(10);
      return;
    }
    final xp = mobExpAt(m.level) *
        m.def.exp *
        (m.elite ? 12 : 1) *
        (m.nightborn ? nightMobExp : 1) *
        expLevelFactor(hero.level, m.level) *
        hero.expMul *
        // Tougher monsters of a field like Cửu U Ma Vực pay somewhat more.
        (dungeon == null ? math.sqrt(map.mul) : 1);
    _text(m.x, m.y - 70, '+${xp.round()} EXP', 0xFFB8E0FF, small: true);
    hero.onKill(m.def, rng);
    if (m.elite) {
      hero.onEliteKill(m.eliteKey!, rng);
      _eliteAgain[m.eliteKey!] = time + 20;
    }
    // Bí cảnh's ma đầu lang bạt: an Epic piece and a better gem on top.
    if (m.eliteKey == 'realm_hunter') {
      drops.add(Drop(m.x + 30, m.y,
          item: makeItem(
            slot: Slot.values[rng.nextInt(Slot.values.length)],
            level: math.min(maxLevel, m.level),
            rarity: Rarity.epic,
            sect: sect,
            rng: rng,
          )));
      drops.add(Drop(m.x - 30, m.y, gem: Gem(m.def.hanh, math.min(maxDropTier, dropTier(m.level, boss: true) + 1))));
      events.add(GameEvent(EvKind.wave, text: 'Đã hạ Ma Đầu Lang Bạt!', color: 0xFFFFD34A, big: true));
    }
    hero.gainExp(xp);
    if (m.def.boss) {
      final tamed = hero.rollPet(m.def.id, rng);
      if (tamed != null) {
        events.add(GameEvent(EvKind.notice,
            text: 'Thu phục linh thú: ${tamed.name}!', color: 0xFFFFD34A, big: true));
        if (pet == null) _spawnPet();
      }
    }
    if (m.big && m.level >= bossShardLevel && dungeon?.isTower != true && rng.nextDouble() < bossShardChance) {
      hero.goldShards++;
      events.add(GameEvent(EvKind.loot, text: 'Nhặt được 1 Mảnh Hoàng Kim', color: goldItemColor));
    }
    // Cửu U Ma Vực: Thần Thiết from any kill now and then, the boss's always.
    if (dungeon == null && map.rebirths > 0) {
      final iron = m.def.boss ? abyssBossIron : (rng.nextDouble() < abyssIronChance ? 1 : 0);
      if (iron > 0) {
        hero.divineIron += iron;
        events.add(GameEvent(EvKind.loot, text: 'Nhặt được $iron Thần Thiết', color: 0xFF9FD8FF));
      }
      if (m.def.boss) hero.unlockCostumes();
    }
    if (m.big && hero.manualOpen && dungeon?.isTower != true &&
        rng.nextDouble() < (m.def.boss ? bossPageChance : elitePageChance)) {
      events.add(GameEvent(EvKind.loot, text: 'Nhặt được ${hero.gainManualPage(rng)}', color: 0xFFC88CFF));
    }
    // Ma khí Bạo liệt: the body bursts a moment later.
    if (affix == NmAffix.volatile && m != boss) {
      _newZones.add(Zone(
        fromHero: false,
        x: m.x,
        y: m.y,
        r: 85,
        delay: 1.0,
        ticks: 1,
        interval: 0,
        power: m.atk * 1.2,
        fx: 'bossSlam_${m.def.hanh.name}',
      ));
    }
    if (mode == WorldMode.field) {
      if (hero.rollTreasureMap(vnDayKey(), m.big, rng)) {
        events.add(GameEvent(EvKind.loot, text: 'Nhặt được Tàng Bảo Đồ (${hero.tbdMaps})', color: 0xFFFFD34A));
      }
      if (m.eliteKey == 'tbd_guard') {
        _tbdChest(m.x, m.y, m.level);
        drops.add(Drop(m.x - 30, m.y, gem: Gem(m.def.hanh, math.min(maxDropTier, dropTier(m.level, boss: true) + 1))));
      }
      if (m == boss) {
        bossRespawnAt = time + 150;
      } else if (!m.elite && m.camp >= 0) {
        m.respawnAt = time + 9 + rng.nextDouble() * 6;
      }
    }
    _rollDrops(m);
    if (m.big) _shake(10);
  }

  void _rollDrops(Mob m) {
    double jx() => (rng.nextDouble() - 0.5) * 60;
    final goldChance = m.big || m.nightborn ? 1.0 : 0.5;
    if (rng.nextDouble() < goldChance) {
      final g = ((1 + m.level * 0.4) *
              (0.7 + rng.nextDouble() * 0.6) *
              (m.big ? 15 : 1) *
              (m.nightborn ? nightMobGold : 1) *
              hero.goldMul)
          .round();
      drops.add(Drop(m.x + jx(), m.y + jx(), gold: g));
    }
    final items = m.big ? 2 : (rng.nextDouble() < 0.075 ? 1 : 0);
    for (var i = 0; i < items; i++) {
      final it = makeItem(
        slot: Slot.values[rng.nextInt(Slot.values.length)],
        level: math.min(maxLevel, m.level),
        rarity: rollRarity(rng, boss: m.big),
        sect: sect,
        rng: rng,
      );
      drops.add(Drop(m.x + jx(), m.y + jx(), item: it));
    }
    if (rng.nextDouble() < 0.04) {
      drops.add(Drop(m.x + jx(), m.y + jx(), potion: rng.nextBool() ? 1 : 2));
    }
    // Herbs of the region go straight to the bag.
    if (dungeon?.isTower != true && (m.big || rng.nextDouble() < herbDropChance)) {
      final tier = _herbTier;
      final n = m.big ? 2 : 1;
      hero.addHerb(tier, n);
      _text(m.x, m.y - 90, '+$n ${herbNames[tier]}', herbColors[tier], small: true);
    }
    // Gems take the monster's phase; bosses always drop one, a tier up.
    if (m.big || m.nightborn || rng.nextDouble() < gemDropChance * EventBoost(vnDayKey()).gems) {
      drops.add(Drop(m.x + jx(), m.y + jx(),
          gem: Gem(m.def.hanh, dropTier(m.level, boss: m.big))));
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
      if (dungeon?.isWorldBoss ?? false) {
        // A knock-out just ends the run early; the damage still counts.
        _endWorldBoss();
      } else if (dungeon?.isArena ?? false) {
        _endArena(false);
      } else if (mode == WorldMode.dungeon && dungeonRevived) {
        finished = true;
        events.add(GameEvent(EvKind.failed, text: 'Trọng thương!'));
      } else {
        // The screen offers a revive (an ad in dungeons) or a way out.
        hero.deaths++;
        events.add(GameEvent(EvKind.heroDied));
      }
    }
  }

  /// A dungeon run may be revived once.
  bool dungeonRevived = false;

  /// Back up where the hero fell, at full strength, with a moment of
  /// safety: monsters close by are knocked away and dazed.
  void reviveHere() {
    final p = player;
    p.hp = p.maxHp;
    p.mp = st.maxMp;
    p.dots.clear();
    p.stunUntil = 0;
    if (mode == WorldMode.dungeon) dungeonRevived = true;
    for (final m in mobs) {
      if (!m.alive) continue;
      final d = _dist(m.x, m.y, p.x, p.y);
      if (d < 260) {
        m.stunUntil = time + 2;
        if (!m.def.boss && d > 1) {
          m.kx = (m.x - p.x) / d * 500;
          m.ky = (m.y - p.y) / d * 500;
        }
      }
    }
    fx.add(Fx('buddha', p.x, p.y, life: 0.8, radius: 260));
    _text(p.x, p.y - 70, 'Hồi sinh!', 0xFFFFD34A, big: true);
  }

  /// Leaving a dungeon after falling: the run counts as failed.
  void giveUp() {
    if (finished) return;
    finished = true;
    events.add(GameEvent(EvKind.failed, text: 'Trọng thương!'));
  }

  /// Field death: back on your feet at the map entrance, EXP docked.
  void revive() {
    final p = player;
    // A new hero loses nothing for a fall.
    if (hero.level >= newbieShieldLevel || hero.rebirths > 0) {
      final loss = (hero.expNeeded * 0.03).round();
      hero.exp = math.max(0, hero.exp - loss);
    }
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
            ((mode == WorldMode.field || realm != null) && home > 650 && dp > 200 && m.eliteKey != 'realm_hunter')) {
          m.state = MobState.leash;
          break;
        }
        if (m.rival != null) {
          _rivalSkills(m);
        } else if (m.def.boss) {
          _bossSkill(m, dt);
        }
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
              status: affix == NmAffix.chill ? Status.slow : Status.none,
              statusPower: 0.3,
              statusTime: 2.5,
            ));
          } else {
            _hurtHero(m.atk, m.def.hanh);
            if (affix == NmAffix.chill) _statusHero(Status.slow, 0.3, 2.5);
          }
        }
    }
  }

  /// Slows or stuns the hero from a monster's skill hit (lighter than on
  /// monsters, so a hero is never locked down).
  void _statusHero(Status s, double power, double t) {
    final p = player;
    switch (s) {
      case Status.slow:
        p.slowUntil = time + t * 0.6;
        p.slowPct = math.min(0.5, power);
      case Status.stun:
        p.stunUntil = time + math.min(0.8, t * 0.4);
      case Status.none || Status.poison || Status.burn:
        break;
    }
  }

  /// A Lôi đài challenger fights with their sect's own skills: attacks in
  /// reach, a heal or guard when hurt, and the tuyệt kỹ once below 60% HP.
  /// Ground skills show a red circle first so they can be dodged.
  void _rivalSkills(Mob m) {
    final r = m.rival!;
    final skills = sectOf(r.hanh).skills;
    if (m.rivalCd.isEmpty) m.rivalCd = List.filled(skills.length, 0);
    if (time < m.rivalNext || !player.alive) return;
    final p = player;
    final d = _dist(m.x, m.y, p.x, p.y);
    final hurt = m.hp / m.maxHp;
    final ready = <int>[];
    for (var i = 0; i < skills.length; i++) {
      final s = skills[i];
      if (time < m.rivalCd[i] || (r.level < s.unlock && r.rebirths == 0)) continue;
      final reach = math.max(s.range, s.radius) + heroRadius + 30;
      final ok = switch (s.kind) {
        SkillKind.passive => false,
        SkillKind.heal => hurt < 0.5,
        SkillKind.guard || SkillKind.shield => hurt < 0.85,
        _ => d < reach && (!s.ultimate || hurt < 0.6),
      };
      if (ok) ready.add(i);
    }
    if (ready.isEmpty) return;
    // The tuyệt kỹ first, then whatever else is up.
    final i = ready.firstWhere((k) => skills[k].ultimate, orElse: () => ready[rng.nextInt(ready.length)]);
    final s = skills[i];
    final lv = ((r.level - s.unlock) ~/ 6 + 1).clamp(1, maxSkillLevel);
    final pw = s.powerAt(lv);
    final dmg = m.atk * pw * arenaRivalSkillMul;
    m.rivalCd[i] = time + s.cooldown * arenaRivalSkillCd;
    m.rivalNext = time + 1.2 + rng.nextDouble() * 0.8;
    m.attackAnim = 1;
    if (p.x != m.x) m.face = (p.x - m.x).sign;
    final ang = math.atan2(p.y - m.y, p.x - m.x);
    _sfx(s.fx);
    if (s.ultimate) {
      events.add(GameEvent(EvKind.boss, text: '${r.name}: ${s.name}!', color: 0xFFFF6A4A, big: true));
    }
    void zone(double x, double y, double delay) {
      final ticks = math.max(1, s.ticks);
      final interval = ticks > 1 ? s.duration / ticks : 0.0;
      zones.add(Zone(fromHero: false, x: x, y: y, r: s.radius, delay: delay, ticks: ticks,
          interval: interval, power: dmg, fx: 'rival_${r.hanh.name}',
          status: s.status, statusPower: s.statusPower, statusTime: s.statusTime));
      zones.add(Zone(fromHero: true, x: x, y: y, r: s.radius, delay: delay, ticks: ticks,
          interval: interval, power: 0, fx: s.fx, visualOnly: true));
    }

    switch (s.kind) {
      case SkillKind.arc:
        fx.add(Fx(s.fx, m.x, m.y, life: 0.3, angle: ang, radius: s.range, spread: s.spread));
        if (d < s.range + heroRadius) _hitHeroBySkill(dmg, r, s);
      case SkillKind.nova || SkillKind.aura:
        final hits = s.kind == SkillKind.aura ? math.min(4, s.ticks) * 0.5 : 1.0;
        fx.add(Fx(s.fx, m.x, m.y, life: s.ultimate ? 1.0 : 0.55, radius: s.radius));
        if (d < s.radius + heroRadius) _hitHeroBySkill(dmg * hits, r, s);
      case SkillKind.projectile || SkillKind.radial:
        final n = math.max(1, s.count);
        for (var k = 0; k < n; k++) {
          final a = s.kind == SkillKind.radial
              ? ang + math.pi * 2 * k / n
              : (n == 1 ? ang : ang - s.spread / 2 + s.spread * k / (n - 1));
          projs.add(Proj(
            fromHero: false,
            x: m.x,
            y: m.y - 30,
            vx: math.cos(a) * 520,
            vy: math.sin(a) * 520,
            maxDist: s.range + 60,
            radius: s.radius > 0 ? s.radius : 16,
            fx: s.fx,
            power: dmg,
            status: s.status,
            statusPower: s.statusPower,
            statusTime: s.statusTime,
            hanh: r.hanh,
          ));
        }
      case SkillKind.ground:
        zone(p.x, p.y, math.max(0.75, s.delay));
      case SkillKind.line:
        final n = math.max(1, s.count);
        for (var k = 0; k < n; k++) {
          final dd = s.range * (k + 1) / n;
          zone(m.x + math.cos(ang) * dd, m.y + math.sin(ang) * dd, 0.6 + k * 0.07);
        }
      case SkillKind.dash:
        final go = math.max(0.0, math.min(s.range, d - m.radius - heroRadius));
        fx.add(Fx(s.fx, m.x, m.y, life: 0.45, angle: ang, radius: go,
            x2: m.x + math.cos(ang) * go, y2: m.y + math.sin(ang) * go));
        m.x += math.cos(ang) * go;
        m.y += math.sin(ang) * go;
        _clamp(m);
        if (d <= s.range + heroRadius + m.radius) _hitHeroBySkill(dmg, r, s);
      case SkillKind.heal:
        final amount = m.maxHp * pw * 0.5;
        m.hp = math.min(m.maxHp, m.hp + amount);
        _text(m.x, m.y - 80, '+${amount.round()}', 0xFF7CF08A, big: true);
        fx.add(Fx(s.fx, m.x, m.y, life: 1.0));
      case SkillKind.guard || SkillKind.shield:
        m.guardUntil = time + s.duration;
        m.guardPct = s.kind == SkillKind.guard ? math.min(0.5, pw) : 0.35;
        fx.add(Fx(s.fx, m.x, m.y, life: math.min(2.0, s.duration)));
      case SkillKind.passive:
        break;
    }
  }

  void _hitHeroBySkill(double dmg, ArenaRival r, SkillDef s) {
    _hurtHero(dmg, r.hanh);
    _statusHero(s.status, s.statusPower, s.statusTime);
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
    speed *= m.speedMul;
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
                knock: pr.knock,
                as: pr.hanh);
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
        _hurtHero(pr.power, pr.hanh ?? _hanhOfFx(pr.fx));
        _statusHero(pr.status, pr.statusPower, pr.statusTime);
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
      if (z.visualOnly || z.ticks <= 0 || z.t < z.delay) continue;
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
                knock: z.knock,
                as: z.hanh);
          }
        }
      } else {
        _shake(6);
        if (_d2(player.x, player.y, z.x, z.y) < _sq(z.r + heroRadius)) {
          _hurtHero(z.power, _hanhOfFx(z.fx));
          _statusHero(z.status, z.statusPower, z.statusTime);
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
    final gem = d.gem;
    if (gem != null) {
      hero.addGem(gem);
      events.add(GameEvent(EvKind.loot,
          text: 'Nhặt được ${gem.name}', color: gem.hanh.color));
      _sfx('loot');
    }
    final it = d.item;
    if (it != null) {
      final kept = hero.addItem(it);
      events.add(GameEvent(EvKind.loot,
          text: kept
              ? 'Nhặt được ${it.name} [${it.rarityLabel}]'
              : 'Đã bán ${it.name} (+${it.sellPrice} lượng)',
          color: it.color));
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
