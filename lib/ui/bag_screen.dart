import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/bag_items.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'character_screen.dart' show ItemDialog, TabChip;
import 'gem_tab.dart' show GemIcon;
import 'sub_screen.dart';
import 'theme.dart';

/// Túi đồ (1.15.0): gear on one tab, everything else collected on the
/// other, each with what it is for and where to get it. Opened from the
/// town's bag icon and from the battle HUD (the battle waits meanwhile).
class BagScreen extends StatefulWidget {
  const BagScreen({super.key, this.tab = 0, this.inBattle = false});
  final int tab;
  final bool inBattle;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late int _tab = widget.tab;
  HeroData get h => SaveService.instance.hero;

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Túi đồ',
      actions: [
        for (final (i, label) in [(0, 'Trang bị ${h.bag.length}/$bagSize'), (1, 'Vật phẩm')])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TabChip(label: label, on: _tab == i, onTap: () => setState(() => _tab = i)),
          ),
      ],
      child: _tab == 0
          ? GearBagView(onChanged: () => setState(() {}))
          : ItemsView(inBattle: widget.inBattle, onChanged: () => setState(() {})),
    );
  }
}

/// Worn gear beside the bag's gear, with the sell and auto-sell controls.
/// Also the Thợ rèn's item picker ([forge]).
class GearBagView extends StatefulWidget {
  const GearBagView({super.key, this.forge = false, this.onChanged});
  final bool forge;
  final VoidCallback? onChanged;

  @override
  State<GearBagView> createState() => _GearBagViewState();
}

class _GearBagViewState extends State<GearBagView> {
  HeroData get h => SaveService.instance.hero;

  void _changed() {
    SaveService.instance.save();
    setState(() {});
    widget.onChanged?.call();
  }

  /// The bag's sell button goes as far as auto-sell does, Thường at least.
  int get _sellUpTo => math.max(0, h.autoSellUpTo);

  static String _sellLabel(int r) => switch (r) {
        0 => 'đồ Thường',
        1 => 'đến Tinh xảo (xanh)',
        _ => 'đến Quý (vàng)',
      };

  bool _bulkSells(Item it) => it.rarity.index <= _sellUpTo && !it.golden && !it.locked;

  /// The grid's slot filter (null for all) and order.
  Slot? _slot;
  int _sort = 0;
  static const _sorts = ['Phẩm chất', 'Cấp', 'Lực chiến'];

  int _compare(Item a, Item b) {
    if (a.golden != b.golden) return a.golden ? -1 : 1;
    int by(int k) => switch (k) {
          0 => b.rarity.index.compareTo(a.rarity.index),
          1 => b.level.compareTo(a.level),
          _ => b.score.compareTo(a.score),
        };
    final first = by(_sort);
    return first != 0 ? first : by(_sort == 0 ? 1 : 0);
  }

