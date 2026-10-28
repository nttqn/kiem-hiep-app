import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/fishing.dart';
import '../core/hero.dart';
import '../services/save.dart';
import 'theme.dart';

/// Ngư phổ: every pond's four fish, the ones caught so far, and the gold
/// for a finished page.
Future<void> showFishBook(BuildContext context, HeroData h) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final caught = fishes.where((f) => (h.fishCaught[f.id] ?? 0) > 0).length;
        return AlertDialog(
          backgroundColor: lacquer,
          title: Text('Ngư phổ · $caught/${fishes.length}', style: titleStyle(18)),
          content: SizedBox(
            width: 640,
            height: 280,
            child: ListView(
              children: [
                Text('Mỗi bãi luyện công có một hồ câu cạnh cổng. Câu đủ 4 loài của một hồ để nhận thưởng.',
                    style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 6),
                for (var i = 0; i < maps.length; i++) _mapRow(h, i, () => setState(() {})),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        );
      },
    ),
  );
}

Widget _mapRow(HeroData h, int i, VoidCallback changed) {
  final m = maps[i];
  final done = h.fishBookDone(m.id);
  final paid = h.fishBooks.contains(m.id);
  return Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(m.name, style: bold.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
        for (final f in fishOfMap(m.id))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: lacquerDeep,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(fishRarityColors[f.rarity.index]).withValues(alpha: 0.6)),
                ),
                child: Text(
                  (h.fishCaught[f.id] ?? 0) > 0 ? '${f.name} ×${h.fishCaught[f.id]}' : '???',
                  style: small.copyWith(fontSize: 10.5, color: Color(fishRarityColors[f.rarity.index])),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        SizedBox(
          width: 92,
          child: paid
              ? Text('Đã nhận', style: small.copyWith(color: const Color(0xFF8CE07A)), textAlign: TextAlign.center)
              : LButton(
                  label: fmt(fishBookGold(i)),
                  small: true,
                  color: jade,
                  enabled: done,
                  onTap: () {
                    if (h.fishBookClaim(m.id) > 0) {
                      SaveService.instance.save();
                      changed();
                    }
                  },
                ),
        ),
      ],
    ),
  );
}
