import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/hero.dart';
import '../core/nightmare.dart';
import '../core/world_boss.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'theme.dart';

/// Ải Ác Mộng: the eighteen nightmares, opened one after another, each with
/// this week's ma khí.
class NightmareView extends StatelessWidget {
  const NightmareView({super.key});

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
                  'Quái mạnh hơn nhiều, boss gọi đồng bọn khi yếu máu, ma khí đổi mỗi thứ Hai. '
                  'Thưởng Mảnh Hoàng Kim, ngọc và trang bí kíp; lần vượt đầu tiên thưởng lớn.',
                  style: small.copyWith(fontSize: 11.5, color: cream),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text('Lượt thưởng', style: small.copyWith(fontSize: 11)),
                  Text('${h.nmRunsLeft}/$nightmarePaidRuns', style: titleStyle(20)),
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
              mainAxisExtent: 150,
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
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ác Mộng ${i + 1}: ${dungeons[i].name}',
                            style: bold.copyWith(color: const Color(0xFFF2B8E0)), overflow: TextOverflow.ellipsis),
                        Text('Quái cấp ${d.level} · ${d.map.name}', style: small, overflow: TextOverflow.ellipsis),
                        Text(
                          'Lực chiến đề nghị ${fmt(nightmarePower(i))}',
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
                          'Thưởng ${fmt(nightmareGold(i, 3))} lượng · ${nightmareShards(i, 3)} mảnh · ngọc bậc ${nightmareGemTier(i)}',
                          style: small.copyWith(fontSize: 11, color: goldLight),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Ma khí ${a.name}: ${a.desc}',
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
                              open ? (stars == 0 ? 'Chưa vượt' : '${d.timeLimit.round()} giây') : 'Vượt Ác Mộng $i trước',
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
