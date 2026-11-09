import 'dart:async';

import 'package:flutter/material.dart';

import '../core/gold_boss.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/world_boss.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'cloud_panel.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'world_boss_screen.dart' show BossPreview;

const _goldTint = Color(0xFFFFD34A);

/// Boss Hoàng Kim (1.12.0): who comes today and when, the session's runs,
/// what it pays and the day's damage board.
class GoldBossScreen extends StatefulWidget {
  const GoldBossScreen({super.key});

  @override
  State<GoldBossScreen> createState() => _GoldBossScreenState();
}

class _GoldBossScreenState extends State<GoldBossScreen> {
  HeroData get h => SaveService.instance.hero;
  Leaderboard get lb => Leaderboard.instance;
  String get _day => vnDayKey();
  List<LbEntry>? _rows;
  int? _place;
  bool _loadFailed = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    h.gbRollDay(_day);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => h.gbRollDay(_day));
    });
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rankReward());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!lb.available) return;
    setState(() {
      _rows = null;
      _loadFailed = false;
    });
    final slot = SaveService.instance.active;
    if (slot >= 0 && h.gbTotal > 0) await lb.submitBoss(slot, h, golden: true);
    try {
      final rows = await lb.topBoss(_day, limit: 50, golden: true);
      final place = h.gbTotal > 0 && !lb.hidden ? await lb.placeBoss(_day, h.gbTotal, golden: true) : null;
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _place = place;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Yesterday's (or an earlier day's) board place, paid once it is known.
  Future<void> _rankReward() async {
    if (!h.gbRankDue || !lb.available) return;
    final place = await lb.placeGoldDay(SaveService.instance.active, h.gbLastDay, h.gbLastTotal);
    if (place == null || !mounted) return;
    final lines = h.payGoldRank(place);
    await SaveService.instance.save();
    if (lines.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text('Thưởng xếp hạng Boss Hoàng Kim', style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lines.first, style: bold.copyWith(color: goldLight)),
            const SizedBox(height: 6),
            for (final l in lines.skip(1)) Text('• $l', style: body),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nhận'))],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _fight() async {
    if (!h.gbStartRun(_day)) return;
    await SaveService.instance.save();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(goldBossDef())));
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    _load();
  }

  static String _clock(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final s = d.inSeconds;
    return s >= 3600 ? '${s ~/ 3600}:${two(s % 3600 ~/ 60)}:${two(s % 60)}' : '${two(s ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Boss Hoàng Kim',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 235, child: _bossPanel()),
          const SizedBox(width: 10),
          Expanded(child: _rewards()),
          const SizedBox(width: 10),
          SizedBox(width: 235, child: _board()),
        ],
      ),
    );
  }

  Widget _bossPanel() {
    final boss = goldBossOf();
    final s = goldBossSessionAt();
    final (wait, next) = goldBossNext();
    final left = h.gbRunsLeft;
    final open = h.goldBossOpen;
    return Panel(
      border: _goldTint,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(boss.name, style: titleStyle(19, color: _goldTint), textAlign: TextAlign.center, maxLines: 1),
          Expanded(child: Center(child: FittedBox(child: BossPreview(def: boss, size: 150)))),
          if (s >= 0) ...[
            Text('Đang xuất hiện · còn ${_clock(goldBossLeft())}',
                style: bold.copyWith(color: const Color(0xFF8CE07A)), textAlign: TextAlign.center),
            Text('Lượt còn: $left/$goldBossRuns', style: small, textAlign: TextAlign.center),
          ] else ...[
            Text('Xuất hiện sau ${_clock(wait)}', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
            Text('Khung ${goldBossSessionLabel(next)}', style: small, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 6),
          LButton(
            label: !open
                ? 'Mở ở cấp $goldBossOpenLevel'
                : s < 0
                    ? 'Chưa đến giờ'
                    : left > 0
                        ? 'Khiêu chiến'
                        : 'Hết lượt khung này',
            icon: Icons.whatshot,
            enabled: open && left > 0,
            onTap: _fight,
          ),
        ],
      ),
    );
  }

  Widget _rewards() {
    const days = ['Thứ 2, 4, 6', 'Thứ 3, 5, 7', 'Chủ nhật'];
    final today = goldBossOf().id;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hôm nay: ${fmt(h.gbTotal)}', style: titleStyle(18, color: const Color(0xFFFF9A5A))),
          Text('Cao nhất một lượt: ${fmt(h.gbBest)}', style: small),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                Text('Mỗi ngày 2 khung: ${[for (var i = 0; i < goldBossSessions.length; i++) goldBossSessionLabel(i)].join(' và ')}. '
                    'Mỗi khung $goldBossRuns lượt, mỗi lượt ${goldBossTime.round()} giây.',
                    style: body.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                Text('Tham gia', style: bold.copyWith(color: goldLight)),
                Text('Gây sát thương trong một khung: +$goldBossJoinShards Mảnh Hoàng Kim (mỗi khung một lần).',
                    style: body.copyWith(fontSize: 13)),
                for (var i = 0; i < goldBossSessions.length; i++)
                  Row(
                    children: [
                      Icon(h.gbPaid & (1 << i) != 0 ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 15, color: h.gbPaid & (1 << i) != 0 ? const Color(0xFF8CE07A) : creamDim),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('Khung ${goldBossSessionLabel(i)} · ${h.gbRunsIn(i)}/$goldBossRuns lượt',
                            style: small.copyWith(fontSize: 12)),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text('Xếp hạng sát thương trong ngày (nhận vào hôm sau)', style: bold.copyWith(color: goldLight)),
                for (var i = 0; i < goldRankBrackets.length; i++) _bracket(i),
                const SizedBox(height: 6),
                Text('Lịch xuất hiện', style: bold.copyWith(color: goldLight)),
                for (var i = 0; i < goldBossMobs.length; i++)
                  Text('${days[i]}: ${goldBossMobs[i].name}',
                      style: small.copyWith(
                          fontSize: 12, color: goldBossMobs[i].id == today ? _goldTint : creamDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bracket(int i) {
    final (label, place) = goldRankBrackets[i];
    final r = goldRankReward(place)!;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(label, style: bold.copyWith(fontSize: 12, color: i == 0 ? _goldTint : cream))),
          Expanded(
            child: Text(
              '${r.shards} Mảnh Hoàng Kim · ${r.iron} Thần Thiết${r.title.isNotEmpty ? ' · « ${r.title} »' : ''}',
              style: small.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    final me = lb.myUid;
    Widget content;
    if (!lb.available) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Đăng nhập để lên bảng xếp hạng và nhận thưởng hạng',
              style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          LButton(label: 'Đăng nhập', small: true, color: jade, onTap: () => showCloudPanel(context)),
        ],
      );
    } else if (_loadFailed) {
      content = Center(child: Text('Không tải được, thử lại sau.', style: small));
    } else if (_rows == null) {
      content = const Center(child: CircularProgressIndicator(color: goldLight));
    } else if (_rows!.isEmpty) {
      content = Center(child: Text('Chưa ai khiêu chiến hôm nay.', style: small, textAlign: TextAlign.center));
    } else {
      content = ListView.builder(
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
          Expanded(child: content),
        ],
      ),
    );
  }
}
