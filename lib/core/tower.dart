import 'dart:math' as math;

import 'content.dart';
import 'gems.dart';

/// Tháp Thử Luyện: an endless climb. Each floor is a one-wave arena built on
/// the fly; every fifth floor ends with that region's boss. Monster level
/// rises to 99, after which a multiplier keeps raising their HP and attack,
/// so every hero eventually hits a wall.
const String towerId = 'tower';

/// Hero level that opens the tower (any rebirth opens it too).
const int towerOpenLevel = 20;

/// Monster level on floor [f]: 99 from floor 32.
int towerLevel(int f) => math.min(99, 5 + 3 * f);

/// HP/attack multiplier on floor [f]: flat until the monsters reach level
/// 99, then +3% per floor, compounding (tuned with a climb simulation).
double towerMul(int f) {
  final over = f - 31;
  return over <= 0 ? 1.0 : math.pow(1.03, over).toDouble();
}

bool towerBossFloor(int f) => f % 5 == 0;

DungeonDef towerFloor(int f) {
  // Five floors per region, cycling through every map.
  final map = maps[((f - 1) ~/ 5) % maps.length];
  return DungeonDef(
    id: towerId,
    name: 'Tháp Thử Luyện · Tầng $f',
    mapId: map.id,
    level: towerLevel(f),
    waves: [math.min(14, 6 + f ~/ 8)],
    timeLimit: 90,
    floor: f,
    mul: towerMul(f),
    boss: towerBossFloor(f),
  );
}

/// Gold for the first clear of floor [f].
int towerGold(int f) => 200 + f * 120;

/// Tier of the gem a boss floor pays: Thô at 5, Tiên from 60, Thánh from 72.
int towerGemTier(int f) => math.min(maxGemTier, 1 + f ~/ 12);
