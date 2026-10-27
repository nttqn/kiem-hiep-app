import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/companions.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/gold_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/tower.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart';

HeroData at(Hanh hanh, int level, {bool gear = false}) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  if (gear) {
    final rng = math.Random(level);
    for (final s in Slot.values) {
      h.addItem(makeItem(slot: s, level: level, rarity: Rarity.rare, sect: h.sect, rng: rng));
    }
    h.autoEquip();
  }
  h.autoSpend();
  h.autoLearn();
  h.hpPots = 99;
  h.mpPots = 99;
  h.notices.clear();
  return h;
}

HeroData roundTrip(HeroData h) =>
    HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

/// Seconds the autopilot takes to clear [d] (or its time limit).
double clearTime(HeroData h, DungeonDef d, int seed) {
  final w = World.dungeon(h, d, seed: seed)..auto = true;
  while (!w.finished) {
    w.update(1 / 30);
  }
  return w.finishTime == 0 ? d.timeLimit : w.finishTime;
}

void main() {
  group('Hoàng Kim', () {
    test('pieces beat Truyền thuyết, keep their set through a save and count toward bonuses', () {
      final rng = math.Random(1);
      final set = goldSetById['hoa']!;
      final it = makeGoldItem(set: set, slot: Slot.weapon, level: 70, sect: sectOf(Hanh.hoa), rng: rng);
      final legend = makeItem(slot: Slot.weapon, level: 70, rarity: Rarity.legend, sect: sectOf(Hanh.hoa), rng: rng);
      expect(it.golden, isTrue);
      expect(it.base[Stat.atk]!, greaterThan(legend.base[Stat.atk]!));
      expect(it.bonus, hasLength(legend.bonus.length));
      expect(it.gems, hasLength(legend.gems.length));
      expect(it.rarityLabel, 'Hoàng Kim');
      final back = Item.fromJson(jsonDecode(jsonEncode(it.toJson())) as Map<String, dynamic>);
      expect(back.set, 'hoa');
      expect(Item.fromJson(legend.toJson()).golden, isFalse);

      expect(goldSetBonuses({'hoa': 1}), isEmpty);
      expect(goldSetBonuses({'hoa': 2}), {Bonus.critDmg: 0.25});
      expect(goldSetBonuses({'hoa': 4}).keys, containsAll([Bonus.critDmg, Bonus.atkPct]));
      expect(fullGoldSet({'hoa': 6}), isNull);
      expect(fullGoldSet({'hoa': 7}), set);
    });

    test('forged from shards at level 60+, worn sets raise stats, reforged at a higher level', () {
      final low = at(Hanh.kim, 40)..goldShards = 500;
      expect(low.forgeGold(goldSets.first, Slot.hat, math.Random(1)), isNull, reason: 'opens at 60');
      final h = at(Hanh.kim, 60)..goldShards = 1000;
      final rng = math.Random(2);
      final before = h.stats.def;
      for (final s in Slot.values) {
        final it = h.forgeGold(goldSetById['kim']!, s, rng)!;
        expect(it.level, 60);
        h.equipItem(it);
      }
      expect(h.goldShards, 1000 - 40 - 6 * 25);
      expect(goldPieces(h.equip.values), {'kim': 7});
      expect(h.stats.def, greaterThan(before));
      expect(h.allBonuses()[Bonus.defPct], greaterThanOrEqualTo(0.10));

      while (h.level < 80) {
        h.gainExp(h.expNeeded.toDouble());
      }
      final w = h.equip[Slot.weapon]!..plus = 5;
      final g = Gem(Hanh.kim, 3);
      h.addGem(g);
      h.socketGem(w, 0, g);
      final shards = h.goldShards;
      final again = h.reforgeGold(w)!;
      expect(again.level, 80);
      expect(again.plus, 5);
      expect(again.gems.first, g);
      expect(again.set, 'kim');
      expect(again.base[Stat.atk]!, greaterThan(w.base[Stat.atk]!));
      expect(h.equip[Slot.weapon], same(again));
      expect(h.goldShards, shards - goldReforgeCost(Slot.weapon));
      expect(h.reforgeGold(again), isNull, reason: 'already at the hero level');
    });

    test('the full set sets off its burst in a fight', () {
      final h = at(Hanh.hoa, 70, gear: true);
      final rng = math.Random(3);
      for (final s in Slot.values) {
        h.equip[s] = makeGoldItem(set: goldSetById['moc']!, slot: s, level: 70, sect: h.sect, rng: rng);
      }
      h.recompute();
      final w = World.field(h, maps[5], seed: 4)..auto = true;
      var bursts = 0;
      for (var i = 0; i < 30 * 60 && bursts == 0; i++) {
        w.update(1 / 30);
        bursts += w.zones.where((z) => z.fx == 'poisonCloud' && z.r == goldBurstRadius).length;
      }
      expect(bursts, greaterThan(0));
    });

    test('shards come from tower floors 40+, Boss Thế Giới milestones and weekly chests', () {
      final h = at(Hanh.thuy, 70)..towerBest = 38;
      h.towerReward(39, math.Random(1));
      expect(h.goldShards, 0);
      h.towerReward(40, math.Random(1));
      expect(h.goldShards, 6);
      h.wbRollDay(vnDayKey());
      h.wbTotal = worldBossMilestones.last;
      for (var i = 0; i < worldBossMilestones.length; i++) {
        h.wbClaim(i, math.Random(i));
      }
      expect(h.goldShards, 6 + worldBossGoldShards.reduce((a, b) => a + b));
      final s = h.goldShards;
      h.actWeekPoints = 5000;
      h.actWeek = '';
      h.actRollDay(vnDayKey());
      h.actWeekPoints = 5000;
      h.actClaim(3, math.Random(1), weekly: true);
      expect(h.goldShards, s + 10);
      expect(roundTrip(h).goldShards, h.goldShards);
    });
  });

  group('Mùa giải Lôi đài', () {
    test('seasons are two weeks from Monday 26/10/2026', () {
      expect(arenaSeasonOf('20261026'), 1);
      expect(arenaSeasonOf('20261108'), 1);
      expect(arenaSeasonOf('20261109'), 2);
      expect(arenaSeasonDaysLeft('20261026'), 14);
      expect(arenaSeasonDaysLeft('20261108'), 1);
      expect(arenaSeasonOf('20260101'), 1, reason: 'before the first season');
      expect(arenaSeasonScore(2, 1500), greaterThan(arenaSeasonScore(1, 2400)));
    });

    test('a season pays by tier only after a fight, and points fall halfway back', () {
      final h = at(Hanh.hoa, 60);
      h.arenaRollDay('20261027');
      expect(h.arenaSeason, 1);
      h.arenaPoints = 1800;
      h.arenaRollDay('20261110');
      expect(h.arenaSeasonResult, isEmpty, reason: 'no fight, no pay');
      expect(h.arenaPoints, 1800, reason: 'only a season fought in resets points');

      h.arenaPoints = 1800;
      h.arenaResult(true, const ArenaRival(name: 'R', hanh: Hanh.kim, level: 60, rebirths: 0, power: 1));
      final pts = h.arenaPoints;
      final tier = h.arenaTier;
      final coins = h.arenaCoins;
      final shards = h.goldShards;
      h.arenaRollDay('20261124');
      expect(h.arenaSeason, 3);
      expect(h.arenaSeasonResult.take(3), [2, tier, pts]);
      expect(h.arenaCoins, coins + arenaSeasonReward(tier, 60).coins);
      expect(h.goldShards, shards + arenaSeasonReward(tier, 60).shards);
      expect(h.arenaPoints, arenaSeasonReset(pts));
      expect(h.arenaBestTier, tier);
      expect(h.ownedCostumes.contains('loidai'), tier >= 4);
      expect(h.arenaSeasonLines(), isNotEmpty);

      final back = roundTrip(h);
      expect(back.arenaSeason, 3);
      expect(back.arenaBestTier, tier);
      expect(back.arenaSeasonResult, h.arenaSeasonResult);
    });

    test('ending a season at Võ Lâm Chí Tôn unlocks both arena outfits', () {
      final h = at(Hanh.tho, 80);
      h.arenaRollDay('20261027');
      h.arenaPoints = 2500;
      h.arenaSeasonFights = 3;
      h.arenaRollDay('20261110');
      expect(h.arenaBestTier, arenaTiers.length - 1);
      expect(h.ownedCostumes, containsAll(['loidai', 'chiton']));
      expect(h.arenaPoints, arenaSeasonReset(2500));
    });
  });

  group('Hiệp khách', () {
    test('met by level, hired for gold, befriended with gifts, saved', () {
      final h = at(Hanh.kim, 35)..gold = 10000000;
      final lam = companionById['lamdiep']!;
      final macliet = companionById['macliet']!;
      expect(h.hireCompanion(macliet), isFalse, reason: 'met at level 50');
      expect(h.hireCompanion(lam), isTrue);
      expect(h.activeCompanion, 'lamdiep');
      expect(h.allBonuses()[Bonus.dotPct], greaterThanOrEqualTo(lam.bonusAt(1)));
      for (var i = 1; i < maxBond; i++) {
        expect(h.giftCompanion(lam), isTrue);
      }
      expect(h.companionBonds['lamdiep'], maxBond);
      expect(h.giftCompanion(lam), isFalse);
      final back = roundTrip(h);
      expect(back.companionBonds, {'lamdiep': maxBond});
      expect(back.activeCompanion, 'lamdiep');
      h.setActiveCompanion('lamdiep');
      expect(h.activeCompanion, '');
    });

    test('they come along in the field and dungeons, not tower, Lôi đài or Boss Thế Giới', () {
      final h = at(Hanh.thuy, 60)..gold = 1000000;
      h.hireCompanion(companionById['tueminh']!);
      expect(World.field(h, maps[4], seed: 1).companion, isNotNull);
      expect(World.dungeon(h, dungeons[5], seed: 1).companion, isNotNull);
      expect(World.dungeon(h, towerFloor(3), seed: 1).companion, isNull);
      expect(World.dungeon(h, worldBossDef(), seed: 1).companion, isNull);
      const r = ArenaRival(name: 'R', hanh: Hanh.kim, level: 60, rebirths: 0, power: 100);
      expect(World.dungeon(h, arenaDef(r), seed: 1).companion, isNull);
    });

    test('a hiệp khách at full hảo cảm clears dungeons clearly faster', () {
      for (final hanh in [Hanh.kim, Hanh.thuy]) {
        final d = dungeons.firstWhere((d) => d.level >= 40);
        var alone = 0.0, along = 0.0;
        for (var s = 0; s < 3; s++) {
          alone += clearTime(at(hanh, d.level, gear: true), d, s);
          final h = at(hanh, d.level, gear: true);
          for (final c in companions) {
            h.companionBonds[c.id] = maxBond;
          }
          h.activeCompanion = companions[(hanh.index + 3) % 5].id;
          h.recompute();
          along += clearTime(h, d, s);
        }
        // ignore: avoid_print
        print('${hanh.name}: alone ${(alone / 3).toStringAsFixed(1)} s, with hiệp khách ${(along / 3).toStringAsFixed(1)} s');
        expect(along, lessThan(alone * 0.92));
      }
    });
  });
}
