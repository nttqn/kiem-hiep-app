import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gem_extras.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/hung_thu.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/ma_vuc.dart';
import 'package:kiem_hiep/core/nightmare.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/sects.dart' show Bonus;
import 'package:kiem_hiep/core/star_up.dart';
import 'package:kiem_hiep/core/tam_ma.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

HeroData _hero() {
  final h = HeroData(name: 'P', hanh: Hanh.hoa)
    ..rebirths = 4
    ..level = 90;
  for (final s in Slot.values) {
    h.equip[s] = makeItem(slot: s, level: 90, rarity: Rarity.legend, sect: h.sect, rng: math.Random(s.index));
  }
  h.recompute();
  return h;
}

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

/// Runs [d] for [seconds] of game time on autopilot; the world.
World _play(HeroData h, DungeonDef d, double seconds) {
  final w = World.dungeon(h, d, seed: 3)..auto = true;
  while (!w.finished && w.time < seconds) {
    w.update(1 / 30);
    w.events.clear();
  }
  return w;
}

void main() {
  group('Tâm Ma Ảo Cảnh', () {
    test('the shadow grows 5% a floor and gains twists from floor 3', () {
      expect(tamMaPower(1), tamMaBase);
      for (var f = 1; f < 60; f++) {
        expect(tamMaPower(f + 1), greaterThan(tamMaPower(f)));
      }
      expect(tamMaAffixes(1), isEmpty);
      expect(tamMaAffixes(2), isEmpty);
      expect(tamMaAffixes(3), hasLength(1));
      expect(tamMaAffixes(10), hasLength(2));
      expect(tamMaAffixes(10).toSet(), hasLength(2), reason: 'two different twists');
      final d = tamMaDef(_hero(), 12);
      expect(d.isTamMa && d.isArena, isTrue);
      expect(d.rival!.power, tamMaPower(12));
      expect(d.rival!.hanh, Hanh.hoa, reason: 'the hero\'s own sect');
    });

    test('a loss costs a try, a first clear pays once', () {
      final h = _hero();
      final rng = math.Random(1);
      h.tmRollDay(vnDayKey());
      final tries = h.tmTriesLeft;
      expect(tries, tamMaFreeTries + (h.cardActive(vnDayKey()) ? monthCardExtraRuns : 0));
      h.tamMaResult(false, 1, rng);
      expect(h.tmTriesLeft, tries - 1);
      final s0 = h.starStones;
      expect(h.tamMaResult(true, 1, rng), isNotEmpty);
      expect(h.tmBest, 1);
      expect(h.starStones, s0 + tamMaStones(1));
      expect(h.tmTriesLeft, tries - 1, reason: 'a win is free');
      expect(h.tamMaResult(true, 1, rng), ['Tầng đã vượt trước đây']);
      h.tmBest = 9;
      final souls = h.beastSouls;
      h.tamMaResult(true, 10, rng);
      expect(h.beastSouls, souls + 1, reason: 'every tenth floor');
      expect(h.tmAddAdTry(vnDayKey()), isTrue);
      expect(h.tmAddAdTry(vnDayKey()), isTrue);
      expect(h.tmAddAdTry(vnDayKey()), isFalse);
    });

    test('the duel runs and its twists act', () {
      final h = _hero();
      final w = _play(h, tamMaDef(h, 30), 20);
      final shadow = w.mobs.firstWhere((m) => m.rival != null);
      expect(shadow.def.name, 'Tâm Ma');
    });
  });

  group('Ma Vực', () {
    test('floors grow, carry one to three of the week\'s ma khí, and a boss every fifth', () {
      for (var f = 1; f < 60; f++) {
        expect(maVucMul(f + 1), greaterThan(maVucMul(f)));
      }
      const week = 3;
      final all = maVucWeekAffixes(week);
      expect(all.toSet(), hasLength(3));
      expect(maVucAffixesAt(1, week), [all[0]]);
      expect(maVucAffixesAt(10, week), all.take(2));
      expect(maVucAffixesAt(25, week), all);
      expect(maVucFloor(5, week).boss, isTrue);
      expect(maVucFloor(6, week).boss, isFalse);
      for (var f = 1; f <= 12; f++) {
        expect(mapById[maVucFloor(f, week).mapId], isNotNull);
      }
      expect(maVucWeekAffixes(4), isNot(equals(all)), reason: 'a new week, new ma khí');
    });

    test('nightmares still rotate the first four ma khí only', () {
      for (var i = 0; i < 18; i++) {
        expect(nightmareAffix(i, '20261102').index, lessThan(nightmareAffixCount));
      }
    });

    test('a floor pays the first time each week, and the climb starts over on Monday', () {
      final h = _hero();
      final rng = math.Random(2);
      expect(h.maVucReward(1, rng), isNotEmpty);
      expect(h.mvBest, 1);
      expect(h.maVucReward(1, rng), ['Tầng đã vượt tuần này']);
      final s = h.starStones;
      h.maVucReward(2, rng);
      expect(h.starStones, s + maVucStones(2));
      expect(h.maVucBoardValue, maVucScore(huntWeekOf(vnDayKey()), 2));
      h.mvWeek -= 1;
      h.mvRollWeek();
      expect(h.mvBest, 0);
      expect(h.maVucBoardValue, 0);
    });

    test('Quần ma brings more monsters, Bất tử heals them', () {
      final h = _hero();
      final d = maVucFloor(25, 3);
      final w = _play(h, d, 3);
      expect(w.affixSet.length, 3);
    });
  });

  group('Thượng Cổ Hung Thú', () {
    test('board score ranks difficulty, then speed, then the week', () {
      expect(beastScore(5, 3, 170), greaterThan(beastScore(5, 2, 20)));
      expect(beastScore(5, 2, 60), greaterThan(beastScore(5, 2, 90)));
      expect(beastScore(6, 1, 170), greaterThan(beastScore(5, 3, 10)));
    });

    test('each difficulty pays fully once a week; tries are daily', () {
      final h = _hero();
      final rng = math.Random(3);
      final day = vnDayKey();
      h.htRoll(day);
      final tries = h.htTriesLeft;
      expect(h.htStart(day), isTrue);
      expect(h.htTriesLeft, tries - 1);
      final s0 = h.starStones, souls0 = h.beastSouls;
      h.beastReward(2, 95, rng);
      expect(h.htSlain(2), isTrue);
      expect(h.starStones, s0 + beastStones[1]);
      expect(h.beastSouls, souls0 + beastSoulsFor(1));
      final s1 = h.starStones;
      h.beastReward(2, 80, rng);
      expect(h.starStones, s1, reason: 'no second full pay');
      expect(h.htScore, beastScore(h.htWeek, 2, 80), reason: 'a faster kill still counts');
      h.htWeek -= 1;
      h.htRoll(day);
      expect(h.htKilled, 0);
      expect(h.htScore, 0);
    });

    test('the beast is the week\'s, huge, and fights with telegraphed blows', () {
      final h = _hero();
      final d = beastDungeon(1, 7);
      expect(d.beastName, beastOfWeek(7).name);
      final w = _play(h, d, 12);
      final b = w.boss!;
      expect(b.def.name, beastOfWeek(7).name);
      expect(b.def.size, greaterThan(mobById[beastOfWeek(7).base]!.size));
      expect(b.maxHp, closeTo(mobHpAt(99) * beastBaseHp * beastHpMul[0], 1));
    });
  });

  group('Thăng Tinh', () {
    test('only a +10 item rises, paying stones, souls and gold', () {
      final h = _hero();
      final it = h.equip[Slot.weapon]!;
      expect(h.starBlock(it), StarBlock.notMax);
      it.plus = maxPlus;
      expect(h.starBlock(it), StarBlock.stones);
      h.starStones = 1000;
      h.beastSouls = 0;
      h.gold = 100000000;
      final p0 = h.power;
      for (var s = 0; s < 3; s++) {
        expect(h.starUp(it), isTrue);
      }
      expect(it.star, 3);
      expect(h.starBlock(it), StarBlock.souls, reason: 'the fourth star takes Tinh Phách');
      h.beastSouls = 10;
      expect(h.starUp(it), isTrue);
      expect(h.starUp(it), isTrue);
      expect(h.starBlock(it), StarBlock.maxed);
      expect(h.starStones, 1000 - starStoneCost.reduce((a, b) => a + b));
      expect(h.beastSouls, 10 - starSoulCost.reduce((a, b) => a + b));
      expect(h.power, greaterThan(p0));
      expect(h.allBonuses()[Bonus.skillDmg]!, greaterThanOrEqualTo(starLines[Slot.weapon]!.per * 5));
    });

    test('stars, materials and the endgame survive a save', () {
      final h = _hero()
        ..tmBest = 14
        ..starStones = 77
        ..beastSouls = 3;
      h.equip[Slot.ring]!
        ..plus = maxPlus
        ..star = 2;
      h.maVucReward(1, math.Random(1));
      h.beastReward(1, 120, math.Random(1));
      final b = _roundTrip(h);
      expect(b.equip[Slot.ring]!.star, 2);
      expect(b.equip[Slot.ring]!.title, endsWith('★★'));
      expect(b.tmBest, 14);
      expect(b.starStones, h.starStones);
      expect(b.beastSouls, h.beastSouls);
      expect(b.mvBest, 1);
      expect(b.htSlain(1), isTrue);
      expect(b.htScore, h.htScore);
    });
  });

  test('board rows read the endgame fields', () {
    final e = LbEntry.fromDoc('u_0', {
      'name': 'A',
      'hanh': 1,
      'level': 99,
      'power': 2000000,
      'tm': 31,
      'mv': maVucScore(2, 22),
      'ht': beastScore(2, 2, 95),
    })!;
    expect(LbBoard.tamMa.valueOf(e), 31);
    expect(LbBoard.maVuc.valueOf(e) % 1000, 22);
    expect(LbBoard.beast.valueOf(e), beastScore(2, 2, 95));
    expect(LbBoard.beast.field, 'ht');
  });
  group('Ngọc (1.8.0)', () {
    test('Hợp tất cả fuses every tier up to the one chosen, carrying upward', () {
      final h = _hero()..gold = 10000000;
      h.addGem(const Gem(Hanh.kim, 1), 9);
      h.addGem(const Gem(Hanh.kim, 2), 1);
      h.addGem(const Gem(Hanh.moc, 1), 5);
      final plan = h.fusePlan(3);
      // Kim: 9 → 3 tier 2 (+1 = 4) → 1 tier 3; Mộc: 5 → 1 tier 2, none at 3.
      expect(plan.fuses, 3 + 1 + 1);
      expect(plan.made, {Hanh.kim: 1});
      expect(plan.gold, 4 * fuseCost(1) + fuseCost(2));
      final g0 = h.gold;
      expect(h.fuseAll(3), isTrue);
      expect(h.gold, g0 - plan.gold);
      expect(h.gemCount(const Gem(Hanh.kim, 3)), 1);
      expect(h.gemCount(const Gem(Hanh.kim, 2)), 1);
      expect(h.gemCount(const Gem(Hanh.moc, 2)), 1);
      expect(h.gemCount(const Gem(Hanh.moc, 1)), 2);
      expect(h.fusePlan(3, only: Hanh.tho).fuses, 0);
      h.gold = 0;
      h.addGem(const Gem(Hanh.thuy, 1), 3);
      expect(h.fuseAll(2), isFalse, reason: 'no gold');
    });

    test('Chuyển hệ: two for one of another phase, same tier', () {
      final h = _hero()..gold = 1000000;
      h.addGem(const Gem(Hanh.kim, 5), 7);
      expect(h.convertGem(const Gem(Hanh.kim, 5), Hanh.kim, 1), isFalse);
      expect(h.convertGem(const Gem(Hanh.kim, 5), Hanh.hoa, 3), isTrue);
      expect(h.gemCount(const Gem(Hanh.kim, 5)), 1);
      expect(h.gemCount(const Gem(Hanh.hoa, 5)), 3);
      expect(h.convertGem(const Gem(Hanh.kim, 5), Hanh.hoa, 1), isFalse, reason: 'one left');
    });

    test('Luyện hóa: Thần/Tiên/Thánh into Tinh Thạch, 50 a week', () {
      final h = _hero();
      h.addGem(const Gem(Hanh.tho, 5), 1000);
      h.addGem(const Gem(Hanh.tho, 4), 100);
      expect(h.refineGems(const Gem(Hanh.tho, 4), 1), isFalse, reason: 'tier 4 does not refine');
      final s0 = h.starStones;
      expect(h.refineGems(const Gem(Hanh.tho, 5), 30), isTrue);
      expect(h.gemCount(const Gem(Hanh.tho, 5)), 700);
      expect(h.starStones, s0 + 30);
      expect(h.gemStonesLeft, gemStonesPerWeek - 30);
      expect(h.refineGems(const Gem(Hanh.tho, 5), 21), isFalse, reason: 'over the week');
      expect(h.refineGems(const Gem(Hanh.tho, 5), 20), isTrue);
      expect(h.gemStonesLeft, 0);
      h.gsWeek -= 1;
      expect(h.gemStonesLeft, gemStonesPerWeek, reason: 'a new week');
      expect(_roundTrip(h).gsMade, 0);
    });

    test('Đục lỗ: a fourth socket at ★3, a fifth at ★5, paid in Thần gems', () {
      final h = _hero()..gold = 100000000;
      final it = h.equip[Slot.armor]!
        ..plus = maxPlus
        ..star = 2;
      final base = it.gems.length;
      expect(h.drillBlock(it), DrillBlock.stars);
      it.star = 3;
      expect(h.drillBlock(it), DrillBlock.gems);
      h.addGem(const Gem(Hanh.kim, 5), 20);
      h.addGem(const Gem(Hanh.moc, 5), 50);
      h.addGem(const Gem(Hanh.hoa, 5), 100);
      expect(h.drillSocket(it), isTrue);
      expect(it.gems.length, base + 1);
      expect(h.gemCount(const Gem(Hanh.hoa, 5)), 100, reason: 'own phase (Hỏa) spent last');
      expect(h.gemCount(const Gem(Hanh.moc, 5)), 20, reason: 'the largest other stack first');
      expect(h.drillBlock(it), DrillBlock.stars, reason: 'the fifth needs ★5');
      it.star = 5;
      expect(h.drillSocket(it), isTrue);
      expect(it.gems.length, base + 2);
      expect(h.drillBlock(it), DrillBlock.maxed);
      expect(h.socketGem(it, base + 1, const Gem(Hanh.hoa, 5)), isTrue);
      final b = _roundTrip(h);
      expect(b.equip[Slot.armor]!.gems.length, base + 2);
      expect(b.equip[Slot.armor]!.gems[base + 1], const Gem(Hanh.hoa, 5));
    });
  });
}
