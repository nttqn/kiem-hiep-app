import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fishing.dart';
import '../core/hero.dart';
import '../core/i18n.dart';
import '../core/manuals.dart';
import '../core/weekly_hunt.dart';
import '../core/world_boss.dart';
import '../services/save.dart';
import 'theme.dart';

/// Ngư phủ (1.26): Ngư tệ from every catch, a finished Ngư phổ page and the
/// Câu cá tuần board buy what the late game needs, a few of each a week.
Future<void> showFishShop(BuildContext context, HeroData h) {
  final rng = math.Random();
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final day = vnDayKey();
        h.fishRollWeek(day);
        return AlertDialog(
          backgroundColor: lacquer,
          title: Row(
            children: [
              Expanded(child: Text(tr('Ngư phủ'), style: titleStyle(20))),
              Text(tr('Ngư tệ: {p0}', {'p0': fmt(h.fishCoins)}), style: bold.copyWith(color: goldLight)),
            ],
          ),
          content: SizedBox(
            width: 560,
            height: 260,
            child: ListView(
              children: [
                Text(
                    tr('Câu cá được Ngư tệ (cá càng quý càng nhiều), đủ một trang Ngư phổ được {fishBookCoins}. '
                        'Hàng đổi mới mỗi thứ Hai. Điểm Câu cá tuần này: {pts}.', {'fishBookCoins': fishBookCoins, 'pts': fmt(h.fishPts)}),
                    style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 6),
                for (final o in fishShop(h.level)) _row(ctx, h, o, day, rng, () => setState(() {})),
                const SizedBox(height: 4),
                Text(tr('Còn {p0} ngày đến lượt đổi hàng mới.', {'p0': huntDaysLeft(day)}), style: small.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
        );
      },
    ),
  );
}

Widget _row(BuildContext ctx, HeroData h, FishOffer o, String day, math.Random rng, VoidCallback changed) {
  final left = h.fishOfferLeft(o, day);
  final locked = o.kind == FishWare.page && !h.manualOpen;
  return Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
    decoration: BoxDecoration(
      color: lacquerDeep,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: gold.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(tr(o.name), style: bold.copyWith(fontSize: 12.5))),
        Text(locked ? tr('Mở ở cấp {lv}', {'lv': manualOpenLevel}) : tr('Còn {left}/{perWeek} tuần này', {'left': left, 'perWeek': o.perWeek}),
            style: small.copyWith(fontSize: 10.5)),
        const SizedBox(width: 8),
        LButton(
          label: tr('{price} Ngư tệ', {'price': o.price}),
          small: true,
          color: jade,
          enabled: !locked && left > 0 && h.fishCoins >= o.price,
          onTap: () {
            final got = h.fishBuy(o, day, rng);
            if (got == null) return;
            SaveService.instance.save();
            changed();
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(tr('Đã đổi: {got}', {'got': got})), duration: const Duration(seconds: 2)));
          },
        ),
      ],
    ),
  );
}
