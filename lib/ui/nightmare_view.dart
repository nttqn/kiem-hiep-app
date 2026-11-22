import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/divine.dart';
import '../core/hero.dart';
import '../core/nightmare.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Ải Ác Mộng: the eighteen nightmares, opened one after another, each with
/// this week's ma khí.
class NightmareView extends StatefulWidget {
  const NightmareView({super.key});

  @override
  State<NightmareView> createState() => _NightmareViewState();
}

class _NightmareViewState extends State<NightmareView> {
  @override
  Widget build(BuildContext context) {
    final HeroData h = SaveService.instance.hero;
    final day = vnDayKey();
    h.nmRollDay(day);
    final week = nightmareWeek(day);
    final power = h.power;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          border: const Color(0xFF8A3A6A),
          child: Row(
            children: [
              const Icon(Icons.nightlight_round, color: Color(0xFFE08AC8), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Quái mạnh hơn nhiều, boss gọi đồng bọn khi yếu máu, ma khí đổi mỗi thứ Hai. '
                  'Thưởng Mảnh Hoàng Kim, ngọc, trang bí kíp, từ ải 7 có Thần Thiết; lần vượt đầu tiên thưởng lớn.'),
                  style: small.copyWith(fontSize: 11.5, color: cream),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(tr('Lượt thưởng'), style: small.copyWith(fontSize: 11)),
                  Text('${h.nmRunsLeft}/${h.nmPaidToday}', style: titleStyle(20)),
                  if (h.nmAds < nightmareAdRuns)
                    ValueListenableBuilder<bool>(
                      valueListenable: AdsService.instance.rewardedReady,
                      builder: (_, ready, _) => LButton(
                        label: tr('+1 lượt'),
                        icon: Icons.ondemand_video,
                        small: true,
                        color: const Color(0xFF8A5A10),
                        enabled: ready,
                        onTap: () async {
                          if (!await AdsService.instance.showRewarded() || !mounted) return;
                          h.nmAddAdRun(vnDayKey());
                          SaveService.instance.save();
                          setState(() {});
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
              mainAxisExtent: 168,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: nightmareCount,
            itemBuilder: (context, i) {
              final affix = nightmareAffix(i, week);
              final d = nightmareDef(i, affix);
              final open = h.nightmareUnlocked(i);
              final stars = h.nmStars[d.id] ?? 0;
              final a = nmAffixes[affix]!;
              return Opacity(
                opacity: open ? 1 : 0.5,
                child: GestureDetector(
                  onTap: open ? () => Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(d))) : null,
                  child: Panel(
                    border: stars == 0 && open ? const Color(0xFFE08AC8) : const Color(0xFF8A3A6A),
                    art: mapArtPath(d.map.theme.name),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Ác Mộng {p0}: {p1}', {'p0': i + 1, 'p1': tr(dungeons[i].name)}),
                            style: bold.copyWith(color: const Color(0xFFF2B8E0)), overflow: TextOverflow.ellipsis),
                        Text(tr('Quái cấp {level} · {mapName}', {'level': d.level, 'mapName': tr(d.map.name)}), style: small, overflow: TextOverflow.ellipsis),
                        Text(
                          tr('Lực chiến đề nghị {p0}', {'p0': fmt(nightmarePower(i))}),
                          style: small.copyWith(
                            fontSize: 11.5,
                            color: power >= nightmarePower(i)
                                ? const Color(0xFF8CE07A)
                                : power >= nightmarePower(i) * 0.6
                                    ? const Color(0xFFF0C060)
                                    : const Color(0xFFF07A6A),
                          ),
                        ),
                        Text(
                          tr('Thưởng {p0} lượng · {p1} mảnh · ngọc bậc {p2}'
                          '{p3}', {'p0': fmt(nightmareGold(i, 3)), 'p1': nightmareShards(i, 3), 'p2': nightmareGemTier(i), 'p3': nightmareIron(i) > 0 ? tr(' · {p0} Thần Thiết', {'p0': nightmareIron(i)}) : ''}),
                          style: small.copyWith(fontSize: 11, color: goldLight),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(tr('Ma khí {aName}: {desc}', {'aName': tr(a.name), 'desc': tr(a.desc)}),
                            style: small.copyWith(color: cream, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          children: [
                            for (var s = 0; s < 3; s++)
                              Icon(s < stars ? Icons.star : Icons.star_border, color: goldLight, size: 20),
                            const Spacer(),
                            Text(
                              open ? (stars == 0 ? tr('Chưa vượt') : tr('{p0} giây', {'p0': d.timeLimit.round()})) : tr('Vượt Ác Mộng {i} trước', {'i': i}),
                              style: small,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
