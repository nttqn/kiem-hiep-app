// Kills on a field in 4 minutes by sect (several seeds), to weigh changes
// to poison and burn. Run with: flutter test tool/dot_probe_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';

import '../test/v130_realm_test.dart' show geared;
import '../test/v140_sea_test.dart' show farm;

void main() {
  test('kills by sect', () {
    for (final (lv, id) in [(50, 'hoadiem'), (90, 'hoason')]) {
      final row = <String>[];
      for (final hanh in Hanh.values) {
        var k = 0;
        for (final seed in [1, 2, 3]) {
          final (kills, _) = farm(geared(lv, hanh), mapById[id]!, seed: seed);
          k += kills;
        }
        row.add('${hanh.name} $k');
      }
      // ignore: avoid_print
      print('lv$lv $id: ${row.join(' | ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
