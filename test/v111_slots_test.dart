import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:kiem_hiep/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('five slots; typing the name to delete ignores case and spaces', () {
    expect(slotCount, 5);
    expect(SaveService.instance.slots.length, 5);
    expect(deleteNameMatches(' đằng viêm ', 'Đằng Viêm'), isTrue);
    expect(deleteNameMatches('Dang Viem', 'Đằng Viêm'), isFalse);
  });

  for (final s in const [Size(760, 344), Size(915, 412), Size(1280, 800)]) {
    testWidgets('the hero list fits ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = s * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final save = SaveService.instance;
      for (var i = 0; i < slotCount; i++) {
        save.slots[i] = i == 2 ? null : (HeroData(name: 'Hiệp $i', hanh: Hanh.values[i])..level = 20 + i * 15);
      }
      save.slots[4]!.rebirths = 2;
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const TitleScreen()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.delete_outline, skipOffstage: false), findsNWidgets(4));

      // A reborn hero asks for its name before it goes.
      await tester.dragUntilVisible(find.text('Hiệp 4'), find.byType(SingleChildScrollView).first, const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Gõ tên nhân vật để xác nhận:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Xóa'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(save.slots[4], isNotNull, reason: 'name not typed yet');
      await tester.enterText(find.byType(TextField), 'hiệp 4');
      await tester.pump();
      await tester.tap(find.text('Xóa'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(save.slots[4], isNull);
      save.slots.fillRange(0, slotCount, null);
      save.backups.fillRange(0, slotCount, null);
    });
  }
}
