import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/clock.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gold_boss.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world_boss.dart';

/// Vietnam wall-clock time as a UTC instant.
DateTime vn(int y, int mo, int d, int h, int mi) => DateTime.utc(y, mo, d, h, mi).subtract(const Duration(hours: 7));

void at(DateTime t) {
  GameClock.reset();
  GameClock.deviceMs = () => t.millisecondsSinceEpoch;
}

HeroData _hero() => HeroData(name: 'G', hanh: Hanh.kim)..level = 70;

void main() {
  tearDown(GameClock.reset);

  test('sessions open at 12:00 and 21:00 Vietnam time for thirty minutes', () {
    expect(goldBossSessionAt(vn(2026, 11, 9, 11, 59)), -1);
    expect(goldBossSessionAt(vn(2026, 11, 9, 12, 0)), 0);
    expect(goldBossSessionAt(vn(2026, 11, 9, 12, 29)), 0);
    expect(goldBossSessionAt(vn(2026, 11, 9, 12, 30)), -1);
    expect(goldBossSessionAt(vn(2026, 11, 9, 21, 10)), 1);
    expect(goldBossNext(vn(2026, 11, 9, 13, 0)), (const Duration(hours: 8), 1));
    expect(goldBossNext(vn(2026, 11, 9, 22, 0)), (const Duration(hours: 14), 0));
    expect(goldBossLeft(vn(2026, 11, 9, 21, 10)), const Duration(minutes: 20));
    expect(goldBossSessionLabel(1), '21:00–21:30');
  });

  test('the boss goes by the weekday', () {
    // 2026-11-09 is a Monday.
    expect(goldBossOf(vn(2026, 11, 9, 12, 0)).id, 'gbSpear');
    expect(goldBossOf(vn(2026, 11, 10, 12, 0)).id, 'gbBandit');
    expect(goldBossOf(vn(2026, 11, 13, 12, 0)).id, 'gbSpear');
    expect(goldBossOf(vn(2026, 11, 14, 12, 0)).id, 'gbBandit');
    expect(goldBossOf(vn(2026, 11, 15, 12, 0)).id, 'gbLady');
    for (final m in goldBossMobs) {
      expect(mobById[m.id], same(m));
    }
    expect(goldBossDef(vn(2026, 11, 15, 21, 0)).golden, isTrue);
    expect(goldBossDef(vn(2026, 11, 15, 21, 0)).worldBoss, 'gbLady');
  });

  test('runs only in a session, five each, and joining pays once a session', () {
    final h = _hero();
    at(vn(2026, 11, 9, 11, 0));
    expect(h.gbStartRun(vnDayKey()), isFalse);
    at(vn(2026, 11, 9, 12, 5));
    final day = vnDayKey();
    for (var i = 0; i < goldBossRuns; i++) {
      expect(h.gbStartRun(day), isTrue);
    }
    expect(h.gbStartRun(day), isFalse);
    final shards = h.goldShards;
    h.goldBossReward(0);
    expect(h.goldShards, shards); // no damage, no shards
    h.goldBossReward(5000);
    h.goldBossReward(9000);
    expect(h.goldShards, shards + goldBossJoinShards);
    expect(h.gbTotal, 14000);
    expect(h.gbBest, 9000);
    at(vn(2026, 11, 9, 21, 1));
    expect(h.gbRunsLeft, goldBossRuns);
    expect(h.gbStartRun(day), isTrue);
    h.goldBossReward(1000);
    expect(h.goldShards, shards + 2 * goldBossJoinShards);
  });

  test('a low hero cannot join', () {
    final h = HeroData(name: 'L', hanh: Hanh.moc)..level = 30;
    at(vn(2026, 11, 9, 12, 5));
    expect(h.gbStartRun(vnDayKey()), isFalse);
  });

  test('the next day the old total waits for its place, paid once', () {
    final h = _hero();
    at(vn(2026, 11, 9, 12, 5));
    h.gbStartRun(vnDayKey());
    h.goldBossReward(70000);
    h.gbRollDay('20261110');
    expect(h.gbRankDue, isTrue);
    expect(h.gbLastDay, '20261109');
    expect(h.gbLastTotal, 70000);
    expect(h.gbTotal, 0);
    final shards = h.goldShards;
    final iron = h.divineIron;
    final lines = h.payGoldRank(1);
    expect(lines, isNotEmpty);
    expect(h.goldShards, shards + 40);
    expect(h.divineIron, iron + 10);
    expect(h.seasonTitles, contains('Hoàng Kim Bá Chủ'));
    expect(h.payGoldRank(1), isEmpty);
    // Off the board or past 50: nothing, and nothing owed.
    h.gbRankDue = true;
    expect(h.payGoldRank(51), isEmpty);
    expect(h.gbRankDue, isFalse);
    expect(goldRankReward(0), isNull);
    expect(goldRankReward(37)!.shards, 6);
  });

  test('Boss Hoàng Kim is saved and loaded', () {
    final h = _hero()
      ..gbDay = '20261109'
      ..gbRuns0 = 3
      ..gbRuns1 = 1
      ..gbTotal = 123456
      ..gbBest = 99999
      ..gbPaid = 3
      ..gbLastDay = '20261108'
      ..gbLastTotal = 555
      ..gbRankDue = true;
    final b = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect([b.gbDay, b.gbRuns0, b.gbRuns1, b.gbTotal, b.gbBest, b.gbPaid, b.gbLastDay, b.gbLastTotal, b.gbRankDue],
        ['20261109', 3, 1, 123456, 99999, 3, '20261108', 555, true]);
  });
}
