import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/week_goals.dart';

HeroData roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  group('Mục tiêu 7 ngày', () {
    test('21 goals, three a day, ids unique', () {
      expect(weekGoals.length, 21);
      expect(weekGoalById.length, 21);
      for (var d = 1; d <= 7; d++) {
        expect(weekGoals.where((g) => g.day == d).length, 3);
      }
    });

    test('a goal opens on its day and pays once when reached', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)
        ..bornDay = '20261101'
        ..level = 20;
      final g = weekGoalById['d3lv']!;
      expect(h.canClaimWeekGoal(g, '20261102'), isFalse, reason: 'day 2');
      expect(h.canClaimWeekGoal(g, '20261103'), isTrue);
      final gold = h.gold;
      expect(h.claimWeekGoal(g, '20261103', math.Random(1)), isNotEmpty);
      expect(h.gold, gold + g.gold);
      expect(h.claimWeekGoal(g, '20261103', math.Random(1)), isEmpty);
      expect(h.canClaimWeekGoal(weekGoalById['d4lv']!, '20261110'), isFalse, reason: 'level 25 not reached');
    });

    test('older heroes do not get them; the chest closes them', () {
      final old = HeroData(name: 'T', hanh: Hanh.kim);
      expect(old.weekGoalsOpen('20261101'), isFalse);
      final h = HeroData(name: 'T', hanh: Hanh.kim)
        ..bornDay = '20261101'
        ..rebirths = 1;
      for (final g in weekGoals) {
        h.weekClaimed.add(g.id);
      }
      expect(h.canClaimWeekChest('20261101'), isTrue);
      final iron = h.divineIron;
      expect(h.claimWeekChest('20261101', math.Random(1)), isNotEmpty);
      expect(h.divineIron, iron + weekChestIron);
      expect(h.weekGoalsOpen('20261101'), isFalse);
      final back = roundTrip(h);
      expect(back.weekChest, isTrue);
      expect(back.weekClaimed.length, 21);
    });
  });

  group('Thưởng hạng mùa Lôi đài', () {
    test('settling a season keeps its score and waits for the rank', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)
        ..level = 40
        ..arenaSeason = 1
        ..arenaSeasonFights = 3
        ..arenaPoints = 1500;
      expect(h.arenaRollSeason('20261109'), isTrue);
      expect(h.arenaLastScore, arenaSeasonScore(1, 1500));
      expect(h.arenaRankDue, isTrue);
      final back = roundTrip(h);
      expect(back.arenaLastScore, h.arenaLastScore);
      expect(back.arenaRankDue, isTrue);
    });

    test('the top pays once, with a title; others just close it', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..arenaRankDue = true;
      final coins = h.arenaCoins;
      final lines = h.payArenaRank(1);
      expect(lines.last, contains('Lôi Đài Bá Chủ'));
      expect(h.arenaCoins, coins + 1500);
      expect(h.seasonTitles, contains('Lôi Đài Bá Chủ'));
      expect(h.payArenaRank(1), isEmpty, reason: 'once');
      final far = HeroData(name: 'T', hanh: Hanh.kim)..arenaRankDue = true;
      expect(far.payArenaRank(51), isEmpty);
      expect(far.arenaRankDue, isFalse);
      expect(roundTrip(h).seasonTitles, contains('Lôi Đài Bá Chủ'));
    });

    test('rank brackets', () {
      expect(arenaRankReward(3)!.title, 'Lôi Đài Tam Hùng');
      expect(arenaRankReward(10)!.title, 'Lôi Đài Thập Kiệt');
      expect(arenaRankReward(50)!.title, isEmpty);
      expect(arenaRankReward(51), isNull);
    });
  });
}
