import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/week_goals.dart';
import '../core/world_boss.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';

/// Mục tiêu 7 ngày: a tab per day, its three goals, and the chest for all.
Future<void> showWeekGoalsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _WeekGoalsDialog());
}

class _WeekGoalsDialog extends StatefulWidget {
  const _WeekGoalsDialog();

  @override
  State<_WeekGoalsDialog> createState() => _WeekGoalsDialogState();
}

class _WeekGoalsDialogState extends State<_WeekGoalsDialog> {
  final _rng = math.Random();
  late int _tab;
  List<String>? _got;

  String get _today => vnDayKey();

  @override
  void initState() {
    super.initState();
    final h = SaveService.instance.hero;
    final open = math.min(7, weekGoalDay(h, _today));
    // The first day with something to take, else the newest open day.
    _tab = [for (var d = 1; d <= open; d++) d]
        .firstWhere((d) => weekGoals.any((g) => g.day == d && h.canClaimWeekGoal(g, _today)), orElse: () => math.max(1, open));
  }

  void _show(List<String> lines) {
    if (lines.isEmpty) return;
    SaveService.instance.hero.notices.clear();
    SaveService.instance.save();
    setState(() => _got = lines);
  }

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final open = weekGoalDay(h, _today);
    final done = h.weekClaimed.length;
    return AlertDialog(
      backgroundColor: lacquer,
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      title: Text('Mục tiêu 7 ngày', style: titleStyle(20)),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mỗi ngày mở thêm 3 mục tiêu, làm lúc nào cũng được. Xong cả 21 mục nhận Rương 7 ngày.',
                style: small.copyWith(fontSize: 11.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var d = 1; d <= 7; d++) ...[
                  if (d > 1) const SizedBox(width: 5),
                  Expanded(child: _dayTab(d, open)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_tab > open)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Mở vào ngày $_tab.', style: body, textAlign: TextAlign.center),
              )
            else
              for (final g in weekGoals.where((g) => g.day == _tab)) _goal(g),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2, color: goldLight, size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rương 7 ngày ($done/${weekGoals.length}): ${fmt(weekChestGold)} lượng, '
                    '$weekChestGems ngọc bậc $weekChestGemTier, $weekChestPills Tẩy Tủy Đan, $weekChestIron Thần Thiết',
                    style: small.copyWith(fontSize: 11.5, color: cream),
                  ),
                ),
                LButton(
                  label: h.weekChest ? 'Đã nhận' : 'Mở rương',
                  small: true,
                  color: jade,
                  enabled: h.canClaimWeekChest(_today),
                  onTap: () {
                    final lines = h.claimWeekChest(_today, _rng);
                    if (lines.isNotEmpty) Analytics.instance.log('week_chest');
                    _show(lines);
                  },
                ),
              ],
            ),
            if (_got != null) ...[
              const SizedBox(height: 8),
              Text('Đã nhận: ${_got!.join(', ')}', style: body.copyWith(fontSize: 12.5, color: const Color(0xFF8CE07A))),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
    );
  }

  Widget _dayTab(int d, int open) {
    final h = SaveService.instance.hero;
    final goals = weekGoals.where((g) => g.day == d);
    final ready = d <= open && goals.any((g) => h.canClaimWeekGoal(g, _today));
    final allDone = goals.every((g) => h.weekClaimed.contains(g.id));
    final selected = d == _tab;
    final c = d > open ? creamDim : (allDone ? jade : goldLight);
    return GestureDetector(
      onTap: () => setState(() => _tab = d),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? lacquerLight : lacquerDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? goldLight : gold.withValues(alpha: 0.4), width: selected ? 2 : 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (d > open) Icon(Icons.lock, size: 12, color: c),
                if (allDone) Icon(Icons.check_circle, size: 13, color: c),
                const SizedBox(width: 2),
                Text('Ngày $d', style: bold.copyWith(fontSize: 12, color: c)),
              ],
            ),
            if (ready)
              const Positioned(
                top: 3,
                right: 3,
                child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF5A4A)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _goal(WeekGoal g) {
    final h = SaveService.instance.hero;
    final taken = h.weekClaimed.contains(g.id);
    final p = math.min(g.progress(h), g.goal);
    final reward = [
      '${fmt(g.gold)} lượng',
      if (g.pots > 0) '${g.pots} bình máu + nội lực',
      if (g.gems > 0) '${g.gems} ngọc bậc ${g.gemTier}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: taken ? jade : gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: bold.copyWith(fontSize: 13, color: goldLight)),
                Text(reward, style: small.copyWith(fontSize: 11, color: cream)),
                const SizedBox(height: 3),
                Bar(value: p / g.goal, color: jade, height: 9, label: '${fmt(p)}/${fmt(g.goal)}'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (taken)
            const Icon(Icons.check_circle, color: Color(0xFF8CE07A))
          else
            LButton(
              label: 'Nhận',
              small: true,
              color: jade,
              enabled: h.canClaimWeekGoal(g, _today),
              onTap: () {
                final lines = h.claimWeekGoal(g, _today, _rng);
                if (lines.isNotEmpty) Analytics.instance.log('week_goal', {'id': g.id});
                _show(lines);
              },
            ),
        ],
      ),
    );
  }
}
