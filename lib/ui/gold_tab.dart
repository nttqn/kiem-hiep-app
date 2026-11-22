import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/gold_extras.dart';
import '../core/gold_sets.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Thợ rèn tab: forge Hoàng Kim set pieces from Mảnh Hoàng Kim.
class GoldTab extends StatefulWidget {
  const GoldTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<GoldTab> createState() => _GoldTabState();
}

class _GoldTabState extends State<GoldTab> {
  HeroData get h => SaveService.instance.hero;
  late GoldSetDef _set = goldSetById[h.hanh.name] ?? goldSets.first;
  String? _msg;
  final _rng = math.Random();

  static const _gold = Color(goldItemColor);

  void _forge(Slot s) {
    final it = h.forgeGold(_set, s, _rng);
    if (it == null) {
      setState(() => _msg = h.bag.length >= bagSize ? tr('Hành trang đã đầy.') : tr('Không đủ Mảnh Hoàng Kim.'));
      return;
    }
    Analytics.instance.log('gold_forge', {'set': _set.id, 'slot': s.index});
    SaveService.instance.save();
    setState(() => _msg = tr('Đã đúc {itName} (cấp {level}), xem trong Hành trang.', {'itName': tr(it.name), 'level': it.level}));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final pieces = goldPieces(h.equip.values);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 230,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: ListView(
              children: [
                for (final s in goldSets) _setRow(s, pieces[s.id] ?? 0),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            border: _gold,
            padding: const EdgeInsets.all(10),
            child: h.goldOpen ? _rightPanel(pieces[_set.id] ?? 0) : _locked(),
          ),
        ),
      ],
    );
  }

  /// 0: forge, 1: Khai Quang and Tinh Luyện, 2: Hoàng Kim Các (1.9.0).
  int _mode = 0;

  Widget _rightPanel(int worn) {
    Widget chip(int i, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _mode = i;
                _msg = null;
              });
              if (i == 2 && h.hkFresh) {
                // Seen this week's goods: the tab's dot goes.
                h.hkRollWeek();
                SaveService.instance.save();
                widget.onChanged();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _mode == i ? seal : lacquerDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _mode == i ? _gold : gold.withValues(alpha: 0.5)),
              ),
              child: Text(label, style: bold.copyWith(fontSize: 12)),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            chip(0, tr('Đúc')),
            chip(1, tr('Khai Quang')),
            chip(2, tr('Hoàng Kim Các')),
            const Spacer(),
            const MatIcon(Mat.shard, size: 20),
            const SizedBox(width: 3),
            Flexible(
              child: Text(tr('{goldShards} mảnh', {'goldShards': h.goldShards}),
                  style: bold.copyWith(color: _gold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: switch (_mode) {
            1 => _glowPanel(),
            2 => _shopPanel(),
            _ => _forgePanel(worn),
          },
        ),
      ],
    );
  }

  void _done(String msg) {
    SaveService.instance.save();
    setState(() => _msg = msg);
    widget.onChanged();
  }

  /// "Do it for every piece" with a confirm showing what it costs (1.9.1).
  Widget _allButton(String label, String unit, (int, int) Function({bool dry}) run) {
    final (n, cost) = run(dry: true);
    return LButton(
      label: n > 0 ? '$label · $cost' : label,
      small: true,
      color: const Color(0xFF8A6A1A),
      enabled: n > 0,
      onTap: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: lacquer,
            content: Text(tr('{label}: +{n} {unit} cho đồ Hoàng Kim đang mặc, tốn {cost} Mảnh Hoàng Kim?', {'label': label, 'n': n, 'unit': unit, 'cost': cost}), style: body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Đồng ý'))),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        final (done, spent) = run(dry: false);
        if (done > 0) _done(tr('{label}: +{done} {unit}, tốn {spent} mảnh.', {'label': label, 'done': done, 'unit': unit, 'spent': spent}));
      },
    );
  }

  /// Khai Quang and Tinh Luyện for each Hoàng Kim piece worn.
  Widget _glowPanel() {
    final worn = h.wornGold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            tr('Khai Quang: chỉ số gốc +4% đến +24% (cấp 1-5). '
            'Tinh Luyện: chạm một dòng phụ để đưa lên mức tối đa ({goldPerfectCost} mảnh).', {'goldPerfectCost': goldPerfectCost}),
            style: small.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        if (worn.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(child: _allButton(tr('Khai Quang tất cả'), tr('cấp Khai Quang'), h.glowAll)),
                const SizedBox(width: 6),
                Expanded(child: _allButton(tr('Tinh Luyện tất cả'), tr('dòng phụ'), h.perfectAll)),
              ],
            ),
          ),
        Expanded(
          child: worn.isEmpty
              ? Center(child: Text(tr('Hãy mặc đồ Hoàng Kim để Khai Quang.'), style: body))
              : ListView(children: [for (final it in worn) _glowRow(it)]),
        ),
        if (_msg != null) Text(_msg!, style: small.copyWith(color: cream), maxLines: 2),
      ],
    );
  }

  Widget _glowRow(Item it) {
    final block = h.glowBlock(it);
    final maxed = it.glow >= maxGlow;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${tr(it.title)} · Khai Quang ${it.glow}/$maxGlow',
                    style: bold.copyWith(fontSize: 12.5, color: _gold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              LButton(
                label: maxed ? tr('Tối đa') : 'Khai Quang · ${goldGlowCost[it.glow]}',
                small: true,
                color: const Color(0xFF8A6A1A),
                enabled: block == null,
                onTap: () {
                  if (h.glowUp(it)) {
                    _done(tr('{itName} Khai Quang {glow}: chỉ số gốc +{p0}%.', {'itName': tr(it.name), 'glow': it.glow, 'p0': (glowPct(it.glow) * 100).round()}));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final e in it.bonus.entries) _lineChip(it, e.key, e.value)],
          ),
        ],
      ),
    );
  }

  Widget _lineChip(Item it, Stat s, double v) {
    final best = maxRollStat(s, it.level);
    final full = v >= best;
    return GestureDetector(
      onTap: full
          ? null
          : () {
              if (h.perfectLine(it, s)) {
                _done(tr('Tinh Luyện {sLabel}: {p0}.', {'sLabel': tr(s.label), 'p0': s.format(best)}));
              } else {
                setState(() => _msg = tr('Cần {goldPerfectCost} Mảnh Hoàng Kim.', {'goldPerfectCost': goldPerfectCost}));
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: full ? Colors.transparent : const Color(0xFF3A2A10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: full ? jade : _gold.withValues(alpha: 0.6)),
        ),
        child: Text(
          full ? '${tr(s.label)} ${s.format(v)} ✓' : '${tr(s.label)} ${s.format(v)} → ${s.format(best)}',
          style: small.copyWith(fontSize: 11, color: full ? const Color(0xFF8CE07A) : cream),
        ),
      ),
    );
  }

  /// Hoàng Kim Các: shards for what is short, a few of each a week.
  Widget _shopPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Đổi Mảnh Hoàng Kim, giới hạn mỗi tuần (làm mới thứ Hai).'), style: small.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [
              for (final w in goldWares)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(tr('{wName} · còn {p0}/{perWeek} tuần này', {'wName': tr(w.name), 'p0': h.hkLeft(w), 'perWeek': w.perWeek}),
                            style: bold.copyWith(fontSize: 12.5)),
                      ),
                      LButton(
                        label: tr('{price} mảnh', {'price': w.price}),
                        small: true,
                        color: const Color(0xFF8A6A1A),
                        enabled: h.hkLeft(w) > 0 && h.goldShards >= w.price,
                        onTap: () {
                          final line = h.buyGoldWare(w, _rng);
                          if (line != null) _done(tr('Đã đổi: {line}', {'line': line}));
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_msg != null) Text(_msg!, style: small.copyWith(color: cream), maxLines: 2),
      ],
    );
  }

  Widget _locked() => Center(
        child: Text(tr('Trang bị Hoàng Kim mở ở cấp {goldOpenLevel} (hoặc sau khi chuyển sinh).', {'goldOpenLevel': goldOpenLevel}),
            style: body, textAlign: TextAlign.center),
      );

  Widget _setRow(GoldSetDef s, int worn) {
    final on = s == _set;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          _set = s;
          _msg = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: on ? seal.withValues(alpha: 0.55) : lacquerDeep.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? _gold : gold.withValues(alpha: 0.4), width: on ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: hanhColor(s.hanh), shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(tr(s.name),
                    style: bold.copyWith(fontSize: 13, color: on ? _gold : cream),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$worn/7', style: small.copyWith(color: worn > 0 ? _gold : creamDim)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _forgePanel(int worn) {
    final s = _set;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Bộ {sName}', {'sName': tr(s.name)}), style: titleStyle(16, color: _gold)),
        const SizedBox(height: 4),
        for (final mark in goldSetMarks)
          Text(
            tr('{mark} món: {p0}'
            '{p1}', {'mark': mark, 'p0': bonusText(s.bonusAt(mark)), 'p1': mark == 7 ? tr(' · đòn đánh thường có {p0}% tung {burst} '
                '({p1}% công lực, hành {hanhLabel})', {'p0': (goldBurstChance * 100).round(), 'burst': s.burst, 'p1': (goldBurstPower * 100).round(), 'hanhLabel': tr(s.hanh.label)}) : ''}),
            style: small.copyWith(fontSize: 11.5, color: worn >= mark ? _gold : creamDim),
          ),
        const SizedBox(height: 8),
        Text(tr('Đúc món mới ở cấp {level} (Truyền thuyết, 3 lỗ khảm, chỉ số gốc cao hơn):', {'level': h.level}),
            style: small.copyWith(color: cream)),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.3,
            children: [for (final slot in Slot.values) _slotButton(slot)],
          ),
        ),
        Text(
          _msg ??
              tr('Mảnh Hoàng Kim: mốc sát thương Boss Thế Giới, tháp tầng 40 trở lên, '
                  'rương Năng động tuần, thưởng mùa Lôi đài, boss và tinh anh cấp {bossShardLevel}+.', {'bossShardLevel': bossShardLevel}),
          style: small.copyWith(fontSize: 11, color: _msg == null ? creamDim : cream),
        ),
      ],
    );
  }

  Widget _slotButton(Slot slot) {
    final cost = goldPieceCost(slot);
    final worn = h.equip[slot]?.set == _set.id;
    return LButton(
      label: '${tr(slot.label)}${worn ? ' ✓' : ''} · $cost',
      small: true,
      color: const Color(0xFF8A6A1A),
      enabled: h.goldShards >= cost,
      onTap: () => _forge(slot),
    );
  }
}
