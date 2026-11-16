import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/bag_items.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  bagMore();
  test('Túi đồ lists what a hero holds, each with its use and sources', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim)
      ..level = 99
      ..rebirths = 6
      ..goldShards = 5
      ..divineIron = 3
      ..starStones = 9
      ..beastSouls = 1
      ..soulPills = 12
      ..tienJade = 4
      ..tbdMaps = 2
      ..arenaCoins = 100
      ..sectCoins = 50
      ..guildCoins = 20;
    h.pills['taytuy'] = 1;
    h.gemBag['1:3'] = 2;
    h.herbs[2] = 6;
    final ids = {for (final e in bagEntries(h)) e.id: e};
    for (final id in ['hp', 'mp', 'pill:taytuy', 'tbd', 'herb:2', 'gem:1:3', 'shard', 'soulpill', 'iron', 'stone',
        'soul', 'jade', 'arena', 'sect', 'guild']) {
      expect(ids, contains(id));
    }
    for (final e in ids.values) {
      expect(e.use, isNotEmpty, reason: e.id);
      expect(e.source, isNotEmpty, reason: e.id);
    }
    expect(ids['shard']!.count, 5);
    expect(ids['herb:2']!.source, contains('Trang viên'));
  });

  test('a new hero sees potions only, not late materials', () {
    final ids = bagEntries(HeroData(name: 'N', hanh: Hanh.thuy)).map((e) => e.id).toSet();
    expect(ids, containsAll(['hp', 'mp']));
    expect(ids.intersection({'iron', 'stone', 'soul', 'jade', 'soulpill', 'shard'}), isEmpty);
  });

  test('the bag holds 120 pieces of gear', () {
    final h = HeroData(name: 'B', hanh: Hanh.hoa);
    expect(bagSize, 120);
    expect(h.bag.length < bagSize, isTrue);
  });
}

Item _piece(HeroData h, Rarity r, {int level = 1, Slot slot = Slot.weapon}) =>
    makeItem(slot: slot, level: level, rarity: r, sect: h.sect, rng: math.Random(3));

void bagMore() {
  test('a locked piece survives selling, bulk or by hand, and keeps its lock in a save', () {
    final h = HeroData(name: 'K', hanh: Hanh.kim);
    final it = _piece(h, Rarity.common)..locked = true;
    h.bag.add(it);
    h.sell(it);
    expect(h.bag, contains(it));
    final back = Item.fromJson(it.toJson());
    expect(back.locked, isTrue);
    expect(Item.fromJson((_piece(h, Rarity.common)).toJson()).locked, isFalse);
  });

  test('the green arrow: wearable and better than what is worn', () {
    final h = HeroData(name: 'A', hanh: Hanh.kim)..level = 10;
    final weak = _piece(h, Rarity.common, level: 5);
    final strong = _piece(h, Rarity.epic, level: 10);
    final tooHigh = _piece(h, Rarity.epic, level: 30);
    expect(h.betterThanWorn(weak), isTrue); // nothing worn
    h.equipItem(strong);
    expect(h.betterThanWorn(weak), isFalse);
    expect(h.betterThanWorn(tooHigh), isFalse);
  });

  test('a full bag says so once a battle', () {
    final h = HeroData(name: 'F', hanh: Hanh.kim)..level = 5;
    h.recompute();
    for (var i = 0; i < bagSize; i++) {
      h.bag.add(_piece(h, Rarity.common));
    }
    final w = World.field(h, maps.first, seed: 1);
    for (var i = 0; i < 2; i++) {
      w.drops.add(Drop(w.player.x, w.player.y, item: _piece(h, Rarity.rare)));
      for (var k = 0; k < 20; k++) {
        w.update(0.05);
      }
    }
    expect(w.events.where((e) => e.kind == EvKind.bagFull).length, 1);
    expect(h.bag.length, bagSize);
  });
}
