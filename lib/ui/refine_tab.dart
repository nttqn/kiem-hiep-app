import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/essence.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Thợ rèn tab: Tẩy luyện rerolls a worn item's extra lines; locked lines
/// stay, and every lock makes the reroll dearer.
class RefineTab extends StatefulWidget {
  const RefineTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<RefineTab> createState() => _RefineTabState();
}

class _RefineTabState extends State<RefineTab> {
  HeroData get h => SaveService.instance.hero;
  Slot? _sel;
  final Set<Stat> _locked = {};
  String? _msg;
  final _rng = math.Random();

  /// 1.18.0: null pays lượng; else Tinh Hoa, new lines from the group.
  RefineAim? _aim;

  Item? get _item {
    final s = _sel ?? Slot.values.firstWhere((s) => (h.equip[s]?.bonus.isNotEmpty ?? false), orElse: () => Slot.weapon);
    return h.equip[s];
  }

  void _pick(Slot s) => setState(() {
        _sel = s;
        _locked.clear();
        _msg = null;
      });

  void _refine(Item it) {
    final aim = _aim;
    if (aim != null) {
      final cost = aimedRefineCost(_locked.length);
      if (!h.refineAimed(it, _locked, aim, _rng)) {
        setState(() => _msg = h.essence < cost ? tr('Không đủ Tinh Hoa (cần {cost}).', {'cost': cost}) : tr('Không thể tẩy luyện món này.'));
        return;
      }
      Analytics.instance.log('refine', {'locks': _locked.length, 'rarity': it.rarity.index, 'aim': aim.name});
      SaveService.instance.save();
      setState(() => _msg = tr('Đã tẩy luyện {itName} hướng {aimLabel} (-{cost} Tinh Hoa).', {'itName': tr(it.name), 'aimLabel': tr(aim.label), 'cost': cost}));
      widget.onChanged();
      return;
    }
    final cost = refineCost(it, _locked.length);
    if (!h.refine(it, _locked, _rng)) {
      setState(() => _msg = h.gold < cost ? tr('Không đủ lượng (cần {p0}).', {'p0': fmt(cost)}) : tr('Không thể tẩy luyện món này.'));
      return;
    }
    Analytics.instance.log('refine', {'locks': _locked.length, 'rarity': it.rarity.index});
    SaveService.instance.save();
    setState(() => _msg = tr('Đã tẩy luyện {itName} (-{p0} lượng).', {'itName': tr(it.name), 'p0': fmt(cost)}));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final it = _item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Chọn món đồ đang mặc'), style: small),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in Slot.values)
                        if (h.equip[s] != null) _row(s, h.equip[s]!),
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
            padding: const EdgeInsets.all(12),
            child: it == null ? Center(child: Text(tr('Chưa mặc trang bị nào.'), style: body)) : _detail(it),
          ),
        ),
      ],
    );
  }

  Widget _row(Slot s, Item it) {
    final sel = identical(it, _item);
    return GestureDetector(
      onTap: () => _pick(s),
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
            ItemTile(item: it, slot: s, size: 38),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(it.title),
                      style: small.copyWith(fontSize: 12, color: rarityColor(it.rarity)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(it.bonus.isEmpty ? tr('Không có dòng phụ') : tr('{bonusLength} dòng phụ', {'bonusLength': it.bonus.length}),
                      style: small.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(Item it) {
    final n = it.bonus.length;
    final cost = refineCost(it, _locked.length);
    final affordable = _aim == null ? h.gold >= cost : h.essence >= aimedRefineCost(_locked.length);
    final canLockMore = _locked.length < n - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Tẩy luyện'), style: titleStyle(20)),
        Text(tr(it.title), style: bold.copyWith(color: rarityColor(it.rarity))),
        Text(
          n == 0
              ? tr('Món đồ Thường không có dòng phụ để tẩy luyện.')
              : n == 1
                  ? tr('Đổi ngẫu nhiên dòng phụ duy nhất của món này (đồ hiếm hơn có nhiều dòng và khóa được).')
                  : tr('Đổi ngẫu nhiên các dòng phụ. Khóa dòng muốn giữ (tối đa {p0}); mỗi khóa làm giá tăng.', {'p0': n - 1}),
          style: small.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final a in <RefineAim?>[null, ...RefineAim.values])
              ChoiceChip(
                label: Text(a == null ? tr('Lượng') : tr('Tinh Hoa · {p0}', {'p0': tr(a.label)}), style: small.copyWith(fontSize: 11.5)),
                selected: _aim == a,
                visualDensity: VisualDensity.compact,
                selectedColor: Color.lerp(lacquer, seal, 0.5),
                backgroundColor: lacquerDeep,
                onSelected: (_) => setState(() {
                  _aim = a;
                  _msg = null;
                }),
              ),
          ],
        ),
        if (_aim != null)
          Text(tr('Dòng mới chỉ ra nhóm {_aimLabel}: {p0}.', {'_aimLabel': tr(_aim!.label), 'p0': _aim!.stats.map((s) => s.label).join(', ')}),
              style: small.copyWith(fontSize: 11, color: const Color(0xFFB8F0FF))),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [
              for (final e in it.bonus.entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lacquerDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _locked.contains(e.key) ? goldLight : gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${tr(e.key.label)} ${e.key.format(e.value)}',
                            style: bold.copyWith(fontSize: 14, color: const Color(0xFF8AC8FF))),
                      ),
                      IconButton(
                        tooltip: _locked.contains(e.key) ? tr('Bỏ khóa') : tr('Khóa dòng này'),
                        icon: Icon(_locked.contains(e.key) ? Icons.lock : Icons.lock_open,
                            color: _locked.contains(e.key) ? goldLight : creamDim),
                        onPressed: !_locked.contains(e.key) && !canLockMore
                            ? null
                            : () => setState(() {
                                  if (!_locked.remove(e.key)) _locked.add(e.key);
                                }),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_msg != null) Text(_msg!, style: small.copyWith(color: cream)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                  _aim == null
                      ? tr('Giá: {p0} lượng{p1}', {'p0': fmt(cost), 'p1': _locked.isEmpty ? '' : tr(' ({_lockedLength} khóa)', {'_lockedLength': _locked.length})})
                      : tr('Giá: {p0} Tinh Hoa (có {essence})', {'p0': aimedRefineCost(_locked.length), 'essence': h.essence}),
                  style: bold.copyWith(color: affordable ? goldLight : const Color(0xFFFF8A7A))),
            ),
            LButton(
              label: tr('Tẩy luyện'),
              icon: Icons.autorenew,
              enabled: n > 0 && affordable,
              onTap: () => _refine(it),
            ),
          ],
        ),
      ],
    );
  }
}
