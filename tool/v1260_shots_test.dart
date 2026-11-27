import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiem_hiep/core/codex.dart';
import 'package:kiem_hiep/core/fishing.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/ui/codex_screen.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/ui/fish_book.dart';
import 'package:kiem_hiep/ui/fish_shop.dart';
import 'package:kiem_hiep/ui/fishing_view.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/save.dart';
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

Future<void> _shot(WidgetTester tester, Widget home, String name, {Future<void> Function()? then, Size size = const Size(915, 412)}) async {
  tester.view.physicalSize = size * 2;
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
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/shots/v1260_$name.png'));
}

void _as(HeroData h) {
  SaveService.instance.slots[0] = h;
  SaveService.instance.active = 0;
}

HeroData _hero() {
  final h = HeroData(name: 'Ngư Ông', hanh: Hanh.thuy)
    ..level = 70
    ..gold = 50000000
    ..fishCoins = 820
    ..fishRod = 3
    ..fishLure = 'linh';
  h.fishLures.addAll({'tom': 12, 'linh': 3, 'than': 1});
  for (final f in fishes.take(30)) {
    h.fishCaught[f.id] = 3;
  }
  return h;
}

void main() {
  setUpAll(_fonts);
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('panel', (tester) async {
    _as(_hero());
    await _shot(tester, Scaffold(backgroundColor: Colors.black, body: Center(child: FishingPanel(mapId: 'vanvu', onClose: () {}))), 'panel');
  });
  testWidgets('shop', (tester) async {
    _as(_hero());
    await _shot(tester, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showFishShop(c, SaveService.instance.hero), child: const Text('open')))), 'shop',
        then: () async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    });
  });
  testWidgets('book', (tester) async {
    _as(_hero());
    await _shot(tester, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showFishBook(c, SaveService.instance.hero), child: const Text('open')))), 'book',
        then: () async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    });
  });
  testWidgets('legend', (tester) async {
    final h = _hero();
    for (var n = 0; n < legendNames.length; n++) {
      for (final sl in Slot.values.take(n + 2 > Slot.values.length ? Slot.values.length : n + 2)) {
        h.codexGear.add(codexLegendKey(n, sl));
      }
    }
    h.codexClaimed.add(codexLegendPage(5));
    _as(h);
    await _shot(tester, const CodexScreen(tab: 3), 'legend');
  });
  for (final sz in const [Size(760, 344), Size(800, 380)]) {
    testWidgets('codex_phone_${sz.width.toInt()}', (tester) async {
      final h = _hero()..gold = 465399720;
      h.codexClaimed.add(codexLegendPage(5));
      _as(h);
      await _shot(tester, const CodexScreen(), 'codex_phone_${sz.width.toInt()}', size: sz);
    });
  }
}
