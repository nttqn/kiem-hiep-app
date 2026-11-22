import 'package:flutter/material.dart';

import '../core/essence.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

const _ess = Color(0xFFB8F0FF);
const _line = Color(0xFF8AC8FF);

/// Thợ rèn tab (1.18.0): Khắc ấn writes one line of a dropped piece over
/// one line of a worn Hoàng Kim piece, for Tinh Hoa; the drop is used up.
class EngraveTab extends StatefulWidget {
  const EngraveTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<EngraveTab> createState() => _EngraveTabState();
}

class _EngraveTabState extends State<EngraveTab> {
  HeroData get h => SaveService.instance.hero;
  Slot? _sel;
  Stat? _replace;
  Item? _donor;
  Stat? _take;
  String? _msg;

  List<Slot> get _slots => [
        for (final s in Slot.values)
          if (h.equip[s]?.golden ?? false) s,
      ];

  Item? get _target {
    final slots = _slots;
    if (slots.isEmpty) return null;
    return h.equip[_sel != null && slots.contains(_sel) ? _sel! : slots.first];
  }

  void _pick(Slot s) => setState(() {
        _sel = s;
        _replace = null;
        _donor = null;
        _take = null;
        _msg = null;
      });

  List<Item> _donors(Item t) {
    final list = h.bag.where((d) => engraveDonorFits(t, d)).toList()
      ..sort((a, b) {
        final r = b.rarity.index.compareTo(a.rarity.index);
        return r != 0 ? r : b.level.compareTo(a.level);
      });
    return list;
  }

  bool _takeable(Item t, Stat s) => !t.bonus.containsKey(s) || s == _replace;

  void _engrave(Item t) {
    final r = _replace, d = _donor, s = _take;
    if (r == null || d == null || s == null) return;
    final v = engraveValue(t, d, s);
    if (!h.engrave(t, r, d, s)) {
      setState(() => _msg = h.essence < engraveCost ? tr('Không đủ Tinh Hoa (cần {engraveCost}).', {'engraveCost': engraveCost}) : tr('Không thể khắc dòng này.'));
      return;
    }
    Analytics.instance.log('engrave', {'stat': s.name, 'from': r.name, 'rarity': d.rarity.index});
    SaveService.instance.save();
    setState(() {
      _msg = tr('Đã khắc {sLabel} {p0} lên {tName}.', {'sLabel': tr(s.label), 'p0': s.format(v), 'tName': tr(t.name)});
      _replace = null;
      _donor = null;
      _take = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = _target;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 250,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Đồ Hoàng Kim đang mặc'), style: small),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(children: [for (final s in _slots) _row(s, h.equip[s]!, identical(h.equip[s], t))]),
                ),
                Row(
                  children: [
                    const Icon(Icons.blur_on, color: _ess, size: 18),
                    const SizedBox(width: 4),
                    Text(tr('{essence} Tinh Hoa', {'essence': h.essence}), style: bold.copyWith(color: _ess)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: t == null
                ? Center(
                    child: Text(tr('Mặc đồ Hoàng Kim để khắc ấn.\nĐồ Hoàng Kim rèn ở thẻ Hoàng Kim từ cấp 60.'),
                        style: body, textAlign: TextAlign.center))
                : _detail(t),
          ),
        ),
      ],
    );
  }

  Widget _row(Slot s, Item it, bool sel) => GestureDetector(
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
              ItemTile(item: it, slot: s, size: 34),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tr(it.title),
                    style: small.copyWith(fontSize: 12, color: Color(it.color)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );

  Widget _chip(String text, {required bool on, bool enabled = true, VoidCallback? onTap}) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(right: 5, bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: on ? Color.lerp(lacquer, seal, 0.5) : lacquerDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? goldLight : gold.withValues(alpha: enabled ? 0.35 : 0.12)),
          ),
          child: Text(text,
              style: bold.copyWith(fontSize: 12.5, color: enabled ? _line : creamDim.withValues(alpha: 0.5))),
        ),
      );

  Widget _detail(Item t) {
    final donors = _donors(t);
    final r = _replace, d = _donor, s = _take;
    final ready = r != null && d != null && s != null && h.canEngrave(t, r, d, s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(tr('Khắc ấn'), style: titleStyle(19)),
              Text(
                  tr('Lấy 1 dòng của đồ rơi (Quý trở lên, cấp từ {p0}) khắc đè lên 1 dòng của '
                  '{tName}. Dòng giữ độ tốt như trên đồ rơi; món đồ rơi sẽ mất.', {'p0': t.level - engraveLevelGap, 'tName': tr(t.name)}),
                  style: small.copyWith(fontSize: 11.5)),
              const SizedBox(height: 6),
              Text(tr('1. Dòng muốn thay'), style: bold.copyWith(color: goldLight, fontSize: 13)),
              const SizedBox(height: 3),
              Wrap(children: [
                for (final e in t.bonus.entries)
                  _chip('${tr(e.key.label)} ${e.key.format(e.value)}',
                      on: r == e.key,
                      onTap: () => setState(() {
                            _replace = e.key;
                            if (_take != null && !_takeable(t, _take!)) _take = null;
                            _msg = null;
                          })),
              ]),
              const SizedBox(height: 6),
              Text(tr('2. Chọn dòng từ đồ rơi ({donorsLength} món phù hợp)', {'donorsLength': donors.length}),
                  style: bold.copyWith(color: goldLight, fontSize: 13)),
              if (donors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      tr('Chưa có món nào. Giữ lại đồ Quý, Hiếm, Truyền thuyết từ cấp {p0} '
                      '(đừng để Tự phân giải ăn mất món có dòng đẹp).', {'p0': t.level - engraveLevelGap}),
                      style: small.copyWith(fontSize: 11.5)),
                ),
              for (final it in donors)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: lacquerDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: identical(it, d) ? goldLight : gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ItemTile(item: it, slot: it.slot, size: 34),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('{itName} · cấp {level}', {'itName': tr(it.name), 'level': it.level}),
                                style: small.copyWith(fontSize: 11.5, color: Color(it.color)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Wrap(children: [
                              for (final k in it.bonus.keys)
                                _chip('${tr(k.label)} ${k.format(engraveValue(t, it, k))}',
                                    on: identical(it, d) && s == k,
                                    enabled: _takeable(t, k),
                                    onTap: () => setState(() {
                                          _donor = it;
                                          _take = k;
                                          _msg = null;
                                        })),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_msg != null) Text(_msg!, style: small.copyWith(color: cream)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                r != null && s != null && d != null
                    ? '${tr(r.label)} ${r.format(t.bonus[r]!)} → ${tr(s.label)} ${s.format(engraveValue(t, d, s))}'
                    : tr('Chọn dòng muốn thay và dòng từ đồ rơi.'),
                style: bold.copyWith(fontSize: 12.5, color: ready ? goldLight : creamDim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            LButton(
              label: tr('Khắc · {engraveCost} Tinh Hoa', {'engraveCost': engraveCost}),
              icon: Icons.blur_on,
              small: true,
              enabled: ready,
              onTap: () => _engrave(t),
            ),
          ],
        ),
      ],
    );
  }
}
