import 'package:flutter/material.dart';

import '../core/gem_extras.dart';
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
                Row(
                  children: [
                    Expanded(child: LButton(label: 'Hợp tất cả', icon: Icons.merge_type, small: true, color: jade, onTap: _fuseAllDialog)),
                    const SizedBox(width: 6),
                    Expanded(child: LButton(label: 'Chuyển hệ', icon: Icons.swap_horiz, small: true, color: const Color(0xFF3A6A8A), onTap: _convertDialog)),
                    const SizedBox(width: 6),
                    Expanded(child: LButton(label: 'Luyện hóa', icon: Icons.auto_awesome, small: true, color: const Color(0xFF8A2A6A), onTap: _refineDialog)),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(child: _bagGrid()),
                if (_msg != null) Text(_msg!, style: small.copyWith(color: cream), maxLines: 2),
                if (MediaQuery.sizeOf(context).height >= 420)
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
          // A small phone gives cells about 30 points: the gem and its count
          // share the top line, the Hợp tag the bottom.
          child: LayoutBuilder(builder: (_, c) {
            final tight = c.maxHeight < 46;
            return Stack(
            children: [
              Align(
                alignment: tight ? const Alignment(-0.65, -0.6) : Alignment.center,
                child: GemIcon(gem: g, size: tight ? 15 : 26, dim: n == 0),
              ),
              Positioned(
                right: tight ? 2 : 3,
                top: tight ? 0 : 1,
                child: Text(n > 0 ? '$n' : '', style: bold.copyWith(fontSize: tight ? 9.5 : 11)),
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
                      child: Text('Hợp', style: TextStyle(fontSize: tight ? 7.5 : 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ],
          );
          }),
        ),
      ),
    );
  }
  // -------------------------------------------------------------- 1.8.0

  Widget _choice(String label, bool on, VoidCallback tap, {Color? color}) => Padding(
        padding: const EdgeInsets.only(right: 5, bottom: 5),
        child: GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: on ? seal : lacquerDeep,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? goldLight : (color ?? gold).withValues(alpha: 0.6)),
            ),
            child: Text(label, style: bold.copyWith(fontSize: 12, color: color ?? cream)),
          ),
        ),
      );

  Future<void> _dialog(String title, Widget Function(StateSetter set) body) => showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            backgroundColor: lacquer,
            title: Text(title, style: titleStyle(20)),
            content: SizedBox(width: 470, child: SingleChildScrollView(child: body(set))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
          ),
        ),
      );

  /// Hợp tất cả: every gem below a tier, of a phase or all, fused up to it.
  Future<void> _fuseAllDialog() async {
    var upTo = 5;
    Hanh? only;
    await _dialog('Hợp tất cả', (set) {
      final plan = h.fusePlan(upTo, only: only);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Hợp mọi ngọc bậc thấp hơn, 3 viên thành 1, cho tới bậc:', style: body),
          const SizedBox(height: 4),
          Wrap(children: [
            for (var t = 2; t <= maxGemTier; t++) _choice('${gemTierNames[t - 1]} ($t)', upTo == t, () => set(() => upTo = t)),
          ]),
          Text('Hệ:', style: body),
          const SizedBox(height: 4),
          Wrap(children: [
            _choice('Tất cả', only == null, () => set(() => only = null)),
            for (final hn in Hanh.values) _choice(hn.label, only == hn, () => set(() => only = hn), color: hanhColor(hn)),
          ]),
          const SizedBox(height: 6),
          if (plan.fuses == 0)
            Text('Không đủ ngọc để hợp.', style: small)
          else ...[
            Text('${plan.fuses} lần hợp · ${fmt(plan.gold)} lượng', style: bold.copyWith(color: goldLight)),
            Text('Được: ${[for (final e in plan.made.entries) '${e.value} ${Gem(e.key, upTo).name}'].join(', ')}',
                style: small.copyWith(color: cream)),
          ],
          const SizedBox(height: 8),
          LButton(
            label: h.gold < plan.gold ? 'Thiếu lượng' : 'Hợp ngay',
            color: jade,
            enabled: plan.fuses > 0 && h.gold >= plan.gold,
            onTap: () {
              if (h.fuseAll(upTo, only: only)) {
                _changed('Đã hợp ${plan.fuses} lần (-${fmt(plan.gold)} lượng).');
                set(() {});
              }
            },
          ),
        ],
      );
    });
  }

  /// Chuyển hệ: two gems of one phase for one of another, same tier.
  Future<void> _convertDialog() async {
    var from = Hanh.values.firstWhere((hn) => hn != h.hanh);
    var to = h.hanh;
    var tier = 5;
    await _dialog('Chuyển hệ ngọc', (set) {
      final g = Gem(from, tier);
      final have = h.gemCount(g);
      final most = have ~/ convertRatio;
      Widget go(int n) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: LButton(
              label: n == most ? 'Đổi hết ($n)' : 'Đổi $n',
              small: true,
              color: const Color(0xFF3A6A8A),
              enabled: n > 0 && n <= most && h.gold >= convertCost(tier) * n && from != to,
              onTap: () {
                if (h.convertGem(g, to, n)) {
                  _changed('Đã đổi ${n * convertRatio} ${g.name} lấy $n ${Gem(to, tier).name}.');
                  set(() {});
                }
              },
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$convertRatio viên hệ này đổi 1 viên hệ khác cùng bậc, thêm ${fmt(convertCost(tier))} lượng mỗi viên.', style: body),
          const SizedBox(height: 6),
          Text('Bậc:', style: body),
          Wrap(children: [for (var t = 1; t <= maxGemTier; t++) _choice(gemTierNames[t - 1], tier == t, () => set(() => tier = t))]),
          Text('Đổi từ:', style: body),
          Wrap(children: [
            for (final hn in Hanh.values)
              _choice('${hn.label} (${h.gemCount(Gem(hn, tier))})', from == hn, () => set(() => from = hn), color: hanhColor(hn)),
          ]),
          Text('Sang:', style: body),
          Wrap(children: [
            for (final hn in Hanh.values)
              if (hn != from)
                _choice(hn == h.hanh ? '${hn.label} (bản mệnh)' : hn.label, to == hn, () => set(() => to = hn), color: hanhColor(hn)),
          ]),
          const SizedBox(height: 6),
          Row(children: [go(1), go(10), go(most)]),
        ],
      );
    });
  }

  /// Luyện hóa: Thần, Tiên and Thánh gems into Tinh Thạch, capped a week.
  Future<void> _refineDialog() async {
    var tier = 5;
    var hanhSel = Hanh.values.firstWhere((hn) => hn != h.hanh);
    await _dialog('Luyện hóa ngọc', (set) {
      final g = Gem(hanhSel, tier);
      final per = gemsPerStone(tier)!;
      final left = h.gemStonesLeft;
      final most = [h.gemCount(g) ~/ per, left].reduce((a, b) => a < b ? a : b);
      Widget go(int n) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: LButton(
              label: n == most ? 'Tối đa ($n)' : '$n viên',
              small: true,
              color: const Color(0xFF8A2A6A),
              enabled: n > 0 && n <= most,
              onTap: () {
                if (h.refineGems(g, n)) {
                  _changed('Luyện ${n * per} ${g.name} thành $n Tinh Thạch.');
                  set(() {});
                }
              },
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Luyện ngọc bậc cao thành Tinh Thạch (dùng để Thăng Tinh): 10 Thần, 3 Tiên hoặc 1 Thánh được 1 viên.', style: body),
          Text('Tuần này còn luyện được $left/$gemStonesPerWeek Tinh Thạch. Đang có ${fmt(h.starStones)}.',
              style: bold.copyWith(color: goldLight)),
          const SizedBox(height: 6),
          Wrap(children: [for (final t in const [5, 6, 7]) _choice('${gemTierNames[t - 1]} (${gemsPerStone(t)} → 1)', tier == t, () => set(() => tier = t))]),
          Wrap(children: [
            for (final hn in Hanh.values)
              _choice('${hn.label} (${h.gemCount(Gem(hn, tier))})', hanhSel == hn, () => set(() => hanhSel = hn), color: hanhColor(hn)),
          ]),
          const SizedBox(height: 6),
          Row(children: [go(1), go(10), go(most)]),
        ],
      );
    });
  }
}
