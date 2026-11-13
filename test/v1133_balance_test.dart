import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/tam_ma.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  test('one volley on one target: the first missile in full, the rest a share', () {
    expect(volleyShare(1), 1);
    expect(volleyShare(2), volleyExtraShare);
    expect(volleyShare(22), volleyExtraShare);
  });

  test('Tâm Ma board rows past 8x their lực chiến are not believed', () {
    // Real climbers: 2.79M on floor 52, about 4M on 59.
    expect(tamMaPlausible(52, 2790000), isTrue);
    expect(tamMaPlausible(59, 4000000), isTrue);
    // The 600k row on floor 104.
    expect(tamMaPlausible(104, 600000), isFalse);
    expect(tamMaPlausible(1, 0), isTrue);
    expect(tamMaPlausible(0, 0), isTrue);
  });
}
