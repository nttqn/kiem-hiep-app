import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/bag_items.dart';
import '../core/essence.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'character_screen.dart' show ItemDialog, TabChip;
import 'gem_tab.dart' show GemIcon;
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

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
      title: tr('Túi đồ'),
      actions: [
        for (final (i, label) in [(0, tr('Trang bị {bagLength}/{bagSize}', {'bagLength': h.bag.length, 'bagSize': bagSize})), (1, tr('Vật phẩm'))])
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
        0 => tr('đồ Thường'),
        1 => tr('đến Tinh xảo (xanh)'),
        _ => tr('đến Quý (vàng)'),
      };

  bool _bulkSells(Item it) => it.rarity.index <= _sellUpTo && !it.golden && !it.locked;

  static String _salvageLabel(int r) => switch (r) {
        < 0 => tr('Không'),
        2 => tr('Quý'),
        3 => tr('đến Hiếm'),
        _ => tr('đến Truyền thuyết'),
      };

  /// Pieces the Phân giải button may take: never locked, Hoàng Kim or an
  /// upgrade on what is worn.
  bool _bulkSalvages(Item it) => canSalvage(it) && !h.betterThanWorn(it);

  /// Breaks down the chosen rarities (Truyền thuyết only when ticked: a
  /// good line there may be worth a Khắc ấn).
  Future<void> _bulkSalvage() async {
    final pick = {Rarity.rare, Rarity.epic};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final list = h.bag.where((it) => _bulkSalvages(it) && pick.contains(it.rarity)).toList();
          final total = list.fold<int>(0, (a, it) => a + essenceOf(it));
          return AlertDialog(
            scrollable: true,
            backgroundColor: lacquer,
            title: Text(tr('Phân giải'), style: titleStyle(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Đồ từ cấp {essenceMinLevel}, không tính đồ đã khóa, Hoàng Kim hay đồ tốt hơn món đang mặc.', {'essenceMinLevel': essenceMinLevel}),
                    style: small.copyWith(fontSize: 11.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final r in [Rarity.rare, Rarity.epic, Rarity.legend])
                      TabChip(
                        label: '${tr(r.label)} (${h.bag.where((it) => _bulkSalvages(it) && it.rarity == r).length})',
                        on: pick.contains(r),
                        onTap: () => set(() {
                          if (!pick.remove(r)) pick.add(r);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr('{listLength} món → +{total} Tinh Hoa', {'listLength': list.length, 'total': total}), style: bold.copyWith(color: const Color(0xFFB8F0FF))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
              TextButton(onPressed: list.isEmpty ? null : () => Navigator.pop(ctx, true), child: Text(tr('Phân giải'))),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    var n = 0, got = 0;
    for (final it in h.bag.where((it) => _bulkSalvages(it) && pick.contains(it.rarity)).toList()) {
      final e = h.salvage(it);
      if (e > 0) {
        n++;
        got += e;
      }
    }
    if (n > 0) Analytics.instance.log('salvage', {'n': n, 'ess': got});
    _changed();
  }

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
          content: Text(tr('Bán {listLength} món {p0}? Đồ Hoàng Kim được giữ lại.', {'listLength': list.length, 'p0': _sellLabel(_sellUpTo)}), style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Bán'))),
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

  /// Mua lại (1.18.1): the last Quý+ pieces sold or broken down on pick-up
  /// this session, each back for exactly what it fetched.
  Future<void> _buyBack() async {
    String? msg;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMsg) => AlertDialog(
          backgroundColor: lacquer,
          title: Text(tr('Mua lại'), style: titleStyle(20)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    tr('Đồ Quý trở lên vừa tự bán hoặc tự phân giải (tối đa {goneKeep} món, '
                    'mất khi tắt game). Chuộc lại đúng giá đã nhận.', {'goneKeep': goneKeep}),
                    style: small),
                const SizedBox(height: 6),
                if (h.gone.isEmpty) Text(tr('Không còn món nào.'), style: body),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in h.gone)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(tr('{itemName} · cấp {level} [{rarityLabel}]', {'itemName': tr(g.item.name), 'level': g.item.level, 'rarityLabel': g.item.rarityLabel}),
                                    style: body.copyWith(color: rarityColor(g.item.rarity)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 6),
                              LButton(
                                label: g.gold > 0 ? tr('{p0} lượng', {'p0': fmt(g.gold)}) : tr('{essence} Tinh Hoa', {'essence': g.essence}),
                                small: true,
                                onTap: () {
                                  final err = h.buyBack(g);
                                  if (err == null) {
                                    Analytics.instance.log('buyback', {'r': g.item.rarity.index, 'ess': g.essence});
                                    _changed();
                                  }
                                  setMsg(() => msg = err);
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (msg != null) Text(msg!, style: small.copyWith(color: const Color(0xFFFF8A7A))),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Xong')))],
        ),
      ),
    );
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
                Text(widget.forge ? tr('Chọn món để cường hóa') : tr('Đang trang bị'), style: small),
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
                      child: Text(tr('Hành trang {bagLength}/{bagSize}{p0}', {'bagLength': h.bag.length, 'bagSize': bagSize, 'p0': full ? tr(' · Đầy') : ''}),
                          style: bold.copyWith(color: full ? const Color(0xFFFF8A7A) : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    LButton(
                      label: tr('Mặc tốt nhất'),
                      small: true,
                      color: jade,
                      onTap: () {
                        h.autoEquip();
                        _changed();
                      },
                    ),
                    const SizedBox(width: 6),
                    LButton(
                      label: tr('Bán {p0}', {'p0': _sellLabel(_sellUpTo)}),
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
                      Text(tr('Tự bán: '), style: small),
                      _drop<int>(
                        h.autoSellUpTo,
                        [for (var r = -1; r <= Rarity.rare.index; r++) (r, r < 0 ? tr('Không') : _sellLabel(r))],
                        (v) {
                          h.autoSellUpTo = v;
                          _changed();
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(tr('Tự phân giải: '), style: small),
                      _drop<int>(
                        h.autoSalvageUpTo,
                        [for (var r = -1; r <= Rarity.legend.index; r++) if (r < 0 || r >= Rarity.rare.index) (r, _salvageLabel(r))],
                        (v) {
                          h.autoSalvageUpTo = v;
                          _changed();
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(tr('Túi đầy: '), style: small),
                      _drop<bool>(
                        h.fullBagSell,
                        [(false, tr('Phân giải')), (true, tr('Bán lấy vàng'))],
                        (v) {
                          h.fullBagSell = v;
                          _changed();
                        },
                      ),
                      const SizedBox(width: 8),
                      LButton(
                        label: tr('Mua lại{p0}', {'p0': h.gone.isEmpty ? '' : ' (${h.gone.length})'}),
                        small: true,
                        color: const Color(0xFF7A5A2A),
                        enabled: h.gone.isNotEmpty,
                        onTap: _buyBack,
                      ),
                      const SizedBox(width: 8),
                      LButton(
                        label: tr('Phân giải'),
                        small: true,
                        color: const Color(0xFF3A6A8A),
                        enabled: h.bag.any(_bulkSalvages),
                        onTap: _bulkSalvage,
                      ),
                      const SizedBox(width: 12),
                      _drop<Slot?>(
                        _slot,
                        [(null, tr('Mọi vị trí')), for (final s in Slot.values) (s, s.label)],
                        (v) => setState(() => _slot = v),
                      ),
                      const SizedBox(width: 12),
                      Text(tr('Xếp: '), style: small),
                      _drop<int>(
                        _sort,
                        [for (var i = 0; i < _sorts.length; i++) (i, tr(_sorts[i]))],
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
                                  ? tr('Hành trang trống. Ra ngoài luyện công để nhặt đồ!')
                                  : tr('Không có món nào ở vị trí này.'),
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
                            label: k?.label ?? tr('Tất cả'),
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
                      ? Center(child: Text(tr('Chưa có vật phẩm nào loại này.'), style: small))
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
                Text(tr('Vật phẩm không chiếm ô hành trang.'), style: small.copyWith(fontSize: 11)),
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
    if (e == null) return Center(child: Text(tr('Chọn một vật phẩm để xem.'), style: small));
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
                  Text(tr(e.name), style: bold.copyWith(color: Color(e.color), fontSize: 15)),
                  Text(tr('{kindLabel} · Đang có: {p0}', {'kindLabel': tr(e.kind.label), 'p0': fmt(e.count)}), style: small),
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
                Text(tr('Công dụng'), style: bold.copyWith(color: goldLight, fontSize: 13)),
                Text(e.use, style: body.copyWith(fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(tr('Cách kiếm'), style: bold.copyWith(color: goldLight, fontSize: 13)),
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
                  label: tr('Dùng 1'),
                  small: true,
                  color: jade,
                  enabled: h.canUsePill(p),
                  onTap: () {
                    if (h.usePill(p)) _changed(tr('Đã dùng {pName}.', {'pName': tr(p.name)}));
                  },
                ),
              ),
              if (p.kind == PillKind.buff) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: LButton(
                    label: tr('Dùng đến đầy'),
                    small: true,
                    enabled: h.canUsePill(p),
                    onTap: () {
                      final n = h.fillPill(p);
                      if (n > 0) _changed(tr('Đã dùng {n} viên {pName}.', {'n': n, 'pName': tr(p.name)}));
                    },
                  ),
                ),
              ],
            ],
          ),
          if (!h.canUsePill(p))
            Text(
              p.kind == PillKind.potential ? tr('Đã dùng tối đa.') : tr('Thời gian hiệu lực đã đầy.'),
              style: small.copyWith(fontSize: 11),
            ),
        ];
      case BagAction.essenceShop:
        return [
          const SizedBox(height: 6),
          for (final w in essenceWares)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('1 {wName}\ncòn {p0}/{perWeek} tuần này', {'wName': tr(w.name), 'p0': h.essLeft(w), 'perWeek': w.perWeek}),
                        style: small.copyWith(fontSize: 11.5, color: cream), maxLines: 2),
                  ),
                  LButton(
                    label: tr('Đổi {price}', {'price': w.price}),
                    small: true,
                    color: const Color(0xFF3A6A8A),
                    enabled: h.essLeft(w) > 0 && h.essence >= w.price,
                    onTap: () {
                      if (h.buyEssenceWare(w)) _changed(tr('Đã đổi {price} Tinh Hoa lấy 1 {wName}.', {'price': w.price, 'wName': tr(w.name)}));
                    },
                  ),
                ],
              ),
            ),
        ];
      case BagAction.soulToIron:
        return [
          const SizedBox(height: 6),
          LButton(
            label: tr('Đổi {soulPillsPerIron} viên → 1 Thần Thiết', {'soulPillsPerIron': soulPillsPerIron}),
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
              tr('Chuyển sinh {p0} cần {nextRebirthPills} Linh Phách Đơn. Đổi ra Thần Thiết sẽ phải tích lại. Vẫn đổi?', {'p0': h.rebirths + 1, 'nextRebirthPills': h.nextRebirthPills}),
              style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Đổi'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (h.soulToIron()) _changed(tr('Đã đổi {soulPillsPerIron} Linh Phách Đơn lấy 1 Thần Thiết.', {'soulPillsPerIron': soulPillsPerIron}));
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
    'fest': Icons.ac_unit,
    'essence': Icons.blur_on,
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
