import '../core/i18n.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/items.dart';
import '../core/sects.dart';
import '../render/quality.dart' show liteGraphics;
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
    if (i > 0 && (s.length - i) % 3 == 0) out.write(thouSep);
    out.write(s[i]);
  }
  return out.toString();
}

/// A small mark of a player's or bang's language (1.22): VN, 繁中.
class LangTag extends StatelessWidget {
  const LangTag(this.lang, {super.key});
  final Lang lang;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 5),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: switch (lang) {
            Lang.vi => const Color(0xFF8A2A1E),
            Lang.zhHant => const Color(0xFF1E4E8A),
            Lang.ko => const Color(0xFF2E6B3A),
            Lang.en => const Color(0xFF5A3E8A),
          },
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(lang.tag, style: const TextStyle(fontSize: 9, height: 1.2, color: Color(0xFFFFF3C4), fontWeight: FontWeight.w800)),
      );
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
    this.art,
    this.outset = 5,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color border;
  final double radius;

  /// A painted picture behind the content, showing through on the right
  /// and fading into lacquer on the left where the text sits (1.11.2).
  final String? art;

  /// How far the painted frame reaches past the box (small tiles: less).
  final double outset;

  @override
  Widget build(BuildContext context) {
    final art = this.art;
    // 1.25: the painted lacquer board with gold cloud corners, for every
    // plain panel; tinted or pictured panels keep the drawn look.
    if (art == null && color == null && border == gold) {
      // The frame reaches a few points past the box, so the corner scrolls
      // sit mostly outside the content instead of under the first words.
      return Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -outset,
            top: -outset,
            right: -outset,
            bottom: -outset,
            child: SliceFrame(uiPanelArt, slice: SliceFrame.panel.$1, imageSize: SliceFrame.panel.$2, scale: 4.6),
          ),
          Padding(padding: padding, child: child),
        ],
      );
    }
    return Container(
      padding: art == null ? padding : EdgeInsets.zero,
      clipBehavior: art == null ? Clip.none : Clip.antiAlias,
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
      child: art == null
          ? child
          : Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: Image.asset(art,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox()),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          lacquer.withValues(alpha: 0.95),
                          lacquer.withValues(alpha: 0.86),
                          lacquer.withValues(alpha: 0.5),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
    );
  }
}

/// Painted UI frames (assets/art/ui, tool/ui_art.js).
const uiPanelArt = 'assets/art/ui/panel.webp';
const uiTitleArt = 'assets/art/ui/title_bar.webp';
const uiButtonArt = 'assets/art/ui/btn_primary.webp';
const uiButtonDarkArt = 'assets/art/ui/btn_secondary.webp';
const uiButtonOffArt = 'assets/art/ui/btn_disabled.webp';

/// btn_primary with the red lacquer turned jade (gold trim kept).
const uiButtonJadeArt = 'assets/art/ui/btn_jade.webp';

/// 1.26.0: amber, blue and purple lacquer the same way, so every button
/// colour has a painted look (see [paintedButtonFor]).
const uiButtonAmberArt = 'assets/art/ui/btn_amber.webp';
const uiButtonBlueArt = 'assets/art/ui/btn_blue.webp';
const uiButtonPurpleArt = 'assets/art/ui/btn_purple.webp';

/// The painted button for lacquer colour [c], by its colour family: red,
/// amber (also gold and cream), jade, blue, purple; greys and dark browns
/// take the dark one.
String paintedButtonFor(Color c) {
  if (c == seal) return uiButtonArt;
  if (c == jade) return uiButtonJadeArt;
  if (c == lacquer || c == lacquerLight || c == lacquerDeep) return uiButtonDarkArt;
  final hsv = HSVColor.fromColor(c);
  if (hsv.saturation < 0.25) return hsv.value > 0.6 ? uiButtonAmberArt : uiButtonDarkArt;
  if (hsv.saturation < 0.4 && hsv.value < 0.45) return uiButtonDarkArt;
  final hue = hsv.hue;
  if (hue < 15 || hue >= 340) return uiButtonArt;
  if (hue < 65) return uiButtonAmberArt;
  if (hue < 185) return uiButtonJadeArt;
  if (hue < 255) return uiButtonBlueArt;
  return uiButtonPurpleArt;
}
String uiSlotArt(int rarity) => 'assets/art/ui/slot_${rarity.clamp(0, 4)}.webp';

