import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/guild.dart';
import 'package:kiem_hiep/core/guild_war.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/guild_screen.dart';
import 'package:kiem_hiep/ui/offers_view.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(760, 344), Size(915, 412), Size(1280, 800)];
const _mon = '20261116', _tue = '20261117', _nextMon = '20261123';

HeroData _hero({String name = 'Chiến Thần'}) {
  final h = HeroData(name: name, hanh: Hanh.kim)
    ..level = 99
    ..rebirths = 6
    ..gold = 50000000;
  h.recompute();
  return h;
}

HeroData _load(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

ArenaRival _rival(int power) => ArenaRival(name: 'Địch', hanh: Hanh.hoa, level: 99, rebirths: 6, power: power);

void main() {
  group('Bang chiến core', () {
    test('Chiến công grows with the foe, within its bounds', () {
      expect(warWinPoints(1000, 1000), warWinBase);
      expect(warWinPoints(1000, 100), warWinMin);
      expect(warWinPoints(1000, 100000), warWinMax);
      expect(warPoints(false, 1000, 100000), warLossPts);
      expect(warMemberWeekCap, warPerDay * 7 * warWinMax);
      expect(warPlausible(warMemberWeekCap * 3, 3), isTrue);
      expect(warPlausible(warMemberWeekCap * 3 + 1, 3), isFalse);
      expect(warPlausible(10, 0), isFalse);
    });

    test('Chiến lệnh: a few a day, each foe once, only in a bang', () {
      final h = _hero();
      expect(h.warStart('a_0', _mon), isFalse, reason: 'not in a bang');
      h.joinGuild('g1', 'G1', roleMember, 1);
      expect(h.warStart('a_0', _mon), isTrue);
      expect(h.warStart('a_0', _mon), isFalse, reason: 'same foe twice a day');
      expect(h.warStart('a_1', _mon), isTrue);
      expect(h.warStart('a_2', _mon), isTrue);
      expect(h.warStart('a_3', _mon), isFalse, reason: 'out of Chiến lệnh');
      expect(h.warLeft(_tue), warPerDay);
      expect(h.warStart('a_0', _tue), isTrue, reason: 'a new day');
    });

    test('a fight pays Chiến công, xu Bang and cống hiến', () {
      final h = _hero()..joinGuild('g1', 'G1', roleMember, 1);
      expect(h.warStart('a_0', _mon), isTrue);
      final lines = h.warResult(true, _rival(h.power * 2));
      expect(h.gwPts, warWinMax);
      expect(h.guildCoins, warWinCoins);
      expect(h.guildContrib, warWinContrib);
      expect(h.gwWins, 1);
      expect(lines.join(), contains('Chiến công'));
      h.warResult(false, _rival(h.power));
      expect(h.gwPts, warWinMax + warLossPts);
      expect(h.warPtsFor('g1'), h.gwPts);
      expect(h.warPtsFor('other'), 0);
    });

    test('moving bang mid-week starts the Chiến công over', () {
      final h = _hero()..joinGuild('g1', 'G1', roleMember, 1);
      h.warStart('a_0', _mon);
      h.warResult(true, _rival(h.power));
      h
        ..leaveGuild()
        ..joinGuild('g2', 'G2', roleMember, 1);
      expect(h.warPtsFor('g2'), 0);
      expect(h.warStart('b_0', _mon), isTrue);
      expect(h.gwGid, 'g2');
      expect(h.gwPts, 0);
    });

    test('the week turns: last week waits for its place, then pays once', () {
      final h = _hero()..joinGuild('g1', 'G1', roleMember, 1);
      h.warStart('a_0', _mon);
      h.warResult(true, _rival(h.power));
      final week = huntWeekOf(_mon);
      h.warRollDay(_nextMon);
      expect(h.gwRankDue, isTrue);
      expect([h.gwLastWeek, h.gwLastGid, h.gwLastPts], [week, 'g1', warWinBase]);
      expect(h.gwPts, 0);
      final coins = h.guildCoins, iron = h.divineIron;
      final lines = h.warTakeRank(1);
      expect(lines.join(), contains(warTopTitle));
      expect(h.guildCoins, coins + warRankReward(1).coins);
      expect(h.divineIron, iron + warRankReward(1).iron);
      expect(h.seasonTitles, contains(warTopTitle));
      expect(h.warTakeRank(1), isEmpty, reason: 'paid once');
      // A week without a fight leaves nothing to pay.
      h.warRollDay('20261130');
      expect(h.gwRankDue, isFalse);
    });

    test('outside the top fifty still pays for fighting', () {
      expect(warRankReward(0).coins, greaterThan(0));
      expect(warRankReward(51).coins, warRankReward(0).coins);
      expect(warRankReward(3).coins, warRankReward(2).coins);
      expect(warRankReward(4).coins, lessThan(warRankReward(3).coins));
    });

    test('Bang chiến survives a save', () {
      final h = _hero()..joinGuild('g1', 'G1', roleMember, 1);
      h.warStart('a_0', _mon);
      h.warResult(true, _rival(h.power));
      final b = _load(h);
      expect([b.gwDay, b.gwCount, b.gwHit, b.gwWeek, b.gwPts, b.gwGid, b.gwWins],
          [h.gwDay, 1, {'a_0'}, h.gwWeek, warWinBase, 'g1', 1]);
      h.warRollDay(_nextMon);
      final c = _load(h);
      expect([c.gwRankDue, c.gwLastPts, c.gwLastGid], [true, warWinBase, 'g1']);
      // A save from before 1.16.0 has none of it.
      final old = h.toJson()..remove('gw');
      final d = HeroData.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      expect([d.gwDay, d.gwPts, d.gwRankDue], ['', 0, false]);
    });
  });

  group('Bang chiến service', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GuildService.instance
        ..debug = true
        ..dWar.clear();
    });
    tearDown(() => GuildService.instance.debug = false);

    test('a member writes the bang sum; the board ranks and drops the impossible', () async {
      final gs = GuildService.instance;
      final h = _hero();
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      gs.debugUid = 'warA';
      final (id, _) = await gs.create(h, 'Chiến Bang A');
      h.joinGuild(id!, 'Chiến Bang A', roleLeader, 1);
      h.warStart('x_0', _mon);
      h.warResult(true, _rival(h.power));
      final g = (await gs.guild(id))!;
      final others = GuildMember.fromDoc('o_0', {...GuildMember.of('o_0', 'o', _hero(), 0).toMap(), 'ww': h.gwWeek, 'wp': 30})!;
      final stale = GuildMember.fromDoc('s_0', {...GuildMember.of('s_0', 's', _hero(), 0).toMap(), 'ww': h.gwWeek - 1, 'wp': 99})!;
      expect(await gs.pushWar(g, h, [...await gs.members(id), others, stale]), isTrue);
      gs.dWar[h.gwWeek]!['big'] = const WarRow('big', 'Lớn', 500, 3);
      gs.dWar[h.gwWeek]!['fake'] = const WarRow('fake', 'Gian', 999999, 2);
      final board = await gs.warBoard(h.gwWeek);
      expect([for (final r in board) r.gid], ['big', id]);
      expect(board[1].pts, warWinBase + 30, reason: 'last week\'s points do not count');
      expect((await gs.member(id, gs.myRow!))!.warIn(h.gwWeek), warWinBase);
    });
  });

  group('Quà nạp đầu', () {
    test('waits for any purchase, old ones included, and pays once', () {
      final h = _hero();
      expect(h.firstPayReady(false), isFalse);
      expect(h.takeFirstPay(false), isEmpty);
      expect(h.firstPayReady(true), isTrue, reason: 'Gói bỏ quảng cáo counts');
      expect((_hero()..starterBought = true).firstPayReady(false), isTrue);
      expect((_hero()..cardUntil = '20261201').firstPayReady(false), isTrue);
      expect((_hero()..passPaidSeason = 1).firstPayReady(false), isTrue);
      h.paidFlag = true;
      final gold = h.gold, iron = h.divineIron, gems = h.gemBag.values.fold<int>(0, (a, b) => a + b);
      final lines = h.takeFirstPay(false);
      expect(lines, isNotEmpty);
      expect(h.ownedCostumes, contains(firstPayCostume));
      expect(costumeById[firstPayCostume]!.source, CostumeSource.firstPay);
      expect(h.seasonTitles, contains(firstPayTitle));
      expect(h.gold, gold + firstPayGold(h.level, h.rebirths));
      expect(h.divineIron, iron + firstPayIron);
      expect(h.gemBag.values.fold<int>(0, (a, b) => a + b), gems + firstPayGems);
      expect(h.firstPayReady(true), isFalse);
      expect(h.takeFirstPay(true), isEmpty);
      final b = _load(h);
      expect([b.paidFlag, b.firstPayTaken], [true, true]);
    });

    test('the outfit is not won by any other goal', () {
      final h = _hero()..unlockCostumes(quiet: true);
      expect(h.ownedCostumes, isNot(contains(firstPayCostume)));
    });

    test('another phone\'s copy keeps the flags', () {
      final a = _hero(), b = _hero()
        ..paidFlag = true
        ..firstPayTaken = true;
      a.mergePaid(b);
      expect([a.paidFlag, a.firstPayTaken], [true, true]);
    });
  });

  group('screens', () {
    late HeroData h;
    var player = 0;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      h = _hero();
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      GuildService.instance
        ..debug = true
        ..dWar.clear()
        ..debugUid = 'wp${player++}';
      Leaderboard.instance.debugEntries = const [];
    });
    tearDown(() {
      GuildService.instance.debug = false;
      Leaderboard.instance.debugEntries = null;
    });

    Future<void> at(WidgetTester tester, Size s, Widget home) async {
      tester.view.physicalSize = s * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final s in _sizes) {
      final tag = '${s.width.toInt()}x${s.height.toInt()}';

      testWidgets('Bang chiến fits and lists a foe\'s heroes $tag', (tester) async {
        final gs = GuildService.instance;
        // Another bang with a member to fight.
        gs.debugUid = 'foe$tag';
        final foe = _hero(name: 'Đối Thủ');
        final (fid, _) = await gs.create(foe, 'Bang Địch $tag');
        gs.debugUid = 'me$tag';
        final (id, _) = await gs.create(h, 'Bang Ta $tag');
        h.joinGuild(id!, 'Bang Ta $tag', roleLeader, 1);
        // On this week's board, so it comes first among the foes (bangs made
        // by the other sizes' tests follow).
        gs.dWar[huntWeekOf(vnDayKey())] = {fid!: WarRow(fid, 'Bang Địch $tag', 50, 1)};
        await at(tester, s, const GuildScreen());
        await tester.tap(find.text('Bang chiến'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Chiến lệnh $warPerDay/$warPerDay'), findsOneWidget);
        await tester.tap(find.text('Bang Địch $tag'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Đối Thủ'), findsOneWidget);
        expect(find.text('Đánh'), findsOneWidget);
        for (final v in ['Xếp hạng', 'Phần thưởng']) {
          await tester.tap(find.text(v));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: v);
        }
      });

      testWidgets('last week is paid on opening Bang chiến $tag', (tester) async {
        final gs = GuildService.instance;
        final (id, _) = await gs.create(h, 'Bang Thưởng $tag');
        h.joinGuild(id!, 'Bang Thưởng $tag', roleLeader, 1);
        h.warRollDay(_mon);
        h
          ..gwLastWeek = huntWeekOf(_mon) - 1
          ..gwLastGid = id
          ..gwLastPts = 40
          ..gwRankDue = true;
        gs.dWar[h.gwLastWeek] = {id: WarRow(id, 'Bang Thưởng $tag', 40, 1)};
        await at(tester, s, const GuildScreen());
        await tester.tap(find.text('Bang chiến'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Thưởng Bang chiến'), findsOneWidget);
        expect(h.gwRankDue, isFalse);
        expect(h.seasonTitles, contains(warTopTitle));
      });

      testWidgets('Ưu đãi with Quà nạp đầu fits $tag', (tester) async {
        h.paidFlag = true;
        await at(tester, s, const Scaffold(body: OffersView()));
        expect(tester.takeException(), isNull);
        expect(find.text('Quà nạp đầu'), findsOneWidget);
        await tester.tap(find.text('Nhận quà'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.firstPayTaken, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
