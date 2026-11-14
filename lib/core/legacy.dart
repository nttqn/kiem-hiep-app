import 'dart:math' as math;

import 'hero.dart';

/// Truyền thừa (1.14.0): a stronger hero on the same account (another save
/// slot) speeds up the others. Players who had maxed one hero rarely made a
/// second one: levels 10-40 felt slow the second time round, and five slots
/// went unused.

/// What a hero must have reached to pass anything on.
const int legacyMinLevel = 60;

/// Monster EXP bonus from a level-60+ hero, more for each of its rebirths,
/// up to [legacyMaxExp]; gold gets [legacyGoldShare] of it.
const double legacyBaseExp = 0.2;
const double legacyPerRebirth = 0.15;
const double legacyMaxExp = 1.0;
const double legacyGoldShare = 0.5;

/// Progress as one number: rebirths first, then level.
int legacyRank(int rebirths, int level) => rebirths * 100 + level;

/// The strongest other hero in [slots] (not slot [active]) that can pass
/// something on, or null.
HeroData? legacySource(List<HeroData?> slots, int active) {
  HeroData? best;
  for (var i = 0; i < slots.length; i++) {
    final s = slots[i];
    if (i == active || s == null) continue;
    if (s.rebirths == 0 && s.level < legacyMinLevel) continue;
    if (best == null || legacyRank(s.rebirths, s.level) > legacyRank(best.rebirths, best.level)) best = s;
  }
  return best;
}

/// The EXP bonus [h] gets from [src]: none once [h] has caught up with it.
double legacyBonus(HeroData h, HeroData? src) {
  if (src == null || legacyRank(h.rebirths, h.level) >= legacyRank(src.rebirths, src.level)) return 0;
  return math.min(legacyMaxExp, legacyBaseExp + legacyPerRebirth * src.rebirths);
}

/// Sets [h]'s bonus from the other slots; called as the town opens.
void applyLegacy(HeroData h, List<HeroData?> slots, int active) {
  final src = legacySource(slots, active);
  h.legacyExp = legacyBonus(h, src);
  h.legacyFrom = h.legacyExp > 0 ? src!.name : '';
}

/// The one-time gift a young hero gets from [src]: lượng, potions.
class LegacyGift {
  const LegacyGift(this.gold, this.pots);
  final int gold, pots;
}

/// Heroes still under this level (and never reborn) may take the gift.
const int legacyGiftMaxLevel = 30;

LegacyGift legacyGiftOf(HeroData src) => LegacyGift(20000 * (1 + src.rebirths), 30);

bool legacyGiftReady(HeroData h) =>
    !h.legacyTaken && h.legacyExp > 0 && h.rebirths == 0 && h.level < legacyGiftMaxLevel;

/// Takes the gift; the lines to show.
List<String> takeLegacyGift(HeroData h, HeroData src) {
  if (!legacyGiftReady(h)) return const [];
  final g = legacyGiftOf(src);
  h.legacyTaken = true;
  h.gold += g.gold;
  h.hpPots += g.pots;
  h.mpPots += g.pots;
  return ['+${g.gold} lượng', '+${g.pots} bình máu, +${g.pots} bình nội lực'];
}
