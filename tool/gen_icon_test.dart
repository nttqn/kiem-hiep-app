// Renders the launcher icon to assets/icon/icon.png.
//
// Run with: flutter test tool/gen_icon_test.dart
// then:     dart run flutter_launcher_icons
//
// It lives in a test because the Flutter test harness can rasterise
// without a device, and this machine has no image tooling.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/render/art_chibi.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('launcher icon', () async {
    const s = 1024.0;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const box = Rect.fromLTWH(0, 0, s, s);

    // Dusk sky, full bleed.
    c.drawRect(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A2E), Color(0xFF8A2E22), Color(0xFFE08A3A)],
        ).createShader(box),
    );
    // Moon.
    c.drawCircle(const Offset(s * 0.5, s * 0.42), 300,
        Paint()..color = const Color(0xFFF8DCA0));
    c.drawCircle(
        const Offset(s * 0.5, s * 0.42),
        360,
        Paint()
          ..color = const Color(0x44F8DCA0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    // Mountain silhouettes.
    final hills = Path()..moveTo(0, s);
    for (var x = 0.0; x <= s; x += 16) {
      final n = math.sin(x / s * 7 + 1) * 0.5 + math.sin(x / s * 15) * 0.25;
      hills.lineTo(x, s * (0.78 - 0.06 * n));
    }
    hills
      ..lineTo(s, s)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF2A1420));

    // The five phases along the bottom.
    for (var i = 0; i < 5; i++) {
      final x = s * (0.18 + i * 0.16);
      final colr = Color(Hanh.values[i].color);
      c.drawCircle(Offset(x, s * 0.9), 52,
          Paint()
            ..color = colr.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
      c.drawCircle(Offset(x, s * 0.9), 40, Paint()..color = colr);
      c.drawCircle(Offset(x, s * 0.9), 40, Paint()
        ..color = const Color(0xFFF3D27A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6);
    }

    // A fiery slash arc behind the blade.
    final slash = Path()
      ..addArc(Rect.fromCircle(center: const Offset(s * 0.5, s * 0.5), radius: 330), -1.9, 2.3)
      ..arcTo(Rect.fromCircle(center: const Offset(s * 0.52, s * 0.52), radius: 250), 0.4, -2.3, false)
      ..close();
    c.drawPath(
        slash,
        Paint()
          ..color = const Color(0xCCFF5A1A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    c.drawPath(slash, Paint()..color = const Color(0xEEFF7A2A));
    c.drawArc(Rect.fromCircle(center: const Offset(s * 0.5, s * 0.5), radius: 330), -1.9, 2.3,
        false,
        Paint()
          ..color = const Color(0xFFFFF0C0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);

    // The chibi swordsman mid-strike in front of the moon.
    c.save();
    c.translate(s * 0.44, s * 0.8);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 300, height: 60),
        Paint()..color = const Color(0x66000000));
    c.scale(10.5);
    drawChibi(c, heroLook(Hanh.hoa, glow: 0xFFFFB03A), attack: 0.4, t: 0.6);
    c.restore();

    final img = await recorder.endRecording().toImage(s.toInt(), s.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icon/icon.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
