import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/leaderboard_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OPPO A57 landscape, the phone in the 1.13.0 report, a common phone, a
/// tablet.
const _sizes = [Size(760, 344), Size(835, 382), Size(915, 412), Size(1280, 800)];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final h = HeroData(name: 'Win', hanh: Hanh.hoa)
      ..level = 99
      ..rebirths = 6
      ..daoLv = 1;
    h.recompute();
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
    Leaderboard.instance.debugEntries = [
      for (var i = 0; i < 12; i++)
        LbEntry(
            id: 'u${i}_0', name: 'Người $i', hanh: i % 5, level: 99, rebirths: 6, power: 5000000 - i * 1000, tower: 200, dao: i),
    ];
  });
  tearDown(() => Leaderboard.instance.debugEntries = null);

  for (final s in _sizes) {
    testWidgets('Xếp hạng keeps "Ẩn tôi khỏi bảng" in sight at ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      tester.view.physicalSize = s * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LeaderboardScreen()));
      await tester.pump(const Duration(milliseconds: 600));
      final ex = tester.takeException();
      expect(ex, isNull);
      final sw = find.byType(Switch);
      expect(sw, findsOneWidget);
      final r = tester.getRect(sw);
      expect(r.bottom, lessThanOrEqualTo(s.height));
      expect(find.text('Vị trí của tôi'), findsOneWidget);
      expect(tester.getRect(find.text('Vị trí của tôi')).bottom, lessThanOrEqualTo(s.height));
    });
  }
}
