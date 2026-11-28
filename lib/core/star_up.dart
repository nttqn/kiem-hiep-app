import 'dart:math' as math;

import 'hero.dart';
import 'items.dart';
import 'sects.dart';

/// Thăng Tinh (1.8.0): a +[maxPlus] item rises ★1 to ★[maxStar]. Each star
/// adds [starBasePct] to its base stats (items.dart) and a line of its
/// slot's own ([starLines]). Tinh Thạch come from Tâm Ma Ảo Cảnh and Ma
/// Vực; ★4 and up also take Hung Thú Tinh Phách. ★6-★10 (Tinh Hồn,
/// 1.24.0) give less a star ([starHighPct], half a line) at a steep price:
/// months of Ma Vực and Hung Thú for a full set.
class StarLine {
  const StarLine(this.bonus, this.per, this.label);
  final Bonus bonus;

  /// Bonus per star.
  final double per;
  final String label;

  String at(int star) => '$label +${(per * starLineUnits(star) * 100).toStringAsFixed(1)}%';
}

/// Line units [star] stars give: one a star to ★5, half one after.
double starLineUnits(int star) => math.min(star, starLowMax) + 0.5 * math.max(0, star - starLowMax);

const starLines = <Slot, StarLine>{
  Slot.weapon: StarLine(Bonus.skillDmg, 0.04, 'Sát thương kỹ năng'),
  Slot.hat: StarLine(Bonus.hpPct, 0.03, 'Sinh lực'),
  Slot.armor: StarLine(Bonus.defPct, 0.04, 'Phòng thủ'),
  Slot.belt: StarLine(Bonus.hpPct, 0.03, 'Sinh lực'),
  Slot.boots: StarLine(Bonus.aspd, 0.015, 'Tốc đánh'),
  Slot.amulet: StarLine(Bonus.critDmg, 0.05, 'ST chí mạng'),
  Slot.ring: StarLine(Bonus.atkPct, 0.03, 'Công lực'),
};

/// Tinh Thạch, Tinh Phách and gold to go from [star] to star + 1.
const starStoneCost = [10, 20, 35, 55, 80, 100, 125, 150, 180, 220];
const starSoulCost = [0, 0, 0, 2, 4, 5, 6, 7, 8, 10];
int starGoldCost(int star) => 500000 * (star + 1);

/// The star lines of every worn item.
Map<Bonus, double> starBonuses(Iterable<Item> worn) {
  final out = <Bonus, double>{};
  for (final it in worn) {
    if (it.star <= 0) continue;
    final l = starLines[it.slot]!;
    out[l.bonus] = (out[l.bonus] ?? 0) + l.per * starLineUnits(it.star);
  }
  return out;
}

enum StarBlock { notMax, maxed, stones, souls, gold }

extension StarUp on HeroData {
  /// Why [it] cannot gain a star now, or null when it can.
  StarBlock? starBlock(Item it) {
    if (it.plus < maxPlus) return StarBlock.notMax;
    if (it.star >= maxStar) return StarBlock.maxed;
    if (starStones < starStoneCost[it.star]) return StarBlock.stones;
    if (beastSouls < starSoulCost[it.star]) return StarBlock.souls;
    if (gold < starGoldCost(it.star)) return StarBlock.gold;
    return null;
  }

  bool starUp(Item it) {
    if (starBlock(it) != null) return false;
    starStones -= starStoneCost[it.star];
    beastSouls -= starSoulCost[it.star];
    gold -= starGoldCost(it.star);
    it.star++;
    recompute();
    return true;
  }
}

// ------------------------------------------------------------ Chuyển sao

/// Chuyển sao (asked for by a top player who wanted to try other builds
/// without hunting the Tinh Phách again): two +[maxPlus] pieces of one slot
/// swap their stars. Tinh Phách move with the stars, nothing is lost; the
/// fee is [starMoveFeePct] of the Tinh Thạch and gold the higher-starred
/// piece took. Drilled sockets stay on their piece (paid in gems).
const double starMoveFeePct = 0.10;

int starStonesTo(int star) {
  var n = 0;
  for (var s = 0; s < star && s < starStoneCost.length; s++) {
    n += starStoneCost[s];
  }
  return n;
}

int starGoldTo(int star) {
  var n = 0;
  for (var s = 0; s < star; s++) {
    n += starGoldCost(s);
  }
  return n;
}

int starMoveStones(Item a, Item b) => a.star == b.star ? 0 : (starStonesTo(math.max(a.star, b.star)) * starMoveFeePct).ceil();
int starMoveGold(Item a, Item b) => a.star == b.star ? 0 : (starGoldTo(math.max(a.star, b.star)) * starMoveFeePct).round();

/// Đổi cả cường hóa (1.27.0): the two pieces swap their + as well, so
/// the one taking the stars need not be +[maxPlus] first. The fee is
/// [plusMoveFeePct] of what forging the lower piece up to the higher +
/// costs on average (failures counted).
const double plusMoveFeePct = 0.3;

int plusMoveGold(Item a, Item b) {
  if (a.plus == b.plus) return 0;
  final lo = a.plus < b.plus ? a : b;
  final hi = math.max(a.plus, b.plus);
  var g = 0.0;
  for (var p = lo.plus; p < hi && p < maxPlus; p++) {
    final cost = ((20 + lo.level * 8) * (1 + p * 0.6) * (1 + lo.rarity.index * 0.3)).roundToDouble();
    g += cost / enhanceChance(p);
  }
  return (g * plusMoveFeePct).round();
}

enum StarMoveBlock { same, slot, notMax, noStars, stones, gold }

extension StarMove on HeroData {
  /// Pieces [it]'s stars could swap with: same slot and other stars; +max
  /// unless [withPlus] swaps the + too (then a different + will do).
  List<Item> starMoveTargets(Item it, {bool withPlus = false}) => [
        if (equip[it.slot] case final w? when !identical(w, it)) w,
        ...bag.where((b) => !identical(b, it) && b.slot == it.slot),
      ].where((o) => withPlus ? (o.star != it.star || o.plus != it.plus) : (o.plus >= maxPlus && o.star != it.star)).toList();

  int starMoveGoldTotal(Item a, Item b, {bool withPlus = false}) =>
      starMoveGold(a, b) + (withPlus ? plusMoveGold(a, b) : 0);

  StarMoveBlock? starMoveBlock(Item a, Item b, {bool withPlus = false}) {
    if (identical(a, b)) return StarMoveBlock.same;
    if (a.slot != b.slot) return StarMoveBlock.slot;
    if (!withPlus && (a.plus < maxPlus || b.plus < maxPlus)) return StarMoveBlock.notMax;
    if (a.star == b.star && (!withPlus || a.plus == b.plus)) return StarMoveBlock.noStars;
    if (starStones < starMoveStones(a, b)) return StarMoveBlock.stones;
    if (gold < starMoveGoldTotal(a, b, withPlus: withPlus)) return StarMoveBlock.gold;
    return null;
  }

  bool moveStars(Item a, Item b, {bool withPlus = false}) {
    if (starMoveBlock(a, b, withPlus: withPlus) != null) return false;
    starStones -= starMoveStones(a, b);
    gold -= starMoveGoldTotal(a, b, withPlus: withPlus);
    final s = a.star;
    a.star = b.star;
    b.star = s;
    if (withPlus) {
      final p = a.plus;
      a.plus = b.plus;
      b.plus = p;
    }
    recompute();
    return true;
  }
}
