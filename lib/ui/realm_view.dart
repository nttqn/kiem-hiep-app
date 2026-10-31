import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/hero.dart';
import '../core/realm.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'theme.dart';

/// Bí cảnh: one wide land per field map, explored a few times a day.
class RealmView extends StatefulWidget {
  const RealmView({super.key});

  @override
  State<RealmView> createState() => _RealmViewState();
}

class _RealmViewState extends State<RealmView> {
  HeroData get h => SaveService.instance.hero;
  bool _adBusy = false;

  Future<void> _adRun() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned && h.realmAddAdRun(vnDayKey())) {
      await SaveService.instance.save();
      if (mounted) setState(() {});
    }
  }

  void _enter(int i) {
    if (!h.realmStartRun(vnDayKey())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hết lượt thám hiểm hôm nay, mai quay lại nhé.')),
      );
      return;
    }
    SaveService.instance.save();
    Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(realmDungeon(i, h.level))));
  }

  @override
  Widget build(BuildContext context) {
    h.realmRollDay(vnDayKey());
    final left = h.realmRunsLeft;
    final last = realms.lastIndexWhere((r) => h.level >= r.openLv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          border: const Color(0xFF3A7A6A),
          child: Row(
            children: [
              const Icon(Icons.explore, color: Color(0xFF8CE0C8), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vùng đất rộng phủ sương, mỗi lần vào một khác. Thắp 3 trận nhãn (hạ Hộ Trận Sứ canh giữ) để phá phong ấn, '
                  'hạ đầu lĩnh. Trên đường có rương báu, bia cổ ban phúc và người gặp nạn cần cứu. 10 phút mỗi lượt.',
                  style: small.copyWith(fontSize: 11.5, color: cream),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lượt hôm nay', style: small.copyWith(fontSize: 11)),
                  Text('$left', style: titleStyle(20)),
                  if (h.realmAds < realmAdRuns)
                    ValueListenableBuilder<bool>(
                      valueListenable: AdsService.instance.rewardedReady,
                      builder: (_, ready, _) => LButton(
                        label: '+1',
                        icon: Icons.ondemand_video,
                        small: true,
                        color: const Color(0xFF8A5A10),
                        enabled: ready && !_adBusy,
                        onTap: _adRun,
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
              mainAxisExtent: 138,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: realms.length,
            itemBuilder: (context, i) {
              final r = realms[i];
              final open = h.realmOpen(i);
              final stars = h.realmStars[r.id] ?? 0;
              final best = i == last;
              return Opacity(
                opacity: open ? 1 : 0.5,
                child: GestureDetector(
                  onTap: open ? () => _enter(i) : null,
                  child: Panel(
                    border: best ? const Color(0xFF8CE0C8) : const Color(0xFF3A7A6A),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.name,
                                  style: bold.copyWith(color: const Color(0xFFB8F0E0)), overflow: TextOverflow.ellipsis),
                            ),
                            if (best) const Icon(Icons.recommend, size: 16, color: Color(0xFF8CE0C8)),
                          ],
                        ),
                        Text('Quái cấp ${realmLevel(r, h.level)} · ${r.map.name}',
                            style: small, overflow: TextOverflow.ellipsis),
                        Text(r.desc,
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
                              !open
                                  ? 'Cần cấp ${r.openLv}'
                                  : stars == 0
                                      ? 'Lần đầu: đồ Hiếm'
                                      : mobById[r.map.boss]!.name,
                              style: small.copyWith(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
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
