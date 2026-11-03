// Renders each sect's four regular active skills at a few moments to
// build/shots/skills.png (one row per skill, sects in order), or to
// build/shots/<name>.png with --dart-define=SHEET=<name>.
// Run with: flutter test tool/skill_sheet_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/render/art_fx.dart';

void main() {
  test('skill sheet', () async {
    const cell = 260.0, rowH = 200.0, label = 150.0;
    const moments = [0.08, 0.2, 0.35, 0.6, 0.9];
    final rows = <(SectDef, SkillDef)>[
      for (final s in sects)
        for (final k in s.skills)
          if (!k.isPassive && !k.ultimate) (s, k),
    ];
    final w = label + cell * moments.length, h = rowH * rows.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var r = 0; r < rows.length; r++) {
      final (sect, s) = rows[r];
      c.drawRect(Rect.fromLTWH(0, r * rowH, w, rowH), Paint()..color = Color(r.isEven ? 0xFF7E9A8C : 0xFF6E8A7C));
      final tp = TextPainter(
        text: TextSpan(text: '${sect.name}\n${s.name}\n${s.kind.name} · ${s.fx}', style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: label - 8);
      tp.paint(c, Offset(6, r * rowH + 10));
      for (var i = 0; i < moments.length; i++) {
        final t = moments[i];
        final x0 = label + cell * i, y = r * rowH + rowH * 0.62;
        final hx = x0 + 50;
        c.save();
        c.clipRect(Rect.fromLTWH(x0, r * rowH, cell, rowH));
        c.translate(hx, y);
        c.scale(0.55);
        c.translate(-hx, -y);
        // The hero's spot.
        c.drawCircle(Offset(hx, y), 14, Paint()..color = const Color(0x66000000));
        switch (s.kind) {
          case SkillKind.projectile || SkillKind.radial:
            final n = s.kind == SkillKind.radial ? s.count : s.count;
            for (var k = 0; k < n; k++) {
              final a = s.kind == SkillKind.radial
                  ? math.pi * 2 * k / n
                  : (n == 1 ? 0.0 : -s.spread / 2 + s.spread * k / (n - 1));
              final d = 600 * t;
              final pr = Proj(
                fromHero: true,
                x: hx + math.cos(a) * d,
                y: y + math.sin(a) * d,
                vx: math.cos(a) * 600,
                vy: math.sin(a) * 600,
                maxDist: s.range,
                radius: s.radius > 0 ? s.radius : 16,
                fx: s.fx,
                power: 1,
              );
              drawProj(c, pr, t);
            }
          case SkillKind.ground || SkillKind.line:
            final n = s.kind == SkillKind.line ? s.count : 1;
            for (var k = 0; k < n; k++) {
              final d = s.kind == SkillKind.line ? s.range * (k + 1) / n : s.range * 0.6;
              final z = Zone(
                fromHero: true,
                x: hx + d,
                y: y,
                r: s.radius,
                delay: s.kind == SkillKind.line ? 0.06 + k * 0.07 : s.delay,
                ticks: s.ticks,
                interval: s.ticks > 1 ? s.duration / s.ticks : 0,
                power: 1,
                fx: s.fx,
              )..t = t * (s.delay + 0.6) / 0.9;
              if (z.t <= z.life) drawZone(c, z, t);
            }
          case SkillKind.dash:
            final f = Fx(s.fx, hx, y, life: 0.45, angle: 0, radius: s.range, x2: hx + s.range, y2: y)..t = t * 0.45 / 0.9;
            drawFx(c, f, t);
          case SkillKind.arc:
            final f = Fx(s.fx, hx, y, life: 0.3, angle: 0, radius: s.range, spread: s.spread)..t = t * 0.3 / 0.9;
            drawFx(c, f, t);
          case SkillKind.nova:
            final f = Fx(s.fx, hx, y, life: 0.55, radius: s.radius)..t = t * 0.55 / 0.9;
            drawFx(c, f, t);
          case SkillKind.aura:
            drawFx(c, Fx(s.fx, hx, y, life: s.duration, radius: s.radius, onHero: true)..t = t * 2, t * 2);
          default:
            final life = s.kind == SkillKind.heal ? 1.0 : s.duration;
            drawFx(c, Fx(s.fx, hx, y, life: life, onHero: true)..t = t * math.min(life, 2) / 0.9, t);
        }
        c.restore();
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    const name = String.fromEnvironment('SHEET', defaultValue: 'skills');
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
