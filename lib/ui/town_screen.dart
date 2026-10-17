import 'package:flutter/material.dart';

import '../core/content.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../services/ads.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'backdrop.dart';
import '../core/rewards.dart';
import 'character_screen.dart';
import 'pet_screen.dart';
import 'rebirth_screen.dart';
import 'rewards_ui.dart';
import 'cloud_panel.dart';
import 'lists.dart';
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
    if (mounted) setState(() {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SaveService.instance.removeListener(_refresh);
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
    final m = mapOfMob(q.target);
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
                  SizedBox(width: 220, child: _heroCard()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('Thành Lạc An', style: titleStyle(24)),
                            const Spacer(),
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
    final glowItem = h.equip[Slot.weapon];
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              child: FigurePreview(
                hanh: h.hanh,
                female: h.female,
                scale: 2,
                glow: glowItem != null && glowItem.rarity.index >= 2 ? glowItem.rarity.color : 0,
              ),
            ),
          ),
          Text(h.name, style: titleStyle(20, color: cream)),
          if (h.title.isNotEmpty)
            Text('« ${h.title} »', style: small.copyWith(color: goldLight, fontStyle: FontStyle.italic)),
          Text('${h.sect.name} · Cấp ${h.level}', style: body.copyWith(color: hanhColor(h.hanh))),
          if (h.rebirths > 0)
            Text('Chuyển sinh lần ${h.rebirths}', style: small.copyWith(color: goldLight, fontWeight: FontWeight.w700)),
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
                Text('Chính tuyến ${h.mainQuest + 1}/${mainQuests.length}: ${q.title}',
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

  Widget _grid(bool pending) {
    final tiles = [
      _Tile('Luyện công', Icons.landscape, () => _go(const MapListScreen())),
      _Tile('Vượt ải', Icons.castle, () => _go(const DungeonListScreen())),
      _Tile('Nhiệm vụ', Icons.assignment, () => _go(const QuestScreen()),
          badge: h.daily.where((d) => !d.done).length),
      _Tile('Nhân vật', Icons.person, () => _go(const CharacterScreen(tab: 0)),
          badge: pending ? h.freePoints + h.skillPoints : 0),
      _Tile('Linh thú', Icons.pets, () => _go(const PetScreen())),
      _Tile('Hành trang', Icons.backpack, () => _go(const CharacterScreen(tab: 2)),
          badge: 0),
      _Tile('Tiệm thuốc', Icons.storefront, () => _go(const ShopScreen())),
      _Tile('Thợ rèn', Icons.hardware, () => _go(const CharacterScreen(tab: 3, forge: true))),
      _Tile('Thành tựu', Icons.emoji_events, () => _go(const AchievementsScreen()),
          badge: claimableCount(h)),
      _Tile('Quà đăng nhập', Icons.card_giftcard, () async {
        await showLoginGiftDialog(context, h);
        if (mounted) setState(() {});
      }, badge: h.lastLoginDate == todayKey() ? 0 : 1),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 4 * 8) / 5;
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: goldLight, size: 26),
                  const SizedBox(height: 2),
                  Text(label,
                      style: bold.copyWith(fontSize: 12.5),
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