/// Hoàng Kim's own frame: slot_4 with pale-gold flames and jade gems, so a
/// set piece reads apart from a Truyền thuyết one (both were fire dragons).
const uiSlotGoldArt = 'assets/art/ui/slot_gold.webp';

/// A painted nine-slice frame filling its box. [slice] is the stretchable
/// middle in image pixels of an [imageSize] picture; [scale] image pixels
/// make one point. A box too small for the fixed edges gets a bigger
/// scale (smaller edges) instead of a broken draw.
class SliceFrame extends StatelessWidget {
  const SliceFrame(this.asset, {super.key, required this.slice, required this.imageSize, required this.scale, this.shadow = false});
  final String asset;
  final Rect slice;
  final Size imageSize;
  final double scale;
  final bool shadow;

  static const panel = (Rect.fromLTRB(95, 80, 505, 355), Size(600, 435));
  static const button = (Rect.fromLTRB(70, 32, 236, 64), Size(306, 96));
  static const title = (Rect.fromLTRB(180, 70, 720, 160), Size(900, 226));

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, k) {
        final w = k.maxWidth, h = k.maxHeight;
        if (!w.isFinite || !h.isFinite || w < 2 || h < 2) return const SizedBox.shrink();
        final s = math.max(scale,
            math.max((imageSize.width - slice.width) / (w - 1), (imageSize.height - slice.height) / (h - 1)));
        return DecoratedBox(
          decoration: BoxDecoration(
            // Chế độ máy yếu (1.28.0): no soft shadow, plainer sampling.
            boxShadow: shadow && !liteGraphics ? const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 3))] : null,
            image: DecorationImage(
              image: AssetImage(asset),
              centerSlice: Rect.fromLTRB(slice.left / s, slice.top / s, slice.right / s, slice.bottom / s),
              scale: s,
              filterQuality: liteGraphics ? FilterQuality.low : FilterQuality.medium,
            ),
          ),
        );
      });
}

/// Read once at start so the first screen does not show bare frames.
Future<void> precacheUiArt(BuildContext context) => Future.wait([
      for (final p in [uiPanelArt, uiTitleArt, uiButtonArt, uiButtonJadeArt, uiButtonAmberArt, uiButtonBlueArt, uiButtonPurpleArt, uiButtonDarkArt, uiButtonOffArt, uiSlotGoldArt, for (var i = 0; i < 5; i++) uiSlotArt(i)])
        precacheImage(AssetImage(p), context, onError: (_, _) {}),
    ]);

/// The painted vignette of a region (assets/art/map_{theme}.webp, 1.11.2).
String mapArtPath(String theme) => 'assets/art/map_$theme.webp';

/// A raised lacquer button that sinks when pressed.
class LButton extends StatefulWidget {
  const LButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = seal,
    this.icon,
    this.leading,
    this.small = false,
    this.width,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;

