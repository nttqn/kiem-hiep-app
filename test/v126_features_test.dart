import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';

HeroData roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
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
