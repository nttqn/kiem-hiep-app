import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';

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
    final cost = refineCost(it, _locked.length);
    if (!h.refine(it, _locked, _rng)) {
      setState(() => _msg = h.gold < cost ? 'Không đủ lượng (cần ${fmt(cost)}).' : 'Không thể tẩy luyện món này.');
      return;
    }
    Analytics.instance.log('refine', {'locks': _locked.length, 'rarity': it.rarity.index});
    SaveService.instance.save();
    setState(() => _msg = 'Đã tẩy luyện ${it.name} (-${fmt(cost)} lượng).');
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
                Text('Chọn món đồ đang mặc', style: small),
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
            child: it == null ? Center(child: Text('Chưa mặc trang bị nào.', style: body)) : _detail(it),
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
                  Text(it.title,
                      style: small.copyWith(fontSize: 12, color: rarityColor(it.rarity)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(it.bonus.isEmpty ? 'Không có dòng phụ' : '${it.bonus.length} dòng phụ',
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
    final canLockMore = _locked.length < n - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tẩy luyện', style: titleStyle(20)),
        Text(it.title, style: bold.copyWith(color: rarityColor(it.rarity))),
        Text(
          n == 0
              ? 'Món đồ Thường không có dòng phụ để tẩy luyện.'
              : n == 1
                  ? 'Đổi ngẫu nhiên dòng phụ duy nhất của món này (đồ hiếm hơn có nhiều dòng và khóa được).'
                  : 'Đổi ngẫu nhiên các dòng phụ. Khóa dòng muốn giữ (tối đa ${n - 1}); mỗi khóa làm giá tăng.',
          style: small.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 8),
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
                        child: Text('${e.key.label} ${e.key.format(e.value)}',
                            style: bold.copyWith(fontSize: 14, color: const Color(0xFF8AC8FF))),
                      ),
                      IconButton(
                        tooltip: _locked.contains(e.key) ? 'Bỏ khóa' : 'Khóa dòng này',
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
              child: Text('Giá: ${fmt(cost)} lượng${_locked.isEmpty ? '' : ' (${_locked.length} khóa)'}',
                  style: bold.copyWith(color: h.gold >= cost ? goldLight : const Color(0xFFFF8A7A))),
            ),
            LButton(
              label: 'Tẩy luyện',
              icon: Icons.autorenew,
              enabled: n > 0 && h.gold >= cost,
              onTap: () => _refine(it),
            ),
          ],
        ),
      ],
    );
  }
}
