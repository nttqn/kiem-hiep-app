import 'dart:math' as math;

import 'content.dart';

/// Bảng Truy Nã: repeatable bounties posted in town, rolled for the hero's
/// level. Progress counts on its own; finished ones are handed in for the
/// reward and a new one takes the slot, up to [bountiesPerDay] a day.
const int bountySlots = 4;
const int bountiesPerDay = 12;
const int bountyMinLevel = 10;
const int bountyAdRefreshes = 3;

enum BountyKind { kill, boss, elite }

/// Epithets that turn an ordinary monster into a wanted one.
const bountyEpithets = [
  'Huyết Nhãn', 'Bá Vương', 'Thiết Giáp', 'Độc Thủ', 'Cuồng Đao', 'Hắc Ám',
  'Phi Thiên', 'Lão Quái', 'Song Đầu', 'Thực Nhân',
];

class Bounty {
  Bounty({
    required this.stars,
    required this.kind,
    required this.target,
    required this.map,
    required this.count,
    required this.exp,
    required this.gold,
    this.epithet = 0,
    this.progress = 0,
  });

  /// 1..5; more stars, harder and better paid.
  final int stars;
  final BountyKind kind;

  /// Monster id (for an elite, the monster it is a tougher take on).
  final String target;
  final String map;
  final int count;
  final int exp;
  final int gold;
  final int epithet;
  int progress;

  bool get done => progress >= count;

  /// Key the world tags this bounty's elite with.
  String get eliteKey => 'b:$map:$target:$epithet';

  String get eliteName => '${mobById[target]!.name} ${bountyEpithets[epithet % bountyEpithets.length]}';

  double get eliteHp => stars >= 5 ? 9 : 5;
  double get eliteAtk => stars >= 5 ? 1.3 : 1.15;

  String get mapName => mapById[map]?.name ?? '';

  String get goal => switch (kind) {
        BountyKind.kill => 'Hạ $count ${mobById[target]!.name}',
        BountyKind.boss => 'Đánh bại ${mobById[target]!.name}',
        BountyKind.elite => 'Truy diệt $eliteName',
      };

  Map<String, dynamic> toJson() => {
        's': stars,
        'k': kind.index,
        't': target,
        'm': map,
        'c': count,
        'x': exp,
        'g': gold,
        'e': epithet,
        'p': progress,
      };

  static Bounty? fromJson(Map<String, dynamic> m) {
    final kind = m['k'] as int;
    final target = m['t'] as String;
    if (kind < 0 || kind >= BountyKind.values.length || !mobById.containsKey(target)) return null;
    if (!mapById.containsKey(m['m'])) return null;
    return Bounty(
      stars: (m['s'] as int).clamp(1, 5),
      kind: BountyKind.values[kind],
      target: target,
      map: m['m'] as String,
      count: m['c'] as int,
      exp: m['x'] as int,
      gold: m['g'] as int,
      epithet: m['e'] as int? ?? 0,
      progress: m['p'] as int? ?? 0,
    );
  }
}

/// Share of a level's EXP and gold multiplier paid per star.
const bountyExpShare = [0.05, 0.08, 0.12, 0.16, 0.22];
const _goldMul = [1.0, 1.5, 2.0, 3.0, 4.0];

/// A bounty for a hero at [level] whose level costs [levelExp] EXP: on the
/// map they level on (sometimes the one before), stars weighted toward the low end.
Bounty rollBounty(int level, int levelExp, math.Random rng) {
  final open = maps.where((m) => m.minLv <= level).toList();
  final map = open.length > 1 && rng.nextDouble() < 0.3 ? open[open.length - 2] : open.last;
  final r = rng.nextDouble();
  var stars = r < 0.30 ? 1 : (r < 0.60 ? 2 : (r < 0.80 ? 3 : (r < 0.93 ? 4 : 5)));
  // The map's boss stays out of reach until a couple of levels in.
  final bossOk = level >= map.minLv + 2;
  if (stars == 3 && !bossOk) stars = 2;
  final kind = switch (stars) {
    1 || 2 => BountyKind.kill,
    3 => BountyKind.boss,
    _ => BountyKind.elite,
  };
  final mob = map.mobs[rng.nextInt(map.mobs.length)];
  final count = switch (stars) {
    1 => 15 + level ~/ 5,
    2 => 25 + level ~/ 3,
    _ => 1,
  };
  return Bounty(
    stars: stars,
    kind: kind,
    target: kind == BountyKind.boss ? map.boss : mob,
    map: map.id,
    count: count,
    exp: (levelExp * bountyExpShare[stars - 1]).round(),
    gold: ((60 + level * 25) * _goldMul[stars - 1]).round(),
    epithet: rng.nextInt(bountyEpithets.length),
  );
}

/// Gold to reroll every unfinished bounty on the board.
int bountyRefreshCost(int level) => 300 + level * 60;
