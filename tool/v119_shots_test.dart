// Renders the 1.19.0 screens to build/shots/v119_*.png for a look:
// flutter test tool/v119_shots_test.dart --update-goldens
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
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/codex_screen.dart';
import 'package:kiem_hiep/ui/guild_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';

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

Future<void> _shot(WidgetTester tester, Widget home, String name, {Future<void> Function()? then}) async {
  tester.view.physicalSize = const Size(915, 412) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), debugShowCheckedModeBanner: false, home: home));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      await precacheImage(img.image, e);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
  if (then != null) await then();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/shots/v119_$name.png'));
}

void main() {
  setUpAll(_fonts);
  setUp(() {
    GuildService.instance.debug = true;
    GuildService.instance.debugUid = 'm';
  });

  testWidgets('codex', (tester) async {
    final h = HeroData(name: 'Thử', hanh: Hanh.kim)..level = 72;
    h.recompute();
    for (var t = 0; t < 7; t++) {
      for (final s in Slot.values) {
        if ((t + s.index) % 3 != 0 || t < 3) h.codexGear.add(codexGearKey(t, s));
      }
    }
    h.codexClaimed.addAll(['g0', 'g1']);
    h.mobKills.addAll({'wolf': 300, 'boar': 300, 'bandit': 300, 'snake': 210, 'mcGu': 40});
    h.bossKillsById.addAll({'banditBoss': 12, 'snakeKing': 3});
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
    await _shot(tester, const CodexScreen(), 'codex_gear');
    await _shot(tester, const CodexScreen(tab: 1), 'codex_lands');
  });

  testWidgets('mentor', (tester) async {
    final m = HeroData(name: 'Độc Cô Cầu Bại', hanh: Hanh.kim)
      ..level = 99
      ..rebirths = 3;
    m.recompute();
    m.acceptDisciple('p_0', 'Tiểu Long Nữ', 2, 18);
    m.acceptDisciple('p_1', 'Lệnh Hồ Xung', 0, 33);
    m.seeDisciple('p_1', 'Lệnh Hồ Xung', 0, 52, 0);
    m.sdListing = true;
    SaveService.instance.slots[0] = m;
    SaveService.instance.active = 0;
    GuildService.instance.dMentorIn['m_0'] = {
      'q_0': const MentorMsg('q_0', 'Đoàn Dự', 4, 12, '20261120', 'req'),
    };
    await _shot(tester, const GuildScreen(tab: 2), 'mentor_master');

    final p = HeroData(name: 'Tiểu Long Nữ', hanh: Hanh.thuy)..level = 33;
    p.recompute();
    p
      ..askMaster('x_0', 'Độc Cô Cầu Bại', 0)
      ..masterAccepted()
      ..level = 41
      ..sdTcReady = true;
    SaveService.instance.slots[0] = p;
    GuildService.instance.debugUid = 'p';
    await _shot(tester, const GuildScreen(tab: 2), 'mentor_pupil');
    expect(discipleExpBonus, 0.1);
  });
}
