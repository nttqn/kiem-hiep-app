import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/ledger.dart';
import 'package:kiem_hiep/core/star_up.dart';

void main() {
  HeroData hero() => HeroData(name: 'P', hanh: Hanh.hoa)
    ..level = 99
    ..gold = 100000000
    ..starStones = 1000;
  Item piece(HeroData h, Slot slot, int seed, {int plus = maxPlus, int star = 0}) =>
      makeItem(slot: slot, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(seed))
        ..plus = plus
        ..star = star;

  test('stars swap, Tinh Phách kept, fee 10% of the higher side', () {
    final h = hero();
    final worn = piece(h, Slot.weapon, 1, star: 7);
    final other = piece(h, Slot.weapon, 2, star: 2);
    h.equip[Slot.weapon] = worn;
    h.bag.add(other);
    h.recompute();
    final souls = h.beastSouls;
    final invested = soulsInvested([worn]);
    final stones = h.starStones, gold = h.gold;
    final feeS = starMoveStones(worn, other), feeG = starMoveGold(worn, other);
    expect(feeS, (starStonesTo(7) * 0.1).ceil());
    expect(h.starMoveTargets(worn), [other]);
    expect(h.moveStars(worn, other), isTrue);
    expect(worn.star, 2);
    expect(other.star, 7);
    expect(h.beastSouls, souls);
    expect(soulsInvested([other]), invested);
    expect(h.starStones, stones - feeS);
    expect(h.gold, gold - feeG);
  });

  test('blocked: other slot, not +max, same stars, short of stones', () {
    final h = hero();
    final a = piece(h, Slot.ring, 1, star: 5);
    h.bag.addAll([
      piece(h, Slot.amulet, 2),
      piece(h, Slot.ring, 3, plus: maxPlus - 1),
      piece(h, Slot.ring, 4, star: 5),
    ]);
    h.bag.add(a);
    expect(h.starMoveTargets(a), isEmpty);
    expect(h.starMoveBlock(a, h.bag[0]), StarMoveBlock.slot);
    expect(h.starMoveBlock(a, h.bag[1]), StarMoveBlock.notMax);
    expect(h.starMoveBlock(a, h.bag[2]), StarMoveBlock.noStars);
    final b = piece(h, Slot.ring, 5);
    h.starStones = 0;
    expect(h.starMoveBlock(a, b), StarMoveBlock.stones);
    expect(h.moveStars(a, b), isFalse);
    expect(a.star, 5);
  });
}
