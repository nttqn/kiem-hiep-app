import 'dart:math' as math;

import 'content.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'premium.dart';
import 'tam_ma.dart' show fmtThousands;
import 'weekly_hunt.dart';
import 'world_boss.dart';

/// Thượng Cổ Hung Thú (1.8.0): one great beast a week, in three
/// difficulties. Unlike Boss Thế Giới it must be slain inside
/// [beastTime], and it fights back with telegraphed blows to dodge, calls
/// its kin at 60% and 30% and goes berserk below 30%. The first kill of
/// each difficulty in a week pays Tinh Thạch and Hung Thú Tinh Phách; the
/// fastest kills of the hardest difficulty top a weekly board.
const int beastOpenRebirths = 3;
const double beastTime = 180;
const int beastFreeTries = 3;

class BeastDef {
  const BeastDef(this.name, this.base, this.mapId, this.desc);
  final String name;

  /// The monster it is drawn and built from, and the land it is fought on.
  final String base;
  final String mapId;
  final String desc;
}

const beasts = [
  BeastDef('Cửu Anh', 'whiteDragon', 'vanvu', 'Rồng chín đầu trên Vân Vụ Sơn, phun thủy hỏa.'),
  BeastDef('Thao Thiết', 'yetiKing', 'bangnguyen', 'Kẻ tham ăn nuốt cả núi tuyết.'),
  BeastDef('Cùng Kỳ', 'kylin', 'hoadiem', 'Hổ có cánh của Hỏa Diệm Sơn, thích kẻ ác ghét người lành.'),
  BeastDef('Hỗn Độn', 'abyssLord', 'cuuu', 'Thứ không mặt mũi dưới đáy Cửu U.'),
  BeastDef('Tương Liễu', 'snakeKing', 'truclam', 'Xà thần chín đầu, nọc độc biến đất thành đầm lầy.'),
  BeastDef('Đào Ngột', 'scorpionKing', 'hoangsa', 'Hung thú cát vàng, ngang ngạnh không ai dạy nổi.'),
];

BeastDef beastOfWeek(int week) => beasts[week % beasts.length];

/// The beast called [name] (the first when unknown).
BeastDef beastOfWeekNamed(String name) => beasts.firstWhere((b) => b.name == name, orElse: () => beasts.first);

const beastLevels = ['Thường', 'Khó', 'Ác Mộng'];

/// Lực chiến each difficulty is meant for (shown to the player).
const beastPowers = [700000, 1500000, 3000000];

// HP and attack of the beast over a level-99 monster of its kind, per
// difficulty (tuned with test/hung_thu_sim_test.dart against a 2M hero).
const beastHpMul = [260.0, 600.0, 1800.0];
const beastAtkMul = [10.0, 14.0, 26.0];

/// The HP and attack factors every beast is built with (a late boss's).
const double beastBaseHp = 18;
const double beastBaseAtk = 1.75;

/// Its kin called at these HP fractions, this many each time.
const beastSummonAt = [0.6, 0.3];
const int beastAdds = 5;

/// Below this HP it goes berserk.
const double beastEnrageAt = 0.3;

DungeonDef beastDungeon(int difficulty, int week) {
  final b = beastOfWeek(week);
  return DungeonDef(
    id: 'hungthu',
    name: '${b.name} · ${beastLevels[difficulty - 1]}',
    mapId: b.mapId,
    level: 99,
    waves: const [],
    timeLimit: beastTime,
    beast: difficulty,
    beastName: b.name,
  );
}

/// First kill of a difficulty in a week.
const beastStones = [15, 30, 60];
const beastSoulReward = [1, 2, 4];
const beastGold = [300000, 600000, 1200000];
const beastGemTier = [5, 6, 7];

/// Board number: the week, then the hardest difficulty slain, then how
/// fast (seconds under [beastTime]).
int beastScore(int week, int difficulty, double seconds) =>
    week * 10000 + difficulty * 1000 + (999 - seconds.round()).clamp(0, 999);

extension HungThu on HeroData {
  bool get beastOpen => rebirths >= beastOpenRebirths;

  int get htThisWeek => huntWeekOf(vnDayKey());

  void htRoll(String day) {
    final w = htThisWeek;
    if (htWeek != w) {
      htWeek = w;
      htKilled = 0;
      htScore = 0;
    }
    if (htDay != day) {
      htDay = day;
      htTries = 0;
    }
  }

  int get htFreeTries => beastFreeTries + (cardActive(vnDayKey()) ? monthCardExtraRuns : 0);
  int get htTriesLeft => math.max(0, htFreeTries - htTries);

  bool htSlain(int difficulty) => htKilled & (1 << difficulty) != 0;

  /// Uses one of the day's tries; false when none are left.
  bool htStart(String day) {
    htRoll(day);
    if (htTriesLeft <= 0) return false;
    htTries++;
    return true;
  }

  int get beastBoardValue {
    htRoll(vnDayKey());
    return htScore;
  }

  List<String> beastReward(int difficulty, double seconds, math.Random rng) {
    htRoll(vnDayKey());
    htScore = math.max(htScore, beastScore(htWeek, difficulty, seconds));
    lastDungeonExp = 0;
    final i = difficulty - 1;
    if (htSlain(difficulty)) {
      final g = beastGold[i] ~/ 10;
      gold += g;
      lastDungeonGold = g;
      return ['Đã hạ ${beastLevels[i]} tuần này', '+${fmtThousands(g)} lượng'];
    }
    htKilled |= 1 << difficulty;
    starStones += beastStones[i];
    beastSouls += beastSoulsFor(i);
    gold += beastGold[i];
    lastDungeonGold = beastGold[i];
    final lines = [
      '+${beastStones[i]} Tinh Thạch',
      '+${beastSoulsFor(i)} Hung Thú Tinh Phách',
      '+${fmtThousands(beastGold[i])} lượng',
    ];
    for (var k = 0; k <= i; k++) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], math.min(maxRewardGemTier, beastGemTier[i]));
      addGem(gem);
      lines.add(gem.name);
    }
    return lines;
  }
}

int beastSoulsFor(int i) => beastSoulReward[i];
