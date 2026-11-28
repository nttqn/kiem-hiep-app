import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/ledger.dart';
import 'package:kiem_hiep/core/star_up.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/character_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hoàn sao (1.28.0): stars off for part of their cost back, and its button
/// beside Thăng and Chuyển sao fitting small landscape phones at x1.1 text.
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

  test('Hoàn sao pays back 70% Tinh Phách, 50% Tinh Thạch, never more than went in', () {
    final h = HeroData(name: 'H', hanh: Hanh.thuy)..level = 99;
    Item piece(int star) =>
        makeItem(slot: Slot.ring, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(star))
          ..plus = maxPlus
          ..star = star;
    expect(starRefundSouls(piece(3)), 0); // ★1-★3 take no Tinh Phách
    expect(starRefundSouls(piece(4)), 1); // 2 spent
    expect(starRefundSouls(piece(5)), 4); // 6 spent
    expect(starRefundStones(piece(5)), 100); // 200 spent
    for (var star = 1; star <= maxStar; star++) {
      expect(starRefundSouls(piece(star)), lessThanOrEqualTo(starSoulsTo(star)));
      expect(starRefundStones(piece(star)), lessThan(starStonesTo(star)));
    }
    // Star up from nothing, then refund: always behind.
    h
      ..beastSouls = 100
      ..starStones = 5000
      ..gold = 999999999;
    final it = piece(0);
    h.equip[Slot.ring] = it;
    for (var i = 0; i < 7; i++) {
      expect(h.starUp(it), isTrue);
    }
    expect(soulsInvested(h.equip.values.whereType<Item>()), starSoulsTo(7));
    final before = h.power;
    expect(h.refundStars(it), isTrue);
    expect(it.star, 0);
    expect(h.beastSouls, 100 - starSoulsTo(7) + (starSoulsTo(7) * 0.7).floor());
    expect(h.beastSouls, lessThan(100));
    expect(h.starStones, lessThan(5000));
    expect(h.power, lessThan(before));
    expect(h.refundStars(it), isFalse);
  });

  for (final s in const [Size(700, 330), Size(760, 344)]) {
    testWidgets('Hoàn sao fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.thuy)
        ..level = 99
        ..gold = 99999999
        ..starStones = 9999;
      Item piece(int seed, int star) =>
          makeItem(slot: Slot.weapon, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(seed))
            ..plus = maxPlus
            ..star = star
            ..extraSockets = 2;
      final worn = piece(1, 5);
      h.equip[Slot.weapon] = worn;
      // The larger screen has no piece to swap with: Hoàn sao still shows.
      if (s.width < 750) h.bag.add(piece(2, 3));
      h.recompute();
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      tester.view.physicalSize = s * 2.75;
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
        home: Scaffold(
            body: Builder(
                builder: (c) => Center(
                    child: TextButton(
                        onPressed: () => showDialog<void>(context: c, builder: (_) => ItemDialog(item: worn, forge: false)),
                        child: const Text('open'))))),
      ));
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final up = find.text('Thăng ★6');
      expect(up, findsOneWidget);
      expect(tester.renderObject<RenderParagraph>(up).didExceedMaxLines, isFalse);
      await tester.tap(find.byKey(const ValueKey('starMove')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('starRefund')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('starRefund')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('starRefundOk')));
      await tester.pump();
      final souls = h.beastSouls;
      await tester.tap(find.byKey(const ValueKey('starRefundOk')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(worn.star, 0);
      expect(h.beastSouls, souls + 4);
    });
  }
}
