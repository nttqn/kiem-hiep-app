import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/guide.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/newbie.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/tang_bao.dart';
import 'package:kiem_hiep/core/weather.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;

import 'v130_realm_test.dart' show geared;

/// A realm seed whose run has [e].
int seedWith(RealmEvent e) {
  for (var s = 0;; s++) {
    if (RealmLayout.generate(s).events.contains(e)) return s;
  }
}

World realmWorld(HeroData h, int seed) => World.dungeon(h, realmDungeon(0, h.level), seed: seed);

void stepOn(World w, double x, double y, [int frames = 2]) {
  w.player
    ..x = x
    ..y = y;
  for (var i = 0; i < frames; i++) {
    w.update(1 / 30);
  }
}

void main() {
  group('Biến cố bí cảnh', () {
    test('one or two per run, with their places', () {
      final seen = <RealmEvent>{};
      for (var s = 0; s < 60; s++) {
        final lay = RealmLayout.generate(s);
        expect(lay.events.length, inInclusiveRange(1, 2));
        seen.addAll(lay.events);
        expect(lay.of(PoiKind.merchant).length, lay.events.contains(RealmEvent.merchant) ? 1 : 0);
        if (lay.events.contains(RealmEvent.vault)) {
          expect(lay.of(PoiKind.lever).map((p) => p.index).toSet(), {0, 1, 2});
          expect(lay.vaultOrder.toSet(), {0, 1, 2});
        } else {
          expect(lay.of(PoiKind.lever), isEmpty);
        }
      }
      expect(seen, RealmEvent.values.toSet());
    });

    test('mật thất: read the door, pull the levers in order', () {
      final h = geared(14, Hanh.kim);
      final w = realmWorld(h, seedWith(RealmEvent.vault));
      w.mobs.clear();
      final lay = w.realm!;
      final door = lay.of(PoiKind.vault).first;
      Poi lever(int mark) => lay.of(PoiKind.lever).firstWhere((l) => l.index == mark);
      stepOn(w, door.x, door.y);
      expect(w.vaultHintKnown, isTrue);
      // A wrong one first locks them all.
      final wrong = lever(lay.vaultOrder[1]);
      stepOn(w, wrong.x, wrong.y);
      expect(w.vaultStep, 0);
      expect(wrong.done, isFalse);
      final drops = w.drops.length;
      for (final m in lay.vaultOrder) {
        stepOn(w, door.x, door.y - 400);
        stepOn(w, lever(m).x, lever(m).y);
      }
      expect(door.done, isTrue);
      expect(w.drops.length, greaterThanOrEqualTo(drops + 4));
    });

    test('the stars fall, the ma đầu comes hunting', () {
      final h = geared(14, Hanh.thuy);
      final w = realmWorld(h, seedWith(RealmEvent.starfall));
      w.time = starfallTo;
      w.update(1 / 30);
      expect(w.realm!.of(PoiKind.star).length, starfallChests);
      final w2 = realmWorld(h, seedWith(RealmEvent.wanderer));
      w2.time = wandererAt;
      w2.update(1 / 30);
      final hunter = w2.mobs.singleWhere((m) => m.eliteKey == 'realm_hunter');
      expect(hunter.state, MobState.chase);
    });

    test('a biến cố stops the autopilot and hands control back', () {
      final h = geared(14, Hanh.hoa);
      final w = realmWorld(h, seedWith(RealmEvent.wanderer))..auto = true;
      w.update(1 / 30);
      expect(w.auto, isTrue);
      w.time = wandererAt;
      w.update(1 / 30);
      expect(w.auto, isFalse);
      expect(w.events.any((e) => e.text.contains('Đã tắt tự động')), isTrue);
      // The thương nhân coming into sight does the same.
      final w2 = realmWorld(h, seedWith(RealmEvent.merchant))..auto = true;
      final m = w2.realm!.of(PoiKind.merchant).first;
      stepOn(w2, m.x - 300, m.y, 8);
      expect(w2.auto, isFalse);
    });

    test('the thương nhân sells for gold, once you have it', () {
      final h = HeroData(name: 'T', hanh: Hanh.hoa)..level = 30;
      final wares = h.merchantWares(30);
      h.gold = wares[0].price - 1;
      expect(h.buyMerchant(wares[0], 30, math.Random(1)), isNull);
      h.gold = wares[0].price;
      final bag = h.bag.length;
      expect(h.buyMerchant(wares[0], 30, math.Random(1)), contains('Hiếm'));
      expect(h.gold, 0);
      expect(h.bag.length, bag + 1);
    });
  });

  group('Tàng Bảo Đồ', () {
    test('drops are capped per day and survive a save', () {
      final h = HeroData(name: 'T', hanh: Hanh.moc);
      final r = math.Random(1);
      for (var i = 0; i < 100; i++) {
        h.rollTreasureMap('20261101', true, r);
      }
      expect(h.tbdMaps, tbdDailyDrops);
      h.tbdSpot = const TbdSpot('truclam', 1000, 900);
      final back = HeroData.fromJson(h.toJson());
      expect(back.tbdMaps, tbdDailyDrops);
      expect(back.tbdSpot!.mapId, 'truclam');
      expect(back.tbdSpot!.x, 1000);
    });

    World field(HeroData h, TbdOutcome o) {
      World.debugTbd = o;
      final w = World.field(h, mapById['ngoaithanh']!, seed: 2);
      h.tbdMaps = 1;
      w.readTreasureMap();
      return w;
    }

    tearDown(() => World.debugTbd = null);

    test('reading marks a far spot; digging a chest pays', () {
      final h = geared(8, Hanh.kim);
      final w = field(h, TbdOutcome.chest);
      final s = w.digSpot!;
      expect(h.tbdMaps, 0);
      expect(math.sqrt(math.pow(s.x - w.player.x, 2) + math.pow(s.y - w.player.y, 2)), greaterThanOrEqualTo(tbdMinDistance - 1));
      final gold = h.gold;
      stepOn(w, s.x, s.y);
      expect(h.tbdSpot, isNull);
      expect(h.gold, greaterThan(gold));
    });

    test('an ambush pays its chest once it is beaten', () {
      final h = geared(8, Hanh.hoa);
      final w = field(h, TbdOutcome.ambush);
      final s = w.digSpot!;
      final before = w.mobs.length;
      stepOn(w, s.x, s.y);
      final ambush = w.mobs.skip(before).toList();
      expect(ambush.length, tbdAmbushSize);
      final gold = h.gold;
      for (final m in ambush) {
        m.hp = 0;
      }
      w.update(1 / 30);
      expect(h.gold, greaterThan(gold));
    });

    test('a portal adds a bí cảnh run today', () {
      final h = geared(8, Hanh.tho);
      final w = field(h, TbdOutcome.portal);
      h.realmRollDay(vnDayKey());
      final runs = h.realmRunsLeft;
      stepOn(w, w.digSpot!.x, w.digSpot!.y);
      expect(h.realmRunsLeft, runs + 1);
    });

    test('a guardian rises', () {
      final h = geared(8, Hanh.thuy);
      final w = field(h, TbdOutcome.guardian);
      stepOn(w, w.digSpot!.x, w.digSpot!.y);
      expect(w.mobs.where((m) => m.eliteKey == 'tbd_guard'), hasLength(1));
    });
  });

  group('Thời tiết và ngày đêm', () {
    tearDown(() {
      World.debugNight = false;
      World.debugWeather = Weather.clear;
    });

    test('weather holds for a two-hour spell, caves stay clear', () {
      final t = DateTime.utc(2026, 11, 1, 3, 10);
      expect(weatherOf('truclam', MapTheme.bamboo, t), weatherOf('truclam', MapTheme.bamboo, t.add(const Duration(minutes: 40))));
      expect(weatherOf('hacphong', MapTheme.cave, t), Weather.clear);
      final kinds = {for (var h = 0; h < 24 * 20; h += 2) weatherOf('truclam', MapTheme.bamboo, t.add(Duration(hours: h)))};
      expect(kinds, containsAll([Weather.clear, Weather.rain, Weather.fog]));
    });

    test('night is 18:00 to 6:00 in Vietnam', () {
      expect(isNight(DateTime.utc(2026, 11, 1, 12)), isTrue); // 19:00
      expect(isNight(DateTime.utc(2026, 11, 1, 3)), isFalse); // 10:00
      expect(isNight(DateTime.utc(2026, 10, 31, 22)), isTrue); // 5:00
    });

    test('at night some monsters are Dạ Yêu, and they pay more', () {
      World.debugNight = true;
      final h = geared(30, Hanh.kim);
      final w = World.field(h, mapById['hoangsa']!, seed: 5);
      expect(w.night, isTrue);
      final dark = w.mobs.where((m) => m.nightborn).toList();
      expect(dark, isNotEmpty);
      final plain = w.mobs.firstWhere((m) => !m.nightborn && !m.big && m.def == dark.first.def);
      expect(dark.first.maxHp, greaterThan(plain.maxHp * 1.5));
      World.debugNight = false;
      expect(World.field(h, mapById['hoangsa']!, seed: 5).mobs.where((m) => m.nightborn), isEmpty);
    });
  });

  group('Tân thủ', () {
    test('no EXP lost for a fall below level 20', () {
      final h = HeroData(name: 'T', hanh: Hanh.hoa)..level = 12;
      h.exp = 500;
      World.field(h, maps.first, seed: 1).revive();
      expect(h.exp, 500);
      h.level = 25;
      h.exp = expToNext(25) ~/ 2;
      final exp = h.exp;
      World.field(h, maps.first, seed: 1).revive();
      expect(h.exp, lessThan(exp));
    });

    test('level gifts come once, on the way up, not after a rebirth', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim);
      final pots = h.hpPots;
      while (h.level < 5) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.hpPots, pots + levelGifts[5]!.hpPots);
      expect(h.notices.any((n) => n.text.startsWith('Quà mốc cấp 5')), isTrue);
      final r = HeroData(name: 'R', hanh: Hanh.kim)
        ..rebirths = 1
        ..level = 4;
      final rp = r.hpPots;
      r.gainExp(r.expNeeded.toDouble());
      expect(r.hpPots, rp);
    });

    test('a new hero drinks by themselves when nearly down', () {
      final h = HeroData(name: 'T', hanh: Hanh.thuy)..hpPots = 5;
      final w = World.field(h, maps.first, seed: 1)..auto = false;
      w.mobs.clear();
      w.player.hp = w.player.maxHp * 0.2;
      w.update(1 / 30);
      expect(h.hpPots, 4);
    });

    test('Nên làm gì tiếp: better gear and unspent points come first', () {
      final h = HeroData(name: 'T', hanh: Hanh.moc)..level = 6;
      h.freePoints = 5;
      h.addItem(makeItem(slot: Slot.weapon, level: 6, rarity: Rarity.epic, sect: h.sect, rng: math.Random(1)));
      final steps = nextSteps(h, '20261101');
      expect(steps.first.kind, StepKind.equip);
      expect(steps.map((s) => s.kind), contains(StepKind.points));
      h.autoEquip();
      expect(nextSteps(h, '20261101').first.kind, StepKind.points);
    });
  });
}

