import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/treasure.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart';

HeroData at(Hanh hanh, int level) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.autoSpend();
  h.autoLearn();
  return h;
}

void main() {
  group('Boss Thế Giới', () {
    test('the boss and the day follow Vietnam time', () {
      // 23:30 UTC on the 23rd is already the 24th in Vietnam.
      expect(vnDayKey(DateTime.utc(2026, 10, 23, 23, 30)), '20261024');
      expect(vnDayKey(DateTime.utc(2026, 10, 23, 16, 59)), '20261023');
      final a = worldBossOf(DateTime.utc(2026, 10, 24, 1));
      final b = worldBossOf(DateTime.utc(2026, 10, 25, 1));
      expect(a.boss && b.boss, isTrue);
      expect(a.id, isNot(b.id), reason: 'a new boss each day');
      expect(worldBossDef().isWorldBoss, isTrue);
    });

    test('three free runs, two more by ad, all reset the next day', () {
      final h = at(Hanh.kim, 40);
      for (var i = 0; i < worldBossFreeTries; i++) {
        expect(h.wbStartRun('20261024'), isTrue);
      }
      expect(h.wbStartRun('20261024'), isFalse);
      expect(h.wbAddAdRun('20261024'), isTrue);
      expect(h.wbAddAdRun('20261024'), isTrue);
      expect(h.wbAddAdRun('20261024'), isFalse);
      expect(h.wbRunsLeft, 2);
      expect(h.wbStartRun('20261025'), isTrue, reason: 'new day');
      expect(h.wbRunsLeft, worldBossFreeTries - 1);
    });

    test('a run cannot kill the boss, scores damage, and ends at the time limit', () {
      final h = at(Hanh.hoa, 60);
      h.wbStartRun(vnDayKey());
      final w = World.dungeon(h, worldBossDef(), seed: 3)..auto = true;
      var cleared = false;
      while (!w.finished && w.time < 75) {
        w.update(1 / 30);
        cleared |= w.events.any((e) => e.kind == EvKind.cleared);
        w.events.clear();
      }
      expect(cleared, isTrue);
      expect(w.boss!.alive, isTrue);
      expect(w.bossDamage, greaterThan(10000));
      expect(w.finishTime, lessThanOrEqualTo(worldBossTime + 0.05));
      expect(h.wbTotal, w.bossDamage.round());
      expect(w.rewardLines.first, startsWith('Sát thương'));
    });

    test('milestones pay once each, and the day survives a save', () {
      final h = at(Hanh.thuy, 50);
      h.wbRollDay('20261024');
      h.worldBossReward(worldBossMilestones[1] + 5, math.Random(1));
      expect(h.wbCanClaim(0) && h.wbCanClaim(1), isTrue);
      expect(h.wbCanClaim(2), isFalse);
      final gold = h.gold;
      expect(h.wbClaim(1, math.Random(2))!.tier, worldBossMilestoneGem[1]);
      expect(h.gold, gold + worldBossMilestoneGold(1));
      expect(h.wbClaim(1, math.Random(2)), isNull);
      final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(copy.wbTotal, h.wbTotal);
      expect(copy.wbCanClaim(1), isFalse);
      expect(copy.wbCanClaim(0), isTrue);
    });
  });

  group('Tẩy luyện', () {
    test('locked lines stay, the rest change, gold is spent', () {
      final h = at(Hanh.moc, 50)..gold = 1000000;
      final it = makeItem(slot: Slot.ring, level: 50, rarity: Rarity.legend, sect: h.sect, rng: math.Random(4));
      h.addItem(it);
      h.equipItem(it);
      final keep = it.bonus.keys.first;
      final kept = it.bonus[keep];
      final n = it.bonus.length;
      final gold = h.gold;
      var changed = false;
      for (var i = 0; i < 10; i++) {
        final before = Map.of(it.bonus);
        expect(h.refine(it, {keep}, math.Random(i)), isTrue);
        expect(it.bonus.length, n);
        expect(it.bonus[keep], kept);
        changed |= before.toString() != it.bonus.toString();
      }
      expect(changed, isTrue);
      expect(h.gold, lessThan(gold));
      expect(refineCost(it, 2), greaterThan(refineCost(it, 0)));
      expect(h.refine(it, it.bonus.keys.toSet(), math.Random(1)), isFalse, reason: 'must leave one line free');
      final common = makeItem(slot: Slot.hat, level: 50, rarity: Rarity.common, sect: h.sect, rng: math.Random(1));
      expect(h.refine(common, {}, math.Random(1)), isFalse);
    });
  });

  group('Kỳ Trân Các', () {
    test('six offers a day, stable until refreshed; buying once each', () {
      final h = at(Hanh.tho, 70)..gold = 5000000;
      final a = h.treasureOffers('20261024');
      expect(a.length, 6);
      expect(a.where((o) => o.gem != null).length, 3);
      expect(a.first.gem!.hanh, h.hanh, reason: 'one gem of the own phase');
      expect(h.treasureOffers('20261024').map((o) => o.price), a.map((o) => o.price));
      final gems = h.gemBag.values.fold<int>(0, (s, v) => s + v);
      expect(h.treasureBuy('20261024', 0), isTrue);
      expect(h.treasureBuy('20261024', 0), isFalse);
      expect(h.gemBag.values.fold<int>(0, (s, v) => s + v), gems + 1);
      final bag = h.bag.length;
      expect(h.treasureBuy('20261024', 5), isTrue);
      expect(h.bag.length, bag + 1);
      final g = h.gold;
      expect(h.treasureRefresh('20261024'), isTrue);
      expect(h.gold, g - treasureRefreshCost(0));
      expect(h.shopBought, isEmpty);
      expect(h.treasureRefresh('20261024', free: true), isTrue);
      expect(h.gold, g - treasureRefreshCost(0), reason: 'the ad refresh is free');
      // A new day starts over.
      h.treasureOffers('20261025');
      expect(h.shopRefresh, 0);
      final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(copy.shopDay, '20261025');
    });
  });
}