  /// A picture in place of [icon] (1.16.2: the painted Tàng Bảo Đồ).
  final Widget? leading;
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
    final h = widget.small ? 34.0 : 44.0;
    // 1.25: painted buttons; 1.26.0: every colour, by its family.
    final painted = !on ? uiButtonOffArt : paintedButtonFor(widget.color);
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
        // The label keeps clear of the cloud scrolls at the ends.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: SliceFrame(painted,
                  slice: SliceFrame.button.$1, imageSize: SliceFrame.button.$2, scale: widget.small ? 4.4 : 3.2, shadow: !_down),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 15 : 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leading != null || widget.icon != null) ...[
                    widget.leading ?? Icon(widget.icon, size: widget.small ? 16 : 20, color: on ? cream : Colors.white38),
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
        // 1.25: an item sits in the painted frame of its rarity, a soft glow
        // of its colour inside; an empty slot keeps the plain drawn one.
        foregroundDecoration: selected && it != null
            ? BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2.4))
            : null,
        decoration: it != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(it.golden ? uiSlotGoldArt : uiSlotArt(it.rarity.index)),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              )
            : BoxDecoration(
                gradient: const RadialGradient(colors: [lacquerLight, lacquerDeep]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? Colors.white : c, width: selected ? 2.4 : 1.6),
              ),
        child: Stack(
          children: [
            if (it != null)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [c.withValues(alpha: 0.38), c.withValues(alpha: 0)]),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: () {
                final glyph = CustomPaint(
                  painter: SlotGlyph(it?.slot ?? slot ?? Slot.weapon, it == null ? Colors.white24 : c),
                );
                final path = it == null ? null : itemIconPath(it);
                if (path == null) return glyph;
                // 1.11.1: the painted icon of its kind and material tier.
                return Padding(
                  padding: EdgeInsets.all(size * 0.13),
                  child: Image.asset(path, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => glyph),
                );
              }(),
            ),
            if (it != null && (it.rarity.index >= Rarity.epic.index || it.golden))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShinePainter(it.golden ? const Color(goldItemColor) : c,
                        grand: it.golden || it.rarity == Rarity.legend),
                  ),
                ),
              ),
            if (it != null && it.plus > 0)
              Positioned(
                right: 3,
                top: 1,
                child: Text('+${it.plus}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: goldLight, shadows: _tileTextShadow)),
              ),
            if (it != null && it.golden)
              const Positioned(
                left: 3,
                top: 2,
                child: Icon(Icons.star, size: 12, color: Color(goldItemColor)),
              ),
            if (it != null && it.star > 0)
              Positioned(
                right: 3,
                bottom: 1,
                child: Text('★${it.star}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(it.star > starLowMax ? starHighColor : 0xFFFFD34A),
                        shadows: _tileTextShadow)),
              ),
            if (it != null)
              Positioned(
                left: 4,
                bottom: 1,
                child: Text('${it.level}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cream, shadows: _tileTextShadow)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One clock for every shining item tile: ticks about 30 times a second
/// while any is on screen, and stops when none is.
class ShineClock extends ChangeNotifier {
  ShineClock._();
  static final ShineClock instance = ShineClock._();
  Timer? _timer;
  final Stopwatch _watch = Stopwatch();
  double get t => _watch.elapsedMilliseconds / 1000;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_timer == null && !liteGraphics) {
      _watch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => notifyListeners());
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// A light running round the frame of an Epic, Legend or Hoàng Kim piece;
/// the grandest also catch a glint across the face now and then.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.color, {required this.grand}) : super(repaint: ShineClock.instance);
  final Color color;
  final bool grand;

  @override
  void paint(Canvas c, Size s) {
    final t = ShineClock.instance.t;
    final rect = (Offset.zero & s).deflate(1);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final turn = (t * (grand ? 0.9 : 0.6)) % 1;
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grand ? 2.6 : 2
          ..shader = SweepGradient(
            colors: [color.withValues(alpha: 0), Colors.white, color, color.withValues(alpha: 0)],
            stops: const [0.0, 0.08, 0.16, 0.3],
            transform: GradientRotation(turn * math.pi * 2),
          ).createShader(rect));
    if (grand) {
      final u = (t * 0.45) % 1.6;
      if (u < 1) {
        c.save();
        c.clipRRect(rr);
        final x = -s.width + u * s.width * 3;
        c.drawPath(
            Path()
              ..moveTo(x, 0)
              ..lineTo(x + 10, 0)
              ..lineTo(x + 10 - s.height, s.height)
              ..lineTo(x - s.height, s.height)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.28));
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.color != color || old.grand != grand;
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
  SkillGlyph(this.skill, this.hanh, {this.locked = false, this.cooldown = 0, this.overlayOnly = false});
  final SkillDef skill;
  final Hanh hanh;
  final bool locked;

  /// Only the cooldown sweep, lock shade and rim, over a painted icon.
  final bool overlayOnly;

  /// 0..1 remaining cooldown, drawn as a dark sweep.
  final double cooldown;

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final ctr = Offset(r, r);
    if (!overlayOnly) _face(c, r, ctr);
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

  void _face(Canvas c, double r, Offset ctr) {
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
  }

  @override
  bool shouldRepaint(SkillGlyph old) =>
      old.cooldown != cooldown || old.locked != locked || old.skill != skill || old.overlayOnly != overlayOnly;
}

/// A skill's painted icon (assets/art/icons/sk_{id}.webp, 1.11.2) cut round,
/// under the cooldown sweep, lock shade and rim; the drawn glyph stands in
/// for one not there.
class SkillIcon extends StatelessWidget {
  const SkillIcon(this.skill, this.hanh, {super.key, this.locked = false, this.cooldown = 0});
  final SkillDef skill;
  final Hanh hanh;
  final bool locked;
  final double cooldown;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipOval(
          child: Image.asset('assets/art/icons/sk_${skill.id}.webp',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => CustomPaint(painter: SkillGlyph(skill, hanh))),
        ),
        CustomPaint(painter: SkillGlyph(skill, hanh, locked: locked, cooldown: cooldown, overlayOnly: true)),
      ],
    );
  }
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

