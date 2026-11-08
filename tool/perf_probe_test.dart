// Times WorldRenderer.render plus rasterising at a phone's real pixels
// (Redmi Note 12 landscape ~ 760x344 points at 2x), by sect, land, weather
// and night, lite graphics on. Run with: flutter test tool/perf_probe_test.dart
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/weather.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/render/quality.dart';
import 'package:kiem_hiep/render/world_renderer.dart';

import '../test/v130_realm_test.dart' show geared;

Future<double> _probe(Hanh hanh, MapDef map, {Weather weather = Weather.clear, bool night = false, int frames = 90}) async {
  liteGraphics = true;
  World.debugWeather = weather;
  World.debugNight = night;
  final h = geared(42, hanh);
  final w = World.field(h, map, seed: 3)..auto = true;
  final r = WorldRenderer();
  const size = Size(760, 344);
  for (var i = 0; i < 300; i++) {
    w.update(1 / 30);
    w.events.clear();
  }
  final sw = Stopwatch();
  var t = 10.0;
  for (var i = 0; i < frames; i++) {
    w.update(1 / 30);
    w.events.clear();
    t += 1 / 30;
    sw.start();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(2);
    r.render(c, size, w, t, 1 / 30);
    final pic = rec.endRecording();
    final img = await pic.toImage(1520, 688);
    sw.stop();
    img.dispose();
    pic.dispose();
  }
  return sw.elapsedMicroseconds / frames / 1000;
}

void main() {
  test('frame cost', () async {
    final snow = mapById['bangnguyen']!, sand = mapById['hoangsa']!;
    Future<void> line(String label, Future<double> Function(Hanh) f) async {
      final row = [for (final hanh in Hanh.values) '${hanh.name} ${(await f(hanh)).toStringAsFixed(1)}'];
      // ignore: avoid_print
      print('$label: ${row.join(' | ')}');
    }

    await line('snow clear', (x) => _probe(x, snow));
    await line('sand clear', (x) => _probe(x, sand));
    await line('snow+snowfall', (x) => _probe(x, snow, weather: Weather.snow));
    await line('snow+fog', (x) => _probe(x, snow, weather: Weather.fog));
    await line('snow night', (x) => _probe(x, snow, night: true));
    await line('sand night', (x) => _probe(x, sand, night: true));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
