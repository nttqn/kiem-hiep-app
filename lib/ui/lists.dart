import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/luan_hoi.dart';
import '../core/tower.dart';
import '../services/save.dart';
import 'bounty_view.dart';
import 'fish_book.dart';
import 'nightmare_view.dart';
import 'play_screen.dart';
import 'realm_view.dart';
import 'sub_screen.dart';
import 'theme.dart';

class MapListScreen extends StatelessWidget {
  const MapListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    // Cửu U Ma Vực last, shown to everyone as something to aim for.
    const all = [...maps, abyssMap];
    bool isOpen(MapDef m) => h.level >= m.entryLv && h.rebirths >= m.rebirths;
    final last = all.lastIndexWhere(isOpen);
    return SubScreen(
      title: 'Luyện công',
      actions: [
        if (h.fishOpen)
          LButton(
            label: 'Ngư phổ',
            icon: Icons.phishing,
            small: true,
            color: const Color(0xFF2E6A8A),
            onTap: () => showFishBook(context, h),
          ),
      ],
      child: _OpenAt(
        fraction: math.max(0, last) / (all.length - 1),
        builder: (ctl) => ListView.separated(
          controller: ctl,
          itemCount: all.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = all[i];
            final open = isOpen(m);
            final fit = open && (m.rebirths > 0 || (h.level >= m.minLv && h.level <= m.maxLv + 2));
            return Opacity(
              opacity: open ? 1 : 0.55,
              child: Panel(
                border: fit ? jade : gold,
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                child: Row(
                  children: [
                    _ThemeSwatch(theme: m.theme),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m.name, style: titleStyle(18, color: cream)),
                              const SizedBox(width: 10),
                              Text(m.rebirths > 0 ? 'Ngũ chuyển · Thần Thiết' : 'Cấp ${m.minLv}–${m.maxLv}',
                                  style: bold.copyWith(color: goldLight)),
                              if (fit) ...[
                                const SizedBox(width: 8),
                                Text('Phù hợp', style: small.copyWith(color: const Color(0xFF8CE07A))),
                              ],
                            ],
                          ),
                          Text(m.desc, style: small),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 10,
                            children: [
                              for (final id in [...m.mobs, m.boss]) _MobTag(def: mobById[id]!),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    open
                        ? LButton(
                            label: 'Vào',
                            small: true,
                            color: fit ? jade : seal,
                            onTap: () => Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.field(m))),
                          )
                        : Text(
                            m.rebirths > 0 ? 'Cần Chuyển sinh ${m.rebirths}\ncấp ${m.entryLv}' : 'Cần cấp ${m.entryLv}',
                            style: small,
                            textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tháp Thử Luyện entry: best floor and a button to climb on.
class TowerCard extends StatelessWidget {
  const TowerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final next = h.towerBest + 1;
    final open = h.level >= towerOpenLevel || h.rebirths > 0;
    return Panel(
      border: goldLight,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: [
          const Icon(Icons.temple_buddhist, color: goldLight, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tháp Thử Luyện', style: titleStyle(19, color: cream)),
                Text(
                  open
                      ? 'Tầng cao nhất: ${h.towerBest} · Mỗi 5 tầng có đầu lĩnh và ngọc, từ tầng 60 rơi ngọc Tiên, 72 ngọc Thánh.'
                      : 'Mở ở cấp $towerOpenLevel. Tháp vô tận, càng lên cao quái càng mạnh.',
                  style: small.copyWith(fontSize: 11.5),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          open
              ? LButton(
                  label: 'Leo tầng $next',
                  small: true,
                  color: jade,
                  onTap: () => Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(towerFloor(next)))),
                )
              : Text('Cấp $towerOpenLevel', style: small),
        ],
      ),
    );
  }
}

/// Builds a scrollable and, after the first frame, scrolls it to [fraction]
/// of its extent so the entries that fit the hero's level are in view.
class _OpenAt extends StatefulWidget {
  const _OpenAt({required this.fraction, required this.builder});
  final double fraction;
  final Widget Function(ScrollController) builder;

  @override
  State<_OpenAt> createState() => _OpenAtState();
}

class _OpenAtState extends State<_OpenAt> {
  final _ctl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ctl.hasClients) return;
      _ctl.jumpTo(_ctl.position.maxScrollExtent * widget.fraction.clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_ctl);
}

class _MobTag extends StatelessWidget {
  const _MobTag({required this.def});
  final MobDef def;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: hanhColor(def.hanh), shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          def.boss ? '${def.name} (đầu lĩnh)' : def.name,
          style: small.copyWith(color: def.boss ? const Color(0xFFFFB08A) : cream, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme});
  final MapTheme theme;

  @override
  Widget build(BuildContext context) {
    const colors = {
      MapTheme.grass: [Color(0xFF86B25A), Color(0xFF3E7A30)],
      MapTheme.bamboo: [Color(0xFF748F58), Color(0xFF6A4A6E)],
      MapTheme.cave: [Color(0xFF5E5348), Color(0xFF1A1612)],
      MapTheme.desert: [Color(0xFFE8CC90), Color(0xFFB08850)],
      MapTheme.snow: [Color(0xFFF6FAFC), Color(0xFF7A90A6)],
      MapTheme.volcano: [Color(0xFFFF6A2A), Color(0xFF33241F)],
      MapTheme.fortress: [Color(0xFF8A0F1A), Color(0xFF1A1A20)],
      MapTheme.cloud: [Color(0xFFC8DCDC), Color(0xFF3E5A54)],
      MapTheme.summit: [Color(0xFFF4A8BC), Color(0xFF4A4240)],
      MapTheme.abyss: [Color(0xFFB04AFF), Color(0xFF0E0A14)],
    };
    final c = colors[theme]!;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
        border: Border.all(color: goldLight.withValues(alpha: 0.6)),
      ),
    );
  }
}

