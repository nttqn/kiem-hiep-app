import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/monthly.dart';
import '../core/rewards.dart';
import '../services/ads.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

String _away(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '$m phút';
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

/// "Bế quan tu luyện": what the hero gained while the game was closed.
Future<void> showOfflineDialog(BuildContext context, HeroData h, OfflineReward r) async {
  var doubled = false;
  void pay(int mul) {
    h.gold += r.gold * mul;
    h.gainExp((r.exp * mul).toDouble());
    h.notices.clear();
    SaveService.instance.save();
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: lacquer,
        title: Row(
          children: [
            const Icon(Icons.self_improvement, color: goldLight),
            const SizedBox(width: 8),
            Text('Bế quan tu luyện', style: titleStyle(22)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trong ${_away(r.away)} vắng mặt, ${h.name} đã bế quan luyện công'
                '${r.away >= offlineCap ? ' (tối đa ${offlineCap.inHours} giờ)' : ''}.',
                style: body,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _gain(Icons.auto_awesome, '+${fmt(r.exp * (doubled ? 2 : 1))}', 'kinh nghiệm'),
                  _gain(Icons.monetization_on, '+${fmt(r.gold * (doubled ? 2 : 1))}', 'lượng'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (!doubled)
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.rewardedReady,
              builder: (_, ready, _) => TextButton.icon(
                onPressed: !ready
                    ? null
                    : () async {
                        final earned = await AdsService.instance.showRewarded();
                        if (!earned) return;
                        pay(2);
                        doubled = true;
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                icon: const Icon(Icons.ondemand_video, size: 18),
                label: Text(ready ? 'Xem quảng cáo: nhận x2' : 'Quảng cáo đang tải…'),
              ),
            ),
          TextButton(
            onPressed: () {
              pay(1);
              Navigator.pop(ctx);
            },
            child: const Text('Nhận'),
          ),
        ],
      ),
    ),
  );
}

Widget _gain(IconData icon, String value, String label) => Column(
      children: [
        Icon(icon, color: goldLight, size: 30),
        Text(value, style: titleStyle(22, color: cream)),
        Text(label, style: small),
      ],
    );

/// The seven-day login gift board; claims today's gift if still due.
Future<void> showLoginGiftDialog(BuildContext context, HeroData h) async {
  final today = todayKey();
  String? got;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final gifts = loginGifts(h.level);
        final due = h.lastLoginDate != today;
        // While due, loginDay points at today's gift; once taken, at tomorrow's.
        final todayIdx = due ? h.loginDay : (h.loginDay + 6) % 7;
        return AlertDialog(
          backgroundColor: lacquer,
          // The monthly track makes it taller than a landscape phone.
          scrollable: true,
          title: Text('Quà đăng nhập', style: titleStyle(22)),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Mỗi ngày mở game nhận một món. Ngày 7 tặng trang bị Hiếm, rồi vòng lại từ đầu. '
                    'Số ngày nhận trong tháng còn mở thêm quà điểm danh.',
                    style: small),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _GiftTile(
                          day: i + 1,
                          gift: gifts[i],
                          taken: i < todayIdx || (i == todayIdx && !due),
                          today: i == todayIdx,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _MonthlyTrack(days: h.monthDaysOn(today), level: h.level),
                if (got != null) ...[
                  const SizedBox(height: 10),
                  Text('Đã nhận: $got', style: bold.copyWith(color: goldLight), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          actions: [
            if (due)
              LButton(
                label: 'Nhận quà ngày ${todayIdx + 1}',
                small: true,
                color: jade,
                onTap: () {
                  final line = claimLoginGift(h, today, math.Random());
                  SaveService.instance.save();
                  setState(() => got = line);
                },
              )
            else
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        );
      },
    ),
  );
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.day, required this.gift, required this.taken, required this.today});
  final int day;
  final LoginGift gift;
  final bool taken;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final icon = switch (gift.kind) {
      GiftKind.gold => Icons.monetization_on,
      GiftKind.hpPots => Icons.local_drink,
      GiftKind.mpPots => Icons.local_drink,
      GiftKind.item => Icons.diamond,
    };
    final c = switch (gift.kind) {
      GiftKind.gold => goldLight,
      GiftKind.hpPots => const Color(0xFFFF7A7A),
      GiftKind.mpPots => const Color(0xFF7AA8FF),
      GiftKind.item => rarityColor(gift.rarity!),
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: today ? Color.lerp(lacquer, seal, 0.5) : lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: today ? goldLight : gold.withValues(alpha: 0.4), width: today ? 2 : 1),
      ),
      child: Opacity(
        opacity: taken && !today ? 0.45 : 1,
        child: Column(
          children: [
            Text('Ngày $day', style: small.copyWith(fontSize: 11, color: cream)),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: c, size: 28),
                if (taken) const Icon(Icons.check_circle, color: Color(0xFF8CE07A), size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              gift.amount > 0 ? fmt(gift.amount) : gift.label.replaceFirst('Trang bị ', ''),
              style: bold.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Điểm danh tháng: check-in days this month and the marks along the way.
class _MonthlyTrack extends StatelessWidget {
  const _MonthlyTrack({required this.days, required this.level});
  final int days;
  final int level;

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now().month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Điểm danh tháng $month: $days ngày', style: bold.copyWith(color: goldLight)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in monthlyMarks)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: lacquerDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: days >= m.days ? jade : gold.withValues(alpha: 0.4),
                      width: days >= m.days ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${m.days} ngày', style: bold.copyWith(fontSize: 12, color: cream)),
                          if (days >= m.days) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.check_circle, color: Color(0xFF8CE07A), size: 14),
                          ],
                        ],
                      ),
                      for (final l in monthlyLabels(m, level))
                        Text(
                          l,
                          style: small.copyWith(
                            fontSize: 10,
                            color: m.item != null && l.startsWith('Trang bị') ? rarityColor(m.item!) : null,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Achievements with rewards, and the title the hero wears.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  HeroData get h => SaveService.instance.hero;

  @override
  Widget build(BuildContext context) {
    final done = h.achClaimed.length;
    // Claimable first, then in progress, then finished.
    int rank(AchDef a) => h.achClaimed.contains(a.id) ? 2 : (a.reached(h) ? 0 : 1);
    final list = List<AchDef>.of(achievements)..sort((a, b) => rank(a).compareTo(rank(b)));
    return SubScreen(
      title: 'Thành tựu',
      actions: [
        Text('$done/${achievements.length}', style: bold.copyWith(color: goldLight)),
        const SizedBox(width: 12),
        Text('Danh hiệu: ', style: small),
        DropdownButton<String>(
          value: h.title,
          dropdownColor: lacquer,
          underline: const SizedBox.shrink(),
          style: bold.copyWith(color: goldLight),
          items: [
            const DropdownMenuItem(value: '', child: Text('(không)')),
            // A set: two achievements share « Võ Lâm Chí Tôn ».
            for (final t in {
              for (final a in achievements)
                if (h.achClaimed.contains(a.id)) a.title,
              ...h.seasonTitles,
            })
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) {
            h.title = v ?? '';
            SaveService.instance.save();
            setState(() {});
          },
        ),
      ],
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 100,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) => _tile(list[i]),
      ),
    );
  }

  Widget _tile(AchDef a) {
    final claimed = h.achClaimed.contains(a.id);
    final reached = a.reached(h);
    final p = math.min(a.progress(h), a.goal);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      border: reached && !claimed ? goldLight : (claimed ? jade : gold),
      child: Row(
        children: [
          Icon(claimed ? Icons.emoji_events : Icons.emoji_events_outlined,
              color: claimed ? goldLight : (reached ? goldLight : creamDim), size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(a.name, style: bold.copyWith(color: goldLight, fontSize: 13.5)),
                Text(a.desc, style: small.copyWith(fontSize: 11.5, color: cream),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Danh hiệu: ${a.title}',
                    style: small.copyWith(fontSize: 11, color: goldLight, fontStyle: FontStyle.italic),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Bar(value: p / a.goal, color: jade, height: 10, label: '${fmt(p)}/${fmt(a.goal)}'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claimed)
            const Icon(Icons.check_circle, color: Color(0xFF8CE07A))
          else
            LButton(
              label: '+${fmt(a.gold)}',
              small: true,
              color: jade,
              enabled: reached,
              onTap: () {
                if (claimAchievement(h, a)) {
                  if (h.title.isEmpty) h.title = a.title;
                  SaveService.instance.save();
                  setState(() {});
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Number of finished achievements waiting to be claimed (town badge).
int claimableCount(HeroData h) => claimable(h).length;
