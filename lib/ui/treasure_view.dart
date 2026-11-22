import 'package:flutter/material.dart';

import '../core/gems.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../core/treasure.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'gem_tab.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Kỳ Trân Các: the day's six rare wares, a paid refresh, and one free
/// refresh a day for a rewarded ad.
class TreasureView extends StatefulWidget {
  const TreasureView({super.key});

  @override
  State<TreasureView> createState() => _TreasureViewState();
}

class _TreasureViewState extends State<TreasureView> {
  HeroData get h => SaveService.instance.hero;
  String get _day => vnDayKey();
  String? _msg;

  void _done(String msg) {
    SaveService.instance.save();
    setState(() => _msg = msg);
  }

  @override
  Widget build(BuildContext context) {
    final offers = h.treasureOffers(_day);
    final cost = treasureRefreshCost(h.shopRefresh);
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Kỳ Trân Các'), style: titleStyle(20)),
                    Text(tr('Hàng quý đổi mỗi ngày: ngọc Ngũ Hành và trang bị Sử thi, Truyền thuyết theo cấp của bạn.'),
                        style: small.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              if (h.shopRefresh == 0)
                ValueListenableBuilder<bool>(
                  valueListenable: AdsService.instance.rewardedReady,
                  builder: (_, ready, _) => LButton(
                    label: tr('Làm mới miễn phí'),
                    icon: Icons.ondemand_video,
                    small: true,
                    color: const Color(0xFF8A5A10),
                    enabled: ready,
                    onTap: () async {
                      final earned = await AdsService.instance.showRewarded();
                      if (!earned || !mounted) return;
                      h.treasureRefresh(_day, free: true);
                      _done(tr('Đã làm mới hàng.'));
                    },
                  ),
                ),
              const SizedBox(width: 6),
              LButton(
                label: tr('Làm mới {p0}', {'p0': fmt(cost)}),
                small: true,
                enabled: h.gold >= cost,
                onTap: () {
                  if (h.treasureRefresh(_day)) _done(tr('Đã làm mới hàng (-{p0} lượng).', {'p0': fmt(cost)}));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 112,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: offers.length,
              itemBuilder: (_, i) => _offer(i, offers[i]),
            ),
          ),
          if (h.soulPills > 0 || h.condensesSoul) _soulRow(),
          if (_msg != null) Text(_msg!, style: small.copyWith(color: cream)),
        ],
      ),
    );
  }

  /// Linh Phách Đơn on hand, and trading some for Thần Thiết.
  Widget _soulRow() => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.blur_circular, color: Color(0xFF6FC8E8), size: 26),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                h.nextRebirthPills > 0
                    ? tr('Linh Phách Đơn: {soulPills}/{nextRebirthPills} viên cần cho Chuyển sinh {p0}. Đổi ra Thần Thiết sẽ phải tích lại.', {'soulPills': h.soulPills, 'nextRebirthPills': h.nextRebirthPills, 'p0': h.rebirths + 1})
                    : tr('Linh Phách Đơn: {soulPills} viên, ngưng tụ từ EXP dư ở cấp {maxLevel}.', {'soulPills': h.soulPills, 'maxLevel': maxLevel}),
                style: small.copyWith(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            LButton(
              label: tr('{soulPillsPerIron} viên → 1 Thần Thiết', {'soulPillsPerIron': soulPillsPerIron}),
              small: true,
              color: const Color(0xFF2F6E8A),
              enabled: h.soulPills >= soulPillsPerIron,
              onTap: () {
                if (!h.soulToIron()) return;
                Analytics.instance.log('soul_to_iron', {'left': h.soulPills});
                _done(tr('Đã đổi {soulPillsPerIron} Linh Phách Đơn lấy 1 Thần Thiết.', {'soulPillsPerIron': soulPillsPerIron}));
              },
            ),
          ],
        ),
      );

  Widget _offer(int i, TreasureOffer o) {
    final bought = h.shopBought.contains(i);
    final it = o.item;
    final g = o.gem;
    final name = tr(g?.name ?? it!.name);
    final color = g != null ? hanhColor(g.hanh) : rarityColor(it!.rarity);
    final desc = g != null
        ? gemEffectText(g, banMenh: g.hanh == h.hanh)
        : tr('{rarityLabel} · cấp {level} · {bonusLength} dòng phụ', {'rarityLabel': tr(it!.rarity.label), 'level': it.level, 'bonusLength': it.bonus.length});
    return Opacity(
      opacity: bought ? 0.5 : 1,
      child: Panel(
        padding: const EdgeInsets.all(8),
        border: color,
        child: Row(
          children: [
            g != null ? GemIcon(gem: g, size: 46) : ItemTile(item: it, size: 46),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: bold.copyWith(fontSize: 13, color: color), overflow: TextOverflow.ellipsis),
                  Text(desc, style: small.copyWith(fontSize: 10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  bought
                      ? Text(tr('Đã mua'), style: bold.copyWith(fontSize: 12, color: creamDim))
                      : LButton(
                          label: fmt(o.price),
                          small: true,
                          color: jade,
                          enabled: h.gold >= o.price,
                          onTap: () {
                            if (h.treasureBuy(_day, i)) {
                              Analytics.instance.log('treasure_buy', {'kind': g != null ? 'gem' : 'gear', 'price': o.price});
                              _done(tr('Đã mua {name}.', {'name': name}));
                            } else {
                              setState(() => _msg = it != null && h.bag.length >= bagSize
                                  ? tr('Hành trang đã đầy.')
                                  : tr('Không đủ lượng.'));
                            }
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
