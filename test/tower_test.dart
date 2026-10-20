import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/tower.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

HeroData at(Hanh hanh, int level) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.autoSpend();
  h.autoLearn();
  return h;
}

void main() {
  test('floors climb in level, then in strength; bosses every fifth floor', () {
    var lastLv = 0, lastMul = 0.0;
    for (var f = 1; f <= 120; f++) {
      final d = towerFloor(f);
      expect(d.isTower, isTrue);
      expect(d.floor, f);
      expect(d.level, greaterThanOrEqualTo(lastLv));
      expect(d.mul, greaterThanOrEqualTo(lastMul));
      expect(d.boss, f % 5 == 0);
      expect(d.map, isNotNull);
      lastLv = d.level;
      lastMul = d.mul;
    }
    expect(towerFloor(32).level, 99);
    expect(towerFloor(31).mul, 1);
    expect(towerFloor(60).mul, greaterThan(2));
    expect(towerGemTier(5), 1);
    expect(towerGemTier(60), 6, reason: 'Tiên from 60');
    expect(towerGemTier(72), maxGemTier, reason: 'Thánh from 72');
  });

  test('only a first clear pays, boss floors add a gem, and the best floor saves', () {
    final h = at(Hanh.kim, 50);
    final rng = math.Random(1);
    final g0 = h.gold;
    expect(h.towerReward(1, rng).length, greaterThanOrEqualTo(2));
    expect(h.towerBest, 1);
    expect(h.gold, g0 + towerGold(1));
    expect(h.towerReward(1, rng), ['Tầng đã vượt trước đây']);
    expect(h.lastDungeonGold, 0, reason: 'no doubling a repeat');
    h.towerBest = 59;
    h.towerReward(60, rng);
    expect(h.gemBag.keys.map(Gem.parse).any((g) => g!.tier == 6), isTrue);
    final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(copy.towerBest, 60);
    expect(copy.gemCount(Gem.parse(h.gemBag.keys.first)!), h.gemBag.values.first);
  });

  test('Thần gems fuse on into Tiên and Thánh, monsters still drop at most Thần', () {
    final h = at(Hanh.hoa, 99)..gold = 1000000;
    h.addGem(const Gem(Hanh.hoa, 5), 9);
    expect(h.fuseGem(const Gem(Hanh.hoa, 5)), isTrue);
    expect(h.fuseGem(const Gem(Hanh.hoa, 5)), isTrue);
    expect(h.fuseGem(const Gem(Hanh.hoa, 5)), isTrue);
    expect(h.fuseGem(const Gem(Hanh.hoa, 6)), isTrue);
    expect(h.gemCount(const Gem(Hanh.hoa, 7)), 1);
    expect(h.fuseGem(const Gem(Hanh.hoa, 7)), isFalse);
    expect(dropTier(99, boss: true), maxDropTier);
  });

  test('a strong hero clears floor 1 and a boss floor in the arena', () {
    final h = at(Hanh.hoa, 99);
    for (final f in [1, 5]) {
      final w = World.dungeon(h, towerFloor(f), seed: f)..auto = true;
      var cleared = false;
      while (!w.finished && w.time < 95) {
        w.update(1 / 30);
        cleared |= w.events.any((e) => e.kind == EvKind.cleared);
        w.events.clear();
      }
      expect(cleared, isTrue, reason: 'floor $f');
      expect(h.towerBest, f);
      h.towerBest = 4;
    }
  });

  test('the tuyệt kỹ cools down and can be used again', () {
    final h = at(Hanh.tho, 60)..skillLv[6] = 10;
    h.recompute();
    final w = World.dungeon(h, towerFloor(40), seed: 3);
    w.player.mp = h.stats.maxMp;
    w.input.skills.add(6);
    w.update(1 / 30);
    expect(w.ready(6), isFalse);
    for (var i = 0; i < 30 * 30; i++) {
      w.player.hp = w.player.maxHp;
      w.player.mp = h.stats.maxMp;
      w.update(1 / 30);
      if (w.ready(6)) break;
    }
    expect(w.ready(6), isTrue);
  });

  test('combat power rises with gear and level', () {
    final h = at(Hanh.thuy, 30);
    final p0 = h.power;
    expect(p0, greaterThan(0));
    final it = makeItem(slot: Slot.weapon, level: 30, rarity: Rarity.legend, sect: h.sect, rng: math.Random(2));
    h.addItem(it);
    h.equipItem(it);
    expect(h.power, greaterThan(p0));
    expect(at(Hanh.thuy, 60).power, greaterThan(p0));
  });

  test('leaderboard ranks rebirths above levels', () {
    const a = LbEntry(id: 'a_0', name: 'A', hanh: 0, level: 99, rebirths: 0, power: 1, tower: 1);
    const b = LbEntry(id: 'b_0', name: 'B', hanh: 1, level: 10, rebirths: 1, power: 1, tower: 1);
    expect(b.rank, greaterThan(a.rank));
    expect(LbEntry.fromDoc('x', {'name': 'X', 'hanh': 9, 'level': 5, 'power': 7})!.hanh, 4);
    expect(LbEntry.fromDoc('x', {'level': 5}), isNull);
  });
}
