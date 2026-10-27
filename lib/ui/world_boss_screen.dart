import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/arena.dart';
import '../core/content.dart';
import '../core/gems.dart';
import '../core/gold_sets.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/tower.dart';
import '../core/world_boss.dart';
import '../render/art_figures.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'arena_screen.dart';
import 'cloud_panel.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Thử thách: the endless tower, the daily world boss and the Lôi đài.
class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  HeroData get h => SaveService.instance.hero;

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(fadeRoute(page));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final towerOpen = h.level >= towerOpenLevel || h.rebirths > 0;
    final bossOpen = h.level >= worldBossOpenLevel || h.rebirths > 0;
    final arenaOpen = h.arenaOpen;
    h.arenaRollDay(vnDayKey());
    final boss = worldBossOf();
    h.wbRollDay(vnDayKey());
    return SubScreen(
      title: 'Thử thách',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _card(
              title: 'Tháp Thử Luyện',
              icon: Icons.temple_buddhist,
              lines: [
                'Tầng cao nhất: ${h.towerBest}',
                'Tháp vô tận, càng lên cao quái càng mạnh.',
                'Mỗi 5 tầng có đầu lĩnh và ngọc; tầng 60 rơi ngọc Tiên, 72 ngọc Thánh.',
              ],
              art: Text('${h.towerBest + 1}', style: titleStyle(84, color: goldLight.withValues(alpha: 0.85))),
              button: towerOpen ? 'Leo tầng ${h.towerBest + 1}' : 'Mở ở cấp $towerOpenLevel',
              enabled: towerOpen,
              onTap: () => _go(PlayScreen.dungeon(towerFloor(h.towerBest + 1))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _card(
              title: 'Boss Thế Giới',
              icon: Icons.whatshot,
              lines: [
                'Hôm nay: ${boss.name}',
                'Lượt còn: ${h.wbRunsLeft} · Tổng sát thương: ${fmt(h.wbTotal)}',
                'Đánh 60 giây, so tổng sát thương trong ngày với cả server. Đổi boss lúc 0 giờ.',
              ],
              art: BossPreview(def: boss, size: 150),
              button: bossOpen ? 'Vào Boss Thế Giới' : 'Mở ở cấp $worldBossOpenLevel',
              enabled: bossOpen,
              onTap: () => _go(const WorldBossScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _card(
              title: 'Lôi đài',
              icon: Icons.sports_kabaddi,
              lines: [
                'Hạng: ${arenaTiers[h.arenaTier].name} · ${h.arenaPoints} điểm',
                'Lượt còn: ${arenaOpen ? h.arenaFightsLeft : 0} · Uy danh: ${fmt(h.arenaCoins)}',
                'Tỷ thí với bản sao cao thủ khác, đổi Uy danh lấy thú cưỡi, ngọc, đan dược.',
              ],
              art: Icon(Icons.sports_kabaddi, size: 110, color: Color(arenaTiers[h.arenaTier].color).withValues(alpha: 0.85)),
              button: arenaOpen ? 'Lên lôi đài' : 'Mở ở cấp $arenaOpenLevel',
              enabled: arenaOpen,
              onTap: () => _go(const ArenaScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<String> lines,
    required Widget art,
    required String button,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Panel(
      border: goldLight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: goldLight, size: 40),
              const SizedBox(width: 10),
              Text(title, style: titleStyle(24, color: cream)),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l, style: body.copyWith(fontSize: 14)),
            ),
          Expanded(child: Center(child: FittedBox(child: art))),
          LButton(label: button, color: jade, enabled: enabled, onTap: onTap),
        ],
      ),
    );
  }
}

/// The day's boss, its runs, damage milestones and the daily board.
class WorldBossScreen extends StatefulWidget {
  const WorldBossScreen({super.key});

  @override
  State<WorldBossScreen> createState() => _WorldBossScreenState();
}

