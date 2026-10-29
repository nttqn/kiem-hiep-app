import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/costumes.dart';
import '../core/mounts.dart';
import '../core/newbie.dart';
import '../core/world_boss.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';

/// Tân thủ thất nhật: the seven gifts, today's to take.
Future<void> showNewbieDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _NewbieDialog());
}

class _NewbieDialog extends StatefulWidget {
  const _NewbieDialog();

  @override
  State<_NewbieDialog> createState() => _NewbieDialogState();
}

class _NewbieDialogState extends State<_NewbieDialog> {
  List<String>? _got;

  void _claim() {
    final h = SaveService.instance.hero;
    final lines = h.claimNewbie(vnDayKey(), math.Random());
    if (lines.isEmpty) return;
    h.notices.clear();
    Analytics.instance.log('newbie_gift', {'day': h.newbieClaimed});
    SaveService.instance.save();
    setState(() => _got = lines);
  }

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final ready = h.newbieReady(vnDayKey());
    return AlertDialog(
      backgroundColor: lacquer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      title: Text('Quà tân thủ 7 ngày', style: titleStyle(20)),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mỗi ngày vào game nhận một phần quà, không cần liên tục. Ngày 7: Thú cưỡi Bạch Mã!',
                style: small.copyWith(fontSize: 11.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < newbieDays; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(child: _day(i, h.newbieClaimed, ready)),
                ],
              ],
            ),
            if (_got != null) ...[
              const SizedBox(height: 8),
              Text('Đã nhận: ${_got!.join(', ')}', style: body.copyWith(fontSize: 12.5, color: const Color(0xFF8CE07A))),
            ],
          ],
        ),
      ),
      actions: [
        if (ready)
          LButton(label: 'Nhận quà ngày ${h.newbieClaimed + 1}', icon: Icons.redeem, small: true, color: jade, onTap: _claim),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }

  Widget _day(int i, int claimed, bool ready) {
    final done = i < claimed;
    final today = i == claimed && ready;
    final g = newbieGifts[i];
    final labels = newbieLabels(
      g,
      costumeName: (id) => costumeById[id]?.name ?? id,
      mountName: (id) => mountById[id]?.name ?? id,
    );
    final c = today ? const Color(0xFF8CE07A) : (done ? creamDim : gold);
    return Container(
      height: 128,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: today ? lacquerLight : lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: today ? 1 : 0.5), width: today ? 2 : 1),
      ),
      child: Column(
        children: [
          Text('Ngày ${i + 1}', style: bold.copyWith(fontSize: 12, color: c)),
          const SizedBox(height: 3),
          Icon(
            done
                ? Icons.check_circle
                : g.mount.isNotEmpty
                    ? Icons.pets
                    : g.costume.isNotEmpty
                        ? Icons.checkroom
                        : Icons.card_giftcard,
            color: c,
            size: 24,
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(labels.join('\n'),
                textAlign: TextAlign.center,
                style: small.copyWith(fontSize: 9.5, color: done ? creamDim : cream),
                overflow: TextOverflow.fade),
          ),
        ],
      ),
    );
  }
}
