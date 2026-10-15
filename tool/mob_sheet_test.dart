// Renders every monster in the chibi style to build/shots/mobs.png, map by
// map in rows, boss last. Run with: flutter test tool/mob_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('monster sheet', () async {
    const cell = 230.0, rowH = 190.0;
    final w = cell * 4, h = rowH * maps.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var r = 0; r < maps.length; r++) {
      c.drawRect(Rect.fromLTWH(0, r * rowH, w, rowH),
          Paint()..color = Color(r.isEven ? 0xFF6E9B4A : 0xFF5E8A40));
      final ids = [...maps[r].mobs, maps[r].boss];
      for (var i = 0; i < ids.length; i++) {
        final d = mobById[ids[i]]!;
        final s = (d.boss ? 1.6 : 2.4) * (d.size > 1 ? 1 / d.size * 1.3 : 1);
        c.save();
        c.translate(cell * i + cell * 0.45, r * rowH + rowH - 22);
        drawShadow(c, 14 * s);
        c.scale(s * d.size);
        drawMob(c, d, t: 0.7 + i, attack: i == 1 ? 0.5 : 0);
        c.restore();
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/mobs.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