/// Painted icon (assets/art/icons, 1.11.1) of an item: its kind (a weapon
/// by the sect's weapon at the end of its name) and its material tier,
/// the same steps as the look on the hero (level / 20: iron, bronze, jade,
/// gold, celestial). Null for anything without one.
String? itemIconPath(Item it) {
  final tier = (it.level ~/ 20).clamp(0, 4) + 1;
  final kind = switch (it.slot) {
    Slot.weapon => weaponIconOf(it.name),
    Slot.hat => 'hat',
    Slot.armor => 'armor',
    Slot.belt => 'belt',
    Slot.boots => 'boots',
    Slot.amulet => 'amulet',
    Slot.ring => 'ring',
  };
  return kind == null ? null : 'assets/art/icons/${kind}_$tier.webp';
}

/// The weapon icon set for an item named [name] (Trường Kiếm before Kiếm).
String? weaponIconOf(String name) {
  if (name.endsWith('Trường Kiếm')) return 'w_truongkiem';
  if (name.endsWith('Kiếm')) return 'w_kiem';
  if (name.endsWith('Đao')) return 'w_dao';
  if (name.endsWith('Côn')) return 'w_con';
  if (name.endsWith('Phi Tiêu')) return 'w_phitieu';
  return null;
}

/// A dark edge under the numbers on an item tile, readable over a bright
/// painted icon.
const _tileTextShadow = [
  Shadow(color: Color(0xF0000000), offset: Offset(0.8, 0.8), blurRadius: 1.5),
  Shadow(color: Color(0xC0000000), offset: Offset(-0.6, -0.6), blurRadius: 1.5),
];

/// Materials with a painted icon (assets/art/icons/mat_*.webp, 1.11.2;
/// potions, Tiên Ngọc, Tàng Bảo Đồ and the five herbs since 1.16.2).
enum Mat { stone, iron, shard, soul, soulPill, hp, mp, jade, map, herb1, herb2, herb3, herb4, herb5 }

/// Herb [tier] (0-4) as a [Mat].
Mat herbMat(int tier) => Mat.values[Mat.herb1.index + tier.clamp(0, 4)];

/// A painted icon from assets/art/icons/[name].webp (town doors, emblems,
/// fish), the plain [fallback] glyph if the picture is missing.
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.name, {super.key, required this.fallback, this.size = 24, this.color = goldLight});
  final String name;
  final IconData fallback;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/art/icons/$name.webp',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(fallback, size: size * 0.85, color: color),
      );
}

/// A material's painted icon; a plain dot if the picture is missing.
class MatIcon extends StatelessWidget {
  const MatIcon(this.mat, {super.key, this.size = 20});
  final Mat mat;
  final double size;

  static const _file = {
    Mat.stone: 'mat_stone',
    Mat.iron: 'mat_iron',
    Mat.shard: 'mat_shard',
    Mat.soul: 'mat_soul',
    Mat.soulPill: 'mat_soulpill',
    Mat.hp: 'item_hp',
    Mat.mp: 'item_mp',
    Mat.jade: 'item_tienngoc',
    Mat.map: 'item_tbd',
    Mat.herb1: 'herb_1',
    Mat.herb2: 'herb_2',
    Mat.herb3: 'herb_3',
    Mat.herb4: 'herb_4',
    Mat.herb5: 'herb_5',
  };

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/art/icons/${_file[mat]}.webp',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => SizedBox.square(
          dimension: size,
          child: const Center(child: Icon(Icons.circle, size: 8, color: creamDim)),
        ),
      );
}

/// A material's icon and an amount beside it.
class MatCount extends StatelessWidget {
  const MatCount(this.mat, this.text, {super.key, this.style, this.size = 18});
  final Mat mat;
  final String text;
  final TextStyle? style;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MatIcon(mat, size: size),
          const SizedBox(width: 3),
          Flexible(child: Text(text, style: style ?? bold, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      );
}
