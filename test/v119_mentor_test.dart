import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/codex.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/mentor.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/codex_screen.dart';
import 'package:kiem_hiep/ui/guild_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _day = '20261120';

HeroData _master() {
  final h = HeroData(name: 'Sư Phụ', hanh: Hanh.kim)
    ..level = 99
    ..rebirths = 2;
  h.recompute();
  return h;
}

HeroData _pupil({int level = 15}) {
  final h = HeroData(name: 'Tân Thủ', hanh: Hanh.thuy)..level = level;
  h.recompute();
  return h;
}

/// Plays [h] as the active hero of account [uid].
void _as(String uid, HeroData h) {
  SaveService.instance.slots[0] = h;
  SaveService.instance.active = 0;
  GuildService.instance.debugUid = uid;
}

void main() {
  setUpAll(_fonts);

  group('rules', () {
    test('who may teach and who may learn', () {
      expect(_master().canTeach, isTrue);
      expect((_pupil(level: 89)).canTeach, isFalse);
      expect(_pupil(level: 60).canBaiSu, isTrue);
      expect(_pupil(level: 61).canBaiSu, isFalse);
      expect((_pupil()..rebirths = 1).canBaiSu, isFalse);
    });

    test('steps by level, then xuất sư', () {
      expect(mentorStepsReached(19, 0), 0);
      expect(mentorStepsReached(20, 0), 1);
      expect(mentorStepsReached(99, 0), mentorMilestones.length);
      expect(mentorStepsReached(1, 1), mentorSteps);
      expect(discipleGifts.length, mentorSteps);
      expect(mentorPay.length, mentorSteps);
    });

    test('a đệ tử gets gifts only for steps passed after the master took them', () {
      final p = _pupil(level: 35)..askMaster('m_0', 'Sư Phụ', 0);
      p.masterAccepted();
      expect(p.hasMaster, isTrue);
      expect(p.discipleGiftReady, isFalse); // 20 and 30 were passed before
      p.level = 41;
      expect(p.discipleGiftReady, isTrue);
      final gold0 = p.gold;
      expect(p.takeDiscipleGift(), isNotEmpty);
      expect(p.gold, gold0 + discipleGifts[2].gold);
      expect(p.discipleGiftReady, isFalse);
      expect(p.discipleExp, discipleExpBonus);
      // Xuất sư: the rest, then the title.
      p
        ..rebirths = 1
        ..level = 1;
      expect(p.discipleExp, 0);
      var n = 0;
      while (p.takeDiscipleGift().isNotEmpty) {
        n++;
      }
      expect(n, mentorSteps - 3);
      expect(p.seasonTitles, contains(discipleTitle));
    });

    test('the master is paid by the board, never twice, and a stale row takes nothing back', () {
      final m = _master();
      expect(m.acceptDisciple('p_0', 'Tân Thủ', 2, 25), isTrue);
      final d = m.discipleOf('p_0')!;
      expect(m.mentorPayDue(d), 0);
      m.seeDisciple('p_0', 'Tân Thủ', 2, 52, 0);
      expect(m.mentorPayDue(d), 3); // 30, 40, 50
      final ess0 = m.essence, iron0 = m.divineIron;
      m.takeMentorPay(d);
      expect(m.essence, ess0 + 3 + 5 + 5);
      expect(m.divineIron, iron0 + 2);
      expect(m.mentorPayDue(d), 0);
      m.seeDisciple('p_0', 'Tân Thủ', 2, 40, 0); // an old row
      expect(d.level, 52);
      expect(m.mentorPayDue(d), 0);
      // Xuất sư frees the seat and counts toward the titles.
      m.seeDisciple('p_0', 'Tân Thủ', 2, 3, 1);
      expect(d.graduated, isTrue);
      expect(m.activeDisciples, 0);
      m.takeMentorPay(d);
      expect(m.sdGraduates, 1);
      expect(m.seasonTitles, contains(mentorTitle1));
    });

    test('three seats, no one over level 60', () {
      final m = _master();
      for (var i = 0; i < mentorMaxDisciples; i++) {
        expect(m.acceptDisciple('p_$i', 'P$i', 0, 10), isTrue);
      }
      expect(m.acceptDisciple('q_0', 'Q', 0, 10), isFalse);
      m.dropDisciple('p_0');
      expect(m.acceptDisciple('q_0', 'Q', 0, 61), isFalse);
      expect(m.acceptDisciple('q_0', 'Q', 0, 60), isTrue);
    });

    test('Truyền công: once a day each way', () {
      final m = _master()..acceptDisciple('p_0', 'P', 0, 10);
      expect(m.canTruyenCong('p_0', _day), isTrue);
      final e0 = m.essence;
      m.sentTruyenCong('p_0', _day);
      m.sentTruyenCong('p_0', _day);
      expect(m.essence, e0 + truyenCongEssence);
      expect(m.canTruyenCong('p_0', _day), isFalse);
      expect(m.canTruyenCong('p_0', '20261121'), isTrue);

      final p = _pupil()
        ..askMaster('m_0', 'M', 0)
        ..masterAccepted()
        ..sdTcReady = true;
      final xp = p.takeTruyenCong(_day);
      expect(xp, greaterThan(0));
      expect(p.takeTruyenCong(_day), 0);
    });

    test('Sư đồ survives a save', () {
      final m = _master()
        ..acceptDisciple('p_0', 'P', 3, 22)
        ..sdListing = true
        ..sdGraduates = 2;
      m.sentTruyenCong('p_0', _day);
      final p = _pupil()
        ..askMaster('m_0', 'Thầy', 1)
        ..masterAccepted()
        ..sdTcDay = _day;
      final mb = HeroData.fromJson(m.toJson());
      expect(mb.disciples.single.row, 'p_0');
      expect(mb.disciples.single.paid, 1);
      expect([mb.sdListing, mb.sdGraduates, mb.sdTcSent], [true, 2, {'p_0'}]);
      final pb = HeroData.fromJson(p.toJson());
      expect([pb.sdMaster, pb.sdMasterName, pb.sdMasterHanh, pb.sdTcDay], ['m_0', 'Thầy', 1, _day]);
      expect(pb.discipleExp, discipleExpBonus);
    });
  });

  group('over the server', () {
    final gs = GuildService.instance;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      gs.debug = true;
      gs.dMentorIn.clear();
      gs.dMentors.clear();
    });
    tearDown(() {
      gs.debug = false;
      Leaderboard.instance.debugEntries = null;
    });

    test('ask, accept, Truyền công, leave', () async {
      final m = _master(), p = _pupil(level: 18);
      _as('m', m);
      expect(await gs.mentorList(m, true, 0), isTrue);
      _as('p', p);
      final ads = await gs.mentors();
      expect(ads.single.row, 'm_0');
      expect(await gs.mentorSend(p, 'm_0', 'req', _day), isTrue);
      p.askMaster('m_0', m.name, 0);

      _as('m', m);
      final req = (await gs.mentorInbox()).single;
      expect([req.kind, req.level], ['req', 18]);
      expect(m.acceptDisciple(req.from, req.name, req.hanh, req.level), isTrue);
      await gs.mentorSend(m, req.from, 'ok', _day);
      await gs.mentorDrop(req.from);
      // Truyền công before the đệ tử looked: it stands in for the yes.
      await gs.mentorSend(m, req.from, 'tc', _day);
      expect(await gs.mentorInbox(), isEmpty);

      _as('p', p);
      final msg = (await gs.mentorInbox()).single;
      expect([msg.from, msg.kind], ['m_0', 'tc']);
      // Own heroes cannot write to each other.
      expect(await gs.mentorSend(p, 'p_1', 'req', _day), isFalse);
    });

    testWidgets('the Sư đồ tab handles a request and an answer', (tester) async {
      final m = _master(), p = _pupil(level: 18);
      _as('p', p);
      await gs.mentorSend(p, 'm_0', 'req', _day);
      p.askMaster('m_0', m.name, 0);
      Leaderboard.instance.debugEntries = [
        const LbEntry(id: 'p_0', name: 'Tân Thủ', hanh: 2, level: 31, rebirths: 0, power: 900, tower: 0),
      ];
      _as('m', m);
      await _pump(tester, const GuildScreen(tab: 2));
      expect(find.textContaining('Xin bái sư'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Nhận').first);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(m.discipleOf('p_0'), isNotNull);
      expect(tester.takeException(), isNull);

      _as('p', p);
      await _pump(tester, const GuildScreen(tab: 2));
      expect(p.sdMaster, 'm_0');
      expect(find.text('Sư phụ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('screens fit 700x330 at x1.1', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GuildService.instance.debug = true;
    });
    tearDown(() => GuildService.instance.debug = false);

    testWidgets('Sư đồ as a master with three đệ tử and requests', (tester) async {
      final m = _master();
      for (var i = 0; i < 3; i++) {
        m.acceptDisciple('p_$i', 'Đệ Tử Có Cái Tên Dài $i', i, 20);
      }
      m.seeDisciple('p_1', 'Đệ Tử Có Cái Tên Dài 1', 1, 45, 0);
      _as('m', m);
      GuildService.instance.dMentorIn['m_0'] = {
        'q_0': const MentorMsg('q_0', 'Người Xin Bái Sư', 3, 12, _day, 'req'),
      };
      await _pump(tester, const GuildScreen(tab: 2));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Đệ tử 3/3'), findsOneWidget);
    });

    testWidgets('Sư đồ as a đệ tử', (tester) async {
      final p = _pupil(level: 33)
        ..askMaster('m_0', 'Sư Phụ Lừng Danh Thiên Hạ', 0)
        ..masterAccepted()
        ..level = 41
        ..sdTcReady = true;
      _as('p', p);
      await _pump(tester, const GuildScreen(tab: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Nhận quà'), findsOneWidget);
    });

    testWidgets('Đồ giám, both books', (tester) async {
      final h = _master();
      h.codexGear.add(codexGearKey(9, Slot.weapon));
      h.mobKills['wolf'] = 300;
      _as('m', h);
      await _pump(tester, const CodexScreen());
      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining('Vạn thú phổ').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(700, 330) * 2.75;
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox()); // a fresh screen, not the last one
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
    home: home,
  ));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await load('BeVietnam', ['BeVietnamPro-Regular.ttf', 'BeVietnamPro-Bold.ttf', 'BeVietnamPro-ExtraBold.ttf']);
  await load('Playfair', ['PlayfairDisplay.ttf']);
}
