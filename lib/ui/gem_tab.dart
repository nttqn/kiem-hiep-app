import 'package:flutter/material.dart';

import '../core/gems.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/save.dart';
import 'theme.dart';

/// A faceted gem in its phase colour with one pip per tier.
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, required this.gem, this.size = 30, this.dim = false});
  final Gem? gem;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GemPainter(gem, dim));
}

class _GemPainter extends CustomPainter {
  _GemPainter(this.gem, this.dim);
  final Gem? gem;
  final bool dim;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final g = gem;
    if (g == null) {
      // Empty socket: a dark ring.
      c.drawCircle(Offset(w / 2, h / 2), w * 0.36, Paint()..color = const Color(0xFF120A08));
      c.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.36,
          Paint()
            ..color = gold.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      return;
    }
    final col = Color(g.hanh.color).withValues(alpha: dim ? 0.35 : 1);
    final p = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.86, h * 0.36)
      ..lineTo(w * 0.5, h * 0.82)
      ..lineTo(w * 0.14, h * 0.36)
      ..close();
    c.drawPath(
        p,
        Paint()
          ..color = col.withValues(alpha: dim ? 0.15 : 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(col, Colors.white, 0.45)!, col, Color.lerp(col, Colors.black, 0.35)!],
          ).createShader(Offset.zero & s));
    c.drawPath(
        p,
        Paint()
          ..color = const Color(0xFF2A1810)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    c.drawLine(Offset(w * 0.14, h * 0.36), Offset(w * 0.86, h * 0.36),
        Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 0.8);
    // Tier pips.
    for (var i = 0; i < g.tier; i++) {
      final x = w * 0.5 + (i - (g.tier - 1) / 2) * w * 0.14;
      c.drawCircle(Offset(x, h * 0.93), w * 0.045, Paint()..color = goldLight);
    }
  }

  @override
  bool shouldRepaint(_GemPainter old) => old.gem != gem || old.dim != dim;
}

/// Character screen tab: socket gems into worn gear, fuse gems.
class GemTab extends StatefulWidget {
  const GemTab({super.key, required this.onChanged, required this.openItem});
  final VoidCallback onChanged;
  final void Function(Item it) openItem;

  @override
  State<GemTab> createState() => _GemTabState();
}

class _GemTabState extends State<GemTab> {
  HeroData get h => SaveService.instance.hero;
  Slot? _sel;
  String? _msg;

  Item? get _item => _sel == null ? null : h.equip[_sel];

  void _changed([String? msg]) {
    SaveService.instance.save();
    setState(() => _msg = msg);
    widget.onChanged();
  }

  void _socket(Gem g) {
    final it = _item;
    if (it == null) {
      setState(() => _msg = 'Chọn một món đồ đang mặc ở bên trái trước.');
      return;
    }
    if (it.gems.isEmpty) {
      setState(() => _msg = '${it.name} không có lỗ khảm (cần độ hiếm Tinh xảo trở lên).');
      return;
    }
    var i = it.gems.indexOf(null);
    if (i < 0) i = 0; // all full: replace the first
    h.socketGem(it, i, g);
    _changed('Đã khảm ${g.name} vào ${it.name}.');
  }

  @override
  Widget build(BuildContext context) {
    final phases = h.gemPhases;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 330,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trang bị đang mặc · chạm để chọn, chạm ngọc để gỡ', style: small),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [for (final s in Slot.values) _row(s)],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final hn in Hanh.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _phasePip(hn),
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(setBonusText(phases),
                          style: bold.copyWith(fontSize: 12.5, color: phases >= 3 ? goldLight : creamDim)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(child: _bagGrid()),
                if (_msg != null) Text(_msg!, style: small.copyWith(color: cream)),
                Text('Ngọc cùng hệ ${h.hanh.label} với môn phái (bản mệnh) mạnh hơn 50%. '
                    'Ngọc rơi từ quái theo hệ của quái, đầu lĩnh luôn rơi.',
                    style: small.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _phasePip(Hanh hn) {
    final on = h.equip.values.any((it) => it.gems.any((g) => g?.hanh == hn));
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? hanhColor(hn) : lacquerDeep,
        border: Border.all(color: hanhColor(hn), width: 1.5),
      ),
      child: Text(hn.label[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: on ? Colors.white : creamDim)),
    );
  }

  Widget _row(Slot s) {
    final it = h.equip[s];
    final sel = _sel == s;
    return GestureDetector(
      onTap: () => setState(() => _sel = s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? Color.lerp(lacquer, seal, 0.4) : lacquerDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? goldLight : gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ItemTile(item: it, slot: s, size: 38, onTap: it == null ? null : () => widget.openItem(it)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(it?.title ?? '${s.label} (trống)',
                  style: small.copyWith(fontSize: 12, color: it == null ? creamDim : rarityColor(it.rarity)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (it != null)
              for (var i = 0; i < it.gems.length; i++)
                GestureDetector(
                  onTap: () {
                    final g = it.gems[i];
                    if (g == null) {
                      setState(() => _sel = s);
                      return;
                    }
                    h.unsocketGem(it, i);
                    _changed('Đã gỡ ${g.name}.');
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: GemIcon(gem: it.gems[i], size: 26),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _bagGrid() {
    return Column(
      children: [
        for (final hn in Hanh.values)
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(gemEffectText(Gem(hn, 1), banMenh: hn == h.hanh).split(',').first,
                      style: small.copyWith(fontSize: 10.5, color: hanhColor(hn)), maxLines: 2),
                ),
                for (var t = 1; t <= maxGemTier; t++) Expanded(child: _cell(Gem(hn, t))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(Gem g) {
    final n = h.gemCount(g);
    final canFuse = n >= 3 && g.tier < maxGemTier;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: n > 0 ? () => _socket(g) : null,
        child: Container(
          decoration: BoxDecoration(
            color: lacquerDeep,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: n > 0 ? hanhColor(g.hanh).withValues(alpha: 0.7) : Colors.white10),
          ),
          child: Stack(
            children: [
              Center(child: GemIcon(gem: g, size: 26, dim: n == 0)),
              Positioned(
                right: 3,
                top: 1,
                child: Text(n > 0 ? '$n' : '', style: bold.copyWith(fontSize: 11)),
              ),
              if (canFuse)
                Positioned(
                  left: 2,
                  bottom: 1,
                  child: GestureDetector(
                    onTap: () {
                      if (h.fuseGem(g)) {
                        _changed('Hợp thành ${Gem(g.hanh, g.tier + 1).name} (-${fuseCost(g.tier)} lượng).');
                      } else {
                        setState(() => _msg = 'Cần ${fuseCost(g.tier)} lượng để hợp ngọc.');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: jade, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Hợp', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
