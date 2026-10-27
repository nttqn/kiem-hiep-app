// Renders every mount alone, galloping, and with a rider to
// build/shots/mounts.png, plus a row of Lôi đài challengers.
// Run with: flutter test tool/mount_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/render/art_chibi.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('mount sheet', () async {
    const cell = 220.0, rowH = 200.0;
    final w = cell * 4, h = rowH * (mounts.length + 1);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var r = 0; r < mounts.length; r++) {
      final m = mounts[r];
      c.drawRect(Rect.fromLTWH(0, r * rowH, w, rowH), Paint()..color = Color(r.isEven ? 0xFF7E9A8C : 0xFF6E8A7C));
      for (var i = 0; i < 4; i++) {
        c.save();
        c.translate(cell * i + cell / 2, r * rowH + rowH * 0.85);
        c.scale(2);
        drawShadow(c, 22);
        final moving = i == 1 || i == 3;
        drawMount(c, m, walk: i * 0.7, moving: moving, t: i * 0.4);
        if (i >= 2) {
          c.translate(0, -mountSeatOf(m));
          drawChibi(c, heroLook(Hanh.values[r % 5], female: r.isOdd), t: 0.3);
        }
        c.restore();
      }
    }
    final y0 = mounts.length * rowH;
    c.drawRect(Rect.fromLTWH(0, y0, w, rowH), Paint()..color = const Color(0xFF8A7A6A));
    for (var i = 0; i < 4; i++) {
      final r = ArenaRival(name: 'x', hanh: Hanh.values[i], level: 25 + i * 25, rebirths: i, power: 1, female: i.isOdd);
      c.save();
      c.translate(cell * i + cell / 2, y0 + rowH * 0.85);
      c.scale(2);
      drawShadow(c, 16);
      drawChibi(c, rivalLook(r), t: 0.3);
      c.restore();
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/mounts.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
