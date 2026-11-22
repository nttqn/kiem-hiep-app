import 'package:flutter/material.dart';

import '../core/arena.dart';
import '../core/hero.dart';
import '../core/lore.dart';
import '../core/stats.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Thống kê: totals and records on the left, the latest battles on the right.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    return SubScreen(
      title: tr('Thống kê'),
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
  if (m < 60) return tr('{m} phút', {'m': m});
  return tr('{p0} giờ {p1} phút', {'p0': m ~/ 60, 'p1': m % 60});
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
          head(tr('Tổng quan')),
          line(tr('Thời gian chơi'), playTime(h.playSeconds)),
          line(tr('Lực chiến'), fmt(h.power), c: goldLight),
          line(tr('Quái đã hạ'), fmt(h.kills)),
          line(tr('Boss đã hạ'), fmt(h.bossKills)),
          line(tr('Số lần trọng thương'), fmt(h.deaths)),
          line(tr('Trận đã đánh (thắng)'), '${fmt(r.runs)} (${fmt(r.wins)})'),
          line(tr('Tổng sát thương'), fmt(r.totalDmg.round())),
          head(tr('Kỷ lục')),
          line(tr('Sát thương/giây'), r.bestDps > 0 ? fmt(r.bestDps.round()) : '-', c: goldLight),
          if (r.bestDpsWhere.isNotEmpty) Text(tr('tại {bestDpsWhere}', {'bestDpsWhere': r.bestDpsWhere}), style: small.copyWith(fontSize: 10.5)),
          line(tr('Đòn mạnh nhất'), r.bestHit > 0 ? fmt(r.bestHit.round()) : '-', c: goldLight),
          line(tr('Hạ quái một chuyến'), r.bestRunKills > 0 ? fmt(r.bestRunKills) : '-'),
          line(tr('Tháp Thử Luyện'), h.towerBest > 0 ? tr('tầng {towerBest}', {'towerBest': h.towerBest}) : '-'),
          line(tr('Boss Thế Giới'), h.wbBest > 0 ? fmt(h.wbBest) : '-'),
          line(tr('Lôi đài cao nhất'), h.arenaBestTier >= 0 ? arenaTiers[h.arenaBestTier].name : '-'),
          line(tr('Sao Bí cảnh'), '$realmStars'),
          line(tr('Trang Ký sự'), '${h.lorePages.length}/$lorePageCount'),
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
          Text(tr('Lịch sử trận ({logLength} gần nhất)', {'logLength': log.length}), style: bold.copyWith(color: goldLight)),
          const Divider(color: gold, height: 10),
          Expanded(
            child: log.isEmpty
                ? Center(child: Text(tr('Chưa có trận nào. Ra trận rồi quay lại xem nhé.'), style: small))
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
      RunResult.won => (tr('Thắng'), const Color(0xFF8CE07A)),
      RunResult.lost => (tr('Thua'), const Color(0xFFFF7A6A)),
      RunResult.left => (tr('Rời đi'), creamDim),
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
              Text(tr(r.name), style: bold.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
              Text(
                tr('{mins}p{p0} · {p1} quái · '
                '{p2}/giây · đòn {p3}'
                '{p4}{p5}', {'mins': mins, 'p0': secs.toString().padLeft(2, '0'), 'p1': fmt(r.kills), 'p2': fmt(r.dps.round()), 'p3': fmt(r.bestHit.round()), 'p4': r.gold > 0 ? tr(' · +{p0} lượng', {'p0': fmt(r.gold)}) : '', 'p5': r.levels > 0 ? tr(' · +{levels} cấp', {'levels': r.levels}) : ''}),
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
