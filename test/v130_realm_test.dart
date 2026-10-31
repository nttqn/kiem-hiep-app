import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/world.dart';

import 'sim.dart';

/// Plays a bí cảnh on autopilot; returns the stars, or -1 for a failure.
(int, World) runRealm(HeroData h, int i, {int seed = 7}) {
  final w = World.dungeon(h, realmDungeon(i, h.level), seed: seed)..auto = true;
  var stars = -1;
  while (!w.finished) {
    w.update(1 / 30);
    for (final e in w.events) {
      if (e.kind == EvKind.cleared) stars = e.value.round();
      if (e.kind == EvKind.heroDied) w.giveUp();
    }
    w.events.clear();
  }
  return (stars, w);
}

HeroData geared(int level, Hanh hanh) {
  final h = HeroData(name: 'T', hanh: hanh)..level = level;
  final r = math.Random(1);
  for (final s in Slot.values) {
    h.addItem(makeItem(slot: s, level: level, rarity: Rarity.epic, sect: h.sect, rng: r));
  }
  h.freePoints = (level - 1) * pointsPerLevel;
  h.skillPoints = level;
  townVisit(h);
  h.hpPots = 40;
  h.mpPots = 30;
  return h;
}

void main() {
  group('Bí cảnh', () {
    test('every run has its three trận nhãn, six chests and a lair, in bounds', () {
      for (var seed = 0; seed < 30; seed++) {
        final lay = RealmLayout.generate(seed);
        expect(lay.of(PoiKind.pillar).length, realmPillars);
        expect(lay.of(PoiKind.chest).length, realmChests);
        expect(lay.of(PoiKind.shrine).length, realmShrines);
        expect(lay.of(PoiKind.captive).length, realmCaptives);
        expect(lay.lair.x, greaterThan(realmWidth - 600));
        for (final p in lay.pois) {
          expect(p.x, inInclusiveRange(200, realmWidth - 200));
          expect(p.y, inInclusiveRange(200, realmHeight - 200));
        }
        expect(lay.camps.length, greaterThanOrEqualTo(20));
      }
      // Same seed, same land; another seed, another.
      expect(RealmLayout.generate(5).lair.y, RealmLayout.generate(5).lair.y);
      expect(RealmLayout.generate(5).lair.y, isNot(RealmLayout.generate(6).lair.y));
    });

    test('three runs a day, two more for ads, and they survive a save', () {
      final h = HeroData(name: 'T', hanh: Hanh.thuy)..level = 10;
      const day = '20261101';
      for (var i = 0; i < realmFreeRuns; i++) {
        expect(h.realmStartRun(day), isTrue);
      }
      expect(h.realmStartRun(day), isFalse);
      expect(h.realmAddAdRun(day), isTrue);
      expect(h.realmAddAdRun(day), isTrue);
      expect(h.realmAddAdRun(day), isFalse);
      expect(h.realmRunsLeft, 2);
      h.realmStars['r1'] = 2;
      final back = HeroData.fromJson(h.toJson());
      expect(back.realmStars['r1'], 2);
      expect(back.realmRunsLeft, 2);
      back.realmRollDay('20261102');
      expect(back.realmRunsLeft, realmFreeRuns);
    });

    test('stars: the master, every chest, most of the land', () {
      expect(realmStarsFor(boss: false, chests: 6, explored: 1), 0);
      expect(realmStarsFor(boss: true, chests: 2, explored: 0.3), 1);
      expect(realmStarsFor(boss: true, chests: 6, explored: 0.3), 2);
      expect(realmStarsFor(boss: true, chests: 6, explored: 0.8), 3);
    });

    test('monsters follow the hero within the realm band', () {
      expect(realmLevel(realms[0], 1), realms[0].level);
      expect(realmLevel(realms[0], 7), 7);
      expect(realmLevel(realms[0], 60), realms[0].map.maxLv);
      expect(realmLevel(realms.last, 99), 99);
    });

    test('the autopilot explores, lights the trận nhãn and beats the master', () {
      final h = geared(14, Hanh.kim);
      final gold = h.gold;
      final (stars, w) = runRealm(h, 0);
      expect(stars, greaterThanOrEqualTo(1), reason: 'pillars ${w.pillarsLit} time ${w.time.round()}');
      expect(w.pillarsLit, realmPillars);
      expect(w.time, lessThan(realmTime));
      expect(h.realmStars['r1'], stars);
      expect(h.gold, greaterThan(gold));
      // The first clear pays an Epic or Legend item.
      expect(h.bag.any((it) => it.rarity.index >= Rarity.epic.index), isTrue);
    });

    test('a shrine blessing lasts the run', () {
      final h = geared(14, Hanh.hoa);
      final w = World.dungeon(h, realmDungeon(0, h.level), seed: 3);
      final shrine = w.realm!.of(PoiKind.shrine).first;
      w.player
        ..x = shrine.x
        ..y = shrine.y;
      w.update(1 / 30);
      expect(shrine.done, isTrue);
      expect(w.realmBuffs, contains(RealmBuff.values[shrine.index]));
    });

    test('a trận nhãn stays dark while its guard lives', () {
      final h = geared(14, Hanh.tho);
      final w = World.dungeon(h, realmDungeon(0, h.level), seed: 4);
      final p = w.realm!.of(PoiKind.pillar).first;
      w.player
        ..x = p.x
        ..y = p.y;
      w.update(1 / 30);
      expect(p.done, isFalse);
      final guard = w.mobs.firstWhere((m) => m.uid == p.guard);
      guard.hp = 0;
      w.update(1 / 30);
      expect(p.done, isTrue);
      expect(w.pillarsLit, 1);
    });
  });

  test('realm probe: every sect clears its level band', () {
    for (final hanh in Hanh.values) {
      for (final i in const [0, 3, 6, 8]) {
        final lv = realms[i].level + 2;
        final h = geared(math.min(maxLevel, lv), hanh);
        final (stars, w) = runRealm(h, i, seed: hanh.index * 31 + i);
        // ignore: avoid_print
        print('${hanh.name} ${realms[i].name} lv$lv: $stars* ${w.time.round()}s '
            'pillars ${w.pillarsLit} chests ${w.chestsOpened} explored ${(w.explored * 100).round()}% '
            'deaths ${h.deaths}');
      }
    }
  }, tags: 'sim');
}
