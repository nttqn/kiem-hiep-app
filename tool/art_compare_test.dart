// Renders old vs chibi figures side by side to build/shots/compare.png.
// Run with: flutter test tool/art_compare_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/render/art_chibi.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('compare sheet', () async {
    const w = 1600.0, h = 1000.0, sc = 3.2;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF6E9B4A));
    c.drawRect(const Rect.fromLTWH(0, 0, w, 330), Paint()..color = const Color(0xFF5E8A40));
    void at(double x, double y, void Function() draw, {double s = sc}) {
      c.save();
      c.translate(x, y);
      drawShadow(c, 16);
      c.scale(s);
      draw();
      c.restore();
    }

    final hoa = heroLook(Hanh.hoa);
    final wolf = mobById['wolf']!, boar = mobById['boar']!;
    // Row 1: current art.
    at(150, 290, () => drawHuman(c, hoa, t: 0.5));
    at(400, 290, () => drawHuman(c, hoa, attack: 0.5, t: 0.5));
    at(650, 290, () => drawHuman(c, heroLook(Hanh.thuy, female: true), t: 0.5));
    at(950, 290, () => drawMob(c, wolf, t: 0.5, chibi: false));
    at(1300, 290, () => drawMob(c, boar, t: 0.5, chibi: false));
    // Row 2: chibi.
    at(150, 620, () => drawChibi(c, hoa, t: 0.5));
    at(400, 620, () => drawChibi(c, hoa, attack: 0.5, t: 0.5));
    at(650, 620, () => drawChibi(c, heroLook(Hanh.thuy, female: true), t: 0.5));
    at(950, 620, () => drawQuadChibi(c, wolf, t: 0.5));
    at(1300, 620, () => drawQuadChibi(c, boar, t: 0.5, attack: 0.5));
    // Row 3: every sect, plus monsters, at a smaller scale.
    var x = 110.0;
    for (final hn in Hanh.values) {
      at(x, 940, () => drawChibi(c, heroLook(hn, female: hn == Hanh.moc), t: 1.3, moving: true, walk: 0.6), s: 2.4);
      x += 160;
    }
    at(x + 20, 940, () => drawChibi(c, const HumanLook(skin: 0xFFC8946A, robe: 0xFF7A3B2A, trim: 0xFF3B2A20,
        pants: 0xFF2A2018, band: 0xFF3A2A1A, weapon: Weapon.saber, blade: 0xFFB0B0B0, longRobe: false), t: 1), s: 2.4);
    at(x + 200, 940, () => drawQuadChibi(c, mobById['fireWolf']!, t: 1), s: 2.2);
    at(x + 420, 940, () => drawQuadChibi(c, mobById['kylin']!, t: 1), s: 1.5);

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/compare.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
