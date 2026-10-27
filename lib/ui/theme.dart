import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/items.dart';
import '../core/sects.dart';
import '../services/sound.dart';

/// Lacquered wood and gold leaf.
const lacquer = Color(0xFF2A1C17);
const lacquerLight = Color(0xFF3D2A22);
const lacquerDeep = Color(0xFF170F0C);
const gold = Color(0xFFD9A93B);
const goldLight = Color(0xFFF3D27A);
const cream = Color(0xFFF3E6C8);
const creamDim = Color(0xFFB8A888);
const seal = Color(0xFFA3271F);
const jade = Color(0xFF3E8D62);
const hpRed = Color(0xFFD8403A);
const mpBlue = Color(0xFF3A7AD8);
const expGold = Color(0xFFE8C547);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnam',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seal,
      brightness: Brightness.dark,
      surface: lacquer,
    ),
    scaffoldBackgroundColor: lacquerDeep,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: cream, displayColor: cream),
    dialogTheme: const DialogThemeData(backgroundColor: lacquer),
  );
}

TextStyle titleStyle(double size, {Color color = goldLight}) => TextStyle(
      fontFamily: 'Playfair',
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation('wght', 800)],
      color: color,
      height: 1.1,
      shadows: const [Shadow(color: Colors.black87, offset: Offset(1.5, 1.5), blurRadius: 2)],
    );

const TextStyle small = TextStyle(fontSize: 12, color: creamDim);
const TextStyle body = TextStyle(fontSize: 14, color: cream);
const TextStyle bold = TextStyle(fontSize: 14, color: cream, fontWeight: FontWeight.w800);

Color hanhColor(Hanh h) => Color(h.color);
Color rarityColor(Rarity r) => Color(r.color);

String fmt(num n) {
  final s = n.round().abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

/// A dark lacquer panel with a gold rim.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.border = gold,
    this.radius = 10,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: color != null
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lacquerLight, lacquer],
              ),
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border.withValues(alpha: 0.8), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// A raised lacquer button that sinks when pressed.
class LButton extends StatefulWidget {
  const LButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = seal,
    this.icon,
    this.small = false,
    this.width,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool small;
  final double? width;
  final bool enabled;

  @override
  State<LButton> createState() => _LButtonState();
}

class _LButtonState extends State<LButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    final c = on ? widget.color : const Color(0xFF4A4038);
    final h = widget.small ? 34.0 : 44.0;
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: on
          ? (_) {
              setState(() => _down = false);
              SoundService.instance.cue('click', volume: 0.6);
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: widget.width,
        height: h,
        margin: EdgeInsets.only(top: _down ? 3 : 0, bottom: _down ? 0 : 3),
        padding: EdgeInsets.symmetric(horizontal: widget.small ? 12 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(c, Colors.white, 0.18)!, c],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? goldLight.withValues(alpha: 0.85) : Colors.white24, width: 1.4),
          boxShadow: _down
              ? null
              : [BoxShadow(color: Color.lerp(c, Colors.black, 0.6)!, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.small ? 16 : 20, color: on ? cream : Colors.white38),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.small ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: on ? cream : Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Bar extends StatelessWidget {
  const Bar({
    super.key,
    required this.value,
    required this.color,
    this.height = 12,
    this.label,
    this.width,
  });

  final double value;
  final Color color;
  final double height;
  final String? label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xCC120A08),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                ),
              ),
            ),
          ),
          if (label != null)
            Center(
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: height * 0.72,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Square item tile: slot glyph on a rarity-coloured ground.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, this.item, this.slot, this.size = 52, this.onTap, this.selected = false});

  final Item? item;
  final Slot? slot;
  final double size;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final c = it == null ? const Color(0xFF5A4A40) : Color(it.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [
            Color.lerp(lacquerLight, c, it == null ? 0 : 0.35)!,
            lacquerDeep,
          ]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.white : c, width: selected ? 2.4 : 1.6),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SlotGlyph(it?.slot ?? slot ?? Slot.weapon,
                    it == null ? Colors.white24 : c),
              ),
            ),
            if (it != null && it.plus > 0)
              Positioned(
                right: 3,
                top: 1,
                child: Text('+${it.plus}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: goldLight)),
              ),
            if (it != null && it.golden)
              const Positioned(
                left: 3,
                top: 2,
                child: Icon(Icons.star, size: 12, color: Color(goldItemColor)),
              ),
            if (it != null)
              Positioned(
                left: 4,
                bottom: 1,
                child: Text('${it.level}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: creamDim)),
              ),
          ],
        ),
      ),
    );
  }
}

