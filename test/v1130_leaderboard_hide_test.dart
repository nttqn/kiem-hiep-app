import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/leaderboard_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.13.0: top players lost their names from the boards with no idea why.
/// A stray tap on "Ẩn tôi khỏi bảng" (half off the screen on small phones
/// in 1.12.0) deleted their rows at once; hiding now asks first and the
/// board says when the player is hidden or their row was not taken.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final h = HeroData(name: 'Nhân Long', hanh: Hanh.moc)
      ..level = 99
      ..rebirths = 6;
    h.recompute();
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
    Leaderboard.instance
      ..hidden = false
      ..submitError = null
      ..debugEntries = [
        LbEntry(id: 'u_0', name: 'Người khác', hanh: 0, level: 99, rebirths: 6, power: 5000000, tower: 200),
      ];
  });
  tearDown(() {
    Leaderboard.instance
      ..debugEntries = null
      ..hidden = false
      ..submitError = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LeaderboardScreen()));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('hiding asks first; "Hủy" keeps the player on the board', (tester) async {
    await open(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ẩn khỏi bảng xếp hạng?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Leaderboard.instance.hidden, isFalse);
    expect(find.textContaining('Bạn đang ẩn khỏi bảng', skipOffstage: false), findsNothing);
  });

  testWidgets('confirmed, the board says the player is hidden', (tester) async {
    await open(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ẩn'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Leaderboard.instance.hidden, isTrue);
    expect(find.textContaining('Bạn đang ẩn khỏi bảng', skipOffstage: false), findsOneWidget);
    // Showing again needs no asking.
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ẩn khỏi bảng xếp hạng?'), findsNothing);
    expect(Leaderboard.instance.hidden, isFalse);
  });

  testWidgets('a row the server would not take is shown, not swallowed', (tester) async {
    Leaderboard.instance.submitError =
        Leaderboard.submitErrorText(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await open(tester);
    expect(find.textContaining('Máy chủ không nhận', skipOffstage: false), findsOneWidget);
  });

  test('failed writes are put in words', () {
    String t(String code) => Leaderboard.submitErrorText(FirebaseException(plugin: 'cloud_firestore', code: code));
    expect(t('permission-denied'), contains('Máy chủ không nhận'));
    expect(t('unauthenticated'), contains('đăng nhập lại'));
    expect(t('unavailable'), contains('Mạng yếu'));
    expect(Leaderboard.submitErrorText(Exception('timeout')), contains('Mạng yếu'));
  });
}
