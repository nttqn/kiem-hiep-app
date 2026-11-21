import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/world.dart';
import '../test/v130_realm_test.dart' show geared;

/// Kỳ ngộ per hour of autopilot on a field (cap lifted to see the raw rate).
void main() {
  test('rate', () {
    for (final (lv, id) in [(25, 'truclam'), (60, 'magiao')]) {
      final h = geared(lv, Hanh.moc);
      final w = World.field(h, mapById[id] ?? fieldMaps[3], seed: 7)..auto = true;
      final k0 = h.kills;
      var meets = 0;
      for (var t = 0; t < 20 * 60 * 30; t++) {
        h.kyToday = 0;
        final before = h.kyTotal;
        w.update(1 / 30);
        meets += h.kyTotal - before;
        for (final e in w.events) {
          if (e.kind == EvKind.heroDied) w.reviveHere();
        }
        w.events.clear();
      }
      // ignore: avoid_print
      print('lv$lv $id: ${(h.kills - k0) * 3} kills/h, ${meets * 3} kỳ ngộ/h');
    }
  });
}
