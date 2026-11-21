// Renders the 1.20.0 screens to build/shots/v120_*.png for a look:
// flutter test tool/v120_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiem_hiep/core/bond.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/core/guild.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      await precacheImage(img.image, e);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
  if (then != null) await then();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/shots/v120_$name.png'));
}

void _as(HeroData h) {
  SaveService.instance.slots[0] = h;
  SaveService.instance.active = 0;
}

void main() {
  setUpAll(_fonts);
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    GuildService.instance.debug = true;
    GuildService.instance.debugUid = 'a';
    GuildService.instance.dBondIn.clear();
    Leaderboard.instance.debugEntries = [
      const LbEntry(id: 'b_0', name: 'Hồng Y Tiên Tử', hanh: 2, level: 70, rebirths: 0, power: 41200, tower: 0),
      const LbEntry(id: 'c_0', name: 'Thanh Phong', hanh: 4, level: 66, rebirths: 0, power: 38800, tower: 0),
      const LbEntry(id: 'd_0', name: 'Tử Vân', hanh: 1, level: 1, rebirths: 2, power: 90500, tower: 0),
    ];
  });

  testWidgets('bond_bonded', (tester) async {
    final h = HeroData(name: 'Lãng Khách', hanh: Hanh.kim)..level = 72;
    h.bondWith('b_0', 'Hồng Y Tiên Tử', 2, '20261101');
    h.kdLove = 230;
    h.addLove(LoveWay.sent, vnDayKey());
    h.recompute();
    _as(h);
    await _shot(tester, const GuildScreen(tab: 3), 'bond_bonded');
  });

  testWidgets('bond_free', (tester) async {
    final h = HeroData(name: 'Lãng Khách', hanh: Hanh.kim)..level = 72;
    h.addFriend('c_0', 'Thanh Phong', 4);
    h.addFriend('d_0', 'Tử Vân', 1);
    h.recompute();
    GuildService.instance.dBondIn['a_0'] = {
      'q_0': BondMsg('q_0', 'Bạch Y Kiếm Khách', 3, 55, 1, vnDayKey(), 'req'),
    };
    _as(h);
    await _shot(tester, const GuildScreen(tab: 3), 'bond_free');
  });

  testWidgets('kyngo', (tester) async {
    final h = HeroData(name: 'Lãng Khách', hanh: Hanh.kim)..level = 72;
    h.kyCount.addAll({'anSi': 4, 'ruongCo': 3, 'linhDuoc': 2, 'maDau': 1, 'caoThu': 3});
    h.kyClaimed.add('ruongCo');
    h.kyTotal = 13;
    h.kyBless = 420;
    h.recompute();
    _as(h);
    await _shot(tester, const CodexScreen(tab: 2), 'kyngo');
  });
}
