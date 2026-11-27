import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/costumes.dart';
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
                _rodRow(ctx, h, () => setState(() {})),
                _shrimpRow(ctx, h, () => setState(() {})),
                for (final o in fishShop(h.level)) _row(ctx, h, o, day, rng, () => setState(() {})),
                _costumeRow(ctx, h, () => setState(() {})),
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

void _toast(BuildContext ctx, String text) => ScaffoldMessenger.of(ctx)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

Widget _box({required Widget title, required Widget note, required Widget button}) => Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(child: title),
          note,
          const SizedBox(width: 8),
          button,
        ],
      ),
    );

/// 1.26.0: the rod, raised a level at a time with gold and Ngư tệ.
Widget _rodRow(BuildContext ctx, HeroData h, VoidCallback changed) {
  final next = h.fishRodNext;
  final block = h.fishRodBlock();
  return _box(
    title: Text.rich(TextSpan(children: [
      TextSpan(text: tr(fishRods[h.fishRod].name), style: bold.copyWith(fontSize: 12.5, color: goldLight)),
      TextSpan(
          text: next == null
              ? tr('  (tối đa)')
              : tr('  · Lên {next}: vạch xanh rộng hơn, kim chậm hơn, cá nặng hơn', {'next': tr(next.name)}),
          style: small.copyWith(fontSize: 10.5)),
    ])),
    note: Text(
        next == null
            ? ''
            : block == tr('Cần cấp {lv}', {'lv': next.level})
                ? block!
                : tr('{gold} lượng', {'gold': fmt(next.gold)}),
        style: small.copyWith(fontSize: 10.5)),
    button: LButton(
      label: next == null ? tr('Tối đa') : tr('Nâng · {coins} Ngư tệ', {'coins': next.coins}),
      small: true,
      color: jade,
      enabled: block == null,
      onTap: () {
        if (!h.fishRodUp()) return;
        SaveService.instance.save();
        changed();
        _toast(ctx, tr('Đã có {rod}', {'rod': tr(fishRods[h.fishRod].name)}));
      },
    ),
  );
}

/// Mồi Tôm for gold, any number.
Widget _shrimpRow(BuildContext ctx, HeroData h, VoidCallback changed) {
  final p = fishShrimpPrice(h.level);
  return _box(
    title: Text(tr('Mồi Tôm ×{n}', {'n': fishShrimpPack}), style: bold.copyWith(fontSize: 12.5)),
    note: Text(tr('Đang có {n}', {'n': h.fishLures['tom'] ?? 0}), style: small.copyWith(fontSize: 10.5)),
    button: LButton(
      label: tr('{p0} lượng', {'p0': fmt(p)}),
      small: true,
      color: jade,
      enabled: h.gold >= p,
      onTap: () {
        if (!h.fishBuyShrimp()) return;
        SaveService.instance.save();
        changed();
        _toast(ctx, tr('+{n} Mồi Tôm', {'n': fishShrimpPack}));
      },
    ),
  );
}

/// The Ngư phủ outfit, once.
Widget _costumeRow(BuildContext ctx, HeroData h, VoidCallback changed) {
  final c = costumeById[fishCostumeShop]!;
  final owned = h.ownedCostumes.contains(c.id);
  return _box(
    title: Text(tr('Ngoại trang « {c} »', {'c': tr(c.name)}), style: bold.copyWith(fontSize: 12.5, color: const Color(0xFF8AD8E8))),
    note: Text(owned ? tr('Đã có') : '', style: small.copyWith(fontSize: 10.5)),
    button: LButton(
      label: tr('{price} Ngư tệ', {'price': fishCostumePrice}),
      small: true,
      color: jade,
      enabled: !owned && h.fishCoins >= fishCostumePrice,
      onTap: () {
        if (!h.fishBuyCostume()) return;
        SaveService.instance.save();
        changed();
        _toast(ctx, tr('Mở khóa ngoại trang: {cName}', {'cName': tr(c.name)}));
      },
    ),
  );
}
