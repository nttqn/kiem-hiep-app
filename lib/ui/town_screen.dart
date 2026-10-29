import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/content.dart';
import '../core/fatigue.dart';
import '../core/live_event.dart';
import '../core/newbie.dart';
import '../core/hero.dart';
import '../core/sect_duty.dart';
import '../core/tower.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/mail.dart';
import '../services/notify.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'activity_screen.dart';
import 'alchemy_screen.dart';
import 'backdrop.dart';
import '../core/rewards.dart';
import 'character_screen.dart';
import 'chat_screen.dart';
import 'leaderboard_screen.dart';
import 'world_boss_screen.dart';
import 'pet_screen.dart';
import 'rebirth_screen.dart';
import 'rewards_ui.dart';
import 'sect_screen.dart';
import 'cloud_panel.dart';
import 'lists.dart';
import 'mail_dialog.dart';
import 'newbie_dialog.dart';
import 'play_screen.dart';
import 'shop_screen.dart';
import 'theme.dart';
import 'title_screen.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key, this.firstVisit = false});
  final bool firstVisit;

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  HeroData get h => SaveService.instance.hero;

  @override
  void initState() {
    super.initState();
    h.refreshDaily(todayKey());
    SaveService.instance.save();
    // Play screens replace the list that opened them, so refresh on saves.
    SaveService.instance.addListener(_refresh);
    MailService.instance.addListener(_refresh);
    MailService.instance.refresh();
    final away = SaveService.instance.pendingAway;
    SaveService.instance.pendingAway = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome(away));
  }

  /// Guide for a new hero; otherwise the closed-door training payout and
  /// today's login gift, one after the other.
  Future<void> _welcome(Duration? away) async {
    if (widget.firstVisit) {
      showGuide(context);
      return;
    }
    if (away != null) {
      final r = offlineReward(h, away);
      if (r != null && mounted) await showOfflineDialog(context, h, r);
    }
    if (mounted && h.lastLoginDate != todayKey()) await showLoginGiftDialog(context, h);
    if (mounted && h.newbieReady(vnDayKey())) await showNewbieDialog(context);
    // Ask for notifications once the player has stuck around a little.
    if (h.level >= 5 || h.rebirths > 0) await NotifyService.instance.askOnce();
    if (mounted) setState(() {});
  }

  /// Strips between the quest and the grid: the newbie gifts while they
  /// last, and today's events.
  List<Widget> _banners() {
    final day = vnDayKey();
    final on = EventBoost(day).on;
    // At most two, so the grid keeps its room on short screens.
    return <Widget>[
      if (h.newbieOpen)
        _banner(
          icon: Icons.redeem,
          color: const Color(0xFF8CE07A),
          title: h.newbieReady(day)
              ? 'Quà tân thủ · ngày ${h.newbieClaimed + 1}/$newbieDays'
              : 'Quà tân thủ · đã nhận ${h.newbieClaimed}/$newbieDays',
          text: h.newbieReady(day)
              ? 'Quà hôm nay đang chờ! Đủ 7 ngày nhận Thú cưỡi Bạch Mã.'
              : 'Đã nhận hôm nay, mai quay lại nhận tiếp nhé.',
          action: h.newbieReady(day) ? 'Nhận' : 'Xem',
          onTap: () async {
            await showNewbieDialog(context);
            if (mounted) setState(() {});
          },
        ),
      for (final e in on)
        _banner(
          icon: Icons.celebration,
          color: const Color(0xFFFFB03A),
          title: e.name,
          text: [if (e.desc.isNotEmpty) e.desc, e.perks.join(' · ')].join(' · '),
        ),
    ].take(2).toList();
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    String? action,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Panel(
          border: color,
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$title  ', style: bold.copyWith(fontSize: 13, color: color)),
                    TextSpan(text: text, style: small.copyWith(fontSize: 11.5, color: cream)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 6),
                LButton(label: action, small: true, color: jade, onTap: onTap),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    // Firebase may come up after the town opened; this is throttled.
    MailService.instance.refresh();
  }

  @override
  void dispose() {
    SaveService.instance.removeListener(_refresh);
    MailService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(fadeRoute(page));
    h.refreshDaily(todayKey());
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  /// Jumps straight to whatever the current main quest needs.
  void _goQuest() {
    final q = h.currentMain;
    if (q == null) return;
    if (q.type == QuestType.dungeon) {
      final d = dungeonById[q.target]!;
      _go(PlayScreen.dungeon(d));
      return;
    }
    final m = questMap(q);
    if (m != null) {
      _go(PlayScreen.field(m));
    } else {
      _go(const MapListScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = h.currentMain;
    final pending = h.freePoints > 0 || h.skillPoints > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pushReplacement(fadeRoute(const TitleScreen()));
      },
      child: Scaffold(
        body: Backdrop(
          town: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 200, child: _heroCard()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Thành Lạc An', style: titleStyle(24)),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Hòm thư',
                              onPressed: () async {
                                await showMailDialog(context);
                                if (mounted) setState(() {});
                              },
                              icon: Badge(
                                isLabelVisible: MailService.instance.open(h).isNotEmpty,
                                label: Text('${MailService.instance.open(h).length}'),
                                backgroundColor: seal,
                                child: const Icon(Icons.mail_outline, color: goldLight),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Kênh Thế Giới',
                              onPressed: () => _go(const ChatScreen()),
                              icon: const Icon(Icons.forum_outlined, color: goldLight),
                            ),
                            const CloudButton(),
                            ValueListenableBuilder<bool>(
                              valueListenable: SoundService.instance.musicOn,
                              builder: (_, on, _) => IconButton(
                                tooltip: on ? 'Tắt nhạc nền' : 'Bật nhạc nền',
                                onPressed: SoundService.instance.toggleMusic,
                                icon: Icon(on ? Icons.music_note : Icons.music_off, color: goldLight),
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: SoundService.instance.sfxOn,
                              builder: (_, on, _) => IconButton(
                                tooltip: on ? 'Tắt tiếng hiệu ứng' : 'Bật tiếng hiệu ứng',
                                onPressed: SoundService.instance.toggleSfx,
                                icon: Icon(on ? Icons.volume_up : Icons.volume_off, color: goldLight),
                              ),
                            ),
                            ListenableBuilder(
                              listenable: NotifyService.instance,
                              builder: (_, _) {
                                final on = NotifyService.instance.enabled;
                                return IconButton(
                                  tooltip: on ? 'Tắt thông báo nhắc' : 'Bật thông báo nhắc',
                                  onPressed: () {
                                    NotifyService.instance.setEnabled(!on);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(on
                                          ? 'Đã tắt thông báo nhắc.'
                                          : 'Đã bật thông báo nhắc: bế quan đầy, quà mới mỗi tối.'),
                                      duration: const Duration(seconds: 2),
                                    ));
                                  },
                                  icon: Icon(on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                                      color: goldLight),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Hướng dẫn',
                              onPressed: () => showGuide(context),
                              icon: const Icon(Icons.help_outline, color: goldLight),
                            ),
                            IconButton(
                              tooltip: 'Đổi nhân vật',
                              onPressed: () => Navigator.of(context)
                                  .pushReplacement(fadeRoute(const TitleScreen())),
                              icon: const Icon(Icons.people_alt_outlined, color: goldLight),
                            ),
                          ],
                        ),
                        if (q != null) _questCard(q),
                        const SizedBox(height: 6),
                        ..._banners(),
                        const Spacer(),
                        _grid(pending),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              child: FigurePreview.of(h, scale: 2, aura: true),
            ),
          ),
          Text(h.name, style: titleStyle(20, color: cream)),
          if (h.title.isNotEmpty)
            Text('« ${h.title} »', style: small.copyWith(color: goldLight, fontStyle: FontStyle.italic)),
          Text('${h.sect.name} · Cấp ${h.level}', style: body.copyWith(color: hanhColor(h.hanh))),
          Text('Lực chiến ${fmt(h.power)}', style: small.copyWith(color: goldLight, fontWeight: FontWeight.w700)),
          if (h.rebirths > 0)
            Text('Chuyển sinh lần ${h.rebirths}', style: small.copyWith(color: goldLight, fontWeight: FontWeight.w700)),
          // Mệt mỏi, from an hour before monster EXP starts to drop.
          if (h.fatigueDay == vnDayKey() && h.fatigueSec >= fatigueStart - 3600)
            Text(
              fatigueMul(h.fatigueSec) < 1
                  ? 'Mệt mỏi: EXP quái ${(fatigueMul(h.fatigueSec) * 100).round()}%'
                  : 'Đã luyện ${fatigueLabel(h.fatigueSec)} hôm nay',
              style: small.copyWith(fontSize: 11, color: const Color(0xFFF0C060)),
            ),
          const SizedBox(height: 6),
          Bar(
            value: (h.exp / h.expNeeded).clamp(0.0, 1.0),
            color: expGold,
            height: 13,
            label: h.expFull ? 'ĐẦY' : '${fmt(h.exp)} / ${fmt(h.expNeeded)}',
          ),
          if (h.level >= maxLevel) ...[
            const SizedBox(height: 6),
            LButton(
              label: h.canRebirth ? 'Chuyển sinh!' : 'Chuyển sinh',
              icon: Icons.autorenew,
              small: true,
              color: h.canRebirth ? seal : const Color(0xFF5A4A3A),
              onTap: () => _go(const RebirthScreen()),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _chip(Icons.monetization_on, fmt(h.gold), goldLight),
              _chip(Icons.local_drink, '${h.hpPots}', const Color(0xFFFF7A7A)),
              _chip(Icons.local_drink, '${h.mpPots}', const Color(0xFF7AA8FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData i, String v, Color c) => Row(
        children: [
          Icon(i, size: 16, color: c),
          const SizedBox(width: 3),
          Text(v, style: bold.copyWith(fontSize: 13)),
        ],
      );

  Widget _questCard(QuestDef q) {
    final locked = h.mainLocked;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.auto_stories, color: goldLight, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${h.questLabel}: ${q.title}',
                    style: bold.copyWith(color: goldLight)),
                Text(
                  locked
                      ? 'Cần đạt cấp ${q.minLv} để nhận nhiệm vụ này.'
                      : '${q.goal}'
                          '${q.type == QuestType.kill ? '  (${h.mainProgress}/${q.count})' : ''}',
                  style: body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (!locked) LButton(label: 'Đi ngay', small: true, color: jade, onTap: _goQuest),
        ],
      ),
    );
  }

  /// Boss Thế Giới runs still free today, for the Thử thách badge.
  int _bossRunsLeft() {
    h.wbRollDay(vnDayKey());
    return h.wbRunsLeft;
  }

  /// A finished duty to hand in, or a khảo hạch ready.
  int _sectBadge() {
    if (!h.sectOpen) return 0;
    h.sectRollDay(vnDayKey(), math.Random());
    return ((h.sectDuty?.done ?? false) ? 1 : 0) + (h.sectCanTrial ? 1 : 0);
  }

  /// Lôi đài duels still left today.
  int _arenaLeft() {
    if (!h.arenaOpen) return 0;
    h.arenaRollDay(vnDayKey());
    return h.arenaFightsLeft;
  }

  Widget _grid(bool pending) {
    final tiles = [
      _Tile('Luyện công', Icons.landscape, () => _go(const MapListScreen())),
      _Tile('Vượt ải', Icons.castle, () => _go(const DungeonListScreen())),
      _Tile('Thử thách', Icons.whatshot, () {
        if (h.level < towerOpenLevel && h.rebirths == 0) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Thử thách mở ở cấp $towerOpenLevel')));
          return;
        }
        _go(const ChallengeScreen());
      }, badge: (h.level >= worldBossOpenLevel || h.rebirths > 0 ? _bossRunsLeft() : 0) + _arenaLeft()),
      _Tile('Xếp hạng', Icons.leaderboard, () => _go(const LeaderboardScreen())),
      _Tile('Nhiệm vụ', Icons.assignment, () => _go(const QuestScreen()),
          badge: h.daily.where((d) => !d.done).length + h.bounties.where((b) => b.done).length),
      _Tile('Nhân vật', Icons.person, () => _go(const CharacterScreen(tab: 0)),
          badge: pending ? h.freePoints + h.skillPoints : 0),
      _Tile('Đồng hành', Icons.groups, () => _go(PetScreen(tab: h.companionsOpen ? 2 : 0))),
      _Tile('Luyện đan', Icons.science, () {
        if (!h.alchemyOpen) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Luyện đan mở ở cấp $alchemyOpenLevel')));
          return;
        }
        _go(const AlchemyScreen());
      }),
      _Tile('Năng động', Icons.local_fire_department, () => _go(const ActivityScreen()),
          badge: activityClaimable(h)),
      _Tile('Sư môn', Icons.temple_buddhist, () {
        if (!h.sectOpen) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Sư môn mở ở cấp $sectOpenLevel')));
          return;
        }
        _go(const SectScreen());
      }, badge: _sectBadge()),
      _Tile('Cửa hàng', Icons.storefront, () => _go(const ShopScreen())),
      _Tile('Thợ rèn', Icons.hardware, () => _go(const CharacterScreen(tab: 3, forge: true))),
      _Tile('Thành tựu', Icons.emoji_events, () => _go(const AchievementsScreen()),
          badge: claimableCount(h)),
      _Tile('Quà ngày', Icons.card_giftcard, () async {
        await showLoginGiftDialog(context, h);
        if (mounted) setState(() {});
      }, badge: h.lastLoginDate == todayKey() ? 0 : 1),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 6 * 8) / 7;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final t in tiles) SizedBox(width: w, height: 68, child: t)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon, this.onTap, {this.badge = 0});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: goldLight, size: 26),
                  const SizedBox(height: 2),
                  Text(label,
                      style: bold.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seal,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: goldLight),
                ),
                child: Text('$badge', style: bold.copyWith(fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}

void showGuide(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text('Bí kíp nhập môn', style: titleStyle(20)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Text(
            '• Kéo bên trái màn hình để di chuyển. Giữ nút lớn bên phải để đánh, '
            'chạm các nút nhỏ để ra chiêu.\n'
            '• Bật TỰ ĐỘNG để nhân vật tự tìm quái, ra chiêu và uống thuốc. '
            'Di chuyển tay sẽ tạm dừng tự động.\n'
            '• Mỗi cấp được 5 điểm tiềm năng và 1 điểm kỹ năng. Vào Nhân vật để cộng.\n'
            '• Ngũ hành: Kim khắc Mộc, Mộc khắc Thổ, Thổ khắc Thủy, Thủy khắc Hỏa, '
            'Hỏa khắc Kim. Đánh quái bị khắc gây thêm 25% sát thương.\n'
            '• Làm nhiệm vụ chính tuyến để nhận nhiều kinh nghiệm và trang bị quý. '
            'Nhiệm vụ hằng ngày làm mới mỗi ngày.\n'
            '• Vượt ải càng nhanh càng được nhiều sao. Đầu lĩnh có đòn đánh lan '
            'báo trước bằng vòng đỏ — hãy tránh ra!\n'
            '• Thợ rèn cường hóa trang bị tới +10, thất bại chỉ mất bạc.',
            style: body.copyWith(height: 1.45),
          ),
        ),
      ),
      actions: [
        if (AdsService.instance.privacyOptionsRequired.value)
          TextButton(
            onPressed: AdsService.instance.showPrivacyOptions,
            child: const Text('Tùy chọn quảng cáo'),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
      ],
    ),
  );
}
