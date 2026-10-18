// Renders each sect's tuyệt kỹ effect at a few moments to
// build/shots/ultimates.png, one row per sect.
// Run with: flutter test tool/ultimate_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/render/art_fx.dart';

void main() {
  test('ultimate sheet', () async {
    const cell = 300.0, rowH = 260.0;
    const moments = [0.2, 0.55, 0.85, 1.3];
    final w = cell * moments.length, h = rowH * sects.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var r = 0; r < sects.length; r++) {
      final s = sects[r].skills.last;
      c.drawRect(Rect.fromLTWH(0, r * rowH, w, rowH),
          Paint()..color = Color(r.isEven ? 0xFF7E9A8C : 0xFF6E8A7C));
      for (var i = 0; i < moments.length; i++) {
        final t = moments[i];
        final x = cell * i + cell / 2, y = r * rowH + rowH * 0.72;
        c.save();
        c.clipRect(Rect.fromLTWH(cell * i, r * rowH, cell, rowH));
        // Scale the effect down so a whole circle fits in the cell.
        c.translate(x, y);
        c.scale(0.5);
        c.translate(-x, -y);
        switch (s.kind) {
          case SkillKind.ground || SkillKind.line:
            final n = s.kind == SkillKind.line ? s.count : 1;
            for (var k = 0; k < n; k++) {
              final z = Zone(
                fromHero: true,
                x: s.kind == SkillKind.line ? x - 260 + k * 75 : x,
                y: y,
                r: s.radius,
                delay: s.kind == SkillKind.line ? 0.06 + k * 0.07 : s.delay,
                ticks: s.ticks,
                interval: s.ticks > 1 ? s.duration / s.ticks : 0,
                power: 1,
                fx: s.fx,
              )..t = t;
              if (z.t <= z.life) drawZone(c, z, t);
            }
          default:
            final life = s.kind == SkillKind.aura ? s.duration : 1.0;
            drawFx(c, Fx(s.fx, x, y, life: life, radius: s.radius)..t = t, t);
        }
        c.restore();
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/ultimates.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
