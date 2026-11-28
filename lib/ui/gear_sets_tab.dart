import 'package:flutter/material.dart';

import '../core/dummy.dart';
import '../core/gear_sets.dart';
import '../core/hero.dart';
import '../core/i18n.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'run_gate.dart';
import 'theme.dart';

/// Nhân vật tab (1.27.0): Bộ trang bị, three saved builds put on in a tap,
/// and the way to Mộc nhân luyện công to weigh them.
class GearSetsTab extends StatefulWidget {
  const GearSetsTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<GearSetsTab> createState() => _GearSetsTabState();
}

class _GearSetsTabState extends State<GearSetsTab> {
  HeroData get h => SaveService.instance.hero;

  void _toast(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  void _save(int i) {
    h.saveGearSet(i);
    Analytics.instance.log('gear_set_save', {'i': i});
    SaveService.instance.save();
    widget.onChanged();
    setState(() {});
    _toast(tr('Đã lưu Bộ {p0}. Đồ trong bộ đã được khóa để không bán nhầm.', {'p0': i + 1}));
  }

  void _wear(int i) {
    final before = h.power;
    final r = h.applyGearSet(i);
    Analytics.instance.log('gear_set_wear', {'i': i, 'missing': r.missing});
    SaveService.instance.save();
    widget.onChanged();
    setState(() {});
    final notes = [
      if (r.missing > 0) tr('{p0} món không còn trong túi', {'p0': r.missing}),
      if (r.tooHigh > 0) tr('{p0} món chưa đủ cấp', {'p0': r.tooHigh}),
    ];
    _toast(tr('Đã mặc Bộ {p0}. Lực chiến {p1}.', {'p0': i + 1, 'p1': fmt(h.power)}) +
        (h.power != before ? ' (${h.power > before ? '+' : ''}${fmt(h.power - before)})' : '') +
        (notes.isEmpty ? '' : ' ${notes.join(', ')}.'));
  }

  Future<void> _dummy() async {
    if (!RunGate.take()) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(dummyDef())));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  tr('Lưu đồ đang mặc và điểm tiềm năng thành bộ, đổi bộ chỉ một chạm. Thử bộ nào mạnh hơn ở Mộc nhân.'),
                  style: small.copyWith(fontSize: 11.5)),
            ),
            const SizedBox(width: 8),
            LButton(
              label: tr('Mộc nhân · kỷ lục {p0}/s', {'p0': fmt(h.dummyBest)}),
              small: true,
              color: const Color(0xFF7A5A2A),
              onTap: _dummy,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < gearSetCount; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _card(i)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(int i) {
    final s = h.gearSets[i];
    final worn = h.gearSetWorn(i);
    const attr = ['Sức', 'Thân', 'Thể', 'Nội'];
    return Panel(
      border: worn ? goldLight : gold,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr('Bộ {p0}', {'p0': i + 1}), style: titleStyle(16))),
              if (worn) Text(tr('Đang mặc'), style: bold.copyWith(fontSize: 11, color: jade)),
            ],
          ),
          Expanded(
            child: s == null
                ? Center(child: Text(tr('Chưa lưu'), style: small.copyWith(color: creamDim)))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Lực chiến khi lưu: {p0}', {'p0': fmt(s.power)}), style: small.copyWith(fontSize: 11, color: goldLight)),
                        Text(
                            [for (var k = 0; k < 4; k++) '${tr(attr[k])} ${s.spent[k]}'].join(' · '),
                            style: small.copyWith(fontSize: 11)),
                        const SizedBox(height: 2),
                        for (final slot in Slot.values)
                          if (s.uids[slot] case final u?)
                            Builder(builder: (_) {
                              final it = h.itemByUid(u);
                              return Text(
                                it == null ? tr('{p0}: đã mất', {'p0': tr(slot.label)}) : tr(it.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: small.copyWith(fontSize: 11, color: it == null ? creamDim : Color(it.color)),
                              );
                            }),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          LButton(
            label: tr('Mặc bộ này'),
            small: true,
            color: jade,
            enabled: s != null && !worn,
            onTap: () => _wear(i),
          ),
          const SizedBox(height: 4),
          LButton(
            label: s == null ? tr('Lưu đồ đang mặc') : tr('Lưu đè'),
            small: true,
            color: const Color(0xFF5A4A3A),
            onTap: () => _save(i),
          ),
        ],
      ),
    );
  }
}
