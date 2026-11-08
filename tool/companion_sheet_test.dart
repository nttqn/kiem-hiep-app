// The five hiệp khách as they fight (chibi) at hảo cảm 1 (top) and 10
// (bottom), to set beside their painted portraits.
// Run with: flutter test tool/companion_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/companions.dart';
import 'package:kiem_hiep/render/art_chibi.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('companion sheet', () async {
    const cell = 220.0, h = 250.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, cell * 5, h * 2), Paint()..color = const Color(0xFF2A1A14));
    for (final (row, bond) in [(0, 1), (1, 10)]) {
      for (var i = 0; i < companions.length; i++) {
        c.save();
        c.translate(cell * i + cell / 2, h * (row + 1) - 18);
        c.scale(2.5);
        drawShadow(c, 16);
        drawChibi(c, companionLook(companions[i], bond), t: 0.4);
        c.restore();
      }
    }
    final img = await rec.endRecording().toImage((cell * 5).toInt(), (h * 2).toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/companions.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
