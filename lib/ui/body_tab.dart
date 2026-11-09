import 'package:flutter/material.dart';

import '../core/body_train.dart';
import '../core/gold_sets.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../services/analytics.dart';
import '../core/premium.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';

/// Nhân vật tab: Luyện thể, five body parts trained with Thần Thiết.
class BodyTab extends StatefulWidget {
  const BodyTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends State<BodyTab> {
  HeroData get h => SaveService.instance.hero;

  void _train(int i) {
    final before = h.power;
    final realm = bodyRealmOf(h.bodyTotal);
    if (!h.trainBody(i)) return;
    h.notices.clear();
    Analytics.instance.log('body_up', {'part': i, 'lv': h.bodyLv[i]});
    SaveService.instance.save();
    final now = bodyRealmOf(h.bodyTotal);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(now != realm
          ? 'Đột phá cảnh giới ${now!.name}! Lực chiến +${fmt(h.power - before)}'
          : '${bodyParts[i].name} tầng ${h.bodyLv[i]}. Lực chiến +${fmt(h.power - before)}'),
      duration: const Duration(seconds: 2),
    ));
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final total = h.bodyTotal;
    final realm = bodyRealmOf(total);
    final c = Color(realm?.color ?? 0xFFB8A888);
    BodyRealm? next;
    for (final r in bodyRealms) {
      if (total < r.at) {
        next = r;
        break;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: Panel(
            border: c,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(child: FittedBox(child: FigurePreview.of(h, scale: 2))),
                Text(realm?.name ?? 'Phàm thể', style: titleStyle(18, color: c)),
                Text('Tổng tầng: $total/${bodyMax * bodyParts.length}', style: small),
                if (next != null)
                  Text('${next.name} ở $total/${next.at}: ${_bonusText(next.bonus)}',
                      style: small.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  children: [
                    MatCount(Mat.iron, '${h.divineIron} Thần Thiết', style: bold.copyWith(fontSize: 12, color: const Color(0xFF9FD8FF))),
                    MatCount(Mat.soulPill, '${h.soulPills} Linh Phách Đơn', style: bold.copyWith(fontSize: 12, color: const Color(0xFFC8B8FF))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            border: c,
            padding: const EdgeInsets.all(10),
            child: h.bodyOpen
                ? ListView(children: [
                    Text('Luyện thể', style: titleStyle(18, color: goldLight)),
                    Text(
                      'Tôi luyện thân thể bằng Thần Thiết và lượng. Tầng 11 cần Chuyển sinh ${bodyTiers[0].$2} '
                      'và ${bodyTiers[0].$3} Linh Phách Đơn, tầng 21 cần Chuyển sinh ${bodyTiers[1].$2} và ${bodyTiers[1].$3} viên.',
                      style: small.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    _boost(),
                    for (var i = 0; i < bodyParts.length; i++) _row(i),
                  ])
                : Center(
                    child: Text(
                      'Luyện thể mở ở Chuyển sinh $bodyOpenRebirths.\n'
                      'Năm phần thân thể: Bì, Nhục, Cân, Cốt, Tủy, mỗi phần $bodyMax tầng.',
                      style: body,
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _boost() {
    if (h.bodyBoost) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('Ưu đãi đang chờ: lần luyện kế tiếp miễn lượng, nửa Thần Thiết.',
            style: bold.copyWith(fontSize: 12, color: jade)),
      );
    }
    if (h.bodyAdsLeft(vnDayKey()) <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ValueListenableBuilder<bool>(
          valueListenable: AdsService.instance.rewardedReady,
          builder: (_, ready, _) => LButton(
            label: 'Xem quảng cáo: lần luyện tới miễn lượng, nửa Thần Thiết',
            icon: Icons.ondemand_video,
            small: true,
            color: const Color(0xFF8A5A10),
            enabled: ready,
            onTap: () async {
              if (!await AdsService.instance.showRewarded() || !mounted) return;
              h.takeBodyAd(vnDayKey());
              SaveService.instance.save();
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  String _bonusText(Map<Bonus, double> b) => [
        for (final e in b.entries) '${bonusLabel(e.key)} +${(e.value * 100).round()}%',
      ].join(', ');

  Widget _row(int i) {
    final p = bodyParts[i];
    final lv = h.bodyLv[i];
    final block = h.bodyBlock(i);
    final pills = bodyPillCost(lv);
    final cost = switch (block) {
      BodyBlock.maxed => 'Đã viên mãn',
      BodyBlock.rebirth => 'Cần Chuyển sinh ${bodyRebirthsFor(lv)}',
      _ => '${h.bodyCost(i).$1} Thần Thiết · ${fmt(h.bodyCost(i).$2)} lượng${pills > 0 ? ' · $pills Linh Phách Đơn' : ''}',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: lacquerDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.name} · tầng $lv/$bodyMax', style: bold.copyWith(fontSize: 13, color: goldLight)),
                Text('${p.label} +${(p.valueAt(lv) * 100).toStringAsFixed(1)}%  (mỗi tầng +${(p.per * 100).toStringAsFixed(1)}%)',
                    style: small.copyWith(fontSize: 11, color: cream)),
                Text(cost,
                    style: small.copyWith(
                        fontSize: 10.5,
                        color: block == null ? creamDim : const Color(0xFFFF9A8A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (block != BodyBlock.maxed)
            LButton(
              label: pills > 0 ? 'Đột phá' : 'Luyện',
              small: true,
              color: pills > 0 ? const Color(0xFF5A3A8A) : seal,
              enabled: block == null,
              onTap: () => _train(i),
            ),
        ],
      ),
    );
  }
}
