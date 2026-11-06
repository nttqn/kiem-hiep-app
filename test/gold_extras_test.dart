import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/gold_extras.dart';
import 'package:kiem_hiep/core/gold_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';

HeroData _hero() => HeroData(name: 'P', hanh: Hanh.hoa)
  ..level = 99
  ..rebirths = 6;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

Item _gold(HeroData h, Slot s) =>
    makeGoldItem(set: goldSetById['hoa']!, slot: s, level: h.level, sect: h.sect, rng: math.Random(3));

void main() {
  test('Khai Quang: costs, caps and raises base stats', () {
    final h = _hero()..goldShards = 10000;
    final it = _gold(h, Slot.weapon);
    h.equip[Slot.weapon] = it;
    h.recompute();
    final before = h.power;
    final atk0 = it.totals[Stat.atk]!;
    var spent = 0;
    for (var i = 0; i < maxGlow; i++) {
      spent += goldGlowCost[i];
      expect(h.glowUp(it), isTrue);
    }
    expect(it.glow, maxGlow);
    expect(h.goldShards, 10000 - spent);
    expect(h.glowBlock(it), GlowBlock.maxed);
    expect(h.glowUp(it), isFalse);
    expect(it.totals[Stat.atk]!, closeTo(atk0 * (1 + glowPct(maxGlow)), atk0 * 0.01 + 1));
    expect(h.power, greaterThan(before));
  });

  test('Khai Quang is for Hoàng Kim pieces only and needs shards', () {
    final h = _hero();
    final plain = makeItem(slot: Slot.weapon, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(1));
    expect(h.glowBlock(plain), GlowBlock.notGold);
    final it = _gold(h, Slot.weapon);
    h.goldShards = goldGlowCost[0] - 1;
    expect(h.glowBlock(it), GlowBlock.shards);
  });

  test('Tinh Luyện takes a line to its best roll, once', () {
    final h = _hero()..goldShards = 1000;
    final it = _gold(h, Slot.armor);
    final s = it.bonus.keys.first;
    it.bonus[s] = it.bonus[s]! * 0.5;
    expect(h.perfectLine(it, s), isTrue);
    expect(it.bonus[s], maxRollStat(s, it.level));
    expect(h.goldShards, 1000 - goldPerfectCost);
    expect(h.perfectLine(it, s), isFalse, reason: 'already at best');
  });

  test('glow survives save, reforge and the load clamp', () {
    final h = _hero()..goldShards = 10000;
    final it = _gold(h, Slot.weapon);
    h.equip[Slot.weapon] = it;
    h.glowUp(it);
    h.glowUp(it);
    final back = _roundTrip(h);
    expect(back.equip[Slot.weapon]!.glow, 2);
    expect(reforgedGold(it, 99).glow, 2);
    final m = it.toJson()..['o'] = 99;
    expect(Item.fromJson(m).glow, maxGlow);
  });

  test('Hoàng Kim Các: weekly limits and goods', () {
    final h = _hero()..goldShards = 100000;
    final stones = goldWares.firstWhere((w) => w.id == 'stones');
    final s0 = h.starStones;
    for (var i = 0; i < stones.perWeek; i++) {
      expect(h.buyGoldWare(stones, math.Random(i)), isNotNull);
    }
    expect(h.starStones, s0 + stones.perWeek * stones.count);
    expect(h.hkLeft(stones), 0);
    expect(h.buyGoldWare(stones, math.Random()), isNull);
    final back = _roundTrip(h);
    expect(back.hkLeft(stones), 0, reason: 'the week count is saved');
    back.hkWeek = 0;
    expect(back.hkLeft(stones), stones.perWeek, reason: 'a new week resets it');
    for (final w in goldWares) {
      expect(h.buyGoldWare(w, math.Random(1)) != null || w.id == 'stones', isTrue, reason: w.id);
    }
  });
}
