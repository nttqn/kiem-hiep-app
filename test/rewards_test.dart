import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/rewards.dart';

HeroData hero({int level = 1}) {
  final h = HeroData(name: 'T', hanh: Hanh.kim);
  for (var l = 1; l < level; l++) {
    h.gainExp(h.expNeeded.toDouble());
  }
  return h;
}

void main() {
  test('offline training: nothing for short breaks, capped at 8 hours', () {
    final h = hero(level: 30);
    expect(offlineReward(h, const Duration(minutes: 3)), isNull);
    final eight = offlineReward(h, const Duration(hours: 8))!;
    final day = offlineReward(h, const Duration(hours: 30))!;
    expect(day.exp, eight.exp);
    expect(day.away, offlineCap);
    // A full night is worth a few levels at most, never a jump of ten.
    expect(eight.exp, lessThan(expToNext(30) * 4));
    expect(eight.exp, greaterThan(expToNext(30)));
  });

  test('login gifts: once a day, cycling through seven', () {
    final h = hero(level: 10);
    final rng = math.Random(1);
    final gold0 = h.gold;
    expect(claimLoginGift(h, '2026-10-15', rng), isNotNull);
    expect(h.gold, greaterThan(gold0));
    expect(claimLoginGift(h, '2026-10-15', rng), isNull, reason: 'same day');
    for (var d = 16; d <= 21; d++) {
      expect(claimLoginGift(h, '2026-10-$d', rng), isNotNull);
    }
    expect(h.loginDay, 0, reason: 'seven gifts wrap round');
    expect(h.bag.where((i) => i.rarity == Rarity.epic), isNotEmpty, reason: 'day 7');
  });

  test('achievements pay once and unlock their title', () {
    final h = hero(level: 10);
    final lv10 = achById['lv10']!;
    expect(claimable(h), contains(lv10));
    final gold = h.gold;
    expect(claimAchievement(h, lv10), isTrue);
    expect(h.gold, gold + lv10.gold);
    expect(claimAchievement(h, lv10), isFalse);
    expect(claimable(h), isNot(contains(lv10)));
    h.onKill(mobById['banditBoss']!, math.Random(1));
    expect(achById['boss1']!.reached(h), isTrue);
  });
}
