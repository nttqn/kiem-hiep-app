import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/pets.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData hero(Hanh hanh, {int level = 20}) {
  final h = HeroData(name: 'T', hanh: hanh);
  for (var l = 1; l < level; l++) {
    h.gainExp(h.expNeeded.toDouble());
  }
  return h;
}

Item gear(HeroData h, Slot s, Rarity r) =>
    makeItem(slot: s, level: h.level, rarity: r, sect: h.sect, rng: math.Random(s.index));

void main() {
  test('sockets follow rarity', () {
    final h = hero(Hanh.kim);
    expect(gear(h, Slot.weapon, Rarity.common).gems, isEmpty);
    expect(gear(h, Slot.weapon, Rarity.fine).gems.length, 1);
    expect(gear(h, Slot.weapon, Rarity.epic).gems.length, 2);
    expect(gear(h, Slot.weapon, Rarity.legend).gems.length, 3);
  });

  test('socket, unsocket and fuse', () {
    final h = hero(Hanh.kim);
    final w = gear(h, Slot.weapon, Rarity.rare);
    h.addItem(w);
    h.equipItem(w);
    final atk0 = h.stats.atk;
    const g = Gem(Hanh.kim, 2);
    h.addGem(g);
    expect(h.socketGem(w, 0, g), isTrue);
    expect(h.gemCount(g), 0);
    // Bản mệnh: Kim gem on a Kim hero, 1.5 x 5% = 7.5% more attack.
    expect(h.stats.atk / atk0, closeTo(1 + 0.05 * banMenhBonus, 1e-6));
    h.unsocketGem(w, 0);
    expect(h.gemCount(g), 1);
    expect(h.stats.atk, closeTo(atk0, 1e-6));

    h.addGem(g, 2);
    h.gold = fuseCost(2);
    expect(h.fuseGem(g), isTrue);
    expect(h.gemCount(g), 0);
    expect(h.gemCount(const Gem(Hanh.kim, 3)), 1);
    expect(h.gold, 0);
    expect(h.fuseGem(const Gem(Hanh.kim, 3)), isFalse, reason: 'only one');
  });

  test('five phases light the full set bonus', () {
    final h = hero(Hanh.tho);
    var i = 0;
    for (final s in [Slot.weapon, Slot.armor, Slot.hat]) {
      final it = gear(h, s, Rarity.rare);
      h.addItem(it);
      h.equipItem(it);
      for (var k = 0; k < it.gems.length && i < 5; k++, i++) {
        final g = Gem(Hanh.values[i], 1);
        h.addGem(g);
        h.socketGem(it, k, g);
      }
    }
    expect(h.gemPhases, 5);
    expect(h.allBonuses()[Bonus.atkPct], greaterThanOrEqualTo(0.08));
  });

  test('selling gear returns its gems', () {
    final h = hero(Hanh.moc);
    final it = gear(h, Slot.ring, Rarity.rare);
    h.addItem(it);
    const g = Gem(Hanh.hoa, 1);
    h.addGem(g);
    it.gems[0] = g;
    h.gemBag.remove(g.key);
    h.sell(it);
    expect(h.gemCount(g), 1);
  });

  test('a boss pet drops for sure by the fifth kill, and buying works', () {
    final h = hero(Hanh.hoa);
    final boss = mobById['banditBoss']!;
    // A random source that never rolls under the drop chance.
    final never = _Fixed(0.99);
    PetDef? got;
    for (var k = 0; k < petPity && got == null; k++) {
      h.onKill(boss, never);
      got = h.rollPet(boss.id, never);
    }
    expect(got?.id, 'tiger');
    expect(h.bossKillsById[boss.id], petPity);
    expect(h.activePet, 'tiger');
    expect(h.allBonuses()[Bonus.crit], greaterThan(0));

    h.gold = 0;
    expect(h.buyPet(petById['crane']!), isFalse);
    h.gold = petById['crane']!.price;
    expect(h.buyPet(petById['crane']!), isTrue);
    h.gold = petLevelCost(1);
    expect(h.levelPet(petById['crane']!), isTrue);
    expect(h.petLevels['crane'], 2);
  });

  test('gems and pets survive a save round trip', () {
    final h = hero(Hanh.thuy);
    final it = gear(h, Slot.amulet, Rarity.legend);
    h.addItem(it);
    h.equipItem(it);
    h.addGem(const Gem(Hanh.thuy, 3), 2);
    h.socketGem(it, 1, const Gem(Hanh.thuy, 3));
    h.petLevels['fox'] = 7;
    h.activePet = 'fox';
    h.bossKillsById['yetiKing'] = 3;
    h.recompute();
    final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), h.toJson());
    expect(copy.equip[Slot.amulet]!.gems[1], const Gem(Hanh.thuy, 3));
    expect(copy.stats.skillDmg, closeTo(h.stats.skillDmg, 1e-9));
  });

  test('in the field a boss drops a gem and the pet hits monsters', () {
    final h = hero(Hanh.kim, level: 8)..petLevels['kylin'] = 1..activePet = 'kylin';
    final w = World.field(h, maps.first, seed: 4);
    expect(w.pet, isNotNull);
    // Park a weak monster next to the pet, keep the hero idle.
    final m = w.mobs.firstWhere((m) => !m.def.boss);
    m
      ..x = w.player.x + 150
      ..y = w.player.y
      ..state = MobState.idle;
    final hp0 = m.hp;
    for (var i = 0; i < 60 * 3; i++) {
      m.attackCd = 99;
      w.update(1 / 60);
    }
    expect(m.hp, lessThan(hp0), reason: 'pet bolts landed');

    final boss = w.boss!;
    boss.hp = 1;
    w.player
      ..x = boss.x - 40
      ..y = boss.y;
    w.input.attack = true;
    for (var i = 0; i < 60 * 3 && boss.alive; i++) {
      w.update(1 / 60);
    }
    expect(boss.alive, isFalse);
    expect(w.drops.where((d) => d.gem != null), isNotEmpty);
  });
}

class _Fixed implements math.Random {
  _Fixed(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
