import 'dart:math' as math;

import 'package:flutter/material.dart';

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
            child: h.goldOpen ? _forgePanel(pieces[_set.id] ?? 0) : _locked(),
          ),
        ),
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
        Row(
          children: [
            Expanded(child: Text('Bộ ${s.name}', style: titleStyle(18, color: _gold))),
            const Icon(Icons.auto_awesome, color: _gold, size: 18),
            const SizedBox(width: 4),
            Text('${h.goldShards} Mảnh Hoàng Kim', style: bold.copyWith(color: _gold)),
          ],
        ),
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
