import 'dart:math' as math;

import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'items.dart';
import 'weekly_hunt.dart';
import 'world_boss.dart' show vnDayKey;

// 1.9.0: more to spend Mảnh Hoàng Kim on once a set is forged.
// Khai Quang raises a piece's base stats, Tinh Luyện takes one of its extra
// lines to the best it can roll, and Hoàng Kim Các trades shards for
// what is short, a few of each a week.

/// Shards for each Khai Quang level (to 1, 2… 5): 560 a piece, 3,920 a set.
const goldGlowCost = [30, 60, 100, 150, 220];

/// Shards to take one extra line of a Hoàng Kim piece to its best roll.
const int goldPerfectCost = 40;

enum GlowBlock { notGold, maxed, shards }

/// What Hoàng Kim Các sells for shards.
enum GoldWareKind { stones, iron, gem, soulPill, pill }

class GoldWare {
  const GoldWare(this.id, this.name, this.price, this.perWeek, this.kind, {this.count = 1, this.pill = ''});
  final String id, name;

  /// Shards each, and how many a week.
  final int price, perWeek, count;
  final GoldWareKind kind;
  final String pill;
}

const goldWares = <GoldWare>[
  GoldWare('stones', '5 Tinh Thạch', 20, 8, GoldWareKind.stones, count: 5),
  GoldWare('iron', '5 Thần Thiết', 15, 10, GoldWareKind.iron, count: 5),
  GoldWare('gem6', 'Ngọc Tiên (hệ ngẫu nhiên)', 30, 5, GoldWareKind.gem),
  GoldWare('lpd', 'Linh Phách Đơn', 25, 5, GoldWareKind.soulPill),
  GoldWare('taytuy', 'Tẩy Tủy Đan', 40, 2, GoldWareKind.pill, pill: 'taytuy'),
  GoldWare('songboi', 'Song Bội Đan', 10, 7, GoldWareKind.pill, pill: 'songboi'),
];

extension GoldExtras on HeroData {
  // -------------------------------------------------------- Khai Quang

  GlowBlock? glowBlock(Item it) {
    if (!it.golden) return GlowBlock.notGold;
    if (it.glow >= maxGlow) return GlowBlock.maxed;
    if (goldShards < goldGlowCost[it.glow]) return GlowBlock.shards;
    return null;
  }

  bool glowUp(Item it) {
    if (glowBlock(it) != null) return false;
    goldShards -= goldGlowCost[it.glow];
    it.glow++;
    recompute();
    return true;
  }

  /// The Hoàng Kim pieces worn, in slot order.
  List<Item> get wornGold => [for (final s in Slot.values) if (equip[s]?.golden ?? false) equip[s]!];

  /// Khai Quang tất cả (1.9.1): raises the lowest worn piece a level at a
  /// time, while the shards last. Returns (levels, shards); with [dry] it
  /// only counts.
  (int, int) glowAll({bool dry = false}) {
    final lv = {for (final it in wornGold) it: it.glow};
    var left = goldShards, levels = 0;
    while (true) {
      final open = lv.entries.where((e) => e.value < maxGlow).toList();
      if (open.isEmpty) break;
      open.sort((a, b) => a.value.compareTo(b.value));
      final e = open.first;
      final cost = goldGlowCost[e.value];
      if (left < cost) break;
      left -= cost;
      lv[e.key] = e.value + 1;
      levels++;
    }
    final spent = goldShards - left;
    if (!dry && levels > 0) {
      lv.forEach((it, g) => it.glow = g);
      goldShards = left;
      recompute();
    }
    return (levels, spent);
  }

  /// Tinh Luyện tất cả (1.9.1): every line of the worn pieces not yet at its
  /// best, while the shards last. Returns (lines, shards).
  (int, int) perfectAll({bool dry = false}) {
    var left = goldShards, lines = 0;
    for (final it in wornGold) {
      for (final s in it.bonus.keys.toList()) {
        if (it.bonus[s]! >= maxRollStat(s, it.level) || left < goldPerfectCost) continue;
        left -= goldPerfectCost;
        lines++;
        if (!dry) it.bonus[s] = maxRollStat(s, it.level);
      }
    }
    final spent = goldShards - left;
    if (!dry && lines > 0) {
      goldShards = left;
      recompute();
    }
    return (lines, spent);
  }

  // -------------------------------------------------------- Tinh Luyện

  /// Whether line [s] of [it] can still be raised.
  bool canPerfect(Item it, Stat s) {
    final v = it.bonus[s];
    return it.golden && v != null && v < maxRollStat(s, it.level) && goldShards >= goldPerfectCost;
  }

  bool perfectLine(Item it, Stat s) {
    if (!canPerfect(it, s)) return false;
    goldShards -= goldPerfectCost;
    it.bonus[s] = maxRollStat(s, it.level);
    recompute();
    return true;
  }

  // -------------------------------------------------------- Hoàng Kim Các

  /// A new week's Hoàng Kim Các not looked at yet, with shards to spend
  /// (1.9.1: a dot on the Hoàng Kim tab).
  bool get hkFresh =>
      goldOpen &&
      hkWeek != huntWeekOf(vnDayKey()) &&
      goldShards >= goldWares.map((w) => w.price).reduce(math.min);

  void hkRollWeek() {
    final w = huntWeekOf(vnDayKey());
    if (hkWeek == w) return;
    hkWeek = w;
    hkBought.clear();
  }

  int hkLeft(GoldWare w) {
    hkRollWeek();
    return math.max(0, w.perWeek - (hkBought[w.id] ?? 0));
  }

  /// Buys one of [w]; the line saying what came in, or null.
  String? buyGoldWare(GoldWare w, math.Random rng) {
    if (hkLeft(w) <= 0 || goldShards < w.price) return null;
    goldShards -= w.price;
    hkBought[w.id] = (hkBought[w.id] ?? 0) + 1;
    switch (w.kind) {
      case GoldWareKind.stones:
        starStones += w.count;
      case GoldWareKind.iron:
        divineIron += w.count;
      case GoldWareKind.gem:
        final g = Gem(Hanh.values[rng.nextInt(5)], 6);
        addGem(g);
        return '+1 ${g.name}';
      case GoldWareKind.soulPill:
        soulPills += w.count;
      case GoldWareKind.pill:
        pills[w.pill] = (pills[w.pill] ?? 0) + w.count;
    }
    return '+${w.name}';
  }
}
