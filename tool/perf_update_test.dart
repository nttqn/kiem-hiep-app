// Times World.update by sect and land (CPU side of a frame).
// Run with: flutter test tool/perf_update_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/world.dart';

import '../test/v130_realm_test.dart' show geared;

void main() {
  test('update cost by sect and land', () {
    for (final id in ['bangnguyen', 'hoangsa', 'hoadiem']) {
      final row = <String>[];
      for (final hanh in Hanh.values) {
        final h = geared(42, hanh);
        final w = World.field(h, mapById[id]!, seed: 3)..auto = true;
        final sw = Stopwatch();
        var worst = 0;
        var zones = 0, mobsMax = 0, texts = 0;
        for (var i = 0; i < 30 * 120; i++) {
          final f = Stopwatch()..start();
          sw.start();
          w.update(1 / 30);
          sw.stop();
          f.stop();
          if (i > 300 && f.elapsedMicroseconds > worst) worst = f.elapsedMicroseconds;
          w.events.clear();
          zones = zones < w.zones.length ? w.zones.length : zones;
          mobsMax = mobsMax < w.mobs.length ? w.mobs.length : mobsMax;
          texts = texts < w.texts.length ? w.texts.length : texts;
        }
        row.add('${hanh.name} ${(sw.elapsedMicroseconds / 3600).toStringAsFixed(0)}us worst ${worst}us z$zones m$mobsMax t$texts');
      }
      // ignore: avoid_print
      print('$id: ${row.join(' | ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
