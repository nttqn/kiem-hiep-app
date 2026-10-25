import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/bounty.dart';
import '../core/content.dart';
import '../core/hero.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'theme.dart';

/// Bảng Truy Nã: four posted bounties, handed in here once done.
class BountyView extends StatefulWidget {
  const BountyView({super.key});

  @override
  State<BountyView> createState() => _BountyViewState();
}

class _BountyViewState extends State<BountyView> {
  HeroData get h => SaveService.instance.hero;
  final _rng = math.Random();
  String? _msg;

  void _claim(int i) {
    final stars = h.bounties[i].stars;
    final lines = h.claimBounty(i, _rng);
    if (lines == null) return;
    Analytics.instance.log('bounty_claim', {'stars': stars});
    SaveService.instance.save();
    setState(() => _msg = 'Nhận thưởng: ${lines.join(' · ')}');
  }

  void _reroll({bool ad = false}) {
    if (!h.rerollBounties(_rng, ad: ad)) {
      setState(() => _msg = ad ? 'Hết lượt làm mới miễn phí hôm nay.' : 'Không đủ lượng.');
      return;
    }
    SaveService.instance.save();
    setState(() => _msg = 'Đã làm mới các lệnh truy nã chưa xong.');
  }

  Future<void> _go(Bounty b) async {
    final m = mapById[b.map];
    if (m == null) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.field(m)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!h.bountyOpen) {
      return Panel(child: Center(child: Text('Bảng Truy Nã mở ở cấp $bountyMinLevel.', style: titleStyle(18))));
    }
    final cost = bountyRefreshCost(h.level);
    final unfinished = h.bounties.any((b) => !b.done);
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Bảng Truy Nã', style: titleStyle(20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Lệnh mới còn hôm nay: ${h.bountyLeft}/$bountiesPerDay',
                    style: small.copyWith(color: cream)),
              ),
              LButton(
                label: 'Làm mới ${fmt(cost)}',
                icon: Icons.refresh,
                small: true,
                enabled: unfinished && h.gold >= cost,
                onTap: () => _reroll(),
              ),
              const SizedBox(width: 6),
              LButton(
                label: 'Miễn phí (${bountyAdRefreshes - h.bountyAds})',
                icon: Icons.ondemand_video,
                small: true,
                color: jade,
                enabled: unfinished && h.bountyAds < bountyAdRefreshes,
                onTap: () async {
                  final earned = await AdsService.instance.showRewarded();
                  if (earned && mounted) _reroll(ad: true);
                },
              ),
            ],
          ),
          Text(
            _msg ?? 'Tiến độ tự cộng khi bạn luyện công. Lệnh 4-5 sao gọi tinh anh xuất hiện trên bản đồ.',
            style: small.copyWith(fontSize: 11, color: _msg == null ? creamDim : goldLight),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: h.bounties.isEmpty
                ? Center(child: Text('Đã hết lệnh truy nã hôm nay. Quay lại vào ngày mai!', style: body))
                // Two rows of two that always fit the panel.
                : LayoutBuilder(
                    builder: (context, c) => GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: math.max(1.6, ((c.maxWidth - 8) / 2) / math.max(1, (c.maxHeight - 8) / 2)),
                      children: [for (var i = 0; i < h.bounties.length; i++) _card(i)],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(int i) {
    final b = h.bounties[i];
    final extra = [
      if (b.stars == 4) 'trang bị Quý',
      if (b.stars >= 5) 'trang bị Hiếm · ngọc',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: b.done ? Color.lerp(lacquerDeep, jade, 0.25) : lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: b.stars >= 4 ? goldLight : gold.withValues(alpha: 0.4), width: b.stars >= 4 ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('★' * b.stars, style: bold.copyWith(color: const Color(0xFFFFD34A), fontSize: 13)),
              Text('★' * (5 - b.stars), style: bold.copyWith(color: creamDim.withValues(alpha: 0.4), fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(b.mapName, style: small.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(b.goal,
              style: bold.copyWith(fontSize: 13.5, color: b.kind == BountyKind.elite ? goldLight : cream),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (b.count > 1)
            Bar(value: b.progress / b.count, color: jade, height: 10, label: '${b.progress}/${b.count}'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '+${fmt(b.exp)} KN · +${fmt(b.gold)} lượng${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}',
                  style: small.copyWith(fontSize: 10.5, color: goldLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              b.done
                  ? LButton(label: 'Nhận', small: true, color: jade, onTap: () => _claim(i))
                  : LButton(label: 'Đi ngay', small: true, onTap: () => _go(b)),
            ],
          ),
        ],
      ),
    );
  }
}
