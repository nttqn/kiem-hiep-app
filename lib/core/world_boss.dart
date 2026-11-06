import 'dart:math' as math;

import 'clock.dart';
import 'content.dart';

/// Boss Thế Giới: one huge boss a day for everyone. A run lasts
/// [worldBossTime] seconds; the boss cannot die, the score is the damage
/// dealt, and the day's total ranks the player on a daily board.
const int worldBossOpenLevel = 20;
const double worldBossTime = 60;

/// Free runs a day, and extra ones a rewarded ad can add.
const int worldBossFreeTries = 3;
const int worldBossAdTries = 2;

/// The boss of the day, in turn.
const worldBossRotation = [
  'demonLord',
  'heavenDemon',
  'whiteDragon',
  'kylin',
  'yetiKing',
  'scorpionKing',
  'zombieKing',
  'snakeKing',
];

/// The game's calendar is Vietnam time (UTC+7), so the boss and the board
/// change at local midnight for every player.
DateTime vnNow([DateTime? now]) => (now ?? GameClock.now()).toUtc().add(const Duration(hours: 7));

/// `20261024` style key of the Vietnam date.
String vnDayKey([DateTime? now]) {
  final d = vnNow(now);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}';
}

int _dayIndex(DateTime now) {
  final d = vnNow(now);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

MobDef worldBossOf([DateTime? now]) =>
    mobById[worldBossRotation[_dayIndex(now ?? GameClock.now()) % worldBossRotation.length]]!;

DungeonDef worldBossDef([DateTime? now]) {
  final boss = worldBossOf(now);
  return DungeonDef(
    id: 'worldboss',
    name: 'Boss Thế Giới · ${boss.name}',
    mapId: mapOfMob(boss.id)!.id,
    level: 99,
    waves: const [],
    timeLimit: worldBossTime,
    worldBoss: boss.id,
  );
}

/// Gold for one run.
int worldBossGold(int damage) => (math.sqrt(math.max(0, damage)) * 4).round();

/// Most damage a day's runs can plausibly add up to, by rebirths: the best
/// real day seen (2026-11-06) was about 0.5 billion at the top of the game,
/// and up to 7 runs a day. Boards drop rows above it and the Firestore
/// rules refuse them (the same sum, firestore.rules).
///
/// Before the first rebirth it also shrinks with the cube of the level
/// (2,061 x level^3: 2 billion at 99, 22 million at 22), as a fresh hero
/// is far weaker (1.8.3: a level-22 edited save posted 838 billion).
int worldBossDayCap(int rebirths, [int level = 99]) =>
    rebirths > 0 ? 2000000000 * (rebirths.clamp(0, 6) + 1) : 2061 * level.clamp(1, 99) * level.clamp(1, 99) * level.clamp(1, 99);

/// Daily damage totals that pay a bonus, and the gem tier each one gives.
// Tuned with a simulation: one 60 s run deals about 0.1M at level 30, 0.5M at
// 50, 1M at 75 and 1-3M at 99 (more after rebirths).
const worldBossMilestones = [100000, 500000, 2000000, 6000000, 15000000];
const worldBossMilestoneGem = [2, 3, 4, 5, 6];
int worldBossMilestoneGold(int i) => 2000 * (i + 1) * (i + 1);
