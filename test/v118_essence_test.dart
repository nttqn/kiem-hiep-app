import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/essence.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/gold_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

Item _drop(int level, Rarity r, {Map<Stat, double>? bonus, Slot slot = Slot.ring}) {
  final it = makeItem(slot: slot, level: level, rarity: r, sect: sects[0], rng: math.Random(level + r.index));
  if (bonus != null) {
    it.bonus
      ..clear()
      ..addAll(bonus);
  }
  return it;
}

HeroData _hero(int level) {
  final h = HeroData(name: 'N', hanh: Hanh.kim)..level = level;
  h.recompute();
  return h;
}

/// A worn Hoàng Kim ring with known lines.
Item _wearGold(HeroData h, Map<Stat, double> lines) {
  final it = makeGoldItem(set: goldSets.first, slot: Slot.ring, level: h.level, sect: h.sect, rng: math.Random(1));
  it.bonus
    ..clear()
    ..addAll(lines);
  h.equip[Slot.ring] = it;
  h.recompute();
  return it;
}

void main() {
  group('Phân giải', () {
    test('yields by rarity from level 50; nothing for low, common, golden or locked', () {
      expect(essenceOf(_drop(60, Rarity.rare)), 1);
      expect(essenceOf(_drop(60, Rarity.epic)), 3);
      expect(essenceOf(_drop(60, Rarity.legend)), 10);
      expect(essenceOf(_drop(60, Rarity.fine)), 0);
      expect(essenceOf(_drop(49, Rarity.legend)), 0);
      final h = _hero(70);
      expect(essenceOf(makeGoldItem(set: goldSets.first, slot: Slot.ring, level: 70, sect: h.sect, rng: math.Random(1))), 0);
      expect(canSalvage(_drop(60, Rarity.legend)..locked = true), isFalse);
    });

    test('salvage takes it from the bag and gives its gems back', () {
      final h = _hero(70);
      final it = _drop(70, Rarity.epic);
      it.gems[0] = const Gem(Hanh.hoa, 3);
      h.bag.add(it);
      const gem = Gem(Hanh.hoa, 3);
      final gems0 = h.gemCount(gem);
      expect(h.salvage(it), 3);
      expect(h.essence, 3);
      expect(h.bag, isNot(contains(it)));
      expect(h.gemCount(gem), gems0 + 1);
      expect(h.salvage(it), 0, reason: 'already gone');
    });

    test('Tự phân giải on pick-up, never an upgrade; a full bag breaks down instead of selling', () {
      final h = _hero(70)..autoSalvageUpTo = Rarity.epic.index;
      _wearGold(h, {Stat.crit: 0.06, Stat.atk: 90, Stat.critDmg: 0.2, Stat.aspd: 0.06});
      final gold0 = h.gold;
      expect(h.addItem(_drop(70, Rarity.epic)), isFalse);
      expect(h.lastEssence, 3);
      expect(h.essence, 3);
      expect(h.addItem(_drop(70, Rarity.legend)), isTrue, reason: 'above the chosen rarity');
      expect(h.lastEssence, 0);
      // An upgrade on an empty slot is kept.
      final hat = _drop(70, Rarity.rare, slot: Slot.hat);
      expect(h.addItem(hat), isTrue);
      // Full bag: a Hiếm piece past the setting is broken down, not sold.
      h.autoSalvageUpTo = -1;
      while (h.bag.length < bagSize) {
        h.bag.add(_drop(10, Rarity.common));
      }
      expect(h.addItem(_drop(70, Rarity.legend)), isFalse);
      expect(h.essence, 13);
      expect(h.gold, gold0, reason: 'nothing sold yet');
      expect(h.addItem(_drop(70, Rarity.fine)), isFalse);
      expect(h.gold, greaterThan(gold0), reason: 'what gives no Tinh Hoa is still sold');
      // 1.18.1 Túi đầy → Bán lấy vàng: sold, no Tinh Hoa; Tự phân giải still wins.
      h.fullBagSell = true;
      final gold1 = h.gold;
      final legend = _drop(70, Rarity.legend);
      expect(h.addItem(legend), isFalse);
      expect((h.essence, h.lastEssence, h.gold), (13, 0, gold1 + legend.sellPrice));
      h.autoSalvageUpTo = Rarity.epic.index;
      expect(h.addItem(_drop(70, Rarity.epic)), isFalse);
      expect(h.essence, greaterThan(13));
      final b = _roundTrip(h);
      expect(b.fullBagSell, isTrue);
      expect(_roundTrip(_hero(5)).fullBagSell, isFalse);
    });

    test('Tinh Hoa and the settings survive a save', () {
      final h = _hero(70)
        ..essence = 42
        ..autoSalvageUpTo = Rarity.legend.index
        ..essWeek = 7;
      h.essBought['shard'] = 3;
      final b = _roundTrip(h);
      expect((b.essence, b.autoSalvageUpTo, b.essWeek, b.essBought['shard']), (42, Rarity.legend.index, 7, 3));
      final fresh = _roundTrip(_hero(5));
      expect((fresh.essence, fresh.autoSalvageUpTo), (0, -1));
    });
  });

  group('Tẩy luyện định hướng', () {
    test('new lines come from the chosen group and cost Tinh Hoa', () {
      final h = _hero(80)..essence = 1000;
      final it = _wearGold(h, {Stat.hp: 500, Stat.def: 50, Stat.move: 10, Stat.mp: 100});
      final rng = math.Random(3);
      for (var i = 0; i < 50; i++) {
        expect(h.refineAimed(it, {Stat.hp}, RefineAim.attack, rng), isTrue);
        expect(it.bonus.length, 4);
        expect(it.bonus.containsKey(Stat.hp), isTrue, reason: 'locked');
        for (final s in it.bonus.keys.where((s) => s != Stat.hp)) {
          expect(RefineAim.attack.stats, contains(s));
        }
      }
      expect(h.essence, 1000 - 50 * aimedRefineCost(1));
      h.essence = 0;
      expect(h.refineAimed(it, {}, RefineAim.defence, rng), isFalse);
    });

    test('a group too small for the free lines fills from the rest', () {
      final it = _drop(80, Rarity.legend, bonus: {Stat.vit: 1, Stat.hp: 1, Stat.mp: 1, Stat.def: 1});
      // Defence has 6 stats; locking 3 of them leaves 3 for 1 line: all defence.
      rerollAffixes(it, {Stat.vit, Stat.hp, Stat.mp}, math.Random(1), prefer: RefineAim.defence.stats);
      expect(it.bonus.length, 4);
      expect(RefineAim.defence.stats.containsAll(it.bonus.keys), isTrue);
      // No preference: any stat still possible.
      final seen = <Stat>{};
      for (var i = 0; i < 300; i++) {
        rerollAffixes(it, {}, math.Random(i));
        seen.addAll(it.bonus.keys);
      }
      expect(seen.length, Stat.values.length);
    });
  });

  group('Khắc ấn', () {
    test('a dropped line replaces a chosen line in place, rescaled; the drop is used up', () {
      final h = _hero(80)..essence = 50;
      final gold = _wearGold(h, {Stat.hp: 500, Stat.crit: 0.05, Stat.def: 40, Stat.mp: 90});
      final donor = _drop(75, Rarity.epic, bonus: {Stat.aspd: 0.06, Stat.str: 20, Stat.atk: 50});
      h.bag.add(donor);
      final want = engraveValue(gold, donor, Stat.aspd);
      expect(want, greaterThan(0.06), reason: 'rescaled up to level 80');
      expect(want, lessThanOrEqualTo(maxRollStat(Stat.aspd, 80)));
      expect(h.engrave(gold, Stat.hp, donor, Stat.aspd), isTrue);
      expect(gold.bonus.keys.toList(), [Stat.aspd, Stat.crit, Stat.def, Stat.mp]);
      expect(gold.bonus[Stat.aspd], want);
      expect(h.essence, 50 - engraveCost);
      expect(h.bag, isNot(contains(donor)));
    });

    test('refuses a duplicate line, a far-lower donor, a locked or common one, or no Tinh Hoa', () {
      final h = _hero(80)..essence = 100;
      final gold = _wearGold(h, {Stat.hp: 500, Stat.crit: 0.05, Stat.def: 40, Stat.mp: 90});
      final dup = _drop(80, Rarity.epic, bonus: {Stat.crit: 0.06});
      final low = _drop(80 - engraveLevelGap - 1, Rarity.legend, bonus: {Stat.aspd: 0.05});
      final locked = _drop(80, Rarity.legend, bonus: {Stat.aspd: 0.05})..locked = true;
      final fine = _drop(80, Rarity.fine, bonus: {Stat.aspd: 0.05});
      h.bag.addAll([dup, low, locked, fine]);
      expect(h.canEngrave(gold, Stat.hp, dup, Stat.crit), isFalse, reason: 'crit already on it');
      expect(h.canEngrave(gold, Stat.crit, dup, Stat.crit), isTrue, reason: 'same line, better roll');
      expect(h.canEngrave(gold, Stat.hp, low, Stat.aspd), isFalse);
      expect(h.canEngrave(gold, Stat.hp, locked, Stat.aspd), isFalse);
      expect(h.canEngrave(gold, Stat.hp, fine, Stat.aspd), isFalse);
      // Only worn Hoàng Kim pieces take a mark.
      final bagGold = makeGoldItem(set: goldSets.first, slot: Slot.hat, level: 80, sect: h.sect, rng: math.Random(2));
      h.bag.add(bagGold);
      expect(h.canEngrave(bagGold, bagGold.bonus.keys.first, dup, Stat.crit), isFalse);
      h.essence = engraveCost - 1;
      expect(h.canEngrave(gold, Stat.crit, dup, Stat.crit), isFalse);
    });
  });

  group('Đổi Tinh Hoa', () {
    test('weekly limits; shards and iron come in', () {
      final h = _hero(80)..essence = 1000;
      final shard = essenceWares.firstWhere((w) => w.id == 'shard');
      final iron = essenceWares.firstWhere((w) => w.id == 'iron');
      final s0 = h.goldShards, i0 = h.divineIron;
      var n = 0;
      while (h.buyEssenceWare(shard)) {
        n++;
      }
      expect(n, shard.perWeek);
      expect(h.goldShards, s0 + shard.perWeek);
      expect(h.buyEssenceWare(iron), isTrue);
      expect(h.divineIron, i0 + 1);
      expect(h.essence, 1000 - shard.perWeek * shard.price - iron.price);
      // A new week opens the limits again.
      h.essWeek = -1;
      expect(h.essLeft(shard), shard.perWeek);
    });
  });
}
