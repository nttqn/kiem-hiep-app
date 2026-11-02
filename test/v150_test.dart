import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/manor.dart';
import 'package:kiem_hiep/core/newbie.dart';
import 'package:kiem_hiep/core/reminders.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/unlocks.dart';
import 'package:kiem_hiep/core/week_goals.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData _newPlayer(Hanh hanh) => HeroData(name: 'N', hanh: hanh)
  ..autoCfg.points = true
  ..autoCfg.gear = true;

void main() {
  group('Tân thủ', () {
    test('a brand-new hero on autopilot hardly dies in the first ten minutes', () {
      for (final hanh in Hanh.values) {
        final h = _newPlayer(hanh);
        final w = World.field(h, maps.first, seed: 2)..auto = true;
        var deaths = 0;
        for (var t = 0; t < 30 * 600; t++) {
          w.update(1 / 30);
          for (final e in w.events) {
            if (e.kind == EvKind.heroDied) {
              deaths++;
              w.revive();
            }
          }
          w.events.clear();
        }
        expect(deaths, lessThanOrEqualTo(2), reason: hanh.name);
        expect(h.level, greaterThanOrEqualTo(6), reason: hanh.name);
        expect(h.freePoints, 0, reason: '${hanh.name} spends points by itself');
      }
    });

    test('monsters hit a new hero softer, the camp sends fewer friends', () {
      expect(newbieDamageTaken(1, 0), 0.5);
      expect(newbieDamageTaken(newbieEaseLevel, 0), 1);
      expect(newbieDamageTaken(1, 1), 1);
      expect(newbieAggroFriends(3, 0), 0);
      expect(newbieAggroFriends(8, 0), 1);
      expect(newbieAggroFriends(20, 0), 2);
      expect(newbieAggroFriends(3, 2), 2);
    });

    test('the first levels need less EXP; level 15 on as before', () {
      expect(earlyExpEase(1), closeTo(0.6, 1e-9));
      expect(earlyExpEase(15), 1);
      expect(expToNext(1), lessThan((mobExpAt(1) * 23.25).round()));
      expect(expToNext(20), (mobExpAt(20) * (20 + 60 + 100)).round());
    });

    test('a fallen new hero finds a few potions again', () {
      final h = _newPlayer(Hanh.kim)..hpPots = 0;
      final w = World.field(h, maps.first, seed: 1);
      w.revive();
      expect(h.hpPots, newbieRevivePots);
      final old = HeroData(name: 'O', hanh: Hanh.kim)..level = 30;
      old.hpPots = 0;
      World.field(old, maps.first, seed: 1).revive();
      expect(old.hpPots, 0);
    });

    test('auto points and gear only for new players; a picked-up better piece is worn', () {
      final legacy = HeroData.fromJson(HeroData(name: 'L', hanh: Hanh.thuy).toJson());
      expect(legacy.autoCfg.points, isFalse);
      final h = _newPlayer(Hanh.thuy);
      h.gainExp(expToNext(1) * 3.0);
      expect(h.freePoints, 0);
      final back = HeroData.fromJson(h.toJson());
      expect(back.autoCfg.points && back.autoCfg.gear, isTrue);
    });
  });

  group('Mở khóa dần', () {
    test('doors open with level, with a notice, and a MỚI tag until visited', () {
      final h = HeroData(name: 'N', hanh: Hanh.hoa);
      expect(h.featureIsOpen('maps'), isTrue);
      expect(h.featureIsOpen('challenge'), isFalse);
      expect(h.featureIsNew('maps'), isFalse);
      while (h.level < 6) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.notices.any((n) => n.text.contains('Mở khóa: Vượt ải')), isTrue);
      expect(h.featureIsNew('dungeons'), isTrue);
      h.seenFeatures.add('dungeons');
      expect(h.featureIsNew('dungeons'), isFalse);
      expect(featuresOpened(1, 6).map((f) => f.id), containsAll(['dungeons', 'forge', 'ach', 'activity']));
    });

    test('a hero saved before 1.5.0 sees nothing as new', () {
      final m = (HeroData(name: 'O', hanh: Hanh.moc)..level = 40).toJson()..remove('seen');
      final h = HeroData.fromJson(m);
      for (final f in townFeatures) {
        expect(h.featureIsNew(f.id), isFalse, reason: f.id);
      }
    });
  });

  group('Mục tiêu 7 ngày', () {
    test('the chest brings its own outfit', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)..bornDay = '20261101';
      h.weekClaimed.addAll(weekGoals.map((g) => g.id));
      final lines = h.claimWeekChest('20261107', math.Random(1));
      expect(lines.first, contains('Thất Nhật Hiệp Y'));
      expect(h.ownedCostumes, contains(weekChestCostume));
    });

    test('tomorrow evening\'s reminder names the day that opens', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)..bornDay = '20261101';
      final plan = reminderPlan(h, DateTime.utc(2026, 11, 1, 5));
      expect(plan.firstWhere((r) => r.id == 2).body, contains('ngày 2'));
    });
  });

  group('Trang viên', () {
    const t0 = 1800000000000;
    test('sow, wait in real time, harvest herbs', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)
        ..level = 30
        ..gold = 100000;
      expect(h.manorSow(0, crops[0], t0), isTrue);
      expect(h.gold, 100000 - crops[0].seedGold);
      expect(h.manorSow(0, crops[0], t0), isFalse, reason: 'field taken');
      expect(h.manorSow(2, crops[0], t0), isFalse, reason: 'third field closed at level 1');
      expect(h.manorSow(1, crops[2], t0), isFalse, reason: 'Linh Chi needs level 42');
      expect(h.manorHarvest(t0 + 60000), isEmpty);
      final herbs = h.herbs[0];
      final lines = h.manorHarvest(t0 + crops[0].minutes * 60000);
      expect(lines.single, contains('Cam Thảo'));
      expect(h.herbs[0], herbs + cropYield(1));
      expect(h.manor.plots[0].empty, isTrue);
    });

    test('the silkworms spin while away, up to twelve hours', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)..level = 20;
      h.manorVisit(t0);
      expect(h.manor.silkWaiting(t0 + 3600000), silkPerHour(1).floor());
      expect(h.manor.silkWaiting(t0 + 100 * 3600000), (silkStoreHours * silkPerHour(1)).floor());
      final n = h.manorCollectSilk(t0 + 4 * 3600000);
      expect(h.manor.silk, n);
      expect(h.manor.silkWaiting(t0 + 4 * 3600000), 0);
      final gold = h.gold;
      h.manorSellSilk(10);
      expect(h.gold, gold + 10 * silkPrice(20));
    });

    test('raising the estate opens fields; keepsakes add stats and are saved', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)
        ..level = 40
        ..gold = 10000000;
      h.manor.silk = 5000;
      expect(h.manor.openPlots, 2);
      for (var i = 0; i < 6; i++) {
        expect(h.manorUpgrade(t0), isTrue);
      }
      expect(h.manor.level, 7);
      expect(h.manor.openPlots, 6);
      h.recompute();
      final hp = h.stats.maxHp;
      expect(h.manorBuy(keepsakeById['koi']!), isTrue);
      expect(h.manorBuy(keepsakeById['koi']!), isFalse);
      expect(h.stats.maxHp, greaterThan(hp));
      expect(h.allBonuses()[Bonus.hpPct], greaterThan(0));
      h.manorSow(5, crops[1], t0);
      final back = HeroData.fromJson(h.toJson());
      expect(back.manor.level, 7);
      expect(back.manor.keepsakesOwned, contains('koi'));
      expect(back.manor.plots[5].tier, 1);
      expect(back.manor.silk, h.manor.silk);
    });

    test('a crop ripening in the day is reminded of', () {
      final h = HeroData(name: 'N', hanh: Hanh.kim)
        ..level = 20
        ..gold = 10000;
      // 03:00 UTC = 10:00 in Vietnam.
      final now = DateTime.utc(2026, 11, 3, 3);
      h.manorSow(0, crops[0], now.millisecondsSinceEpoch);
      expect(reminderPlan(h, now).any((r) => r.id == 5), isTrue);
    });
  });

}
