import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/festival.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/live_event.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/branch_dialog.dart';
import 'package:kiem_hiep/ui/fest_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OPPO A57 landscape, a common phone, a tablet.
const _sizes = [Size(760, 344), Size(915, 412), Size(1280, 800)];

HeroData _hero() {
  final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.hoa)
    ..level = 99
    ..rebirths = 2
    ..gold = 5000000
    ..divineIron = 40;
  h.recompute();
  return h;
}

Future<void> _at(WidgetTester tester, Size s, Widget home) async {
  tester.view.physicalSize = s * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    liveEvents = const [LiveEvent(id: 't', fest: 'dongchi')];
  });
  tearDown(() => liveEvents = const []);

  for (final s in _sizes) {
    testWidgets('Lễ hội fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      final h = _hero();
      h.festRoll(festivals.first, vnDayKey());
      h.festCoins = 1234;
      h.festKills = 70;
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      await _at(tester, s, const FestScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Đổi quà'), findsOneWidget);
    });

    testWidgets('Lưu phái fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      final h = _hero()..branch = 0;
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      await _at(
        tester,
        s,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showBranchDialog(context, h), child: const Text('go')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text('Hộ Hỏa Đường'), findsOneWidget);
      expect(find.text('Tu luyện'), findsOneWidget);
    });
  }
}