  Widget _drop<T>(T value, List<(T, String)> items, ValueChanged<T> onChanged) => DropdownButton<T>(
        value: value,
        isDense: true,
        dropdownColor: lacquer,
        underline: const SizedBox.shrink(),
        style: small.copyWith(color: goldLight),
        items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l))],
        onChanged: (v) => onChanged(v as T),
      );

  /// Sells the bag's gear up to [_sellUpTo]; asks first past Thường, since
  /// a Quý piece can still beat what is worn.
  Future<void> _bulkSell() async {
    final list = h.bag.where(_bulkSells).toList();
    if (list.isEmpty) return;
    if (_sellUpTo > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: lacquer,
          content: Text('Bán ${list.length} món ${_sellLabel(_sellUpTo)}? Đồ Hoàng Kim được giữ lại.', style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bán')),
          ],
        ),
      );
      if (ok != true) return;
    }
    for (final it in list) {
      h.sell(it);
    }
    _changed();
  }

  Future<void> _open(Item it) async {
    await showDialog<void>(context: context, builder: (ctx) => ItemDialog(item: it, forge: widget.forge));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final bag = [
      for (final it in h.bag)
        if (_slot == null || it.slot == _slot) it,
    ]..sort(_compare);
    final full = h.bag.length >= bagSize;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 250,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(widget.forge ? 'Chọn món để cường hóa' : 'Đang trang bị', style: small),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [for (final s in [Slot.hat, Slot.armor, Slot.belt, Slot.boots]) _slotTile(s)],
                      ),
                      Expanded(child: FittedBox(child: FigurePreview.of(h, scale: 1.4))),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [for (final s in [Slot.weapon, Slot.amulet, Slot.ring]) _slotTile(s)],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Hành trang ${h.bag.length}/$bagSize${full ? ' · Đầy' : ''}',
                          style: bold.copyWith(color: full ? const Color(0xFFFF8A7A) : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    LButton(
                      label: 'Mặc tốt nhất',
                      small: true,
                      color: jade,
                      onTap: () {
                        h.autoEquip();
                        _changed();
                      },
                    ),
                    const SizedBox(width: 6),
                    LButton(
                      label: 'Bán ${_sellLabel(_sellUpTo)}',
                      small: true,
                      enabled: h.bag.any(_bulkSells),
                      onTap: _bulkSell,
                    ),
                  ],
                ),
                // Slides sideways when a narrow phone cannot fit all three.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('Tự bán: ', style: small),
                      _drop<int>(
                        h.autoSellUpTo,
                        [for (var r = -1; r <= Rarity.rare.index; r++) (r, r < 0 ? 'Không' : _sellLabel(r))],
                        (v) {
                          h.autoSellUpTo = v;
                          _changed();
                        },
                      ),
                      const SizedBox(width: 12),
                      _drop<Slot?>(
                        _slot,
                        [(null, 'Mọi vị trí'), for (final s in Slot.values) (s, s.label)],
                        (v) => setState(() => _slot = v),
                      ),
                      const SizedBox(width: 12),
                      Text('Xếp: ', style: small),
                      _drop<int>(
                        _sort,
                        [for (var i = 0; i < _sorts.length; i++) (i, _sorts[i])],
                        (v) => setState(() => _sort = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bag.isEmpty
                      ? Center(
                          child: Text(
                              h.bag.isEmpty
                                  ? 'Hành trang trống. Ra ngoài luyện công để nhặt đồ!'
                                  : 'Không có món nào ở vị trí này.',
                              style: small))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 60,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: bag.length,
                          itemBuilder: (_, i) => _bagTile(bag[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A bag piece, with a green arrow when it beats what is worn and a
  /// padlock when locked.
  Widget _bagTile(Item it) => Stack(
        children: [
          Positioned.fill(child: ItemTile(item: it, onTap: () => _open(it))),
          if (h.betterThanWorn(it))
            const Positioned(
              left: 1,
              top: 1,
              child: IgnorePointer(
                child: Icon(Icons.arrow_upward, size: 16, color: Color(0xFF5CE07A), shadows: [Shadow(blurRadius: 3)]),
              ),
            ),
          if (it.locked)
            const Positioned(
              right: 1,
              top: 1,
              child: IgnorePointer(
                child: Icon(Icons.lock, size: 13, color: goldLight, shadows: [Shadow(blurRadius: 3)]),
              ),
            ),
        ],
      );

  Widget _slotTile(Slot s) {
    final it = h.equip[s];
    return ItemTile(item: it, slot: s, size: 48, onTap: it == null ? null : () => _open(it));
  }
}

/// Everything counted rather than slotted: potions, pills, herbs, gems,
/// materials, currencies. A tap shows its use and sources on the right.
class ItemsView extends StatefulWidget {
  const ItemsView({super.key, this.inBattle = false, this.onChanged});
  final bool inBattle;
  final VoidCallback? onChanged;

  @override
  State<ItemsView> createState() => _ItemsViewState();
}

class _ItemsViewState extends State<ItemsView> {
  HeroData get h => SaveService.instance.hero;
  BagKind? _kind;
  String? _sel;
  String? _msg;

  void _changed(String msg) {
    SaveService.instance.save();
    setState(() => _msg = msg);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final all = bagEntries(h);
    final list = [
      for (final e in all)
        if (_kind == null || e.kind == _kind) e,
    ]..sort((a, b) => (a.count > 0 ? 0 : 1).compareTo(b.count > 0 ? 0 : 1));
    final sel = list.where((e) => e.id == _sel).firstOrNull ?? list.firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final k in [null, ...BagKind.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TabChip(
                            label: k?.label ?? 'Tất cả',
                            on: _kind == k,
                            onTap: () => setState(() {
                              _kind = k;
                              _msg = null;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text('Chưa có vật phẩm nào loại này.', style: small))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 64,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _tile(list[i], list[i].id == sel?.id),
                        ),
                ),
                Text('Vật phẩm không chiếm ô hành trang.', style: small.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 300, child: Panel(padding: const EdgeInsets.all(10), child: _detail(sel))),
      ],
    );
  }

  Widget _tile(BagEntry e, bool on) {
    final c = Color(e.color);
    return GestureDetector(
      onTap: () => setState(() {
        _sel = e.id;
        _msg = null;
      }),
      child: Opacity(
        opacity: e.count > 0 ? 1 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: on ? const Color(0xFF3A2A1C) : const Color(0xFF1E1410),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? goldLight : c.withValues(alpha: 0.6), width: on ? 2 : 1.2),
          ),
          child: Stack(
            children: [
              Center(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: BagIcon(e, size: 34))),
              Positioned(
                right: 4,
                bottom: 2,
                child: Text(_short(e.count),
                    style: bold.copyWith(fontSize: 12, shadows: const [Shadow(blurRadius: 3)])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _short(int n) =>
      n >= 1000000 ? '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}tr' : n >= 10000 ? '${n ~/ 1000}k' : '$n';

  Widget _detail(BagEntry? e) {
    if (e == null) return Center(child: Text('Chọn một vật phẩm để xem.', style: small));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BagIcon(e, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name, style: bold.copyWith(color: Color(e.color), fontSize: 15)),
                  Text('${e.kind.label} · Đang có: ${fmt(e.count)}', style: small),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Công dụng', style: bold.copyWith(color: goldLight, fontSize: 13)),
                Text(e.use, style: body.copyWith(fontSize: 12.5)),
                const SizedBox(height: 6),
                Text('Cách kiếm', style: bold.copyWith(color: goldLight, fontSize: 13)),
                Text(e.source, style: body.copyWith(fontSize: 12.5)),
                if (e.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.note, style: small.copyWith(color: const Color(0xFF9FE0C0))),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: 6),
                  Text(_msg!, style: small.copyWith(color: cream)),
                ],
              ],
            ),
          ),
        ),
        ..._actions(e),
      ],
    );
  }

  List<Widget> _actions(BagEntry e) {
    switch (e.action) {
      case BagAction.none:
        return const [];
      case BagAction.pill:
        final p = e.pill!;
        return [
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LButton(
                  label: 'Dùng 1',
                  small: true,
                  color: jade,
                  enabled: h.canUsePill(p),
                  onTap: () {
                    if (h.usePill(p)) _changed('Đã dùng ${p.name}.');
                  },
                ),
              ),
              if (p.kind == PillKind.buff) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: LButton(
                    label: 'Dùng đến đầy',
                    small: true,
                    enabled: h.canUsePill(p),
                    onTap: () {
                      final n = h.fillPill(p);
                      if (n > 0) _changed('Đã dùng $n viên ${p.name}.');
                    },
                  ),
                ),
              ],
            ],
          ),
          if (!h.canUsePill(p))
            Text(
              p.kind == PillKind.potential ? 'Đã dùng tối đa.' : 'Thời gian hiệu lực đã đầy.',
              style: small.copyWith(fontSize: 11),
            ),
        ];
      case BagAction.soulToIron:
        return [
          const SizedBox(height: 6),
          LButton(
            label: 'Đổi $soulPillsPerIron viên → 1 Thần Thiết',
            small: true,
            color: const Color(0xFF5A6A8A),
            enabled: h.soulPills >= soulPillsPerIron,
            onTap: _soulToIron,
          ),
        ];
    }
  }

  /// Asks first when the trade would leave too few for the next rebirth.
  Future<void> _soulToIron() async {
    final short = h.rebirths < maxRebirths && h.soulPills - soulPillsPerIron < h.nextRebirthPills;
    if (short) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: lacquer,
          content: Text(
              'Chuyển sinh ${h.rebirths + 1} cần ${h.nextRebirthPills} Linh Phách Đơn. Đổi ra Thần Thiết sẽ phải tích lại. Vẫn đổi?',
              style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đổi')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (h.soulToIron()) _changed('Đã đổi $soulPillsPerIron Linh Phách Đơn lấy 1 Thần Thiết.');
  }
}

/// A bag entry's picture: its painted icon, a gem, or a coloured glyph.
class BagIcon extends StatelessWidget {
  const BagIcon(this.e, {super.key, this.size = 32});
  final BagEntry e;
  final double size;

  static const _glyphs = {
    'drink': Icons.local_drink,
    'map': Icons.map,
    'herb': Icons.spa,
    'jade': Icons.diamond,
    'arena': Icons.military_tech,
    'sect': Icons.temple_buddhist,
    'guild': Icons.shield,
  };

  @override
  Widget build(BuildContext context) {
    if (e.gem != null) return GemIcon(gem: e.gem, size: size);
    final glyph = Icon(_glyphs[e.glyph] ?? Icons.inventory_2, size: size * 0.85, color: Color(e.color));
    if (e.art.isEmpty) return SizedBox.square(dimension: size, child: Center(child: glyph));
    return Image.asset(
      'assets/art/icons/${e.art}.webp',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size, child: Center(child: glyph)),
    );
  }
}
