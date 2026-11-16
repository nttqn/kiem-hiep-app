import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/bag_items.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';

void main() {
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