class SlotGlyph extends CustomPainter {
  SlotGlyph(this.slot, this.color);
  final Slot slot;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final f = Paint()..color = color.withValues(alpha: 0.35);
    final w = s.width, h = s.height;
    Offset o(double x, double y) => Offset(w * x, h * y);
    switch (slot) {
      case Slot.weapon:
        c.drawLine(o(0.25, 0.75), o(0.75, 0.25), p);
        c.drawLine(o(0.2, 0.6), o(0.4, 0.8), p);
        c.drawLine(o(0.18, 0.82), o(0.27, 0.73), p);
      case Slot.hat:
        final path = Path()
          ..moveTo(w * 0.15, h * 0.65)
          ..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.85, h * 0.65)
          ..close();
        c.drawPath(path, f);
        c.drawPath(path, p);
        c.drawLine(o(0.1, 0.68), o(0.9, 0.68), p);
      case Slot.armor:
        final path = Path()
          ..moveTo(w * 0.3, h * 0.22)
          ..lineTo(w * 0.7, h * 0.22)
          ..lineTo(w * 0.85, h * 0.4)
          ..lineTo(w * 0.72, h * 0.48)
          ..lineTo(w * 0.72, h * 0.8)
          ..lineTo(w * 0.28, h * 0.8)
          ..lineTo(w * 0.28, h * 0.48)
          ..lineTo(w * 0.15, h * 0.4)
          ..close();
        c.drawPath(path, f);
        c.drawPath(path, p);
        c.drawLine(o(0.42, 0.22), o(0.55, 0.45), p);
      case Slot.belt:
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.12, h * 0.4, w * 0.88, h * 0.6),
            Radius.circular(w * 0.05)), p);
        c.drawRect(Rect.fromLTRB(w * 0.42, h * 0.36, w * 0.58, h * 0.64), f);
        c.drawRect(Rect.fromLTRB(w * 0.42, h * 0.36, w * 0.58, h * 0.64), p);
      case Slot.boots:
        final path = Path()
          ..moveTo(w * 0.35, h * 0.2)
          ..lineTo(w * 0.55, h * 0.2)
          ..lineTo(w * 0.55, h * 0.6)
          ..lineTo(w * 0.82, h * 0.68)
          ..lineTo(w * 0.82, h * 0.8)
          ..lineTo(w * 0.32, h * 0.8)
          ..close();
        c.drawPath(path, f);
        c.drawPath(path, p);
      case Slot.amulet:
        c.drawLine(o(0.3, 0.15), o(0.5, 0.42), p);
        c.drawLine(o(0.7, 0.15), o(0.5, 0.42), p);
        c.drawCircle(o(0.5, 0.6), w * 0.17, f);
        c.drawCircle(o(0.5, 0.6), w * 0.17, p);
        c.drawLine(o(0.5, 0.77), o(0.5, 0.9), p);
      case Slot.ring:
        c.drawCircle(o(0.5, 0.58), w * 0.22, p);
        final gem = Path()
          ..moveTo(w * 0.5, h * 0.18)
          ..lineTo(w * 0.62, h * 0.3)
          ..lineTo(w * 0.5, h * 0.4)
          ..lineTo(w * 0.38, h * 0.3)
          ..close();
        c.drawPath(gem, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(SlotGlyph old) => old.slot != slot || old.color != color;
}

/// Round skill badge with a glyph for how the skill is delivered.
class SkillGlyph extends CustomPainter {
  SkillGlyph(this.skill, this.hanh, {this.locked = false, this.cooldown = 0});
  final SkillDef skill;
  final Hanh hanh;
  final bool locked;

