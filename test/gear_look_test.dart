import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/render/art_figures.dart';

Item _item(Slot s, int level, [Rarity r = Rarity.common]) =>
    makeItem(slot: s, level: level, rarity: r, sect: sectOf(Hanh.kim), rng: math.Random(1));

void main() {
  test('look tier steps every 20 levels and tops out at 80', () {
    expect(gearTier(null), 0);
    expect(gearTier(_item(Slot.hat, 19)), 0);
    expect(gearTier(_item(Slot.hat, 20)), 1);
    expect(gearTier(_item(Slot.hat, 59)), 2);
    expect(gearTier(_item(Slot.hat, 79)), 3);
    expect(gearTier(_item(Slot.hat, 99)), maxGearTier);
  });

  test('worn gear reaches the hero look; no gear keeps the sect outfit', () {
    final plain = heroLook(Hanh.hoa);
    expect([plain.hat, plain.armor, plain.belt, plain.boots, plain.weaponTier, plain.pendant], everyElement(0));
    expect(plain.cape, 0);

    final gear = HeroGear.of({
      Slot.weapon: _item(Slot.weapon, 85, Rarity.epic),
      Slot.hat: _item(Slot.hat, 45),
      Slot.armor: _item(Slot.armor, 90),
      Slot.amulet: _item(Slot.amulet, 30, Rarity.fine),
    });
    final look = heroLook(Hanh.hoa, gear: gear);
    expect(look.weaponTier, maxGearTier);
    expect(look.hat, 2);
    expect(look.armor, maxGearTier);
    expect(look.cape, isNot(0), reason: 'top armour brings a cape');
    expect(look.belt, 0);
    expect(look.pendant, Rarity.fine.color);
    expect(look.glow, Rarity.epic.color);
    expect(look.blade, isNot(plain.blade));
  });

  test('gear compares by value so previews only repaint on a real change', () {
    final a = HeroGear.of({Slot.hat: _item(Slot.hat, 70)});
    final b = HeroGear.of({Slot.hat: _item(Slot.hat, 75)});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(HeroGear.none));
  });
}
