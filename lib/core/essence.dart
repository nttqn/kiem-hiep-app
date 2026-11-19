import 'dart:math' as math;

import 'hero.dart';
import 'items.dart';
import 'weekly_hunt.dart' show huntWeekOf;
import 'world_boss.dart' show vnDayKey;

/// Tinh Hoa (1.18.0): monster gear past level 60 lost every use once a hero
/// wore Hoàng Kim; players only sold it ("dở quá"). Now a Quý or better
/// piece of level [essenceMinLevel]+ can be broken down into Tinh Hoa, spent
/// on:
/// * Tẩy luyện định hướng: rerolls whose new lines come only from the
///   attack or the defence group;
/// * Khắc ấn: one line of a dropped piece written over one line of a worn
///   Hoàng Kim piece (the drop is used up), so a good drop is worth a look;
/// * a weekly exchange for Mảnh Hoàng Kim and Thần Thiết.
/// None of it adds power past what Tẩy luyện and Tinh Luyện already reach.

/// Pieces below this level give nothing (low fields are farmed fastest).
const int essenceMinLevel = 50;

/// Tinh Hoa a piece breaks down into: Quý 1, Hiếm 3, Truyền thuyết 10.
int essenceOf(Item it) {
  if (it.golden || it.level < essenceMinLevel) return 0;
  return switch (it.rarity) {
    Rarity.rare => 1,
    Rarity.epic => 3,
    Rarity.legend => 10,
    _ => 0,
  };
}

bool canSalvage(Item it) => !it.locked && essenceOf(it) > 0;

// ------------------------------------------------------------ Tẩy luyện

/// The two groups a Tinh Hoa reroll may aim at.
enum RefineAim { attack, defence }

extension RefineAimInfo on RefineAim {
  String get label => this == RefineAim.attack ? 'Công' : 'Thủ';

  Set<Stat> get stats => this == RefineAim.attack
      ? const {Stat.str, Stat.dex, Stat.ene, Stat.atk, Stat.crit, Stat.critDmg, Stat.aspd}
      : const {Stat.vit, Stat.hp, Stat.mp, Stat.def, Stat.dodge, Stat.move};
}

/// Tinh Hoa for an aimed reroll keeping [locks] lines.
int aimedRefineCost(int locks) => 3 + 3 * locks;

// --------------------------------------------------------------- Khắc ấn

const int engraveCost = 20;

/// A donor may be at most this many levels below the piece it marks.
const int engraveLevelGap = 10;

/// [donor] can give a line to [target]: a worn-kind Hoàng Kim piece, a
/// dropped piece with lines, not locked, close enough in level.
bool engraveDonorFits(Item target, Item donor) =>
    target.golden &&
    !donor.golden &&
    !donor.locked &&
    donor.bonus.isNotEmpty &&
    donor.rarity.index >= Rarity.rare.index &&
    donor.level >= target.level - engraveLevelGap;

/// The value line [s] of [donor] would have on [target]: as good for the
/// target's level as it was for the donor's.
double engraveValue(Item target, Item donor, Stat s) =>
    math.min(rescaleAffixes({s: donor.bonus[s]!}, donor.level, target.level)[s]!, maxRollStat(s, target.level));

// -------------------------------------------------------------- exchange

class EssenceWare {
  const EssenceWare(this.id, this.name, this.price, this.perWeek);
  final String id, name;
  final int price, perWeek;
}

const essenceWares = [
  EssenceWare('shard', 'Mảnh Hoàng Kim', 15, 10),
  EssenceWare('iron', 'Thần Thiết', 10, 10),
];

extension EssenceOps on HeroData {
  /// Breaks [it] (in the bag) down; the Tinh Hoa it gave, 0 if it could not.
  int salvage(Item it) {
    final n = essenceOf(it);
    if (n <= 0 || it.locked || !bag.remove(it)) return 0;
    for (final g in it.gems) {
      if (g != null) addGem(g);
    }
    essence += n;
    return n;
  }

  /// Should a piece just picked up be broken down rather than kept or
  /// sold? Never one that beats what is worn.
  bool autoSalvages(Item it) =>
      essenceOf(it) > 0 && it.rarity.index <= autoSalvageUpTo && !betterThanWorn(it);

  /// Tẩy luyện định hướng: like [HeroData.refine], paid in Tinh Hoa, new
  /// lines from [aim]'s group while it has any left.
  bool refineAimed(Item it, Set<Stat> locked, RefineAim aim, math.Random rng) {
    if (it.bonus.isEmpty || locked.length >= it.bonus.length) return false;
    final cost = aimedRefineCost(locked.length);
    if (essence < cost) return false;
    essence -= cost;
    rerollAffixes(it, locked, rng, prefer: aim.stats);
    recompute();
    return true;
  }

  /// Can line [take] of [donor] (in the bag) replace line [replace] of
  /// [target] (a worn Hoàng Kim piece)?
  bool canEngrave(Item target, Stat replace, Item donor, Stat take) =>
      equip[target.slot] == target &&
      bag.contains(donor) &&
      engraveDonorFits(target, donor) &&
      target.bonus.containsKey(replace) &&
      donor.bonus.containsKey(take) &&
      (take == replace || !target.bonus.containsKey(take)) &&
      essence >= engraveCost;

  /// Khắc ấn: writes [donor]'s [take] line over [target]'s [replace] line,
  /// keeping the line's place; the donor is used up (its gems come back).
  bool engrave(Item target, Stat replace, Item donor, Stat take) {
    if (!canEngrave(target, replace, donor, take)) return false;
    final v = engraveValue(target, donor, take);
    essence -= engraveCost;
    final lines = target.bonus.entries.toList();
    target.bonus
      ..clear()
      ..addEntries([for (final e in lines) e.key == replace ? MapEntry(take, v) : e]);
    bag.remove(donor);
    for (final g in donor.gems) {
      if (g != null) addGem(g);
    }
    recompute();
    return true;
  }

  void essRollWeek() {
    final w = huntWeekOf(vnDayKey());
    if (essWeek == w) return;
    essWeek = w;
    essBought.clear();
  }

  int essLeft(EssenceWare w) {
    essRollWeek();
    return math.max(0, w.perWeek - (essBought[w.id] ?? 0));
  }

  /// Buys one [w] with Tinh Hoa.
  bool buyEssenceWare(EssenceWare w) {
    if (essLeft(w) <= 0 || essence < w.price) return false;
    essence -= w.price;
    essBought[w.id] = (essBought[w.id] ?? 0) + 1;
    switch (w.id) {
      case 'shard':
        goldShards += 1;
      case 'iron':
        divineIron += 1;
    }
    return true;
  }
}
