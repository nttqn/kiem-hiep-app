import 'dart:math' as math;

import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'items.dart';
import 'weekly_hunt.dart';
import 'world_boss.dart';

// 1.8.0: more to do with gems once every socket holds a Thánh one. Fuse a
// whole bag at once, turn a phase into another, refine high gems into
// Tinh Thạch (a weekly cap), and drill a fourth and fifth socket into
// starred gear.

/// What fusing everything up to a tier would do.
class FusePlan {
  FusePlan(this.fuses, this.gold, this.made);
  final int fuses, gold;

  /// Gems of the top tier made, by phase.
  final Map<Hanh, int> made;
}

// ---------------------------------------------------------------- chuyển hệ

/// Gems of one phase given for one of another, and the gold for each made.
const int convertRatio = 2;
int convertCost(int tier) => 100 * tier * tier;

// ---------------------------------------------------------------- luyện hóa

/// Gems of a tier that make one Tinh Thạch (only Thần, Tiên, Thánh refine).
int? gemsPerStone(int tier) => switch (tier) {
      5 => 10,
      6 => 3,
      7 => 1,
      _ => null,
    };

/// Tinh Thạch gems may make in a week.
const int gemStonesPerWeek = 50;

// ---------------------------------------------------------------- đục lỗ

/// Stars an item needs for its first and second drilled socket.
const drillStars = [3, 5];

/// Thần (tier 5) gems of any phase and gold to drill socket [n] (0, 1).
const drillGems = [30, 60];
const drillGold = [2000000, 5000000];
const int drillGemTier = 5;

enum DrillBlock { stars, maxed, gems, gold }

extension GemExtras on HeroData {
  /// Fusing every phase (or only [only]) from tier 1 up to [upTo].
  FusePlan fusePlan(int upTo, {Hanh? only}) {
    var fuses = 0, cost = 0;
    final made = <Hanh, int>{};
    for (final hn in Hanh.values) {
      if (only != null && hn != only) continue;
      var carry = 0;
      for (var t = 1; t < upTo; t++) {
        final n = (gemCount(Gem(hn, t)) + carry) ~/ 3;
        fuses += n;
        cost += n * fuseCost(t);
        carry = n;
      }
      if (carry > 0) made[hn] = carry;
    }
    return FusePlan(fuses, cost, made);
  }

  /// Carries out [fusePlan]; false when the gold falls short.
  bool fuseAll(int upTo, {Hanh? only}) {
    final plan = fusePlan(upTo, only: only);
    if (plan.fuses == 0 || gold < plan.gold) return false;
    gold -= plan.gold;
    for (final hn in Hanh.values) {
      if (only != null && hn != only) continue;
      for (var t = 1; t < upTo; t++) {
        final g = Gem(hn, t);
        final n = gemCount(g) ~/ 3;
        if (n == 0) continue;
        takeGem(g, n * 3);
        addGem(Gem(hn, t + 1), n);
      }
    }
    return true;
  }

  /// [n] gems of [to] for [convertRatio]·n of [from] (same tier).
  bool convertGem(Gem from, Hanh to, int n) {
    if (n <= 0 || to == from.hanh) return false;
    final cost = convertCost(from.tier) * n;
    if (gold < cost || gemCount(from) < n * convertRatio) return false;
    gold -= cost;
    takeGem(from, n * convertRatio);
    addGem(Gem(to, from.tier), n);
    return true;
  }

  void gsRollWeek() {
    final w = huntWeekOf(vnDayKey());
    if (gsWeek == w) return;
    gsWeek = w;
    gsMade = 0;
  }

  int get gemStonesLeft {
    gsRollWeek();
    return math.max(0, gemStonesPerWeek - gsMade);
  }

  /// Turns gems of [g] into [stones] Tinh Thạch.
  bool refineGems(Gem g, int stones) {
    final per = gemsPerStone(g.tier);
    if (per == null || stones <= 0 || stones > gemStonesLeft || gemCount(g) < per * stones) return false;
    takeGem(g, per * stones);
    starStones += stones;
    gsMade += stones;
    return true;
  }

  /// Drilled sockets [it] may have by its stars.
  int drillAllowed(Item it) => drillStars.where((s) => it.star >= s).length;

  /// Tier-[drillGemTier] gems in the bag, all phases.
  int get drillGemsHeld => [for (final hn in Hanh.values) gemCount(Gem(hn, drillGemTier))].fold(0, (a, b) => a + b);

  DrillBlock? drillBlock(Item it) {
    final n = it.extraSockets;
    if (n >= drillStars.length) return DrillBlock.maxed;
    if (n >= drillAllowed(it)) return DrillBlock.stars;
    if (drillGemsHeld < drillGems[n]) return DrillBlock.gems;
    if (gold < drillGold[n]) return DrillBlock.gold;
    return null;
  }

  /// Drills the next socket into [it], paying in the phases held most
  /// (the hero's own last).
  bool drillSocket(Item it) {
    if (drillBlock(it) != null) return false;
    final n = it.extraSockets;
    var need = drillGems[n];
    final order = [...Hanh.values]..sort((a, b) {
        if (a == hanh) return 1;
        if (b == hanh) return -1;
        return gemCount(Gem(b, drillGemTier)).compareTo(gemCount(Gem(a, drillGemTier)));
      });
    for (final hn in order) {
      final g = Gem(hn, drillGemTier);
      final take = math.min(need, gemCount(g));
      if (take > 0) takeGem(g, take);
      need -= take;
      if (need == 0) break;
    }
    gold -= drillGold[n];
    it.extraSockets++;
    it.gems.add(null);
    recompute();
    return true;
  }
}
