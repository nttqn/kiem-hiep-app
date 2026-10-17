import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/rewards.dart';
import 'package:kiem_hiep/core/sects.dart';

HeroData maxed(Hanh hanh) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < maxLevel) {
    h.gainExp(h.expNeeded.toDouble());
  }
  return h;
}

void main() {
  test('EXP keeps filling at level 99 and caps there', () {
    final h = maxed(Hanh.kim);
    expect(h.level, maxLevel);
    expect(h.canRebirth, isFalse);
    final cap = expToNext(maxLevel);
    h.gainExp(cap / 2);
    expect(h.exp, (cap / 2).round());
    expect(h.expFull, isFalse);
    h.notices.clear();
    h.gainExp(cap.toDouble());
    expect(h.exp, cap);
    expect(h.expFull, isTrue);
    expect(h.canRebirth, isTrue);
    expect(h.notices, isNotEmpty);
  });

  test('rebirth resets level and points, keeps gear and adds bonuses', () {
    final h = maxed(Hanh.hoa);
    final w = makeItem(slot: Slot.weapon, level: 95, rarity: Rarity.epic, sect: h.sect, rng: math.Random(1));
    h.addItem(w);
    h.equipItem(w);
    h.spent[0] = 200;
    h.freePoints -= 200;
    h.gold = 12345;
    h.gainExp(expToNext(maxLevel).toDouble());
    expect(h.rebirth(), isTrue);
    expect(h.rebirths, 1);
    expect(h.level, rebirthLevel);
    expect(h.exp, 0);
    expect(h.spent, [0, 0, 0, 0]);
    expect(h.freePoints, (rebirthLevel - 1) * pointsPerLevel + rebirthPoints);
    expect(h.equip[Slot.weapon], same(w));
    expect(h.gold, 12345);
    expect(h.allBonuses()[Bonus.atkPct], closeTo(rebirthHpAtk, 1e-9));
    expect(h.rebirth(), isFalse, reason: 'not level 99 any more');

    // Reborn heroes gain 50% more EXP per rebirth.
    h.gainExp(100);
    expect(h.exp, 150);

    final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(copy.rebirths, 1);
    expect(copy.stats.atk, closeTo(h.stats.atk, 1e-9));
  });

  test('at most five rebirths, with achievements on the way', () {
    final h = HeroData(name: 'T', hanh: Hanh.thuy);
    for (var n = 0; n < maxRebirths; n++) {
      while (!h.expFull) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.rebirth(), isTrue);
    }
    while (!h.expFull) {
      h.gainExp(h.expNeeded.toDouble());
    }
    expect(h.canRebirth, isFalse);
    expect(h.rebirth(), isFalse);
    expect(h.freePoints + h.spent.reduce((a, b) => a + b),
        (maxLevel - 1) * pointsPerLevel + maxRebirths * rebirthPoints);
    expect(achievements.firstWhere((a) => a.id == 'cs5').reached(h), isTrue);
  });
}
