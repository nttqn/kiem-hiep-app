import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/ui/hero_card.dart';
import 'package:kiem_hiep/ui/theme.dart';

const _sizes = [Size(760, 344), Size(915, 412), Size(1280, 800)];

HeroData _hero() {
  final h = HeroData(name: 'Kiếm Thánh Vô Danh', hanh: Hanh.kim, female: true)
    ..level = 99
    ..rebirths = 6
    ..daoLv = 12
    ..divine = 5
    ..title = 'Hoàng Kim Bá Chủ';
  for (final s in Slot.values) {
    h.equip[s] = makeItem(slot: s, level: 95, rarity: Rarity.legend, sect: h.sect, rng: math.Random(s.index))
      ..plus = 10
      ..star = 3;
  }
  h.recompute();
  return h;
}

/// A board row as Firestore would hand it back.
LbEntry _row(HeroData h) {
  final m = jsonDecode(jsonEncode({
    'name': h.name,
    'hanh': h.hanh.index,
    'level': h.level,
    'rebirths': h.rebirths,
    'power': h.power,
    'tower': 321,
    'title': h.title,
    'dao': h.daoLv,
    'mount': '',
    'look': lookRow(h),
    'st': statRow(h),
  })) as Map<String, dynamic>;
  return LbEntry.fromDoc('u_0', m)!;
}

void main() {
  test('looks, gear and stats survive the board row', () {
    final h = _hero();
    final e = _row(h);
    expect(e.look!['f'], isTrue);
    expect(e.look!['dv'], 5);
    expect((e.look!['eq'] as List).length, Slot.values.length);
    expect(e.st!.length, 8);
    expect(e.st![2], h.stats.atk.round());
    // Rows from older apps carry neither.
    final old = LbEntry.fromDoc('u_1', {'name': 'X', 'hanh': 0, 'level': 5, 'power': 10})!;
    expect(old.look, isNull);
    expect(old.st, isNull);
  });

  for (final s in _sizes) {
    testWidgets('hero card fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      tester.view.physicalSize = s * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final e = _row(_hero());
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(child: TextButton(onPressed: () => showHeroCard(ctx, e), child: const Text('go'))),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text('Kiếm Thánh Vô Danh'), findsOneWidget);
      expect(find.text('Lực chiến'), findsOneWidget);
      expect(find.text('Trang bị'), findsOneWidget);
    });
  }

  testWidgets('menu offers Xem thông tin and Báo cáo, only the first for oneself', (tester) async {
    final e = _row(_hero());
    for (final mine in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(mine),
        theme: buildTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
                child: TextButton(onPressed: () => showLbHeroMenu(ctx, e, mine: mine), child: const Text('go'))),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Xem thông tin'), findsOneWidget);
      expect(find.text('Báo cáo gian lận'), mine ? findsNothing : findsOneWidget);
      await tester.tap(find.text('Xem thông tin'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Trang bị'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
