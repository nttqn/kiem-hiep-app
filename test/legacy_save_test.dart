import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hero.dart';

/// Saves written by version 1.0.1 (the first Play release line), made with
/// that commit's own code: level 80 with the old story finished, level 76 on
/// the old final "reach level 80" quest, and a level 48 mid-story hero.
Map<String, dynamic> fixture(String key) {
  final all = jsonDecode(File('test/fixtures/saves_v1_0_1.json').readAsStringSync()) as Map<String, dynamic>;
  return (all[key] as Map).cast<String, dynamic>();
}

void main() {
  test('every 1.0.1 save loads and round-trips', () {
    for (final key in ['maxed', 'onLastQuest', 'mid']) {
      final m = fixture(key);
      final h = HeroData.fromJson(m);
      expect(h.level, m['level']);
      expect(h.gold, m['gold']);
      expect(h.equip.length, (m['equip'] as Map).length);
      expect(h.rebirths, 0);
      expect(h.gemBag, isEmpty);
      expect(h.petLevels, isEmpty);
      // Old gear gains empty sockets by rarity.
      for (final it in [...h.equip.values, ...h.bag]) {
        expect(it.gems.length, socketsFor(it.rarity));
        expect(it.gems.every((g) => g == null), isTrue);
      }
      final again = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), h.toJson());
    }
  });

  test('a level 80 hero who finished the old story carries on to 99', () {
    final h = HeroData.fromJson(fixture('maxed'));
    expect(h.level, 80);
    expect(h.mainQuest, 43);
    expect(h.currentMain?.title, 'Vân Vụ Sơn');
    expect(h.mainLocked, isFalse);
    // The old cap kept EXP at zero; now it counts again.
    h.gainExp(h.expNeeded.toDouble());
    expect(h.level, 81);
  });

  test('a hero on the old final quest has it settled on the next town visit', () {
    final h = HeroData.fromJson(fixture('onLastQuest'));
    expect(h.level, 76);
    expect(h.currentMain?.type, QuestType.level);
    expect(h.currentMain?.count, 72);
    final gold = h.gold;
    h.refreshDaily('2026-10-18');
    expect(h.mainQuest, 43);
    expect(h.gold, greaterThan(gold));
  });

  test('a mid-story hero keeps the same quest', () {
    final m = fixture('mid');
    final h = HeroData.fromJson(m);
    expect(h.mainQuest, 30);
    expect(h.currentMain?.target, 'fireWolf');
  });
}
