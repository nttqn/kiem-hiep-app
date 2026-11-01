import 'dart:math' as math;

import 'arena.dart';
import 'content.dart';
import 'hanh.dart';
import 'hero.dart';

/// Tỷ võ: two players' heroes fighting live (trial build). The room's host
/// runs the fight; the guest sends what they press and draws what the host
/// sends back. Real stats, no potions, no pets or companions, damage cut so
/// a fight lasts, no rewards yet.

/// Seconds a fight lasts; at the end the larger share of HP left wins.
const double duelTime = 120;

/// Skills are tuned to clear packs of monsters: one tuyệt kỹ can deal many
/// times a hero's whole HP. So in a duel all damage between the two is
/// divided by one shared factor, picked so an even fight lasts about
/// [duelTargetTtk] seconds of steady hitting; HP stays as the player built
/// it and the stronger side keeps its edge...
const double duelTargetTtk = 45;

/// ...no one loses more than this share of their HP in any one second...
const double duelBurstCap = 0.12;

/// ...and nothing lands before the countdown ends.
const double duelCountdown = 3;

/// Damage a second of one side on the other, roughly: basic hits with
/// crits, attack speed and some skill on top, after the target's defence
/// (as mitigation(def, attacker level) gives it).
double duelDps({
  required double atk,
  required double crit,
  required double critDmg,
  required double aspd,
  required double skillDmg,
  required double targetMitigation,
}) =>
    atk * (1 + crit * (critDmg - 1)) * aspd / 0.75 * (1 + skillDmg) * 2 * (1 - targetMitigation);

/// Keeps one side's damage taken under [duelBurstCap] of their HP a second.
class DuelBurst {
  double _from = -99, _sum = 0;

  double cap(double dmg, double maxHp, double now) {
    if (now - _from >= 1) {
      _from = now;
      _sum = 0;
    }
    final d = math.min(dmg, math.max(0.0, duelBurstCap * maxHp - _sum));
    _sum += d;
    return d;
  }
}

/// The shared damage divisor for a pair: never below 1.
double duelDamageFactor({required double hpA, required double hpB, required double dpsA, required double dpsB}) {
  // dpsA is A hitting B.
  final ttk = (hpB / math.max(1, dpsA) + hpA / math.max(1, dpsB)) / 2;
  return math.max(1, duelTargetTtk / math.max(0.1, ttk));
}

/// Messages a second each way.
const int duelSendHz = 12;

/// Silence this long from the other side ends the fight unplayed.
const double duelTimeout = 8;

/// Heroes below this level cannot duel yet.
const int duelOpenLevel = 10;

/// A hero as the other side needs it: looks, stats, skill levels.
class DuelInfo {
  const DuelInfo({
    required this.uid,
    required this.name,
    required this.hanh,
    required this.level,
    required this.rebirths,
    required this.power,
    required this.hp,
    required this.atk,
    required this.def,
    required this.crit,
    required this.critDmg,
    required this.aspd,
    required this.skillDmg,
    required this.move,
    required this.skillLv,
    this.female = false,
    this.title = '',
  });

  final String uid, name, title;
  final Hanh hanh;
  final int level, rebirths, power;
  final double hp, atk, def, crit, critDmg, aspd, skillDmg, move;
  final List<int> skillLv;
  final bool female;

  factory DuelInfo.of(HeroData h, String uid) {
    h.recompute();
    final s = h.stats;
    return DuelInfo(
      uid: uid,
      name: h.name,
      hanh: h.hanh,
      level: h.level,
      rebirths: h.rebirths,
      power: h.power,
      hp: s.maxHp,
      atk: s.atk,
      def: s.def,
      crit: s.crit,
      critDmg: s.critDmg,
      aspd: s.aspd,
      skillDmg: s.skillDmg,
      move: s.move,
      skillLv: List.of(h.skillLv),
      female: h.female,
      title: h.title,
    );
  }

  /// For drawing and for the sect's skills.
  ArenaRival get rival => ArenaRival(
      name: name, hanh: hanh, level: level, rebirths: rebirths, power: power, female: female, title: title);

  Map<String, Object> toJson() => {
        'u': uid,
        'n': name,
        'h': hanh.index,
        'l': level,
        'r': rebirths,
        'p': power,
        't': title,
        'f': female,
        's': [hp, atk, def, crit, critDmg, aspd, skillDmg, move].map(_r2).toList(),
        'k': skillLv,
      };

  static double _r2(double v) => (v * 100).round() / 100;

  static DuelInfo fromJson(Map m) {
    final s = [for (final v in m['s'] as List) (v as num).toDouble()];
    return DuelInfo(
      uid: '${m['u']}',
      name: '${m['n']}',
      hanh: Hanh.values[((m['h'] as num).toInt()).clamp(0, 4)],
      level: (m['l'] as num).toInt(),
      rebirths: (m['r'] as num).toInt(),
      power: (m['p'] as num).toInt(),
      title: '${m['t'] ?? ''}',
      female: m['f'] == true,
      hp: math.max(1, s[0]),
      atk: s[1],
      def: s[2],
      crit: s[3],
      critDmg: s[4],
      aspd: math.max(0.2, s[5]),
      skillDmg: s[6],
      move: s[7],
      skillLv: [for (final v in m['k'] as List) (v as num).toInt()],
    );
  }
}

/// What the guest pressed: the stick, the attack button, and skill presses
/// numbered so none is lost or run twice.
class DuelInput {
  DuelInput({this.mx = 0, this.my = 0, this.attack = false, List<(int, int)>? presses}) : presses = presses ?? [];
  double mx, my;
  bool attack;

  /// (number, skill index), the last few.
  final List<(int, int)> presses;

  Map<String, Object> toJson() => {
        'x': (mx * 100).round() / 100,
        'y': (my * 100).round() / 100,
        'a': attack ? 1 : 0,
        'k': [for (final (n, i) in presses) [n, i]],
      };

  static DuelInput fromJson(Map m) => DuelInput(
        mx: ((m['x'] as num?) ?? 0).toDouble().clamp(-1.0, 1.0),
        my: ((m['y'] as num?) ?? 0).toDouble().clamp(-1.0, 1.0),
        attack: m['a'] == 1,
        presses: [
          for (final p in (m['k'] as List?) ?? const []) (((p as List)[0] as num).toInt(), (p[1] as num).toInt()),
        ],
      );
}

/// The fight as a [DungeonDef], against [foe], on the Hoa Sơn ring.
DungeonDef duelDef(DuelInfo foe, {bool guest = false}) => DungeonDef(
      id: 'duel',
      name: 'Tỷ võ · ${foe.name}',
      mapId: 'hoason',
      level: foe.level,
      waves: const [],
      timeLimit: duelTime,
      duel: foe,
      duelGuest: guest,
    );

/// A fight about to start: its room, which side this phone is, the foe.
class DuelRoom {
  const DuelRoom(this.code, {required this.host, required this.foe});
  final String code;
  final bool host;
  final DuelInfo foe;
}

/// A six-digit room code.
String duelCode(math.Random r) => '${100000 + r.nextInt(900000)}';

/// Who won at the bell: the larger share of HP left, near-equal is a draw.
String duelByHp(double aShare, double bShare) =>
    (aShare - bShare).abs() < 0.01 ? 'draw' : (aShare > bShare ? 'a' : 'b');