  /// 0..1 remaining cooldown, drawn as a dark sweep.
  final double cooldown;

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final ctr = Offset(r, r);
    final hc = hanhColor(hanh);
    c.drawCircle(
        ctr,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(hc, Colors.white, 0.25)!,
            Color.lerp(hc, Colors.black, 0.55)!,
          ]).createShader(Rect.fromCircle(center: ctr, radius: r)));
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    final f = Paint()..color = Colors.white.withValues(alpha: 0.92);
    Offset o(double x, double y) => Offset(r + x * r, r + y * r);
    if (skill.ultimate) {
      // Tuyệt kỹ: an eight-pointed burst inside a gold ring.
      final star = Path();
      for (var k = 0; k < 16; k++) {
        final a = -math.pi / 2 + k * math.pi / 8;
        final d = k.isEven ? 0.62 : 0.28;
        final pt = o(math.cos(a) * d, math.sin(a) * d);
        k == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
      }
      star.close();
      c.drawPath(star, Paint()..color = const Color(0xFFFFE08A));
      c.drawCircle(ctr, r * 0.2, Paint()..color = Color.lerp(hc, Colors.black, 0.3)!);
      c.drawCircle(ctr, r * 0.8, p..strokeWidth = r * 0.05);
    } else {
    switch (skill.kind) {
      case SkillKind.arc:
        c.drawArc(Rect.fromCircle(center: o(-0.25, 0.1), radius: r * 0.6), -1.3, 2.2, false, p);
        c.drawArc(Rect.fromCircle(center: o(-0.25, 0.1), radius: r * 0.35), -1.0, 1.6, false,
            p..strokeWidth = r * 0.07);
      case SkillKind.nova:
        c.drawCircle(ctr, r * 0.2, f);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          c.drawLine(o(math.cos(a) * 0.35, math.sin(a) * 0.35), o(math.cos(a) * 0.62, math.sin(a) * 0.62), p);
        }
      case SkillKind.projectile:
        c.drawLine(o(-0.5, 0.25), o(0.4, -0.2), p);
        c.drawPath(
            Path()
              ..moveTo(r + 0.55 * r, r - 0.28 * r)
              ..lineTo(r + 0.22 * r, r - 0.32 * r)
              ..lineTo(r + 0.4 * r, r - 0.02 * r)
              ..close(),
            f);
        if (skill.count > 1) {
          c.drawLine(o(-0.45, 0.5), o(0.2, 0.25), p..strokeWidth = r * 0.08);
          c.drawLine(o(-0.5, -0.05), o(0.15, -0.45), p);
        }
      case SkillKind.radial:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4 + 0.2;
          c.drawLine(o(math.cos(a) * 0.15, math.sin(a) * 0.15), o(math.cos(a) * 0.62, math.sin(a) * 0.62),
              p..strokeWidth = r * 0.09);
        }
      case SkillKind.ground:
        c.drawOval(Rect.fromCenter(center: o(0, 0.3), width: r * 1.3, height: r * 0.55), p);
        c.drawLine(o(0.35, -0.6), o(0.05, 0.15), p);
        c.drawCircle(o(0.4, -0.6), r * 0.16, f);
      case SkillKind.line:
        for (var i = 0; i < 3; i++) {
          final x = -0.5 + i * 0.45;
          c.drawPath(
              Path()
                ..moveTo(r + (x - 0.15) * r, r + 0.45 * r)
                ..lineTo(r + x * r, r - (0.1 + i * 0.15) * r)
                ..lineTo(r + (x + 0.15) * r, r + 0.45 * r)
                ..close(),
              f);
        }
      case SkillKind.dash:
        for (var i = 0; i < 3; i++) {
          final x = -0.5 + i * 0.35;
          c.drawLine(o(x, -0.35), o(x + 0.25, 0), p);
          c.drawLine(o(x + 0.25, 0), o(x, 0.35), p);
        }
      case SkillKind.aura:
        c.drawCircle(ctr, r * 0.5, p..strokeWidth = r * 0.07);
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi * 2 / 3;
          c.drawCircle(o(math.cos(a) * 0.5, math.sin(a) * 0.5), r * 0.14, f);
        }
      case SkillKind.guard:
        final path = Path()
          ..moveTo(r - 0.45 * r, r + 0.45 * r)
          ..quadraticBezierTo(r - 0.5 * r, r - 0.55 * r, r, r - 0.6 * r)
          ..quadraticBezierTo(r + 0.5 * r, r - 0.55 * r, r + 0.45 * r, r + 0.45 * r)
          ..close();
        c.drawPath(path, p);
        c.drawLine(o(-0.55, 0.45), o(0.55, 0.45), p);
      case SkillKind.heal:
        c.drawLine(o(0, -0.5), o(0, 0.5), p..strokeWidth = r * 0.2);
        c.drawLine(o(-0.5, 0), o(0.5, 0), p);
      case SkillKind.shield:
        final hex = Path();
        for (var k = 0; k < 6; k++) {
          final a = k * math.pi / 3 + math.pi / 6;
          final pt = o(math.cos(a) * 0.55, math.sin(a) * 0.55);
          k == 0 ? hex.moveTo(pt.dx, pt.dy) : hex.lineTo(pt.dx, pt.dy);
        }
        hex.close();
        c.drawPath(hex, p);
      case SkillKind.passive:
        c.drawCircle(ctr, r * 0.55, f);
        c.drawArc(Rect.fromCircle(center: ctr, radius: r * 0.55), math.pi / 2, math.pi, true,
            Paint()..color = Color.lerp(hc, Colors.black, 0.6)!);
        c.drawCircle(o(0, -0.275), r * 0.275, f);
        c.drawCircle(o(0, 0.275), r * 0.275, Paint()..color = Color.lerp(hc, Colors.black, 0.6)!);
    }
    }
    if (cooldown > 0) {
      c.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2, math.pi * 2 * cooldown, true,
          Paint()..color = const Color(0xAA000000));
    }
    if (locked) c.drawCircle(ctr, r, Paint()..color = const Color(0xAA000000));
    c.drawCircle(ctr, r - 1, Paint()
      ..color = goldLight.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = skill.ultimate ? 3.5 : 2);
  }

  @override
  bool shouldRepaint(SkillGlyph old) =>
      old.cooldown != cooldown || old.locked != locked || old.skill != skill;
}

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

/// A pill-shaped tab switch for a screen's title bar.
Widget tabChip(String name, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? seal : lacquer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? goldLight : gold.withValues(alpha: 0.5)),
          ),
          child: Text(name, style: bold.copyWith(fontSize: 13)),
        ),
      ),
    );
