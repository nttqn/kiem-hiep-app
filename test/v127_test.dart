import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/dummy.dart';
import 'package:kiem_hiep/core/gear_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/star_up.dart';
import 'package:kiem_hiep/core/world.dart';

/// A hero of [level] in rare gear of that level, points spent.
HeroData _hero(Hanh hanh, int level) {
  final h = HeroData(name: 'Sim', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  final rng = math.Random(level * 7 + hanh.index);
  for (final s in Slot.values) {
    h.addItem(makeItem(slot: s, level: level, rarity: Rarity.rare, sect: h.sect, rng: rng));
  }
  h.autoSpend();
  h.autoLearn();
  h.autoEquip();
  return h;
}

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  group('Mộc nhân', () {
    for (final hanh in Hanh.values) {
      test('${hanh.name}: 30 s of autopilot, damage tallied, nothing paid', () {
        final h = _hero(hanh, 60);
        final gold = h.gold, exp = h.exp, bag = h.bag.length;
        final w = World.dungeon(h, dummyDef(), seed: 3)..auto = true;
        var cleared = false;
        var t = 0.0;
        while (!w.finished && t < 40) {
          w.update(1 / 30);
          t += 1 / 30;
          for (final e in w.events) {
            if (e.kind == EvKind.cleared) cleared = true;
          }
          w.events.clear();
        }
        expect(cleared, isTrue);
        expect(w.finishTime, closeTo(dummyTime, 0.1));
        final r = w.dummyReport;
        expect(r.total, greaterThan(0));
        expect(r.dmg[0] + r.dmg[1], greaterThan(0));
        expect(r.hits, greaterThan(10));
        expect(w.player.hp, w.player.maxHp);
        expect(w.boss!.alive, isTrue);
        expect(h.gold, gold);
        expect(h.exp, exp);
        expect(h.bag.length, bag);
      });
    }
  });

  group('Bộ trang bị', () {
    test('save, swap pieces and points, round trip, missing piece', () {
      final h = _hero(Hanh.kim, 60);
      final rng = math.Random(9);
      h.saveGearSet(0);
      final setA = {for (final e in h.equip.entries) e.key: e.value};
      final spentA = List.of(h.spent);
      expect(setA.values.every((it) => it.locked && it.uid > 0), isTrue);
      // A second build: new weapon and ring, points moved.
      final w2 = makeItem(slot: Slot.weapon, level: 60, rarity: Rarity.epic, sect: h.sect, rng: rng);
      final r2 = makeItem(slot: Slot.ring, level: 60, rarity: Rarity.epic, sect: h.sect, rng: rng);
      h.bag.addAll([w2, r2]);
      h.equipItem(w2);
      h.equipItem(r2);
      h.resetPoints();
      h.spendPoint(2, h.freePoints);
      h.saveGearSet(1);
      expect(h.gearSetWorn(1), isTrue);
      expect(h.gearSetWorn(0), isFalse);

      var r = h.applyGearSet(0);
      expect(r.changed, 2);
      expect(r.points, isTrue);
      expect(h.equip[Slot.weapon], same(setA[Slot.weapon]));
      expect(h.spent, spentA);
      expect(h.gearSetWorn(0), isTrue);
      expect(h.bag, containsAll([w2, r2]));

      final back = _roundTrip(h);
      expect(back.gearSets[1]!.uids[Slot.weapon], w2.uid);
      expect(back.itemUid, h.itemUid);
      r = back.applyGearSet(1);
      expect(r.changed, 2);
      expect(back.equip[Slot.weapon]!.uid, w2.uid);
      expect(back.gearSetWorn(1), isTrue);

      // A piece sold since: its slot keeps what is worn.
      final ring = back.equip[Slot.ring]!;
      back.unequip(Slot.ring);
      ring.locked = false;
      back.sell(ring);
      r = back.applyGearSet(1);
      expect(r.missing, 1);
      expect(back.potentialTotal, h.potentialTotal);
    });
  });

  test('Song Bội Đan adds to an EXP event: x2 + x2 = x3', () {
    expect(HeroData.expBoostMul(false, 1), 1);
    expect(HeroData.expBoostMul(true, 1), 2);
    expect(HeroData.expBoostMul(false, 2), 2);
    expect(HeroData.expBoostMul(true, 2), 3);
    expect(HeroData.expBoostMul(true, 1.5), 2.5);
  });

  group('Đổi cả cường hóa', () {
    test('stars and + travel together to an unforged piece', () {
      final h = _hero(Hanh.thuy, 60)
        ..gold = 99999999
        ..starStones = 999;
      final a = h.equip[Slot.weapon]!
        ..plus = maxPlus
        ..star = 5;
      final b = makeItem(slot: Slot.weapon, level: 60, rarity: Rarity.legend, sect: h.sect, rng: math.Random(4))..plus = 2;
      // Level-up gifts may have left random pieces in the bag.
      h.bag
        ..clear()
        ..add(b);
      expect(h.starMoveTargets(a), isEmpty);
      expect(h.starMoveTargets(a, withPlus: true), [b]);
      expect(h.starMoveBlock(a, b), StarMoveBlock.notMax);
      final g = h.gold;
      final fee = h.starMoveGoldTotal(a, b, withPlus: true);
      expect(fee, greaterThan(starMoveGold(a, b)));
      expect(h.moveStars(a, b, withPlus: true), isTrue);
      expect((a.plus, a.star, b.plus, b.star), (2, 0, maxPlus, 5));
      expect(h.gold, g - fee);
    });

    test('same stars, different +: no star fee', () {
      final h = _hero(Hanh.hoa, 60);
      final a = h.equip[Slot.boots]!..plus = maxPlus;
      final b = makeItem(slot: Slot.boots, level: 60, rarity: Rarity.rare, sect: h.sect, rng: math.Random(2));
      expect(starMoveStones(a, b), 0);
      expect(starMoveGold(a, b), 0);
      expect(plusMoveGold(a, b), greaterThan(0));
    });
  });
}
