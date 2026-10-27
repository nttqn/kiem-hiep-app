import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/activity.dart';
import '../core/hero.dart';
import '../core/world_boss.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Chests a hero can open right now, for the town badge.
int activityClaimable(HeroData h) {
  h.actRollDay(vnDayKey());
  var n = 0;
  for (var i = 0; i < actDailyMarks.length; i++) {
    if (h.actCanClaim(i)) n++;
    if (h.actCanClaim(i, weekly: true)) n++;
  }
  return n;
}

/// Điểm năng động: where today's points come from, and the day's and the
/// week's chests.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  HeroData get h => SaveService.instance.hero;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    h.actRollDay(vnDayKey());
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Năng động',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: _sources()),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _chests(false)),
                const SizedBox(height: 8),
                Expanded(child: _chests(true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sources() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hôm nay', style: titleStyle(18)),
          Text('Mỗi hoạt động có điểm tối đa trong ngày.', style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (final s in ActSource.values) _source(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _source(ActSource s) {
    final d = actSources[s]!;
    final got = h.actPointsOf(s);
    final full = got >= d.cap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${d.label} (+${d.points})',
                    style: small.copyWith(fontSize: 12, color: full ? const Color(0xFF8CE07A) : cream)),
              ),
              Text('$got/${d.cap}', style: bold.copyWith(fontSize: 12, color: full ? const Color(0xFF8CE07A) : goldLight)),
            ],
          ),
          const SizedBox(height: 2),
          Bar(value: got / d.cap, color: full ? jade : expGold, height: 5),
        ],
      ),
    );
  }

  Widget _chests(bool weekly) {
    final marks = weekly ? actWeeklyMarks : actDailyMarks;
    final pts = weekly ? h.actWeekPoints : h.actPoints;
    final top = marks.last;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(weekly ? 'Quà tuần' : 'Quà ngày', style: titleStyle(18)),
              const SizedBox(width: 10),
              Text(weekly ? 'Điểm tuần: $pts (làm mới thứ Hai)' : 'Điểm năng động: $pts',
                  style: bold.copyWith(color: goldLight)),
            ],
          ),
          const SizedBox(height: 4),
          Bar(value: (pts / top).clamp(0.0, 1.0), color: expGold, height: 8),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < marks.length; i++) Expanded(child: _chest(i, marks[i], weekly)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chest(int i, int mark, bool weekly) {
    final claimed = (weekly ? h.actWeekClaimed : h.actClaimed) & (1 << i) != 0;
    final can = h.actCanClaim(i, weekly: weekly);
    final c = actChest(i, h.level, weekly: weekly);
    final what = [
      '${fmt(c.gold)} lượng',
      if (c.potions > 0) '${c.potions} thuốc',
      if (c.herbs > 0) '${c.herbs} dược liệu',
      if (c.gemTier > 0) 'ngọc cấp ${c.gemTier}',
      if (c.coins > 0) '${c.coins} Uy danh',
      if (c.shards > 0) '${c.shards} mảnh Hoàng Kim',
      if (c.pill == 'songboi') 'Song Bội Đan',
      if (c.pill == 'cuongluc') 'Cuồng Lực Đan',
      if (c.pill == 'taytuy') 'Tẩy Tủy Đan',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: can
            ? () {
                final lines = h.actClaim(i, _rng, weekly: weekly);
                if (lines == null) return;
                SoundService.instance.cue('loot');
                SaveService.instance.save();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('Mở rương: ${lines.join(', ')}')));
                setState(() {});
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: can ? Color.lerp(lacquer, seal, 0.4) : lacquerDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: can ? goldLight : gold.withValues(alpha: 0.3), width: can ? 2 : 1),
          ),
          child: Column(
            children: [
              Text('$mark điểm', style: bold.copyWith(fontSize: 12, color: goldLight)),
              Expanded(
                child: Icon(
                  claimed ? Icons.check_circle : (can ? Icons.redeem : Icons.inventory_2_outlined),
                  color: claimed ? const Color(0xFF8CE07A) : (can ? goldLight : creamDim),
                  size: 30,
                ),
              ),
              Text(claimed ? 'Đã nhận' : (can ? 'Chạm để mở!' : what),
                  style: small.copyWith(fontSize: 9.5, color: can ? cream : creamDim),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
