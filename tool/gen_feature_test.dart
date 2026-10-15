// Renders Google Play's 1024 x 500 feature graphic to
// store/feature-graphic.png.
//
// Run with: flutter test tool/gen_feature_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/render/art_chibi.dart';
import 'package:kiem_hiep/render/art_figures.dart';

Future<void> _font(String family, String file) async {
  final bytes = File(file).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void _text(Canvas c, String s, Offset centre, double size, Color color,
    {String family = 'Playfair', double outline = 0, FontWeight weight = FontWeight.w800}) {
  TextPainter make(Paint? fg, Color? fill) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            height: 1,
            fontWeight: weight,
            fontVariations: [FontVariation('wght', weight == FontWeight.w800 ? 850 : 500)],
            color: fill,
            foreground: fg,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
  final shadow = make(null, const Color(0xAA000000));
  final at = centre - Offset(shadow.width / 2, shadow.height / 2);
  shadow.paint(c, at + const Offset(4, 5));
  if (outline > 0) {
    make(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outline
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2A1810),
            null)
        .paint(c, at);
  }
  make(null, color).paint(c, at);
}

void main() {
  test('feature graphic', () async {
    await _font('Playfair', 'assets/fonts/PlayfairDisplay.ttf');
    await _font('BeVietnam', 'assets/fonts/BeVietnamPro-Bold.ttf');
    const w = 1024.0, h = 500.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const box = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        box,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1A2E), Color(0xFF8A2E22), Color(0xFFE08A3A)],
          ).createShader(box));
    c.drawCircle(const Offset(w * 0.5, h * 0.42), 150, Paint()..color = const Color(0xFFF8DCA0));
    c.drawCircle(
        const Offset(w * 0.5, h * 0.42),
        200,
        Paint()
          ..color = const Color(0x44F8DCA0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    final hills = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 12) {
      hills.lineTo(x, h * (0.8 - 0.05 * (math.sin(x / w * 9 + 1) + 0.5 * math.sin(x / w * 21))));
    }
    hills
      ..lineTo(w, h)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF2A1420));

    // The five sects lined up, monsters squaring off at the edges.
    void fig(double x, double scale, void Function() draw) {
      c.save();
      c.translate(x, h * 0.93);
      drawShadow(c, 14 * scale / 3);
      c.scale(scale);
      draw();
      c.restore();
    }

    fig(70, 2.4, () => drawMob(c, mobById['wolf']!, t: 1));
    fig(965, 1.9, () {
      c.scale(-1, 1);
      drawMob(c, mobById['yeti']!, t: 1, attack: 0.5);
    });
    const order = [Hanh.moc, Hanh.thuy, Hanh.hoa, Hanh.tho, Hanh.kim];
    for (var i = 0; i < order.length; i++) {
      final x = 230 + i * 140.0;
      final face = i < 2 ? -1.0 : 1.0;
      fig(x, i == 2 ? 3.4 : 2.8, () {
        c.scale(face, 1);
        drawChibi(c, heroLook(order[i], female: i == 1), attack: i == 2 ? 0.4 : 0, t: i * 0.7);
      });
    }

    _text(c, 'KIẾM HIỆP NGŨ HÀNH', const Offset(w / 2, 70), 64, const Color(0xFFF3D27A), outline: 8);
    _text(c, 'Ngũ phái · Ngũ hành tương khắc · Chơi offline', const Offset(w / 2, 128), 24,
        const Color(0xFFFFF3C4), family: 'BeVietnam', outline: 5, weight: FontWeight.w700);

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('store').createSync(recursive: true);
    File('store/feature-graphic.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
