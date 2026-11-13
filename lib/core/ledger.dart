import 'dart:math' as math;

import 'gems.dart';
import 'items.dart';
import 'star_up.dart';
import 'tam_ma.dart';

/// Ceilings on endgame currencies (1.13.3), by Săn quái week ([huntWeekOf]:
/// week 1 began Mon 2026-10-26). A save edited while the game runs (seen:
/// 22,751 Tinh Thạch, 3,922 Tinh Phách, 1,467 Tiên Ngọc on a hero ten days
/// old, where the best real players had earned ~1,300 / ~20 / ~30) keeps at
/// most these. Each is about twice what every source together can give, so
/// an honest hero never meets one.
///
/// Tinh Phách: Hung Thú 7 a week (from 1.8.0, week 2), Gói Thăng Tinh 3,
/// Lệnh Bài and Lễ hội a few.
int soulCeiling(int week) => 15 + 14 * math.max(1, week - 1);

/// Tinh Thạch: every Tâm Ma floor's first clear up to [tmBest], plus per
/// week Ma Vực (~250 at floor 100), Hung Thú 105, gem refining 50, Gói
/// Thăng Tinh 120, Lệnh Bài, bang and Hoàng Kim Các shops.
int stoneCeiling(int week, int tmBest) {
  var tm = 0;
  for (var f = 1; f <= tmBest; f++) {
    tm += tamMaStones(f);
  }
  return 500 + tm + 900 * math.max(1, week - 1);
}

/// Tiên Ngọc (from 1.13.0, week 3): a tầng of Ngộ Đạo each, Độ kiếp 5 a
/// stage, Boss Hoàng Kim top ten (up to 6 a day), bang chests and shop.
int jadeCeiling(int week, int daoLv) => 150 + 2 * daoLv + 100 * math.max(1, week - 2);

/// Tinh Phách locked in worn gear: ★4 and ★5 Thăng Tinh and every Thiên
/// gem (each fused with one).
int soulsInvested(Iterable<Item> worn) {
  var n = 0;
  for (final it in worn) {
    for (var s = 0; s < it.star && s < starSoulCost.length; s++) {
      n += starSoulCost[s];
    }
    n += it.gems.where((g) => g != null && g.tier >= maxGemTier).length;
  }
  return n;
}
