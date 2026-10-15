import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/sync_plan.dart';

SlotInfo s(int at, String data) => SlotInfo(savedAt: at, data: data);

void main() {
  test('empty on both sides does nothing', () {
    expect(planSync([null], [null]), [SlotAction.none]);
  });

  test('device only uploads, cloud only restores (fresh reinstall)', () {
    expect(planSync([s(5, 'a'), null], [null, s(9, 'b')]),
        [SlotAction.upload, SlotAction.restore]);
  });

  test('identical copies are left alone whatever their stamps', () {
    expect(planSync([s(1, 'x')], [s(99, 'x')]), [SlotAction.none]);
  });

  test('newer device copy uploads, newer cloud copy asks', () {
    expect(planSync([s(10, 'new'), s(10, 'old')], [s(5, 'old'), s(20, 'other')]),
        [SlotAction.upload, SlotAction.ask]);
  });

  test('missing cloud entries count as empty', () {
    expect(planSync([s(1, 'a'), null, null], [s(1, 'a')]),
        [SlotAction.none, SlotAction.none, SlotAction.none]);
  });
}
