// Renders the three store product icons (512x512, no text) to
// build/shots/iap_<sku>.png for Play Console / App Store Connect.
// Run with: flutter test tool/iap_icons_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/render/art_chibi.dart';

const _s = 512.0;
const _gold = Color(0xFFF3D27A);
const _goldDeep = Color(0xFFB8862A);

void _frame(Canvas c, Color inner, Color outer) {
  const r = Rect.fromLTWH(0, 0, _s, _s);
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(_s / 2, _s * 0.42), _s * 0.72, [inner, outer]),
  );
  // Gold rim.
  c.drawRect(
    r.deflate(14),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = _gold,
  );
  c.drawRect(
    r.deflate(26),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _goldDeep,
  );
}

void _sparkle(Canvas c, Offset p, double r, Color col) {
  final path = Path()
    ..moveTo(p.dx, p.dy - r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
    ..close();
  c.drawPath(path, Paint()..color = col);
}

void _glow(Canvas c, Offset p, double r, Color col) {
  c.drawCircle(
    p,
    r,
    Paint()..shader = ui.Gradient.radial(p, r, [col, col.withValues(alpha: 0)]),
  );
}

/// Nguyệt thẻ: a gold crescent over the night sky with stars.
void _monthCard(Canvas c) {
  _frame(c, const Color(0xFF2E3F78), const Color(0xFF0E1430));
  const m = Offset(_s / 2, _s / 2);
  _glow(c, m, 230, const Color(0x88F3D27A));
  final moon = Path()
    ..addOval(Rect.fromCircle(center: m, radius: 150));
  final bite = Path()..addOval(Rect.fromCircle(center: m + const Offset(70, -50), radius: 128));
  final crescent = Path.combine(PathOperation.difference, moon, bite);
  c.drawPath(
    crescent,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(120, 120), const Offset(380, 420), [const Color(0xFFFFF4C8), _gold, _goldDeep], [0, 0.5, 1]),
  );
  c.drawPath(
    crescent,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF8A5A10),
  );
  for (final (p, r) in [
    (const Offset(350, 150), 26.0),
    (const Offset(400, 250), 16.0),
    (const Offset(330, 330), 20.0),
    (const Offset(120, 110), 12.0),
    (const Offset(410, 390), 12.0),
  ]) {
    _sparkle(c, p, r, const Color(0xFFFFF4C8));
  }
}

/// Gói tân thủ: Bạch Mã on a jade field with a gift glow.
void _starter(Canvas c) {
  _frame(c, const Color(0xFF4FA878), const Color(0xFF123A28));
  _glow(c, const Offset(_s / 2, _s * 0.55), 220, const Color(0x99FFF4C8));
  c.drawOval(
    Rect.fromCenter(center: const Offset(_s / 2, _s * 0.8), width: 300, height: 46),
    Paint()..color = const Color(0x55000000),
  );
  c.save();
  c.translate(_s / 2 - 30, _s * 0.78);
  c.scale(3.9);
  drawMount(c, mountById['bachma']!);
  c.restore();
  for (final (p, r) in [
    (const Offset(110, 120), 22.0),
    (const Offset(400, 110), 28.0),
    (const Offset(420, 300), 16.0),
    (const Offset(90, 290), 14.0),
  ]) {
    _sparkle(c, p, r, const Color(0xFFFFF4C8));
  }
}

/// Bỏ quảng cáo: a screen with a play mark, struck through.
void _noAds(Canvas c) {
  _frame(c, const Color(0xFFB8402A), const Color(0xFF3A0E0A));
  const m = Offset(_s / 2, _s / 2);
  _glow(c, m, 220, const Color(0x66FFC34A));
  final screen = RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 250, height: 180), const Radius.circular(22));
  c.drawRRect(screen, Paint()..color = const Color(0xFFFFF4E0));
  c.drawRRect(
    screen,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0xFF5A1A10),
  );
  final play = Path()
    ..moveTo(m.dx - 32, m.dy - 44)
    ..lineTo(m.dx + 48, m.dy)
    ..lineTo(m.dx - 32, m.dy + 44)
    ..close();
  c.drawPath(play, Paint()..color = const Color(0xFFB8402A));
  // Prohibition ring and slash.
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 30
    ..strokeCap = StrokeCap.round;
  const rr = 178.0;
  final d = rr * math.cos(math.pi / 4);
  for (final (col, w) in [(const Color(0xFF5A1A10), 42.0), (_gold, 28.0)]) {
    ring
      ..color = col
      ..strokeWidth = w;
    c.drawCircle(m, rr, ring);
    c.drawLine(m + Offset(-d, -d), m + Offset(d, d), ring);
  }
}

