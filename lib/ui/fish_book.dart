import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/fishing.dart';
import '../core/hero.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

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
          title: Text(tr('Ngư phổ · {caught}/{fishesLength}', {'caught': caught, 'fishesLength': fishes.length}), style: titleStyle(18)),
          content: SizedBox(
            width: 640,
            height: 280,
            child: ListView(
              children: [
                Text(tr('Mỗi bãi luyện công có một hồ câu cạnh cổng. Câu đủ 4 loài của một hồ để nhận thưởng và {fishBookCoins} Ngư tệ.', {'fishBookCoins': fishBookCoins}),
                    style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 6),
                for (final m in pondMaps) _mapRow(h, m, () => setState(() {})),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
        );
      },
    ),
  );
}

Widget _mapRow(HeroData h, MapDef m, VoidCallback changed) {
  final done = h.fishBookDone(m.id);
  final paid = h.fishBooks.contains(m.id);
  return Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(tr(m.name), style: bold.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
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
                child: Row(
                  children: [
                    // Not caught yet: a dark shadow of the fish.
                    (h.fishCaught[f.id] ?? 0) > 0
                        ? ArtIcon('fish_${f.id}', fallback: Icons.set_meal, size: 26)
                        : ColorFiltered(
                            colorFilter: const ColorFilter.mode(Color(0xFF0E0806), BlendMode.srcATop),
                            child: ArtIcon('fish_${f.id}', fallback: Icons.set_meal, size: 26, color: creamDim),
                          ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (h.fishCaught[f.id] ?? 0) > 0 ? tr('{fName} ×{p0}', {'fName': tr(f.name), 'p0': h.fishCaught[f.id]}) : '???',
                            style: small.copyWith(fontSize: 10.5, color: Color(fishRarityColors[f.rarity.index])),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 1.26: the heaviest one caught.
                          if ((h.fishBest[f.id] ?? 0) > 0)
                            Text(tr('Kỷ lục {w}', {'w': fishWeightText(h.fishBest[f.id]!)}),
                                style: small.copyWith(fontSize: 9.5, color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          width: 92,
          child: paid
              ? Text(tr('Đã nhận'), style: small.copyWith(color: const Color(0xFF8CE07A)), textAlign: TextAlign.center)
              : LButton(
                  label: fmt(fishBookGold(pondTier(m.id))),
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
