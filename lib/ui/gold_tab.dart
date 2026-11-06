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
      setState(() => _msg = h.bag.length >= bagSize ? 'Hành trang đã đầy.' : 'Không đủ Mảnh Hoàng Kim.');
      return;
    }
    Analytics.instance.log('gold_forge', {'set': _set.id, 'slot': s.index});
    SaveService.instance.save();
    setState(() => _msg = 'Đã đúc ${it.name} (cấp ${it.level}), xem trong Hành trang.');
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
            onTap: () => setState(() {
              _mode = i;
              _msg = null;
            }),
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
            chip(0, 'Đúc'),
            chip(1, 'Khai Quang'),
            chip(2, 'Hoàng Kim Các'),
            const Spacer(),
            const Icon(Icons.auto_awesome, color: _gold, size: 16),
            const SizedBox(width: 3),
            Flexible(
              child: Text('${h.goldShards} mảnh',
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

  /// Khai Quang and Tinh Luyện for each Hoàng Kim piece worn.
  Widget _glowPanel() {
    final worn = [for (final s in Slot.values) if (h.equip[s]?.golden ?? false) h.equip[s]!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'Khai Quang: chỉ số gốc +4% đến +24% (cấp 1-5). '
            'Tinh Luyện: chạm một dòng phụ để đưa lên mức tối đa ($goldPerfectCost mảnh).',
            style: small.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Expanded(
          child: worn.isEmpty
              ? Center(child: Text('Hãy mặc đồ Hoàng Kim để Khai Quang.', style: body))
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
                child: Text('${it.title} · Khai Quang ${it.glow}/$maxGlow',
                    style: bold.copyWith(fontSize: 12.5, color: _gold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              LButton(
                label: maxed ? 'Tối đa' : 'Khai Quang · ${goldGlowCost[it.glow]}',
                small: true,
                color: const Color(0xFF8A6A1A),
                enabled: block == null,
                onTap: () {
                  if (h.glowUp(it)) {
                    _done('${it.name} Khai Quang ${it.glow}: chỉ số gốc +${(glowPct(it.glow) * 100).round()}%.');
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
                _done('Tinh Luyện ${s.label}: ${s.format(best)}.');
              } else {
                setState(() => _msg = 'Cần $goldPerfectCost Mảnh Hoàng Kim.');
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
          full ? '${s.label} ${s.format(v)} ✓' : '${s.label} ${s.format(v)} → ${s.format(best)}',
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
        Text('Đổi Mảnh Hoàng Kim, giới hạn mỗi tuần (làm mới thứ Hai).', style: small.copyWith(fontSize: 11)),
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
                        child: Text('${w.name} · còn ${h.hkLeft(w)}/${w.perWeek} tuần này',
                            style: bold.copyWith(fontSize: 12.5)),
                      ),
                      LButton(
                        label: '${w.price} mảnh',
                        small: true,
                        color: const Color(0xFF8A6A1A),
                        enabled: h.hkLeft(w) > 0 && h.goldShards >= w.price,
                        onTap: () {
                          final line = h.buyGoldWare(w, _rng);
                          if (line != null) _done('Đã đổi: $line');
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
        child: Text('Trang bị Hoàng Kim mở ở cấp $goldOpenLevel (hoặc sau khi chuyển sinh).',
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
                child: Text(s.name,
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
        Text('Bộ ${s.name}', style: titleStyle(16, color: _gold)),
        const SizedBox(height: 4),
        for (final mark in goldSetMarks)
          Text(
            '$mark món: ${bonusText(s.bonusAt(mark))}'
            '${mark == 7 ? ' · đòn đánh thường có ${(goldBurstChance * 100).round()}% tung ${s.burst} '
                '(${(goldBurstPower * 100).round()}% công lực, hành ${s.hanh.label})' : ''}',
            style: small.copyWith(fontSize: 11.5, color: worn >= mark ? _gold : creamDim),
          ),
        const SizedBox(height: 8),
        Text('Đúc món mới ở cấp ${h.level} (Truyền thuyết, 3 lỗ khảm, chỉ số gốc cao hơn):',
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
              'Mảnh Hoàng Kim: mốc sát thương Boss Thế Giới, tháp tầng 40 trở lên, '
                  'rương Năng động tuần, thưởng mùa Lôi đài, boss và tinh anh cấp $bossShardLevel+.',
          style: small.copyWith(fontSize: 11, color: _msg == null ? creamDim : cream),
        ),
      ],
    );
  }

  Widget _slotButton(Slot slot) {
    final cost = goldPieceCost(slot);
    final worn = h.equip[slot]?.set == _set.id;
    return LButton(
      label: '${slot.label}${worn ? ' ✓' : ''} · $cost',
      small: true,
      color: const Color(0xFF8A6A1A),
      enabled: h.goldShards >= cost,
      onTap: () => _forge(slot),
    );
  }
}
