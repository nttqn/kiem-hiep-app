// Gold an hour from field farming at a few stages (autopilot, 4 minutes,
// scaled). Run with: flutter test tool/gold_probe_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';

import '../test/v130_realm_test.dart' show geared;
import '../test/v140_sea_test.dart' show farm;

void main() {
  test('gold an hour', () {
    for (final (lv, cs, map) in [(30, 0, 'hoangsa'), (60, 0, 'magiao'), (90, 0, 'hoason'), (99, 2, 'hoason'), (99, 5, 'cuuu')]) {
      final h = geared(lv, Hanh.hoa)..rebirths = cs;
      h.recompute();
      final g0 = h.gold;
      final (kills, deaths) = farm(h, mapById[map]!, minutes: 4);
      // ignore: avoid_print
      print('lv$lv cs$cs $map: ${((h.gold - g0) * 15).round()} lượng/h, $kills kills/4min, $deaths deaths');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
