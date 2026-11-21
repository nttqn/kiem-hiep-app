import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/bond.dart';
import 'package:kiem_hiep/core/codex.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/helper.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/ky_ngo.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/codex_screen.dart';
import 'package:kiem_hiep/ui/guild_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v130_realm_test.dart' show geared;

const _day = '20261121';

HeroData _hero(String name, {int level = 60, Hanh hanh = Hanh.kim}) {
  final h = HeroData(name: name, hanh: hanh)..level = level;
  h.recompute();
  return h;
}

void _as(String uid, HeroData h) {
  SaveService.instance.slots[0] = h;
  SaveService.instance.active = 0;
  GuildService.instance.debugUid = uid;
}

void main() {
  setUpAll(_fonts);

  group('Kỳ ngộ', () {
    test('kinds, chance and the daily cap', () {
      expect(KyNgo.values.length, 8);
      final r = math.Random(1);
      final low = _hero('Tân', level: kyMinLevel - 1);
      expect(low.rollKy(_day, true, r, force: KyNgo.anSi), isNull);
      final h = _hero('Hiệp');
      for (var i = 0; i < kyDaily; i++) {
        expect(h.rollKy(_day, false, r, force: KyNgo.ruongCo), KyNgo.ruongCo);
      }
      expect(h.rollKy(_day, true, r, force: KyNgo.ruongCo), isNull);
      expect(h.kyLeft(_day), 0);
      expect(h.kyLeft('20261122'), kyDaily);
      expect(h.kySeen(KyNgo.ruongCo), kyDaily);
      expect(h.kyTotal, kyDaily);
      // About one in 200 ordinary kills.
      final f = _hero('Đếm');
      var n = 0;
      for (var i = 0; i < 4000; i++) {
        f.kyToday = 0;
        if (f.rollKy(_day, false, r) != null) n++;
      }
      expect(n, inInclusiveRange(10, 35));
      // Rarer kinds are rarer.
      final counts = <KyNgo, int>{};
      for (var i = 0; i < 20000; i++) {
        final k = rollKyNgo(r);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      expect(counts[KyNgo.anSi]!, greaterThan(counts[KyNgo.thienThach]! * 3));
    });

    test('a torn page needs bí kíp open', () {
      final h = _hero('Nhỏ', level: 10);
      expect(h.manualOpen, isFalse);
      expect(h.rollKy(_day, false, math.Random(1), force: KyNgo.biKip), KyNgo.anSi);
    });

    test('what each meeting pays', () {
      final r = math.Random(3);
      final h = _hero('Hiệp', level: 70);
      final exp0 = h.exp, gold0 = h.gold, hp0 = h.hpPots;
      expect(h.payKy(KyNgo.anSi, r), isNotEmpty);
      expect(h.exp > exp0 || h.level > 70, isTrue);
      h.payKy(KyNgo.ruongCo, r);
      expect(h.gold, greaterThan(gold0));
      h.payKy(KyNgo.linhDuoc, r, herbTier: 1);
      expect(h.hpPots, hp0 + kyPots);
      expect(h.herbs[1], kyHerbs);
      final mul0 = h.expMul;
      h.payKy(KyNgo.tienChi, r);
      expect(h.expMul, closeTo(mul0 * (1 + kyBlessBonus), 1e-9));
      h.tickKyBless(kyBlessSec + 1);
      expect(h.kyBless, 0);
      expect(h.expMul, closeTo(mul0, 1e-9));
      final iron0 = h.divineIron;
      h.payKy(KyNgo.thienThach, r);
      expect(h.divineIron, iron0, reason: 'gems before a rebirth');
      expect(h.gemBag.values.fold<int>(0, (a, b) => a + b), kyStarGems);
      h.rebirths = 1;
      h.payKy(KyNgo.thienThach, r);
      expect(h.divineIron, iron0 + kyStarIron);
      expect(h.payKy(KyNgo.caoThu, r), isEmpty);
      final ess0 = h.essence;
      expect(h.kyFightEssence(KyNgo.maDau), kyMaDauEssence);
      expect(h.essence, ess0 + kyMaDauEssence);
      expect(_hero('Nhỏ', level: 30).kyFightEssence(KyNgo.caoThu), 0);
    });

    test('Kỳ ngộ phổ pages and titles', () {
      final h = _hero('Hiệp');
      expect(h.kyClaimPage(KyNgo.anSi), isEmpty);
      for (final k in KyNgo.values) {
        h.kyCount[k.name] = kyPageNeed;
      }
      expect(h.kyPagesReady, KyNgo.values.length);
      expect(h.codexReady, greaterThanOrEqualTo(KyNgo.values.length));
      final ess0 = h.essence;
      for (final k in KyNgo.values) {
        expect(h.kyClaimPage(k), isNotEmpty);
      }
      expect(h.essence, ess0 + kyPageEssence * KyNgo.values.length);
      expect(h.seasonTitles, contains(kyAllTitle));
      expect(h.kyClaimPage(KyNgo.anSi), isEmpty);
      h.kyTotal = 50;
      expect(h.kyTitles(), ['Danh hiệu « Kỳ Duyên Khách »']);
      expect(h.kyTitles(), isEmpty);
    });

    test('meetings in the field: the challenger appears and pays', () {
      final h = geared(60, Hanh.kim);
      World.debugKy = KyNgo.caoThu;
      addTearDown(() => World.debugKy = null);
      final w = World.field(h, mapById['magiao']!, seed: 4)..auto = true;
      var saw = false, won = false;
      final ess0 = h.essence;
      for (var t = 0; t < 6 * 60 * 30 && !won; t++) {
        w.update(1 / 30);
        for (final e in w.events) {
          if (e.text.contains('Kỳ ngộ · ${KyNgo.caoThu.label}')) saw = true;
          if (e.text.contains('Đã hạ $kyCaoThuName')) won = true;
          if (e.kind == EvKind.heroDied) w.reviveHere();
        }
        w.events.clear();
      }
      expect(saw, isTrue);
      expect(won, isTrue);
      expect(h.kySeen(KyNgo.caoThu), greaterThan(0));
      expect(h.kyToday, lessThanOrEqualTo(kyDaily));
      expect(h.essence, greaterThan(ess0));
    });

    test('the ma đầu brings followers', () {
      final h = geared(60, Hanh.thuy);
      World.debugKy = KyNgo.maDau;
      addTearDown(() => World.debugKy = null);
      final w = World.field(h, mapById['magiao']!, seed: 2)..auto = true;
      var spawned = false;
      var grew = 0;
      for (var t = 0; t < 3 * 60 * 30 && !spawned; t++) {
        final before = w.mobs.length;
        w.update(1 / 30);
        spawned = w.mobs.any((m) => m.eliteKey == kyMaDauKey && m.alive);
        if (spawned) grew = w.mobs.length - before;
        for (final e in w.events) {
          if (e.kind == EvKind.heroDied) w.reviveHere();
        }
        w.events.clear();
      }
      expect(spawned, isTrue);
      // The leader and its followers (a strong hero may cut the followers
      // down in the same moment).
      expect(grew, greaterThanOrEqualTo(1 + kyMaDauMinions));
    });

    test('saves and loads', () {
      final h = _hero('Hiệp')
        ..kyDay = _day
        ..kyToday = 3
        ..kyTotal = 41
        ..kyBless = 120;
      h.kyCount['anSi'] = 7;
      h.kyClaimed.add('anSi');
      final b = HeroData.fromJson(h.toJson());
      expect([b.kyDay, b.kyToday, b.kyTotal, b.kyCount['anSi'], b.kyBless], [_day, 3, 41, 7, 120]);
      expect(b.kyClaimed, {'anSi'});
      // An old save has none of it.
      final c = HeroData.fromJson(_hero('Cũ').toJson());
      expect(c.kyTotal, 0);
    });
  });

  group('Kết duyên', () {
    test('ring levels, bonuses and titles', () {
      expect(bondRingAt(0), 0);
      expect(bondRingAt(bondRingNeeds.first), 1);
      expect(bondRingAt(99999), bondRingMax);
      for (var i = 1; i < bondRingNeeds.length; i++) {
        expect(bondRingNeeds[i], greaterThan(bondRingNeeds[i - 1]));
      }
      expect(bondDaysBetween('20261130', '20261202'), 2);
      expect(bondDaysBetween('', '20261202'), 0);
    });

    test('Tình ý: each way once a day, the ring counts only while bonded', () {
      final h = _hero('Phu');
      expect(h.addLove(LoveWay.sent, _day), isEmpty, reason: 'not bonded');
      h.bondWith('b_0', 'Thê', 1, _day);
      final hp0 = h.stats.maxHp;
      for (final w in LoveWay.values) {
        expect(h.addLove(w, _day), isNotEmpty);
        expect(h.addLove(w, _day), isEmpty);
      }
      expect(h.kdLove, bondLovePer * LoveWay.values.length);
      expect(h.bondRing, 1);
      expect(h.stats.maxHp, greaterThan(hp0));
      expect(h.bondBadge(_day), 0);
      expect(h.bondBadge('20261122'), 1);
      h.kdLove = bondRingNeeds[5] - 1;
      final lines = h.addLove(LoveWay.sent, '20261122');
      expect(lines.join(), contains('Song Kiếm Hợp Bích'));
      expect(h.seasonTitles, containsAll(['Tâm Đầu Ý Hợp', 'Song Kiếm Hợp Bích']));
      h.part('20261122');
      expect([h.bonded, h.kdLove, h.bondRing], [false, 0, 0]);
      expect(h.stats.maxHp, closeTo(hp0, 1e-6));
      expect(h.canBond('20261123'), isFalse);
      expect(h.bondWait('20261123'), 2);
      expect(h.canBond('20261125'), isTrue);
      expect(_hero('Nhỏ', level: bondMinLevel - 1).canBond(_day), isFalse);
      expect((_hero('CS', level: 5)..rebirths = 1).canBond(_day), isTrue);
    });

    test('the partner in Trợ chiến', () {
      final h = _hero('Phu');
      expect(h.helpCap, helpCallsPerDay);
      h.bondWith('b_0', 'Thê', 1, _day);
      expect(h.helpCap, helpCallsPerDay + 1);
      expect(h.helperMulFor('b_0', h.power), closeTo(helperMul(h.power, h.power) * bondHelperMul, 1e-9));
      expect(h.helperMulFor('c_0', h.power), closeTo(helperMul(h.power, h.power), 1e-9));
    });

    test('saves and loads', () {
      final h = _hero('Phu')..bondWith('b_0', 'Thê', 3, _day);
      h.addLove(LoveWay.sent, _day);
      h.kdPartedDay = '20261101';
      final b = HeroData.fromJson(h.toJson());
      expect([b.kdPartner, b.kdPartnerName, b.kdPartnerHanh, b.kdSince, b.kdLove], ['b_0', 'Thê', 3, _day, bondLovePer]);
      expect(b.loveDone(LoveWay.sent, _day), isTrue);
      expect(b.kdPartedDay, '20261101');
      expect(HeroData.fromJson(_hero('Cũ').toJson()).bonded, isFalse);
    });

    group('over the server', () {
      final gs = GuildService.instance;
      setUp(() {
        SharedPreferences.setMockInitialValues({});
        gs.debug = true;
        gs.dBondIn.clear();
      });
      tearDown(() {
        gs.debug = false;
        Leaderboard.instance.debugEntries = null;
      });

      test('own heroes cannot bond', () async {
        final a = _hero('A');
        _as('a', a);
        expect(await gs.bondSend(a, 'a_1', 'req', _day), isFalse);
        expect(await gs.bondSend(a, 'b_0', 'req', _day), isTrue);
      });

      testWidgets('propose, accept, Tương tư, part', (tester) async {
        final a = _hero('Lãng Khách'), b = _hero('Hồng Y', hanh: Hanh.thuy);
        Leaderboard.instance.debugEntries = [
          const LbEntry(id: 'a_0', name: 'Lãng Khách', hanh: 0, level: 60, rebirths: 0, power: 900, tower: 0),
          const LbEntry(id: 'b_0', name: 'Hồng Y', hanh: 2, level: 60, rebirths: 0, power: 800, tower: 0),
        ];
        // A proposes to B, a friend.
        a.friends.clear();
        _as('a', a);
        await gs.bondSend(a, 'b_0', 'req', _day);
        a.askBond('b_0', b.name, 2, _day);

        _as('b', b);
        await _pump(tester, const GuildScreen(tab: 3));
        expect(find.textContaining('Lời cầu duyên'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('Nhận lời').first);
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(b.kdPartner, 'a_0');
        expect(tester.takeException(), isNull);

        // B sends Tương tư before A looks: it stands in for the yes.
        await tester.runAsync(() async {
          await tester.tap(find.text('Gửi Tương tư'));
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(b.kdLove, bondLovePer);

        _as('a', a);
        await _pump(tester, const GuildScreen(tab: 3));
        expect(a.kdPartner, 'b_0');
        expect(a.isFriendRow('b_0'), isTrue);
        expect(a.loveDone(LoveWay.got, vnDay()), isTrue);
        expect(find.text('Phu thê'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // A parts; B learns of it.
        await gs.bondSend(a, 'b_0', 'bye', _day);
        a.part(_day);
        _as('b', b);
        await _pump(tester, const GuildScreen(tab: 3));
        expect(b.bonded, isFalse);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('screens fit 700x330 at x1.1', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GuildService.instance.debug = true;
      GuildService.instance.dBondIn.clear();
    });
    tearDown(() => GuildService.instance.debug = false);

    testWidgets('Kết duyên, bonded', (tester) async {
      final h = _hero('Hiệp Khách')..bondWith('b_0', 'Người Thương Có Cái Tên Rất Dài', 4, _day);
      h.kdLove = 230;
      _as('a', h);
      await _pump(tester, const GuildScreen(tab: 3));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Nhẫn Đồng Tâm · cấp'), findsOneWidget);
    });

    testWidgets('Kết duyên, proposals waiting', (tester) async {
      final h = _hero('Hiệp Khách')..askBond('c_0', 'Người Đang Được Cầu Duyên', 1, _day);
      GuildService.instance.dBondIn['a_0'] = {
        'q_0': const BondMsg('q_0', 'Người Cầu Duyên Tên Dài', 3, 55, 1, _day, 'req'),
      };
      _as('a', h);
      await _pump(tester, const GuildScreen(tab: 3));
      expect(tester.takeException(), isNull);
      expect(find.text('Nhận lời'), findsOneWidget);
    });

    testWidgets('Đồ giám, Kỳ ngộ phổ', (tester) async {
      final h = _hero('Hiệp Khách');
      h.kyCount['anSi'] = 3;
      h.kyCount['maDau'] = 1;
      h.kyBless = 300;
      _as('a', h);
      await _pump(tester, const CodexScreen(tab: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Nhận'), findsOneWidget);
    });
  });
}

String vnDay() {
  final v = DateTime.now().toUtc().add(const Duration(hours: 7));
  return '${v.year}${'${v.month}'.padLeft(2, '0')}${'${v.day}'.padLeft(2, '0')}';
}

extension on HeroData {
  bool isFriendRow(String row) => friends.any((f) => f.row == row);
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(700, 330) * 2.75;
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
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
