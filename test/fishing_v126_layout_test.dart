import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/fishing.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/fish_book.dart';
import 'package:kiem_hiep/ui/fish_shop.dart';
import 'package:kiem_hiep/ui/fishing_view.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.26 fishing: the Ngư phủ, the Ngư phổ with records and the pond panel
/// fit small landscape phones with the game's fonts at x1.1 text.
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

HeroData _hero() {
  final h = HeroData(name: 'Ngư Ông', hanh: Hanh.thuy)
    ..level = 90
    ..fishCoins = 123456
    ..fishPts = 98765
    ..fishRod = 5
    ..fishLure = 'than';
  h.fishLures.addAll({'tom': 120, 'linh': 33, 'than': 9});
  for (final f in fishes) {
    h.fishCaught[f.id] = 123;
    h.fishBest[f.id] = 1234;
  }
  return h;
}

Future<void> _pump(WidgetTester tester, Size s, Widget Function(BuildContext) open, {bool dialog = true}) async {
  SharedPreferences.setMockInitialValues({});
  final h = _hero();
  SaveService.instance.slots[0] = h;
  SaveService.instance.active = 0;
  tester.view.physicalSize = s * 2.75;
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
    home: Scaffold(body: Builder(builder: (c) => dialog ? Center(child: TextButton(onPressed: () => open(c), child: const Text('open'))) : open(c))),
  ));
  if (dialog) {
    await tester.tap(find.text('open'));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_fonts);

  for (final s in const [Size(700, 330), Size(760, 344)]) {
    testWidgets('Ngư phủ fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      await _pump(tester, s, (c) {
        showFishShop(c, SaveService.instance.hero);
        return const SizedBox();
      });
      expect(tester.takeException(), isNull);
      expect(find.text('Ngư phủ'), findsOneWidget);
    });

    testWidgets('Ngư phổ with records fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      await _pump(tester, s, (c) {
        showFishBook(c, SaveService.instance.hero);
        return const SizedBox();
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('pond panel fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      await _pump(tester, s, (c) => Center(child: FishingPanel(mapId: 'conlon', onClose: () {})), dialog: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Ngư phủ'), findsOneWidget);
    });
  }
}
