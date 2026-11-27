import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/codex.dart';
import 'package:kiem_hiep/core/gold_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';

/// Truyền thuyết phổ (1.26.0): every Truyền thuyết name in every slot.
Item legend(HeroData h, int name, Slot slot, {int level = 60}) {
  final rng = math.Random(name * 10 + slot.index);
  while (true) {
    final it = makeItem(slot: slot, level: level, rarity: Rarity.legend, sect: h.sect, rng: rng);
    if (legendNameOf(it) == name) return it;
  }
}

void main() {
  test('a legend piece is known by its name; others and Hoàng Kim are not', () {
    final h = HeroData(name: 'Tàng', hanh: Hanh.kim)..level = 60;
    for (var n = 0; n < legendNames.length; n++) {
      expect(legendNameOf(legend(h, n, Slot.ring)), n);
    }
    final rng = math.Random(1);
    expect(legendNameOf(makeItem(slot: Slot.hat, level: 60, rarity: Rarity.epic, sect: h.sect, rng: rng)), -1);
    final gold = makeGoldItem(set: goldSets.first, slot: Slot.hat, level: 60, sect: sects.first, rng: rng);
    expect(legendNameOf(gold), -1);
    expect(h.codexNoteLegend(gold), isFalse);
  });

  test('a full name pays once, adds its bonus, all six add the title', () {
    final h = HeroData(name: 'Tàng', hanh: Hanh.kim)..level = 60;
    for (final s in Slot.values.take(6)) {
      h.addItem(legend(h, 0, s));
    }
    expect(h.codexLegendCount(0), 6);
    expect(h.codexClaimable(codexLegendPage(0)), isFalse);
    // Kept after the piece is gone.
    h.bag.clear();
    h.addItem(legend(h, 0, Slot.values.last));
    expect(h.codexClaimable(codexLegendPage(0)), isTrue);
    // The Thần binh phổ count is not mixed with it.
    expect(h.codexGearCount(codexTierOf(60)), Slot.values.length);
    final g0 = h.gold, e0 = h.essence;
    expect(h.codexClaim(codexLegendPage(0)), isNotEmpty);
    expect(h.gold, g0 + codexLegendGold(0));
    expect(h.essence, e0 + codexLegendEssence);
    expect(h.codexBonuses()[Bonus.atkPct], closeTo(codexLegendBonus[0].$2, 1e-9));
    expect(h.codexClaim(codexLegendPage(0)), isEmpty);
    for (var n = 1; n < legendNames.length; n++) {
      for (final s in Slot.values) {
        h.codexNoteLegend(legend(h, n, s));
      }
      h.codexClaim(codexLegendPage(n));
    }
    expect(h.codexLegendAll, isTrue);
    expect(h.seasonTitles, contains(codexLegendTitle));
    expect(h.codexBonuses()[Bonus.hpPct], greaterThanOrEqualTo(codexLegendBonus[5].$2 + codexLegendAllBonus[Bonus.hpPct]!));
  });

  test('cells and pages survive a save; old saves read as before', () {
    final h = HeroData(name: 'Tàng', hanh: Hanh.kim)..level = 60;
    for (final s in Slot.values) {
      h.codexNoteLegend(legend(h, 2, s));
    }
    h.codexClaim(codexLegendPage(2));
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.codexLegendCount(2), Slot.values.length);
    expect(back.codexClaimed, contains(codexLegendPage(2)));
    expect(back.codexBonuses()[Bonus.skillDmg], closeTo(codexLegendBonus[2].$2, 1e-9));
  });
}
