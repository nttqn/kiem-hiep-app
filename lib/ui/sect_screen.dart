import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/gold_sets.dart';
import '../core/hero.dart';
import '../core/manuals.dart';
import '../core/sect_duty.dart';
import '../core/world_boss.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'lists.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Sư môn: the hero's chức vị and khảo hạch, the day's chain of duties, and
/// Tàng Kinh Các where cống hiến is spent.
class SectScreen extends StatefulWidget {
  const SectScreen({super.key});

  @override
  State<SectScreen> createState() => _SectScreenState();
}

class _SectScreenState extends State<SectScreen> {
  HeroData get h => SaveService.instance.hero;
  final _rng = math.Random();

  void _changed() {
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    h.sectRollDay(vnDayKey(), _rng);
    return SubScreen(
      title: 'Sư môn · ${h.sect.name}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 250, child: _rankPanel()),
          const SizedBox(width: 8),
          Expanded(child: _dutyPanel()),
          const SizedBox(width: 8),
          SizedBox(width: 250, child: _shopPanel()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- chức vị

  Widget _rankPanel() {
    final next = h.nextSectRank;
    final bonus = sectRankBonus(h.hanh, h.sectRank);
    return Panel(
      padding: const EdgeInsets.all(10),
      border: hanhColor(h.hanh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chức vị', style: small),
          Text(sectRanks[h.sectRank].name, style: titleStyle(20)),
          const SizedBox(height: 4),
          if (bonus.isEmpty)
            Text('Chưa có thưởng chức vị', style: small.copyWith(fontSize: 11))
          else
            Text(bonus.entries.map((e) => '${bonusLabel(e.key)} +${(e.value * 100).toStringAsFixed(1)}%').join(' · '),
                style: small.copyWith(fontSize: 11, color: const Color(0xFF8CE07A))),
          const SizedBox(height: 8),
          Text('Cống hiến tích lũy: ${fmt(h.sectContrib)}', style: bold.copyWith(fontSize: 13)),
          if (next != null) ...[
            const SizedBox(height: 4),
            Bar(
              value: (h.sectContrib / next.need).clamp(0, 1).toDouble(),
              color: expGold,
              height: 8,
            ),
            const SizedBox(height: 4),
            Text('Lên ${next.name}: ${fmt(next.need)} cống hiến · cấp ${next.level}',
                style: small.copyWith(fontSize: 11)),
            const Spacer(),
            Text('Khảo hạch: tỉ thí với ${sectExaminer(h.hanh, h.sectRank + 1)}',
                style: small.copyWith(fontSize: 11, color: cream)),
            const SizedBox(height: 4),
            LButton(
              label: 'Khảo hạch',
              icon: Icons.sports_kabaddi,
              color: seal,
              enabled: h.sectCanTrial,
              onTap: _trial,
            ),
          ] else ...[
            const Spacer(),
            Text('Đã là Chưởng môn của ${h.sect.name}.', style: bold.copyWith(color: goldLight)),
          ],
        ],
      ),
    );
  }

  Future<void> _trial() async {
    final r = h.sectExaminerNow();
    Analytics.instance.log('sect_trial_start', {'rank': h.sectRank + 1});
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(sectTrialDef(r))));
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------- nhiệm vụ

  Widget _dutyPanel() {
    final d = h.sectDuty;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Nhiệm vụ sư môn', style: titleStyle(18)),
              const Spacer(),
              Text('Hôm nay ${h.sectDone}/$sectDutiesPerDay', style: bold.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Mỗi ngày $sectDutiesPerDay việc nối nhau; việc thứ 5 và 10 là truy bắt phản đồ, thưởng gấp đôi.',
              style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          if (d == null)
            Expanded(
              child: Center(
                child: Text('Hôm nay đã xong hết việc. Mai quay lại nhé!',
                    style: body.copyWith(color: creamDim), textAlign: TextAlign.center),
              ),
            )
          else ...[
            Panel(
              padding: const EdgeInsets.all(10),
              border: d.done ? const Color(0xFF8CE07A) : gold,
              child: Row(
                children: [
                  Icon(_dutyIcon(d.kind), color: d.kind == DutyKind.traitor ? const Color(0xFFFF8A6A) : goldLight, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.goal, style: bold.copyWith(color: goldLight)),
                        Text(
                          d.kind == DutyKind.dungeon ? 'Ải hoặc tầng tháp bất kỳ' : 'Tại ${d.mapName}',
                          style: small,
                        ),
                        if (d.count > 1) Text('Tiến độ ${d.progress}/${d.count}', style: small.copyWith(color: cream)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thưởng: +${dutyContribution(h.sectDone)} cống hiến, '
              '${fmt(dutyGold(h.level) * (dutyContribution(h.sectDone) > 25 ? 2 : 1))} lượng và kinh nghiệm',
              style: small.copyWith(color: cream),
            ),
            const Spacer(),
            Row(
              children: [
                if (d.done)
                  Expanded(
                    child: LButton(
                      label: 'Phục mệnh',
                      color: jade,
                      onTap: () {
                        final lines = h.sectClaim(_rng);
                        if (lines == null) return;
                        Analytics.instance.log('sect_duty', {'n': h.sectDone});
                        _changed();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lines.join(' · '))));
                      },
                    ),
                  )
                else ...[
                  Expanded(child: LButton(label: 'Đi ngay', color: jade, onTap: () => _go(d))),
                  const SizedBox(width: 8),
                  LButton(
                    label: 'Đổi việc ${fmt(dutyRerollCost(h.level))}',
                    small: true,
                    color: const Color(0xFF5A4A3A),
                    enabled: h.gold >= dutyRerollCost(h.level),
                    onTap: () {
                      if (h.sectReroll(_rng)) _changed();
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _dutyIcon(DutyKind k) => switch (k) {
        DutyKind.kill => Icons.gps_fixed,
        DutyKind.boss => Icons.whatshot,
        DutyKind.herb => Icons.spa,
        DutyKind.fish => Icons.phishing,
        DutyKind.dungeon => Icons.castle,
        DutyKind.traitor => Icons.person_off,
      };

  Future<void> _go(SectDuty d) async {
    final Widget page = d.kind == DutyKind.dungeon ? const DungeonListScreen() : PlayScreen.field(mapById[d.map]!);
    await Navigator.of(context).push(fadeRoute(page));
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------- tàng kinh các

  Widget _shopPanel() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tàng Kinh Các', style: titleStyle(18)),
          Text('Cống hiến: ${fmt(h.sectCoins)}', style: bold.copyWith(color: goldLight)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (final o in sectOffers) _offer(o),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offer(SectOffer o) {
    final locked = h.sectRank < o.rank;
    final name = switch (o.kind) {
      SectWare.gem => 'Ngọc ngũ hành bậc ${sectGemTier(h.sectRank)}',
      _ => o.name,
    };
    final pageLocked = o.kind == SectWare.page && !h.manualOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: bold.copyWith(fontSize: 12.5), maxLines: 2),
                  Text(
                    locked
                        ? 'Cần chức ${sectRanks[o.rank].name}'
                        : (pageLocked ? 'Bí kíp mở ở cấp $manualOpenLevel' : '${o.price} cống hiến'),
                    style: small.copyWith(fontSize: 11, color: locked || pageLocked ? const Color(0xFFFF8A7A) : creamDim),
                  ),
                ],
              ),
            ),
            LButton(
              label: 'Đổi',
              small: true,
              color: jade,
              enabled: !locked && !pageLocked && h.sectCoins >= o.price,
              onTap: () async {
                String? page;
                if (o.kind == SectWare.page) {
                  page = await pickManualPage(context, h);
                  if (page == null) return;
                }
                if (h.sectBuy(o, _rng, page: page)) _changed();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the player pick a skill and school for a bought page.
Future<String?> pickManualPage(BuildContext context, HeroData h) {
  final sect = h.sect;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text('Chọn trang bí kíp', style: titleStyle(18)),
      content: SizedBox(
        width: 560,
        height: 260,
        child: ListView(
          children: [
            for (final i in manualSkills(sect))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 130, child: Text(sect.skills[i].name, style: bold.copyWith(fontSize: 12.5))),
                    for (final k in manualKindsFor(sect.skills[i]))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: LButton(
                          label: '${manualKinds[k]!.name} ${h.manualPagesOf(manualKey(sect.skills[i].id, k))}',
                          small: true,
                          color: const Color(0xFF5A3A7A),
                          onTap: () => Navigator.pop(ctx, manualKey(sect.skills[i].id, k)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy'))],
    ),
  );
}