Future<void> _write(String name, void Function(Canvas) paint) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, _s, _s));
  paint(c);
  final img = await rec.endRecording().toImage(_s.toInt(), _s.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/shots/iap_$name.png');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// One faceted crystal standing at [base], [h] tall and [w] wide.
void _crystal(Canvas c, Offset base, double w, double h, Color light, Color dark) {
  final top = base + Offset(0, -h);
  final l = base + Offset(-w / 2, -h * 0.28);
  final r = base + Offset(w / 2, -h * 0.28);
  final left = Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(l.dx, l.dy)
    ..lineTo(base.dx, base.dy)
    ..close();
  final right = Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(r.dx, r.dy)
    ..lineTo(base.dx, base.dy)
    ..close();
  c.drawPath(left, Paint()..shader = ui.Gradient.linear(top, l, [const Color(0xFFF2F8FF), light]));
  c.drawPath(right, Paint()..shader = ui.Gradient.linear(top, r, [light, dark]));
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF1A1450);
  c.drawPath(left, edge);
  c.drawPath(right, edge);
}

/// Gói Thăng Tinh: a cluster of Tinh Thạch under a rising gold star, with
/// the blue flame of a Tinh Phách.
void _starPack(Canvas c) {
  _frame(c, const Color(0xFF5B3FA8), const Color(0xFF140C38));
  _glow(c, const Offset(_s / 2, _s * 0.5), 240, const Color(0x8890B8FF));
  const star = Offset(_s / 2, 150);
  _glow(c, star, 120, const Color(0xCCFFF4C8));
  final pts = <Offset>[
    for (var i = 0; i < 10; i++) star + Offset.fromDirection(-math.pi / 2 + i * math.pi / 5, i.isEven ? 78 : 32),
  ];
  final starPath = Path()..addPolygon(pts, true);
  c.drawPath(
    starPath,
    Paint()
      ..shader = ui.Gradient.linear(star + const Offset(0, -78), star + const Offset(0, 60),
          [const Color(0xFFFFF8D8), _gold, _goldDeep], [0, 0.5, 1]),
  );
  c.drawPath(
    starPath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF7A4A08),
  );
  c.drawOval(Rect.fromCenter(center: const Offset(_s / 2, 432), width: 330, height: 44),
      Paint()..color = const Color(0x66000000));
  _crystal(c, const Offset(170, 425), 90, 170, const Color(0xFF7FA8FF), const Color(0xFF3A3AA8));
  _crystal(c, const Offset(345, 425), 90, 180, const Color(0xFFB08CFF), const Color(0xFF4A2A98));
  _crystal(c, const Offset(_s / 2, 440), 120, 230, const Color(0xFF8FD8FF), const Color(0xFF2A5AB8));
  const soul = Offset(105, 300);
  _glow(c, soul, 70, const Color(0xAA60F0FF));
  final flame = Path()
    ..moveTo(soul.dx, soul.dy - 52)
    ..quadraticBezierTo(soul.dx + 40, soul.dy - 4, soul.dx + 22, soul.dy + 26)
    ..quadraticBezierTo(soul.dx, soul.dy + 40, soul.dx - 22, soul.dy + 26)
    ..quadraticBezierTo(soul.dx - 40, soul.dy - 4, soul.dx, soul.dy - 52)
    ..close();
  c.drawPath(
      flame,
      Paint()
        ..shader = ui.Gradient.linear(soul + const Offset(0, -52), soul + const Offset(0, 40),
            [const Color(0xFFE8FFFF), const Color(0xFF40C8F0)]));
  for (final (p, r) in [
    (const Offset(400, 110), 24.0),
    (const Offset(110, 120), 18.0),
    (const Offset(420, 300), 16.0),
    (const Offset(335, 225), 12.0),
  ]) {
    _sparkle(c, p, r, const Color(0xFFFFF4C8));
  }
}

void main() {
  test('iap icons', () async {
    await _write('kh_nguyet_the', _monthCard);
    await _write('kh_goi_tan_thu', _starter);
    await _write('kh_bo_quang_cao', _noAds);
    await _write('kh_goi_thang_tinh', _starPack);
  });
}
