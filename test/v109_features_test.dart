import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/activity.dart';
import 'package:kiem_hiep/core/alchemy.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart';

HeroData at(Hanh hanh, int level) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.autoSpend();
  h.autoLearn();
  h.notices.clear();
  return h;
}

void main() {
  group('Thú cưỡi', () {
    test('bought from level 10, ridden for speed and a stat, fed with gold', () {
      final low = at(Hanh.kim, 5)..gold = 1000000;
      expect(low.buyMount(mounts.first), isFalse, reason: 'level 10 needed');
      final h = at(Hanh.kim, 30)..gold = 1000000;
      final walk = h.stats.move;
      final hp = h.stats.maxHp;
      expect(h.buyMount(mountById['nau']!), isTrue);
      expect(h.ridingMount?.id, 'nau');
      expect(h.stats.move, greaterThan(walk * 1.14));
      expect(h.stats.maxHp, greaterThan(hp));
      expect(h.feedMount(mountById['nau']!), isTrue);
      expect(h.mountLevels['nau'], 2);
      h.rideMount('nau');
      expect(h.ridingMount, isNull, reason: 'second tap gets off');
      expect(h.stats.move, closeTo(walk, 0.01));
    });

    test('tower, rebirth and Uy danh mounts are earned, not bought', () {
      final h = at(Hanh.thuy, 60)..gold = 10000000;
      expect(h.buyMount(mountById['hanhuyet']!), isFalse);
      h.towerBest = 39;
      h.towerReward(40, math.Random(1));
      expect(h.ownsMount('hanhuyet'), isTrue);
      h.arenaCoins = 4000;
      final tiger = arenaShop(h.level).firstWhere((o) => o.id == 'bachho');
      expect(h.arenaBuy(tiger, math.Random(1)), isTrue);
      expect(h.ownsMount('bachho'), isTrue);
      expect(h.arenaBuy(tiger, math.Random(1)), isFalse);
    });
  });

  group('Luyện đan', () {
    test('herbs and gold become pills; buffs last only while playing', () {
      final h = at(Hanh.hoa, 40)..gold = 100000;
      final p = pillById['cuongluc']!;
      expect(h.canCraft(p), isFalse);
      h.addHerb(1, 4);
      h.addHerb(2, 2);
      expect(h.craft(p), isTrue);
      expect(h.herbs[1], 0);
      expect(h.pills['cuongluc'], 1);
      final atk = h.stats.atk;
      expect(h.usePill(p), isTrue);
      expect(h.stats.atk, closeTo(atk * (1 + 0.15) / 1, atk * 0.2));
      expect(h.stats.atk, greaterThan(atk));
      h.tickBuffs(p.minutes * 60 - 1);
      expect(h.buffLeft('cuongluc'), greaterThan(0));
      expect(h.tickBuffs(2), isTrue);
      expect(h.stats.atk, closeTo(atk, 0.01));
    });

    test('Song Bội Đan doubles monster EXP; Tẩy Tủy Đan is capped', () {
      final h = at(Hanh.moc, 30);
      expect(h.expMul, 1);
      h.pills['songboi'] = 1;
      h.usePill(pillById['songboi']!);
      expect(h.expMul, expPillMul);
      h.pills['taytuy'] = maxPotentialPills + 2;
      final free = h.freePoints;
      var eaten = 0;
      while (h.usePill(pillById['taytuy']!)) {
        eaten++;
      }
      expect(eaten, maxPotentialPills);
      expect(h.freePoints, free + maxPotentialPills * potentialPerPill);
    });

    test('field maps grow herbs of their tier that the hero picks up', () {
      final h = at(Hanh.kim, 30);
      final map = maps[2];
      final w = World.field(h, map, seed: 1);
      expect(w.herbs, hasLength(herbNodes));
      final n = w.herbs.first;
      w.player
        ..x = n.x
        ..y = n.y;
      w.update(1 / 30);
      expect(h.herbs[herbTierOfMap(2)], 1);
      w.update(1 / 30);
      expect(h.herbs[herbTierOfMap(2)], 1, reason: 'regrows later');
    });
  });

  group('Lôi đài', () {
    test('five duels a day plus three by ad; points move with the rival', () {
      final h = at(Hanh.tho, 40);
      for (var i = 0; i < arenaFreeFights; i++) {
        expect(h.arenaStart('20261027'), isTrue);
      }
      expect(h.arenaStart('20261027'), isFalse);
      expect(h.arenaAddAdFight('20261027'), isTrue);
      expect(h.arenaFightsLeft, 1);
      final strong = ArenaRival(name: 'X', hanh: Hanh.kim, level: 40, rebirths: 0, power: h.power * 2);
      h.arenaResult(true, strong);
      expect(h.arenaPoints, arenaStartPoints + arenaWinPoints(2));
      expect(h.arenaCoins, arenaWinCoins);
      final weak = ArenaRival(name: 'Y', hanh: Hanh.kim, level: 40, rebirths: 0, power: h.power ~/ 2);
      h.arenaResult(false, weak);
      expect(h.arenaPoints, arenaStartPoints + arenaWinPoints(2) - arenaLossPoints(0.5));
      expect(h.arenaClaimSalary('20261027'), isTrue);
      expect(h.arenaClaimSalary('20261027'), isFalse);
    });

    test('challengers come from the board near the hero, else invented', () {
      final bots = botRivals(power: 1000, level: 40, rebirths: 0, seed: 1);
      expect(bots.map((b) => b.bot), everyElement(isTrue));
      expect(bots[0].power, lessThan(bots[2].power));
      const real = ArenaRival(name: 'Thật', hanh: Hanh.moc, level: 41, rebirths: 0, power: 1020);
      const far = ArenaRival(name: 'Xa', hanh: Hanh.moc, level: 90, rebirths: 2, power: 9000);
      final picked = pickRivals([real, far], bots, 1000, 5);
      expect(picked, hasLength(3));
      expect(picked[1].name, 'Thật');
      expect(picked.any((r) => r.name == 'Xa'), isFalse);
    });

    test('a duel ends in a win or a loss and settles once', () {
      final h = at(Hanh.kim, 50)..hpPots = 20;
      final r = ArenaRival(name: 'Z', hanh: Hanh.thuy, level: 50, rebirths: 0, power: (h.power * 0.5).round());
      final w = World.dungeon(h, arenaDef(r), seed: 2)..auto = true;
      var won = false;
      while (!w.finished) {
        w.update(1 / 30);
        won |= w.events.any((e) => e.kind == EvKind.cleared);
        w.events.clear();
      }
      expect(won, isTrue, reason: 'a rival at half the power');
      expect(w.arenaPotsUsed, lessThanOrEqualTo(arenaPotions));
      expect(h.arenaPoints, greaterThan(arenaStartPoints));
      expect(h.kills, 0, reason: 'a duel is no monster kill');
    });
  });

  group('Năng động', () {
    test('sources are capped per day; points add up for the week', () {
      final h = at(Hanh.kim, 30);
      h.addActivity(ActSource.dungeon, 10);
      expect(h.actPointsOf(ActSource.dungeon), actSources[ActSource.dungeon]!.cap);
      h.addActivity(ActSource.kills, 59);
      expect(h.actPointsOf(ActSource.kills), 2, reason: 'per 30 kills');
      expect(h.actWeekPoints, h.actPoints);
      expect(h.actCanClaim(0), isTrue);
      final gold = h.gold;
      expect(h.actClaim(0, math.Random(1)), isNotEmpty);
      expect(h.gold, greaterThan(gold));
      expect(h.actClaim(0, math.Random(1)), isNull);
    });

    test('a new day clears the day but keeps the week until Monday', () {
      expect(weekKeyOf('20261027'), '20261026');
      expect(weekKeyOf('20261101'), '20261026');
      expect(weekKeyOf('20261102'), '20261102');
      final h = at(Hanh.kim, 30);
      h.actRollDay('20261027');
      h.actCounts[ActSource.arena] = 5;
      h.actWeekPoints = 25;
      h.actRollDay('20261028');
      expect(h.actPoints, 0);
      expect(h.actWeekPoints, 25);
      h.actRollDay('20261102');
      expect(h.actWeekPoints, 0);
    });

    test('everyday play feeds it: kills, dungeons, bounties, world boss', () {
      final h = at(Hanh.kim, 30);
      h.actRollDay(vnDayKey());
      h.worldBossReward(1000, math.Random(1));
      h.onDungeonClear('a1', 3, math.Random(1));
      expect(h.actPointsOf(ActSource.worldBoss), 10);
      expect(h.actPointsOf(ActSource.dungeon), 10);
    });
  });

  test('new systems survive a save round trip', () {
    final h = at(Hanh.thuy, 45)..gold = 1000000;
    h.buyMount(mountById['bachma']!);
    h.feedMount(mountById['bachma']!);
    h.riding = false;
    h.addHerb(3, 7);
    h.pills['kimcang'] = 2;
    h.buffs['tubao'] = 300;
    h.potentialPills = 4;
    h.arenaPoints = 1333;
    h.arenaCoins = 77;
    h.arenaRollDay('20261027');
    h.arenaStart('20261027');
    h.arenaSalaryDay = '20261027';
    h.addActivity(ActSource.arena, 2);
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.mountLevels, {'bachma': 2});
    expect(back.activeMount, 'bachma');
    expect(back.riding, isFalse);
    expect(back.herbs[3], 7);
    expect(back.pills, {'kimcang': 2});
    expect(back.buffLeft('tubao'), 300);
    expect(back.potentialPills, 4);
    expect(back.arenaPoints, 1333);
    expect(back.arenaCoins, 77);
    expect(back.arenaFights, 1);
    expect(back.arenaSalaryDay, '20261027');
    expect(back.actCounts[ActSource.arena], 2);
    expect(back.actWeekPoints, h.actWeekPoints);
  });
}
