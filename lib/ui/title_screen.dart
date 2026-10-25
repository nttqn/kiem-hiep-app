import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../services/cloud.dart';
import '../services/save.dart';
import '../services/sound.dart';
import '../services/sync_plan.dart';
import 'cloud_panel.dart';
import '../render/art_figures.dart';
import 'backdrop.dart';
import 'create_screen.dart';
import 'theme.dart';
import 'town_screen.dart';

const gameTitle = 'Kiếm Hiệp Ngũ Hành';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  void initState() {
    super.initState();
    SoundService.instance.playMusic('menu');
    // A newer save played on another phone shows up here after sync.
    CloudSave.instance.addListener(_checkConflicts);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConflicts());
  }

  @override
  void dispose() {
    CloudSave.instance.removeListener(_checkConflicts);
    super.dispose();
  }

  void _checkConflicts() {
    if (!mounted || CloudSave.instance.conflicts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) resolveConflicts(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([SaveService.instance, CloudSave.instance]),
            builder: (context, _) => Stack(
              children: [
                const Positioned(right: 8, top: 4, child: CloudButton()),
                Positioned.fill(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return Builder(
      builder: (context) => Column(
        children: [
          const SizedBox(height: 14),
          Text(gameTitle.toUpperCase(), style: titleStyle(34)),
          const SizedBox(height: 4),
          Text(
            'Ngũ hành tương khắc · Ngũ phái tranh hùng',
            style: body.copyWith(color: goldLight.withValues(alpha: 0.85)),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slotCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _SlotCard(index: i),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.index});
  final int index;

  /// The backup worth offering for this slot: the local or cloud one that
  /// got furthest, if it beats (or differs from) what the slot holds.
  HeroData? _backup() {
    final cur = SaveService.instance.slots[index];
    final curInfo = cur == null ? null : SlotInfo.ofHero(cur);
    HeroData? best;
    for (final b in [SaveService.instance.backups[index], CloudSave.instance.cloudBackupHero(index)]) {
      if (b == null || !backupWorthOffering(curInfo, SlotInfo.ofHero(b))) continue;
      if (best == null || compareProgress(SlotInfo.ofHero(b), SlotInfo.ofHero(best)) > 0) best = b;
    }
    return best;
  }

  Future<void> _restore(BuildContext context, HeroData b) async {
    final cur = SaveService.instance.slots[index];
    final bInfo = SlotInfo.ofHero(b);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Khôi phục bản dự phòng?', style: titleStyle(20)),
        content: Text(
          'Đưa ${b.name} (${b.sect.name}, ${bInfo.levelText}) về ô ${index + 1}.'
          '${cur == null ? '' : ' Bản đang có (${cur.name}, ${SlotInfo.ofHero(cur).levelText}) sẽ được cất làm bản dự phòng.'}',
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục', style: TextStyle(color: Color(0xFF8CE07A), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await SaveService.instance.restore(index, b);
  }

  @override
  Widget build(BuildContext context) {
    final b = _backup();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _card(context),
        SizedBox(
          height: 30,
          child: b == null
              ? null
              : TextButton.icon(
                  onPressed: () => _restore(context, b),
                  icon: const Icon(Icons.restore, size: 16, color: goldLight),
                  label: Text('Bản dự phòng: ${SlotInfo.ofHero(b).levelText}',
                      style: small.copyWith(color: goldLight, fontWeight: FontWeight.w700)),
                ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context) {
    final h = SaveService.instance.slots[index];
    return GestureDetector(
      onTap: () => _open(context, h),
      onLongPress: h == null ? null : () => _confirmDelete(context, h),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: SizedBox(
          width: 178,
          height: 176,
          child: h == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 44,
                      color: gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo nhân vật',
                      style: bold.copyWith(color: goldLight),
                    ),
                    Text('Ô ${index + 1}', style: small),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FigurePreview(
                          hanh: h.hanh,
                          female: h.female,
                          scale: 1.25,
                          gear: HeroGear.of(h.equip),
                        ),
                      ),
                    ),
                    Text(
                      h.name,
                      style: bold.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: hanhColor(h.hanh),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${h.sect.name} · Cấp ${h.level}',
                          style: small.copyWith(color: cream),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LButton(
                      label: 'Vào game',
                      small: true,
                      onTap: () => _open(context, h),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, HeroData? h) {
    if (h == null) {
      Navigator.of(context).push(fadeRoute(CreateScreen(slot: index)));
      return;
    }
    SaveService.instance.active = index;
    if (h.savedAt > 0) {
      SaveService.instance.pendingAway =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(h.savedAt));
    }
    Navigator.of(context).pushReplacement(fadeRoute(const TownScreen()));
  }

  Future<void> _confirmDelete(BuildContext context, HeroData h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Xóa nhân vật?', style: titleStyle(20)),
        content: Text(
          '${h.name} (${h.sect.name}, cấp ${h.level}) sẽ bị xóa vĩnh viễn.',
          style: body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFFF7A6A)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) SaveService.instance.delete(index);
  }
}
