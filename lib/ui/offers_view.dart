import 'package:flutter/material.dart';

import '../core/costumes.dart';
import '../core/hero.dart';
import '../core/premium.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../services/purchase.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Cửa hàng tab "Ưu đãi" (1.7.0): Nguyệt thẻ, Gói tân thủ, Gói bỏ quảng
/// cáo and the daily Rương quảng cáo.
class OffersView extends StatefulWidget {
  const OffersView({super.key});

  @override
  State<OffersView> createState() => _OffersViewState();
}

class _OffersViewState extends State<OffersView> {
  HeroData get h => SaveService.instance.hero;
  final _iap = PurchaseService.instance;

  @override
  void initState() {
    super.initState();
    _iap.changed.addListener(_refresh);
    _iap.message.addListener(_tell);
    AdsService.instance.adFree.addListener(_refresh);
  }

  @override
  void dispose() {
    _iap.changed.removeListener(_refresh);
    _iap.message.removeListener(_tell);
    AdsService.instance.adFree.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tell() {
    final m = _iap.message.value;
    if (m == null || !mounted) return;
    _iap.message.value = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 4)));
  }

  void _say(String title, List<String> lines) {
    if (lines.isEmpty) return;
    SaveService.instance.save();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(title, style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines) Text('• $l', style: body)],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Nhận')))],
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = (c.maxWidth / 4).clamp(190.0, 260.0);
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final card in [_firstPay(), _monthCard(), _goldPack(), _starPack(), _starter(), _noAds(), _adChest()]) SizedBox(width: w, child: card),
          ],
        );
      },
    );
  }

  Widget _box({required String title, required Color color, required IconData icon, required List<Widget> children}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Panel(
          border: color,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 6),
                  Expanded(child: Text(title, style: titleStyle(17, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );

  Widget _line(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('• $s', style: small.copyWith(fontSize: 11.5, color: cream)),
      );

  Widget _buy(String sku, {bool enabled = true, String? done}) {
    final price = _iap.priceOf(sku);
    return ValueListenableBuilder<bool>(
      valueListenable: _iap.busy,
      builder: (_, busy, _) => LButton(
        label: done ?? (price == null ? tr('Chưa mở bán') : tr('Mua {price}', {'price': price})),
        icon: done == null ? Icons.shopping_bag : Icons.check,
        small: true,
        color: const Color(0xFF8A2A1A),
        enabled: enabled && done == null && price != null && !busy,
        onTap: () => _iap.buy(sku),
      ),
    );
  }

  Widget _monthCard() {
    final today = vnDayKey();
    final r = cardDailyFor(h.level, h.rebirths);
    final active = h.cardActive(today);
    return _box(
      title: tr('Nguyệt thẻ'),
      color: goldLight,
      icon: Icons.calendar_month,
      children: [
        Text(tr('{monthCardDays} ngày cho {hName}. Mỗi ngày nhận:', {'monthCardDays': monthCardDays, 'hName': h.name}), style: small.copyWith(fontSize: 11.5)),
        const SizedBox(height: 4),
        _line(tr('{p0} lượng', {'p0': fmt(r.gold)})),
        _line(tr('{gems} ngọc bậc {gemTier}', {'gems': r.gems, 'gemTier': r.gemTier})),
        if (r.iron > 0) _line(tr('{iron} Thần Thiết', {'iron': r.iron})),
        _line(tr('+{monthCardExtraRuns} lượt Bí cảnh, +{monthCardExtraRuns} lượt Boss Thế Giới', {'monthCardExtraRuns': monthCardExtraRuns})),
        const Spacer(),
        if (active)
          Text(tr('Còn {p0} ngày', {'p0': h.cardDaysLeft(today)}), style: bold.copyWith(color: jade), textAlign: TextAlign.center),
        if (active) ...[
          const SizedBox(height: 4),
          LButton(
            label: h.canClaimCard(today) ? tr('Nhận quà hôm nay') : tr('Đã nhận hôm nay'),
            small: true,
            color: jade,
            enabled: h.canClaimCard(today),
            onTap: () {
              Analytics.instance.log('card_claim');
              _say(tr('Nguyệt thẻ'), h.claimCard(today));
            },
          ),
          const SizedBox(height: 4),
        ],
        _buy(skuMonthCard),
        if (active) Text(tr('Mua thêm để gia hạn {monthCardDays} ngày.', {'monthCardDays': monthCardDays}), style: small.copyWith(fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  /// Quà nạp đầu (1.16.0): a gift for the first purchase of any kind.
  Widget _firstPay() {
    final adFree = AdsService.instance.adFree.value;
    final ready = h.firstPayReady(adFree);
    final costume = costumeById[firstPayCostume]!;
    return _box(
      title: tr('Quà nạp đầu'),
      color: const Color(0xFFFFB04A),
      icon: Icons.redeem,
      children: [
        // The list scrolls and the button stays put on short phones.
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(tr('Mua bất kỳ gói nào cho {hName}, nhận thêm:', {'hName': h.name}), style: small.copyWith(fontSize: 11.5)),
              const SizedBox(height: 4),
              _line(tr('Ngoại trang {costumeName}', {'costumeName': tr(costume.name)})),
              _line(tr('Danh hiệu « {firstPayTitle} »', {'firstPayTitle': firstPayTitle})),
              _line(tr('{p0} lượng', {'p0': fmt(firstPayGold(h.level, h.rebirths))})),
              _line(tr('{firstPayIron} Thần Thiết, {firstPayPills} Linh Phách Đơn', {'firstPayIron': firstPayIron, 'firstPayPills': firstPayPills})),
              _line(tr('{firstPayShards} mảnh Hoàng Kim, {firstPayGems} ngọc bậc {p0}', {'firstPayShards': firstPayShards, 'firstPayGems': firstPayGems, 'p0': firstPayGemTier(h.level)})),
              _line(tr('{firstPayHpPots} Kim Sang Dược', {'firstPayHpPots': firstPayHpPots})),
            ],
          ),
        ),
        const SizedBox(height: 4),
        LButton(
          label: h.firstPayTaken ? tr('Đã nhận') : ready ? tr('Nhận quà') : tr('Chưa mua gói nào'),
          icon: h.firstPayTaken ? Icons.check : Icons.redeem,
          small: true,
          color: jade,
          enabled: ready,
          onTap: () {
            Analytics.instance.log('first_pay_claim');
            _say(tr('Quà nạp đầu'), h.takeFirstPay(adFree));
          },
        ),
      ],
    );
  }

  Widget _starter() => _box(
        title: tr('Gói tân thủ'),
        color: const Color(0xFF8CE07A),
        icon: Icons.card_giftcard,
        children: [
          Text(tr('Một lần cho mỗi nhân vật:'), style: small.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          _line(tr('Thú cưỡi Bạch Mã')),
          _line(tr('1 trang bị Sử thi theo cấp')),
          _line(tr('{p0} lượng', {'p0': fmt(starterGift.gold)})),
          _line(tr('{hpPots} Kim Sang Dược, {mpPots} Ngưng Thần Đan', {'hpPots': starterGift.hpPots, 'mpPots': starterGift.mpPots})),
          _line(tr('{gems} ngọc bậc {gemTier}', {'gems': starterGift.gems, 'gemTier': starterGift.gemTier})),
          const Spacer(),
          _buy(skuStarter, done: h.starterBought ? tr('Đã mua') : null),
        ],
      );

  /// Hòm Ngân Lượng (1.11.1): gold for this hero, as often as wanted.
  Widget _goldPack() => _box(
        title: tr('Hòm Ngân Lượng'),
        color: const Color(0xFFFFC34A),
        icon: Icons.savings,
        children: [
          Text(tr('Nhận ngay cho {hName}:', {'hName': h.name}), style: small.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          _line(tr('{p0} lượng', {'p0': fmt(goldPackFor(h.level, h.rebirths))})),
          _line(tr('Tăng theo cấp và số lần chuyển sinh')),
          _line(tr('Mua bao nhiêu lần cũng được')),
          const Spacer(),
          _buy(skuGoldPack),
        ],
      );

  /// Gói Thăng Tinh (1.9.0): once a week a hero.
  Widget _starPack() => _box(
        title: tr('Gói Thăng Tinh'),
        color: const Color(0xFFFFD34A),
        icon: Icons.auto_awesome,
        children: [
          Text(tr('Mỗi tuần một lần cho {hName}:', {'hName': h.name}), style: small.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          _line(tr('{starPackStones} Tinh Thạch', {'starPackStones': starPackStones})),
          _line(tr('{starPackSouls} Hung Thú Tinh Phách', {'starPackSouls': starPackSouls})),
          _line(tr('Đủ nâng một món từ ★0 lên ★3, hoặc góp sao 4–5')),
          Wrap(spacing: 8, children: [
            MatCount(Mat.stone, fmt(h.starStones), style: small.copyWith(fontSize: 11, color: cream), size: 16),
            MatCount(Mat.soul, '${h.beastSouls}', style: small.copyWith(fontSize: 11, color: cream), size: 16),
          ]),
          const Spacer(),
          _buy(skuStarPack, done: h.starPackThisWeek ? tr('Đã mua tuần này') : null),
        ],
      );

  Widget _noAds() {
    final owned = AdsService.instance.adFree.value;
    return _box(
      title: tr('Bỏ quảng cáo'),
      color: const Color(0xFF9FD8FF),
      icon: Icons.block,
      children: [
        Text(tr('Cho cả tài khoản cửa hàng, mọi nhân vật:'), style: small.copyWith(fontSize: 11.5)),
        const SizedBox(height: 4),
        _line(tr('Không còn quảng cáo khi về thành hay mở lại game')),
        _line(tr('Mọi phần thưởng "xem quảng cáo" nhận ngay, không phải xem')),
        _line(tr('Mua một lần, cài lại vẫn giữ')),
        const Spacer(),
        _buy(skuNoAds, done: owned ? tr('Đã sở hữu') : null),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _iap.available ? _iap.restore : null,
          child: Text(tr('Khôi phục giao dịch'), style: small.copyWith(fontSize: 11, color: creamDim)),
        ),
      ],
    );
  }

  Widget _adChest() {
    final today = vnDayKey();
    final left = h.adChestsLeft(today);
    final n = adChestMax - left;
    final next = left > 0 ? adChestFor(n, h.level, h.rebirths) : null;
    return _box(
      title: tr('Rương quảng cáo'),
      color: const Color(0xFFE8A84A),
      icon: Icons.inventory_2,
      children: [
        Text(tr('{adChestMax} rương mỗi ngày, rương sau quý hơn rương trước.', {'adChestMax': adChestMax}), style: small.copyWith(fontSize: 11.5)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < adChestMax; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(i < n ? Icons.check_circle : Icons.inventory_2,
                    size: i == adChestMax - 1 ? 26 : 20, color: i < n ? jade : (i == adChestMax - 1 ? goldLight : creamDim)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (next != null) ...[
          Text(tr('Rương {p0}:', {'p0': n + 1}), style: bold.copyWith(fontSize: 12)),
          _line(tr('{p0} lượng', {'p0': fmt(next.gold)})),
          if (next.gems > 0) _line(tr('{gems} ngọc', {'gems': next.gems})),
          if (next.iron > 0) _line(tr('{iron} Thần Thiết', {'iron': next.iron})),
          if (next.shards > 0) _line(tr('{shards} mảnh Hoàng Kim', {'shards': next.shards})),
        ] else
          Text(tr('Đã mở hết hôm nay. Mai quay lại nhé!'), style: small, textAlign: TextAlign.center),
        const Spacer(),
        ValueListenableBuilder<bool>(
          valueListenable: AdsService.instance.rewardedReady,
          builder: (_, ready, _) => LButton(
            label: left <= 0 ? tr('Hết lượt') : (ready ? tr('Xem quảng cáo, mở rương') : tr('Quảng cáo đang tải…')),
            icon: Icons.ondemand_video,
            small: true,
            color: const Color(0xFF8A5A10),
            enabled: left > 0 && ready,
            onTap: () async {
              if (!await AdsService.instance.showRewarded() || !mounted) return;
              Analytics.instance.log('ad_chest', {'n': n + 1});
              _say(tr('Rương quảng cáo {p0}', {'p0': n + 1}), h.openAdChest(vnDayKey()));
            },
          ),
        ),
      ],
    );
  }
}
