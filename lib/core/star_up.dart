import 'hero.dart';
import 'items.dart';
import 'sects.dart';

/// Thăng Tinh (1.8.0): a +[maxPlus] item rises ★1 to ★[maxStar]. Each star
/// adds [starBasePct] to its base stats (items.dart) and a line of its
/// slot's own ([starLines]). Tinh Thạch come from Tâm Ma Ảo Cảnh and Ma
/// Vực; the last two stars also take Hung Thú Tinh Phách.
class StarLine {
  const StarLine(this.bonus, this.per, this.label);
  final Bonus bonus;

  /// Bonus per star.
  final double per;
  final String label;

  String at(int star) => '$label +${(per * star * 100).toStringAsFixed(1)}%';
}

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
const starStoneCost = [10, 20, 35, 55, 80];
const starSoulCost = [0, 0, 0, 2, 4];
int starGoldCost(int star) => 500000 * (star + 1);

/// The star lines of every worn item.
Map<Bonus, double> starBonuses(Iterable<Item> worn) {
  final out = <Bonus, double>{};
  for (final it in worn) {
    if (it.star <= 0) continue;
    final l = starLines[it.slot]!;
    out[l.bonus] = (out[l.bonus] ?? 0) + l.per * it.star;
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
