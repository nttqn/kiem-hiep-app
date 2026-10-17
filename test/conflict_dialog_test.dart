import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/cloud.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/services/sync_plan.dart';
import 'package:kiem_hiep/ui/cloud_panel.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

HeroData hero(int level, int savedAt) {
  final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.hoa);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.playSeconds = level * 600.0;
  h.savedAt = savedAt;
  return h;
}

void main() {
  testWidgets('keeping the weaker copy asks twice; the stronger one wins', (tester) async {
    tester.view.physicalSize = const Size(1688, 780);
    tester.view.devicePixelRatio = 2;
    SharedPreferences.setMockInitialValues({});
    final save = SaveService.instance;
    final cloud = CloudSave.instance;
    // A stale level 27 copy on the device (restored by Android, newer stamp)
    // and the real level 50 one in the cloud.
    save.slots[0] = hero(27, 2000);
    cloud.cloudSlots[0] = SlotInfo.ofHero(hero(50, 1000));
    cloud.conflicts
      ..clear()
      ..add(0);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => resolveConflicts(context), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đang kém hơn bản trên mây'), findsOneWidget);
    expect(find.textContaining('tiến độ cao hơn'), findsOneWidget);

    await tester.tap(find.text('Giữ bản trong máy'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn bản kém hơn?'), findsOneWidget);
    await tester.tap(find.text('Chọn lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dùng bản trên mây'));
    await tester.pumpAndSettle();
    expect(save.slots[0]!.level, 50);
    expect(cloud.conflicts, isEmpty);
  });
}