class _WorldBossScreenState extends State<WorldBossScreen> {
  HeroData get h => SaveService.instance.hero;
  Leaderboard get lb => Leaderboard.instance;
  String get _day => vnDayKey();
  List<LbEntry>? _rows;
  int? _place;
  bool _loadFailed = false;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    h.wbRollDay(_day);
    _load();
  }

  Future<void> _load() async {
    if (!lb.available) return;
    setState(() {
      _rows = null;
      _loadFailed = false;
    });
    final slot = SaveService.instance.active;
    if (slot >= 0 && h.wbTotal > 0) await lb.submitBoss(slot, h);
    try {
      final rows = await lb.topBoss(_day);
      final place = h.wbTotal > 0 && !lb.hidden ? await lb.placeBoss(_day, h.wbTotal) : null;
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _place = place;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _fight() async {
    if (!h.wbStartRun(_day)) return;
    await SaveService.instance.save();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(worldBossDef())));
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final boss = worldBossOf();
    return SubScreen(
      title: 'Boss Thế Giới',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 270, child: _bossPanel(boss)),
          const SizedBox(width: 10),
          Expanded(child: _milestones()),
          const SizedBox(width: 10),
          SizedBox(width: 270, child: _board()),
        ],
      ),
    );
  }

  Widget _bossPanel(MobDef boss) {
    final left = h.wbRunsLeft;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(boss.name, style: titleStyle(20, color: hanhColor(boss.hanh)), textAlign: TextAlign.center),
          Expanded(child: Center(child: BossPreview(def: boss, size: 150))),
          Text('Lượt còn: $left (${worldBossFreeTries + h.wbAdRuns} hôm nay)',
              style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          Text('Cao nhất: ${fmt(h.wbBest)}', style: small, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          LButton(label: 'Khiêu chiến', icon: Icons.whatshot, enabled: left > 0, onTap: _fight),
          if (h.wbAdRuns < worldBossAdTries) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.rewardedReady,
              builder: (_, ready, _) => LButton(
                label: 'Xem quảng cáo: +1 lượt',
                icon: Icons.ondemand_video,
                small: true,
                color: const Color(0xFF8A5A10),
                enabled: ready,
                onTap: () async {
                  final earned = await AdsService.instance.showRewarded();
                  if (!earned || !mounted) return;
                  h.wbAddAdRun(_day);
                  SaveService.instance.save();
                  setState(() {});
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _milestones() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mốc sát thương hôm nay', style: titleStyle(18)),
          Text('Tổng: ${fmt(h.wbTotal)}', style: bold.copyWith(color: const Color(0xFFFF9A5A))),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [for (var i = 0; i < worldBossMilestones.length; i++) _milestone(i)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestone(int i) {
    final goal = worldBossMilestones[i];
    final done = h.wbClaimed & (1 << i) != 0;
    final can = h.wbCanClaim(i);
    final gemName = gemTierNames[worldBossMilestoneGem[i] - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: can ? goldLight : gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt(goal), style: bold.copyWith(color: cream)),
                Text(
                    '${fmt(worldBossMilestoneGold(i))} lượng · 1 ngọc $gemName ngẫu nhiên'
                    '${worldBossGoldShards[i] > 0 ? ' · ${worldBossGoldShards[i]} mảnh Hoàng Kim' : ''}',
                    style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 3),
                Bar(value: (h.wbTotal / goal).clamp(0.0, 1.0), color: const Color(0xFFFF9A5A), height: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          done
              ? const Icon(Icons.check_circle, color: Color(0xFF8CE07A))
              : LButton(
                  label: 'Nhận',
                  small: true,
                  color: jade,
                  enabled: can,
                  onTap: () {
                    final g = h.wbClaim(i, _rng);
                    if (g == null) return;
                    SaveService.instance.save();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                            content: Text('Nhận ${fmt(worldBossMilestoneGold(i))} lượng và ${g.name}'
                                '${worldBossGoldShards[i] > 0 ? ', ${worldBossGoldShards[i]} mảnh Hoàng Kim' : ''}')));
                    setState(() {});
                  },
                ),
        ],
      ),
    );
  }

  Widget _board() {
    final me = lb.myUid;
    Widget body;
    if (!lb.available) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Đăng nhập để lên bảng xếp hạng', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          LButton(label: 'Đăng nhập', small: true, color: jade, onTap: () => showCloudPanel(context)),
        ],
      );
    } else if (_loadFailed) {
      body = Center(child: Text('Không tải được, thử lại sau.', style: small));
    } else if (_rows == null) {
      body = const Center(child: CircularProgressIndicator(color: goldLight));
    } else if (_rows!.isEmpty) {
      body = Center(child: Text('Chưa ai khiêu chiến hôm nay.', style: small, textAlign: TextAlign.center));
    } else {
      body = ListView.builder(
        itemCount: _rows!.length,
        itemBuilder: (_, i) {
          final e = _rows![i];
          final mine = me != null && e.id.startsWith('${me}_');
          return Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: mine ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: bold.copyWith(color: i < 3 ? goldLight : cream))),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: hanhColor(Hanh.values[e.hanh]), shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(e.name, style: small.copyWith(fontSize: 12, color: cream), overflow: TextOverflow.ellipsis),
                ),
                Text(fmt(e.power), style: bold.copyWith(fontSize: 12, color: const Color(0xFFFF9A5A))),
              ],
            ),
          );
        },
      );
    }
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Xếp hạng hôm nay', style: titleStyle(18)),
          if (_place != null) Text('Hạng của bạn: #$_place', style: bold.copyWith(color: goldLight)),
          const SizedBox(height: 4),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// A gently animated monster portrait.
class BossPreview extends StatefulWidget {
  const BossPreview({super.key, required this.def, this.size = 120});
  final MobDef def;
  final double size;

  @override
  State<BossPreview> createState() => _BossPreviewState();
}

class _BossPreviewState extends State<BossPreview> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(widget.size),
        painter: _BossPainter(_t, widget.def),
      );
}

class _BossPainter extends CustomPainter {
  _BossPainter(this.t, this.def) : super(repaint: t);
  final ValueNotifier<double> t;
  final MobDef def;

  @override
  void paint(Canvas c, Size s) {
    final time = t.value;
    final cycle = time % 3;
    c.save();
    c.translate(s.width * 0.5, s.height * 0.88);
    drawShadow(c, s.width * 0.25);
    // Bosses are drawn about 2x their base; fit that into the box.
    final k = s.width / (95 * def.size);
    c.scale(k * def.size);
    drawMob(c, def, t: time, attack: cycle < 0.4 ? 1 - cycle / 0.4 : 0);
    c.restore();
  }

  @override
  bool shouldRepaint(_BossPainter old) => old.def != def;
}

