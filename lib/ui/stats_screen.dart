import 'package:flutter/material.dart';

import '../core/arena.dart';
import '../core/hero.dart';
import '../core/lore.dart';
import '../core/stats.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Thống kê: totals and records on the left, the latest battles on the right.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    return SubScreen(
      title: 'Thống kê',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 300, child: _Totals(h)),
          const SizedBox(width: 10),
          Expanded(child: _Log(h)),
        ],
      ),
    );
  }
}

String playTime(double sec) {
  final m = sec ~/ 60;
  if (m < 60) return '$m phút';
  return '${m ~/ 60} giờ ${m % 60} phút';
}

class _Totals extends StatelessWidget {
  const _Totals(this.h);
  final HeroData h;

  @override
  Widget build(BuildContext context) {
    final r = h.records;
    Widget line(String k, String v, {Color? c}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(k, style: small.copyWith(fontSize: 12, color: creamDim))),
              Text(v, style: bold.copyWith(fontSize: 12.5, color: c ?? cream)),
            ],
          ),
        );
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(t, style: bold.copyWith(color: goldLight, fontSize: 13.5)),
        );
    final realmStars = h.realmStars.values.fold<int>(0, (a, b) => a + b);
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: ListView(
        children: [
          head('Tổng quan'),
          line('Thời gian chơi', playTime(h.playSeconds)),
          line('Lực chiến', fmt(h.power), c: goldLight),
          line('Quái đã hạ', fmt(h.kills)),
          line('Boss đã hạ', fmt(h.bossKills)),
          line('Số lần trọng thương', fmt(h.deaths)),
          line('Trận đã đánh (thắng)', '${fmt(r.runs)} (${fmt(r.wins)})'),
          line('Tổng sát thương', fmt(r.totalDmg.round())),
          head('Kỷ lục'),
          line('Sát thương/giây', r.bestDps > 0 ? fmt(r.bestDps.round()) : '-', c: goldLight),
          if (r.bestDpsWhere.isNotEmpty) Text('tại ${r.bestDpsWhere}', style: small.copyWith(fontSize: 10.5)),
          line('Đòn mạnh nhất', r.bestHit > 0 ? fmt(r.bestHit.round()) : '-', c: goldLight),
          line('Hạ quái một chuyến', r.bestRunKills > 0 ? fmt(r.bestRunKills) : '-'),
          line('Tháp Thử Luyện', h.towerBest > 0 ? 'tầng ${h.towerBest}' : '-'),
          line('Boss Thế Giới', h.wbBest > 0 ? fmt(h.wbBest) : '-'),
          line('Lôi đài cao nhất', h.arenaBestTier >= 0 ? arenaTiers[h.arenaBestTier].name : '-'),
          line('Sao Bí cảnh', '$realmStars'),
          line('Trang Ký sự', '${h.lorePages.length}/$lorePageCount'),
        ],
      ),
    );
  }
}

const _kindIcons = {
  'field': Icons.landscape,
  'dungeon': Icons.castle,
  'realm': Icons.explore,
  'tower': Icons.stairs,
  'arena': Icons.sports_kabaddi,
  'daihoi': Icons.emoji_events,
  'boss': Icons.whatshot,
  'nightmare': Icons.dark_mode,
};

class _Log extends StatelessWidget {
  const _Log(this.h);
  final HeroData h;

  @override
  Widget build(BuildContext context) {
    final log = h.runLog;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lịch sử trận (${log.length} gần nhất)', style: bold.copyWith(color: goldLight)),
          const Divider(color: gold, height: 10),
          Expanded(
            child: log.isEmpty
                ? Center(child: Text('Chưa có trận nào. Ra trận rồi quay lại xem nhé.', style: small))
                : ListView.separated(
                    itemCount: log.length,
                    separatorBuilder: (_, _) => const Divider(color: Color(0x33C8A050), height: 8),
                    itemBuilder: (_, i) => _row(log[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(RunLog r) {
    final (label, color) = switch (r.result) {
      RunResult.won => ('Thắng', const Color(0xFF8CE07A)),
      RunResult.lost => ('Thua', const Color(0xFFFF7A6A)),
      RunResult.left => ('Rời đi', creamDim),
    };
    final mins = r.sec ~/ 60, secs = r.sec % 60;
    return Row(
      children: [
        Icon(_kindIcons[r.kind] ?? Icons.flag, size: 18, color: goldLight),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: bold.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
              Text(
                '${mins}p${secs.toString().padLeft(2, '0')} · ${fmt(r.kills)} quái · '
                '${fmt(r.dps.round())}/giây · đòn ${fmt(r.bestHit.round())}'
                '${r.gold > 0 ? ' · +${fmt(r.gold)} lượng' : ''}${r.levels > 0 ? ' · +${r.levels} cấp' : ''}',
                style: small.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: bold.copyWith(fontSize: 12, color: color)),
      ],
    );
  }
}