class DungeonListScreen extends StatefulWidget {
  const DungeonListScreen({super.key, this.nightmare = false, this.realm = false});
  final bool nightmare;
  final bool realm;

  @override
  State<DungeonListScreen> createState() => _DungeonListScreenState();
}

class _DungeonListScreenState extends State<DungeonListScreen> {
  /// 0 the regular dungeons, 1 Bí cảnh, 2 Ác Mộng.
  late int _mode = widget.nightmare && SaveService.instance.hero.nightmareOpen
      ? 2
      : (widget.realm && SaveService.instance.hero.realmOpen(0) ? 1 : 0);

  static const _modeColors = [seal, Color(0xFF1E5A4A), Color(0xFF5A1A3A)];

  Widget _chip(String label, int mode, {bool fresh = false}) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _mode == mode ? _modeColors[mode] : lacquer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _mode == mode ? goldLight : gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: bold.copyWith(fontSize: 13)),
                if (fresh) ...[
                  const SizedBox(width: 4),
                  Text('MỚI', style: bold.copyWith(fontSize: 9.5, color: const Color(0xFFFFD34A))),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final realmOpen = h.realmOpen(0);
    return SubScreen(
      title: const ['Vượt ải', 'Bí cảnh', 'Ải Ác Mộng'][_mode],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h.nightmareOpen || realmOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                _chip('Thường', 0),
                if (realmOpen) _chip('Bí cảnh', 1, fresh: h.realmStars.isEmpty),
                if (h.nightmareOpen) _chip('Ác Mộng', 2),
              ]),
            ),
          Expanded(
            child: switch (_mode) {
              1 => const RealmView(),
              2 => const NightmareView(),
              _ => _normal(h),
            },
          ),
        ],
      ),
    );
  }

  Widget _normal(HeroData h) {
    final last = dungeons.lastIndexWhere((d) => h.level >= d.level - 2);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TowerCard(),
          const SizedBox(height: 8),
          Expanded(
            child: _OpenAt(
              fraction: math.max(0, last) / (dungeons.length - 1),
              builder: (ctl) => GridView.builder(
                controller: ctl,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 270,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: dungeons.length,
                itemBuilder: (context, i) {
                  final d = dungeons[i];
                  final stars = h.dungeonStars[d.id] ?? 0;
                  final open = h.level >= d.level - 2;
                  final quest = h.currentMain?.type == QuestType.dungeon && h.currentMain?.target == d.id;
                  return Opacity(
                    opacity: open ? 1 : 0.5,
                    child: GestureDetector(
                      onTap: open
                          ? () => Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(d)))
                          : null,
                      child: Panel(
                        border: quest ? goldLight : gold,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ải ${i + 1}: ${d.name}',
                                    style: bold.copyWith(color: goldLight),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (quest) const Icon(Icons.auto_stories, size: 16, color: goldLight),
                              ],
                            ),
                            Text('Cấp ${d.level} · ${d.map.name}', style: small),
                            Text(
                              '${d.waves.length} đợt quái + ${mobById[d.map.boss]!.name}',
                              style: small.copyWith(color: cream),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                for (var s = 0; s < 3; s++)
                                  Icon(s < stars ? Icons.star : Icons.star_border, color: goldLight, size: 20),
                                const Spacer(),
                                Text(open ? '${d.timeLimit.round()} giây' : 'Cần cấp ${d.level - 2}', style: small),
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
          ),
        ],
      );
  }
}

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key, this.tab = 0});

  /// 0 the story and dailies, 1 Bảng Truy Nã.
  final int tab;

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  late int _tab = widget.tab;

  /// What the story panel says once there is no quest under way.
  Widget _storyDone(HeroData h) {
    final (head, line) = h.rebirths == 0
        ? ('Đã hoàn thành toàn bộ chính tuyến!', 'Đạt cấp 99 đầy kinh nghiệm rồi chuyển sinh để mở Luân Hồi.')
        : h.rbDone >= luanHoi.length
            ? ('Đã hoàn thành toàn bộ Luân Hồi!', 'Danh xưng Võ Lâm Chí Tôn đã thuộc về bạn.')
            : (
                'Hoàn thành ${chapterLabel(h.chapter)}: ${luanHoi[h.chapter].title}',
                'Chuyển sinh lần nữa để mở ${chapterLabel(h.chapter + 1)}. Trong lúc chờ, hãy nhận lệnh ở Bảng Truy Nã.'
              );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(head, style: titleStyle(18), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(line, style: body, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _chip(String label, int i) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _tab == i ? seal : lacquer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _tab == i ? goldLight : gold.withValues(alpha: 0.5)),
            ),
            child: Text(label, style: bold.copyWith(fontSize: 13)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final q = h.currentMain;
    final ready = h.bounties.where((b) => b.done).length;
    return SubScreen(
      title: 'Nhiệm vụ',
      actions: [
        _chip('Cốt truyện', 0),
        _chip(ready > 0 ? 'Truy nã ($ready)' : 'Truy nã', 1),
      ],
      child: _tab == 1 ? const BountyView() : Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Panel(
              child: q == null
                  ? _storyDone(h)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.inLuanHoi ? '${h.questLabel} · ${luanHoi[h.chapter].title}' : h.questLabel,
                            style: small.copyWith(color: h.inLuanHoi ? goldLight : creamDim)),
                        Text(q.title, style: titleStyle(22)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                                h.inLuanHoi && h.rbQuest == 0
                                    ? '${luanHoi[h.chapter].intro}\n\n${q.story}'
                                    : q.story,
                                style: body.copyWith(fontStyle: FontStyle.italic, height: 1.4)),
                          ),
                        ),
                        const Divider(color: gold),
                        Text(
                          h.mainLocked ? 'Cần đạt cấp ${q.minLv}' : 'Mục tiêu: ${q.goal}',
                          style: bold.copyWith(color: h.mainLocked ? const Color(0xFFFF8A7A) : cream),
                        ),
                        if (q.type == QuestType.kill && !h.mainLocked)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Bar(
                              value: h.mainProgress / q.count,
                              color: jade,
                              label: '${h.mainProgress}/${q.count}',
                              height: 14,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Thưởng: ${fmt(expToNext(q.minLv) * q.expFactor)} kinh nghiệm · '
                          '${fmt(q.gold)} lượng${q.item ? ' · trang bị Quý' : ''}',
                          style: small.copyWith(color: goldLight),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hằng ngày', style: titleStyle(20)),
                  Text('Làm mới mỗi ngày · thưởng theo cấp', style: small),
                  const SizedBox(height: 6),
                  for (final d in h.daily)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            d.done ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: d.done ? const Color(0xFF8CE07A) : creamDim,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.goal, style: body.copyWith(fontSize: 13)),
                                if (!d.done)
                                  Bar(
                                    value: d.progress / d.count,
                                    color: jade,
                                    height: 10,
                                    label: '${d.progress}/${d.count}',
                                  ),
                                Text(
                                  '+${fmt(d.exp)} kinh nghiệm · +${fmt(d.gold)} lượng',
                                  style: small.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text('Ngũ hành: Kim → Mộc → Thổ → Thủy → Hỏa → Kim', style: small),
                  Text('Phái của bạn: ${h.sect.name} (${h.hanh.label})', style: small),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
