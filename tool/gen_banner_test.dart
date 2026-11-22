// Renders the 劍俠五行 YouTube channel banner (2560 x 1440) to
// store/youtube/zh-channel-banner.png. Title and the two front heroes sit in
// the 1546 x 423 centre that every device shows; the rest of the line-up and
// the sky fill the wider desktop and TV crops.
//
// Run with: flutter test tool/gen_banner_test.dart
// Needs Windows' Microsoft JhengHei Bold (C:/Windows/Fonts/msjhbd.ttc).
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

void _text(Canvas c, String s, Offset centre, double size, Color color, {double outline = 0, double spacing = 0}) {
  TextPainter make(Paint? fg, Color? fill) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'JhengHei',
            fontSize: size,
            height: 1,
            letterSpacing: spacing,
            fontWeight: FontWeight.w700,
            color: fill,
            foreground: fg,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
  final shadow = make(null, const Color(0xAA000000));
  final at = centre - Offset(shadow.width / 2, shadow.height / 2);
  shadow.paint(c, at + Offset(size * 0.05, size * 0.06));
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
  test('channel banner', () async {
    await _font('JhengHei', 'C:/Windows/Fonts/msjhbd.ttc');
    const w = 2560.0, h = 1440.0, cx = w / 2;
    // The always-visible band: y 508..931.
    const base = 920.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const box = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
        box,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1426), Color(0xFF2A1A2E), Color(0xFF8A2E22), Color(0xFFE08A3A), Color(0xFF2A1420)],
            stops: [0, 0.3, 0.5, 0.62, 0.66],
          ).createShader(box));
    // A few stars in the high sky (TV crop only).
    final rng = math.Random(7);
    for (var i = 0; i < 90; i++) {
      c.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * 480), 1 + rng.nextDouble() * 2.2,
          Paint()..color = Color.fromARGB(80 + rng.nextInt(120), 255, 240, 210));
    }
    c.drawCircle(const Offset(cx, 640), 330,
        Paint()
          ..color = const Color(0x44F8DCA0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60));
    c.drawCircle(const Offset(cx, 640), 250, Paint()..color = const Color(0xFFF8DCA0));
    // Far mountains, then the near ridge the heroes stand on.
    void ridge(double y, double amp, double f, Color col, double phase) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 16) {
        p.lineTo(x, y - amp * (math.sin(x / w * f + phase) + 0.5 * math.sin(x / w * f * 2.3 + phase * 2)));
      }
      p
        ..lineTo(w, h)
        ..close();
      c.drawPath(p, Paint()..color = col);
    }

    ridge(800, 70, 7, const Color(0xFF5A2224), 0.4);
    ridge(base - 10, 22, 11, const Color(0xFF2A1420), 1);

    void fig(double x, double scale, void Function() draw) {
      c.save();
      c.translate(x, base);
      drawShadow(c, 14 * scale / 3);
      c.scale(scale);
      draw();
      c.restore();
    }

    // A wolf at the far left; heroes face the title from both sides.
    fig(cx - 1130, 4.0, () => drawMob(c, mobById['wolf']!, t: 1));
    final heroes = <(double, Hanh, bool, double, double)>[
      // x offset, sect, female, scale, attack
      (-880, Hanh.moc, false, 4.4, 0),
      (-680, Hanh.hoa, false, 5.2, 0),
      (640, Hanh.thuy, true, 5.0, 0),
      (880, Hanh.kim, false, 4.4, 0),
      (1110, Hanh.tho, false, 4.0, 0),
    ];
    for (final (dx, hanh, female, scale, attack) in heroes) {
      fig(cx + dx, scale, () {
        c.scale(dx < 0 ? 1 : -1, 1);
        drawChibi(c, heroLook(hanh, female: female), attack: attack, t: dx.abs() / 300);
      });
    }

    _text(c, '劍 俠 五 行', const Offset(cx, 640), 190, const Color(0xFFF3D27A), outline: 16);
    _text(c, '五大門派 · 五行相剋 · 武俠動作 RPG', const Offset(cx, 790), 58, const Color(0xFFFFF3C4), outline: 9);
    _text(c, 'Google Play 免費下載', const Offset(cx, 870), 40, const Color(0xFFFFE08A), outline: 7);

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('store/youtube').createSync(recursive: true);
    File('store/youtube/zh-channel-banner.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
