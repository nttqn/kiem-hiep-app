import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  autoSellAndHerbs();
  group('Săn quái tuần', () {
    test('weeks run Monday to Sunday from 26/10/2026', () {
      expect(huntWeekOf('20261026'), 1);
      expect(huntWeekOf('20261101'), 1, reason: 'Sunday');
      expect(huntWeekOf('20261102'), 2, reason: 'Monday');
      expect(huntDaysLeft('20261102'), 7);
      expect(huntDaysLeft('20261108'), 1);
      expect(huntScore(2, 500), 2000500);
      expect(huntScore(2, 999999), 2000000 + huntWeekMax, reason: 'capped');
    });

    test('a new week keeps the old score for its rank, then starts over', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..huntRollDay('20261102');
      expect(h.huntBoardValue, 0, reason: 'no kills yet');
      h.huntKills = 420;
      expect(h.huntBoardValue, huntScore(2, 420));
      h.huntRollDay('20261108');
      expect(h.huntRankDue, isFalse, reason: 'same week');
      h.huntRollDay('20261109');
      expect(h.huntRankDue, isTrue);
      expect(h.huntLastScore, huntScore(2, 420));
      expect(h.huntKills, 0);
      expect(h.huntWeek, 3);
      final back = roundTrip(h);
      expect(back.huntLastScore, h.huntLastScore);
      expect(back.huntRankDue, isTrue);
      expect(back.huntWeek, 3);
    });

    test('a week without kills pays nothing', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..huntRollDay('20261102');
      h.huntRollDay('20261109');
      expect(h.huntRankDue, isFalse);
    });

    test('the top pays once; the winner gets a title', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..huntRankDue = true;
      final iron = h.divineIron;
      final lines = h.payHuntRank(1, math.Random(1));
      expect(h.divineIron, iron + 15);
      expect(lines.last, contains('Săn Quái Vương'));
      expect(h.seasonTitles, contains('Săn Quái Vương'));
      expect(h.payHuntRank(1, math.Random(1)), isEmpty);
      final far = HeroData(name: 'T', hanh: Hanh.kim)..huntRankDue = true;
      expect(far.payHuntRank(51, math.Random(1)), isEmpty);
      expect(far.huntRankDue, isFalse);
    });
  });
}

void autoSellAndHerbs() {
  group('Tự bán', () {
    Item piece(Rarity r) => makeItem(slot: Slot.weapon, level: 10, rarity: r, sect: sectOf(Hanh.kim), rng: math.Random(1));

    test('sells up to the chosen rarity, keeps the rest', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..autoSellUpTo = Rarity.rare.index;
      final gold = h.gold;
      expect(h.addItem(piece(Rarity.common)), isFalse);
      expect(h.addItem(piece(Rarity.fine)), isFalse);
      expect(h.addItem(piece(Rarity.rare)), isFalse);
      expect(h.addItem(piece(Rarity.epic)), isTrue);
      expect(h.gold, greaterThan(gold));
      expect(h.bag.length, 1);
    });

    test('the old switch still loads, and the level is saved', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim);
      final m = h.toJson()
        ..remove('autoSellR')
        ..['autoSell'] = true;
      expect(HeroData.fromJson(jsonDecode(jsonEncode(m)) as Map<String, dynamic>).autoSellUpTo, 0);
      h.autoSellUpTo = 1;
      expect(roundTrip(h).autoSellUpTo, 1);
    });
  });

  test('autopilot walks to a linh thảo between fights and picks it', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim);
    final w = World.field(h, maps.first, seed: 3)..auto = true;
    w.mobs.clear();
    w.drops.clear();
    for (final n in w.herbs) {
      n.readyAt = 1e9;
    }
    w.herbs.add(HerbNode(w.player.x + 300, w.player.y, 0));
    int total() => h.herbs.fold<int>(0, (a, b) => a + b);
    final before = total();
    for (var i = 0; i < 60 * 6; i++) {
      w.mobs.clear();
      w.update(1 / 60);
    }
    expect(total(), greaterThan(before));
  });
}
