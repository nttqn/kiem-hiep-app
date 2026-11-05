import 'dart:math' as math;

import 'content.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'nightmare.dart';
import 'tam_ma.dart' show fmtThousands;
import 'weekly_hunt.dart';
import 'world_boss.dart';

/// Ma Vực (1.8.0): an endless climb that starts over every Monday. Floors
/// begin about where Tháp Thử Luyện's 120th stands and grow by
/// [maVucGrowth]; every floor carries the week's ma khí, one more of them
/// from floors 10 and 20. Every fifth floor ends with a boss. A floor
/// reached for the first time in the week pays Tinh Thạch, so the climb is
/// worth making again each week, and the week's best goes on a board.
const int maVucOpenTower = 100;
const double maVucTime = 150;

/// HP/attack multiplier of floor 1 (level-99 monsters), and the rise per floor.
const double maVucBase = 15;
const double maVucGrowth = 1.06;

double maVucMul(int floor) => maVucBase * math.pow(maVucGrowth, floor - 1).toDouble();

/// Ma khí that can turn up in Ma Vực.
const maVucPool = NmAffix.values;

/// The week's three ma khí, in the order they join.
List<NmAffix> maVucWeekAffixes(int week) {
  final pool = List<NmAffix>.of(maVucPool)..shuffle(math.Random(week * 7919 + 13));
  return pool.take(3).toList();
}

/// How many of the week's ma khí floor [floor] carries.
int maVucAffixCount(int floor) => floor < 10 ? 1 : (floor < 20 ? 2 : 3);

List<NmAffix> maVucAffixesAt(int floor, int week) =>
    maVucWeekAffixes(week).take(maVucAffixCount(floor)).toList();

/// The lands floors cycle through: the late game's darker ones.
const _lands = ['hoason', 'hoadiem', 'vanvu', 'cuuu', 'donghai', 'huyethai'];

DungeonDef maVucFloor(int floor, int week) {
  final land = _lands[(floor - 1) % _lands.length];
  return DungeonDef(
    id: 'mavuc',
    name: 'Ma Vực · Tầng $floor',
    mapId: mapById.containsKey(land) ? land : maps.last.id,
    level: 99,
    waves: [math.min(18, 10 + floor ~/ 5)],
    timeLimit: maVucTime,
    mul: maVucMul(floor),
    boss: floor % 5 == 0,
    maVuc: floor,
    affixes: [for (final a in maVucAffixesAt(floor, week)) a.index],
  );
}

/// Tinh Thạch and gold for a floor reached for the first time this week.
int maVucStones(int floor) => 1 + floor ~/ 3;
int maVucGold(int floor) => 15000 * floor;
int maVucGemTier(int floor) => math.min(maxGemTier, 4 + floor ~/ 12);
int maVucIron(int floor) => 2 + floor ~/ 10;

/// One number per week for the board, newer weeks above older ones.
int maVucScore(int week, int floor) => week * 1000 + floor.clamp(0, 999);

extension MaVuc on HeroData {
  bool get maVucOpen => towerBest >= maVucOpenTower || mvBest > 0;

  int get mvThisWeek => huntWeekOf(vnDayKey());

  /// Starts the climb over when a new week came.
  void mvRollWeek() {
    final w = mvThisWeek;
    if (mvWeek == w) return;
    mvWeek = w;
    mvBest = 0;
  }

  int get maVucBoardValue {
    mvRollWeek();
    return mvBest > 0 ? maVucScore(mvWeek, mvBest) : 0;
  }

  List<String> maVucReward(int floor, math.Random rng) {
    mvRollWeek();
    if (floor <= mvBest) {
      lastDungeonGold = 0;
      lastDungeonExp = 0;
      return const ['Tầng đã vượt tuần này'];
    }
    mvBest = floor;
    final stones = maVucStones(floor);
    final g = maVucGold(floor);
    starStones += stones;
    gold += g;
    lastDungeonGold = g;
    lastDungeonExp = 0;
    final lines = ['+$stones Tinh Thạch', '+${fmtThousands(g)} lượng'];
    if (floor % 5 == 0) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], maVucGemTier(floor));
      addGem(gem);
      final iron = maVucIron(floor);
      divineIron += iron;
      lines
        ..add(gem.name)
        ..add('+$iron Thần Thiết');
    }
    return lines;
  }
}
