import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/weather.dart';
import 'quality.dart';

/// Weather drawn over the screen (not the world): rain streaks, snow,
/// drifting fog, blowing sand, falling ash or petals. Particles are placed
/// from their index and the clock, so nothing is stored between frames.

double _h(double v) {
  final s = math.sin(v * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

void drawWeather(Canvas c, Size size, Weather w, double t) {
  if (w == Weather.clear) return;
  final wd = size.width, ht = size.height;
  final many = !liteGraphics;
  switch (w) {
    case Weather.rain:
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x1A1A2A40));
      final p = Paint()
        ..color = const Color(0x88B8D0EC)
        ..strokeWidth = 1.3;
      for (var i = 0; i < (many ? 90 : 40); i++) {
        final sp = 700 + _h(i + 0.3) * 400;
        final y = (_h(i + 0.1) * (ht + 60) + t * sp) % (ht + 60) - 30;
        final x = (_h(i + 0.7) * (wd + 100) - y * 0.22) % (wd + 100) - 50;
        c.drawLine(Offset(x, y), Offset(x + 4, y + 16), p);
      }
    case Weather.snow:
      final p = Paint()..color = const Color(0xDDFFFFFF);
      for (var i = 0; i < (many ? 80 : 35); i++) {
        final sp = 40 + _h(i + 0.2) * 70;
        final y = (_h(i + 0.5) * (ht + 20) + t * sp) % (ht + 20) - 10;
        final x = (_h(i + 0.9) * wd + math.sin(t * 1.3 + i) * 18) % wd;
        c.drawCircle(Offset(x, y), 1.4 + _h(i + 0.4) * 2, p);
      }
    case Weather.fog:
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x24E8ECF0));
      if (many) {
        for (var i = 0; i < 5; i++) {
          final x = (_h(i + 0.3) * wd * 1.6 + t * (12 + i * 5)) % (wd * 1.6) - wd * 0.3;
          final y = ht * (0.15 + _h(i + 0.8) * 0.8);
          c.drawOval(
              Rect.fromCenter(center: Offset(x, y), width: wd * 0.7, height: ht * 0.3),
              Paint()
                ..color = const Color(0x2EF2F4F6)
                ..maskFilter = softBlur(40));
        }
      }
    case Weather.sand:
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x26C8A060));
      final p = Paint()
        ..color = const Color(0x77E0C080)
        ..strokeWidth = 1.2;
      for (var i = 0; i < (many ? 70 : 30); i++) {
        final sp = 380 + _h(i + 0.6) * 300;
        final x = (_h(i + 0.2) * (wd + 80) + t * sp) % (wd + 80) - 40;
        final y = (_h(i + 0.9) * ht + math.sin(t * 2 + i) * 6) % ht;
        c.drawLine(Offset(x, y), Offset(x - 18, y + 2), p);
      }
    case Weather.ash:
      for (var i = 0; i < (many ? 60 : 25); i++) {
        final sp = 25 + _h(i + 0.1) * 40;
        final y = (_h(i + 0.3) * (ht + 20) + t * sp) % (ht + 20) - 10;
        final x = (_h(i + 0.8) * wd + t * 15 + math.sin(t + i) * 10) % wd;
        final ember = i % 6 == 0;
        c.drawCircle(Offset(x, y), ember ? 1.8 : 1.4,
            Paint()..color = ember ? const Color(0xCCFF8A3A) : const Color(0x998A8480));
      }
    case Weather.petals:
      final p = Paint()..color = const Color(0xCCF6B8CC);
      for (var i = 0; i < (many ? 40 : 18); i++) {
        final sp = 35 + _h(i + 0.4) * 40;
        final y = (_h(i + 0.6) * (ht + 20) + t * sp) % (ht + 20) - 10;
        final x = (_h(i + 0.2) * wd + t * 30 + math.sin(t * 1.5 + i) * 20) % wd;
        c.save();
        c.translate(x, y);
        c.rotate(t * 2 + i);
        c.drawOval(const Rect.fromLTWH(-3.5, -2, 7, 4), p);
        c.restore();
      }
    case Weather.clear:
      break;
  }
}
