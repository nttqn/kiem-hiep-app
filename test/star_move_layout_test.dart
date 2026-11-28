import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/character_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chuyển sao: the item dialog with its extra button, and the picker, fit
/// small landscape phones with the game's fonts at x1.1 text.
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

void main() {
  setUpAll(_fonts);

  for (final s in const [Size(700, 330), Size(760, 344)]) {
    for (final bagSide in [false, true]) {
      testWidgets('Chuyển sao fits ${s.width.toInt()}x${s.height.toInt()} (${bagSide ? 'bag' : 'worn'})', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.hoa)
          ..level = 99
          ..gold = 99999999
          ..starStones = 9999;
        Item piece(int seed, int star) =>
            makeItem(slot: Slot.weapon, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(seed))
              ..plus = maxPlus
              ..star = star
              ..extraSockets = 2;
        final worn = piece(1, 7);
        h.equip[Slot.weapon] = worn;
        for (var i = 0; i < 6; i++) {
          h.bag.add(piece(10 + i, i % 3));
        }
        h.recompute();
        SaveService.instance.slots[0] = h;
        SaveService.instance.active = 0;
        tester.view.physicalSize = s * 2.75;
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        final it = bagSide ? h.bag.first : worn;
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (c) => Center(
                      child: TextButton(
                          onPressed: () => showDialog<void>(context: c, builder: (_) => ItemDialog(item: it, forge: false)),
                          child: const Text('open'))))),
        ));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        final btn = tester.getRect(find.byKey(const ValueKey('starMove')));
        expect(btn.bottom, lessThan(s.height - 24));
        await tester.tap(find.byKey(const ValueKey('starMove')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Chuyển'), findsWidgets);
        await tester.tap(find.text('Chuyển').first);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(worn.star, isNot(7));
      });
    }
  }
}
