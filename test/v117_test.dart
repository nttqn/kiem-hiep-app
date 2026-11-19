import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/comeback.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/festival.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/quest_go.dart';
import 'package:kiem_hiep/core/reminders.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

HeroData _hero(int level, {int cs = 0, String login = '2026-11-1'}) => HeroData(name: 'N', hanh: Hanh.kim)
  ..level = level
  ..rebirths = cs
  ..lastLoginDate = login;

void main() {
  group('Quà hồi quy', () {
    test('days count across both key styles', () {
      expect(daysBetween('2026-11-1', '20261106'), 5);
      expect(daysBetween('20261130', '2026-12-2'), 2);
      expect(daysBetween('2026-11-9', '2026-11-19'), 10, reason: 'unpadded keys sort wrong as text');
      expect(daysBetween('20261119', '20261101'), 0);
      expect(daysBetween('', '20261101'), 0);
      expect(parseDay('rác'), isNull);
    });

    test('away is counted over every hero on the phone', () {
      final a = _hero(50, login: '2026-11-9');
      final b = _hero(50, login: '2026-11-19');
      expect(lastLoginOf([a, null, b]), '2026-11-19');
      expect(comebackDue(a, lastLoginOf([a, b]), '20261120'), 0, reason: 'b played yesterday');
      expect(comebackDue(a, lastLoginOf([a]), '20261120'), 1);
    });

    test('tiers by days away; new and barely-started heroes get none', () {
      for (final (days, tier) in [(4, 0), (5, 1), (13, 1), (14, 2), (29, 2), (30, 3), (200, 3)]) {
        expect(comebackTier(days), tier, reason: '$days days');
      }
      expect(comebackDue(_hero(50, login: ''), '2026-11-1', '20261201'), 0);
      expect(comebackDue(_hero(4), '2026-11-1', '20261201'), 0);
      expect(comebackDue(_hero(4, cs: 1), '2026-11-1', '20261201'), 3);
    });

    test('the gift pays once a month and its boost lasts tier+1 days', () {
      final h = _hero(70);
      final gold0 = h.gold, pots0 = h.hpPots;
      final lines = takeComeback(h, 2, '20261120');
      expect(lines, isNotEmpty);
      expect(h.gold - gold0, 3000 * 80 * 2);
      expect(h.hpPots - pots0, 60);
      expect(h.pills['songboi'], 2);
      expect(h.starStones, 0, reason: 'endgame materials from level 80 or a rebirth');
      expect(h.comebackUntil, '20261122');
      expect(comebackOn(h, '20261122'), isTrue);
      expect(comebackOn(h, '20261123'), isFalse);
      // Away again a week later: still inside the 30-day cooldown.
      expect(comebackDue(h, '2026-11-20', '20261201'), 0);
      expect(comebackDue(h, '2026-12-15', '20261220'), 1);
      final back = _roundTrip(h);
      expect((back.comebackDay, back.comebackUntil), ('20261120', '20261122'));
      expect(_roundTrip(_hero(10)).comebackDay, '');
    });

    test('reborn heroes also get endgame materials', () {
      final h = _hero(99, cs: 3);
      takeComeback(h, 3, '20261120');
      expect((h.starStones, h.divineIron, h.goldShards), (15, 9, 6));
    });

    test('the boost lifts monster EXP and gold by half while it runs', () {
      final h = _hero(40);
      h.recompute();
      final exp0 = h.expMul, gold0 = h.goldMul;
      h.comebackUntil = dayAfter(vnDayKey(), 1);
      expect(h.expMul, closeTo(exp0 * (1 + comebackExp), 1e-9));
      expect(h.goldMul, closeTo(gold0 * (1 + comebackGold), 1e-9));
      h.comebackUntil = dayAfter(vnDayKey(), -1);
      expect(h.expMul, closeTo(exp0, 1e-9));
    });
  });

  group('reminders', () {
    test('a week away tells of the gift; a month away too', () {
      final h = _hero(40, login: '2026-11-10');
      final plan = reminderPlan(h, DateTime.utc(2026, 11, 10, 12));
      final week = plan.firstWhere((r) => r.id == 4);
      expect(week.title, 'Quà hồi quy đang chờ');
      expect(week.body, contains('2 ngày'));
      expect(plan.firstWhere((r) => r.id == 6).body, contains('3 ngày'), reason: 'tier 2 at 14 days');
      expect(plan.firstWhere((r) => r.id == 7).body, contains('4 ngày'), reason: 'tier 3 at 30 days');
      expect(plan.firstWhere((r) => r.id == 3).title, 'Giang hồ dậy sóng');
    });

    test('no gift promised while the cooldown runs', () {
      final h = _hero(40, login: '2026-11-10')..comebackDay = '20261109';
      final plan = reminderPlan(h, DateTime.utc(2026, 11, 10, 12));
      expect(plan.firstWhere((r) => r.id == 4).title, 'Giang hồ vẫn chờ');
      expect(plan.firstWhere((r) => r.id == 7).title, 'Quà hồi quy đang chờ', reason: 'cooldown over by then');
    });

    test('a festival opening while away gets its own reminder', () {
      final dc = festById['dongchi']!;
      // Left on 10/12: Đông Chí opens five days later.
      final h = _hero(40, login: '2026-12-10');
      final plan = reminderPlan(h, DateTime.utc(2026, 12, 10, 12));
      final f = plan.firstWhere((r) => r.id == 8);
      expect(f.title, '${dc.name} đã mở!');
      expect(f.at, DateTime.utc(2026, 12, 15, reminderHour - 7, reminderMinute));
      // Left on 8/12: the 7-day nudge is the festival's.
      final p2 = reminderPlan(h, DateTime.utc(2026, 12, 8, 12));
      expect(p2.firstWhere((r) => r.id == 4).title, '${dc.name} đã mở!');
      expect(p2.any((r) => r.id == 8), isFalse);
      // Left the evening before: tomorrow's reminder is the festival's.
      final p3 = reminderPlan(h, DateTime.utc(2026, 12, 14, 3));
      expect(p3.firstWhere((r) => r.id == 2).title, '${dc.name} đã mở!');
      // Too young to join: nothing about it.
      final young = _hero(8, login: '2026-12-10');
      expect(reminderPlan(young, DateTime.utc(2026, 12, 10, 12)).any((r) => r.title.contains(dc.name)), isFalse);
    });

    test('ids stay unique', () {
      final h = _hero(40, login: '2026-12-10');
      for (final now in [DateTime.utc(2026, 12, 10, 12), DateTime.utc(2026, 12, 14, 3), DateTime.utc(2026, 11, 1, 12)]) {
        final ids = reminderPlan(h, now).map((r) => r.id).toList();
        expect(ids.toSet().length, ids.length, reason: '$now');
      }
    });
  });

  group('Đông Chí', () {
    test('coins per plain kill scale with the land for rebirths', () {
      for (var cs = 0; cs <= 6; cs++) {
        final rng = math.Random(cs);
        var n = 0;
        for (var i = 0; i < 20000; i++) {
          n += festKillCoins(cs, rng);
        }
        final want = festCoinChance * festMulByRebirth[cs];
        expect(n / 20000, closeTo(want, 0.03), reason: 'cs$cs');
      }
    });

    test('the story quest does not pull a hero off the festival land', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim);
      h.recompute();
      final land = festMap(festById['dongchi']!, h);
      final elsewhere = maps.firstWhere((m) => m.id != maps.first.id);
      final away = questGo(h, hereMap: elsewhere.id);
      final there = questGo(h, hereMap: land.id);
      expect(there, isNull);
      // Same hero on another field still gets pulled (when the quest is elsewhere).
      if (away != null) expect(away.id, isNot(land.id));
    });
  });
}
