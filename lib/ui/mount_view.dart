import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/hero.dart';
import '../core/mount_skins.dart';
import '../core/mounts.dart';
import '../render/art_chibi.dart';
import '../render/art_figures.dart';
import '../services/save.dart';
import 'theme.dart';

/// Thú cưỡi: buy, earn, feed and ride.
class MountView extends StatefulWidget {
  const MountView({super.key});

  @override
  State<MountView> createState() => _MountViewState();
}

class _MountViewState extends State<MountView> {
  HeroData get h => SaveService.instance.hero;

  void _changed() {
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Ten mounts and counting: cards keep a readable width and the row
    // scrolls sideways once they no longer fit.
    return LayoutBuilder(
      builder: (_, c) {
        final w = math.max(158.0, c.maxWidth / mounts.length);
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [for (final m in mounts) SizedBox(width: w, child: _card(m))],
        );
      },
    );
  }

  Future<void> _skins(MountDef m) async {
    await showDialog<void>(context: context, builder: (_) => MountSkinDialog(mount: m));
    _changed();
  }

  Widget _card(MountDef m) {
    final owned = h.ownsMount(m.id);
    final lv = h.mountLevels[m.id] ?? 1;
    final ridden = h.ridingMount?.id == m.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Panel(
        border: ridden ? goldLight : (owned ? gold : gold.withValues(alpha: 0.4)),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(m.name,
                      style: titleStyle(m.name.length > 12 ? 13.5 : 16, color: owned ? goldLight : creamDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (skinsOf(m.id).isNotEmpty)
                  GestureDetector(
                    onTap: () => _skins(m),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.palette, size: 20, color: owned ? goldLight : creamDim),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Opacity(
                opacity: owned ? 1 : 0.45,
                child: LayoutBuilder(
                  builder: (_, c) => Center(
                    child: MountPreview(
                      mount: owned ? h.dressed(m) : m,
                      rider: ridden ? lookOfHero(h) : null,
                      size: math.max(60, math.min(c.maxWidth, c.maxHeight)),
                    ),
                  ),
                ),
              ),
            ),
            Text(m.desc, style: small.copyWith(fontSize: 10.5), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(owned ? 'Cấp $lv/$maxMountLevel' : m.howTo, style: bold.copyWith(fontSize: 12, color: cream)),
            Text(m.bonusText(lv), style: small.copyWith(fontSize: 10.5)),
            const SizedBox(height: 6),
            if (owned) ...[
              LButton(
                label: ridden ? 'Xuống ngựa' : 'Cưỡi',
                small: true,
                color: ridden ? jade : seal,
                onTap: () {
                  h.rideMount(m.id);
                  _changed();
                },
              ),
              const SizedBox(height: 4),
              LButton(
                label: lv >= maxMountLevel ? 'Tối đa' : 'Nâng ${fmt(mountLevelCost(lv))}',
                small: true,
                color: const Color(0xFF7A5A1A),
                enabled: lv < maxMountLevel && h.gold >= mountLevelCost(lv),
                onTap: () {
                  if (h.feedMount(m)) _changed();
                },
              ),
            ] else if (m.source == MountSource.gold)
              LButton(
                label: h.mountsOpen ? 'Mua ${fmt(m.need)}' : 'Mở ở cấp $mountOpenLevel',
                small: true,
                color: jade,
                enabled: h.mountsOpen && h.gold >= m.need,
                onTap: () {
                  if (h.buyMount(m)) _changed();
                },
              )
            else
              Text(
                switch (m.source) {
                  MountSource.tower => 'Tầng cao nhất: ${h.towerBest}/${m.need}',
                  MountSource.rebirth => 'Đã chuyển sinh: ${h.rebirths}/${m.need}',
                  MountSource.abyss => 'Đã hạ Ma Tôn: ${h.abyssBossKills}/${m.need}',
                  MountSource.sea => 'Đã hạ Long Vương: ${h.seaBossKills}/${m.need}',
                  _ => 'Uy danh: ${fmt(h.arenaCoins)}/${fmt(m.need)}',
                },
                style: small.copyWith(fontSize: 10.5, color: creamDim),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Ngoại hình: the looks a mount can wear.
class MountSkinDialog extends StatefulWidget {
  const MountSkinDialog({super.key, required this.mount});
  final MountDef mount;

  @override
  State<MountSkinDialog> createState() => _MountSkinDialogState();
}

class _MountSkinDialogState extends State<MountSkinDialog> {
  HeroData get h => SaveService.instance.hero;

  @override
  Widget build(BuildContext context) {
    final m = widget.mount;
    final owned = h.ownsMount(m.id);
    final worn = h.mountSkin[m.id];
    Widget card({required String name, required MountDef look, required bool on, required Widget action, String? note}) =>
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Panel(
              border: on ? goldLight : gold.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Text(name, style: bold.copyWith(fontSize: 12.5, color: on ? goldLight : cream),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Expanded(child: ClipRect(child: Center(child: MountPreview(mount: look, size: look.look == 'sword' ? 82 : 110)))),
                  if (note != null) Text(note, style: small.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  action,
                ],
              ),
            ),
          ),
        );
    return Dialog(
      backgroundColor: lacquer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ngoại hình · ${m.name}', style: titleStyle(18, color: goldLight)),
            Text(owned ? 'Chỉ đổi dáng vẻ, chỉ số giữ nguyên.' : 'Cần có ${m.name} trước.',
                style: small.copyWith(fontSize: 11)),
            const SizedBox(height: 6),
            SizedBox(
              height: 230,
              child: ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                children: [
                  card(
                    name: 'Nguyên bản',
                    look: m,
                    on: worn == null,
                    action: LButton(
                      label: worn == null ? 'Đang dùng' : 'Dùng',
                      small: true,
                      color: jade,
                      enabled: owned && worn != null,
                      onTap: () => setState(() => h.wearSkin(m.id, null)),
                    ),
                  ),
                  for (final s in skinsOf(m.id))
                    card(
                      name: s.name,
                      look: m.skinned(s.c1, s.c2, s.c3, s.aura),
                      on: worn == s.id,
                      note: h.ownsSkin(s.id) ? null : s.howTo,
                      action: h.ownsSkin(s.id)
                          ? LButton(
                              label: worn == s.id ? 'Đang dùng' : 'Dùng',
                              small: true,
                              color: jade,
                              enabled: worn != s.id,
                              onTap: () => setState(() => h.wearSkin(m.id, s.id)),
                            )
                          : LButton(
                              label: s.source == SkinSource.tower ? 'Nhận' : 'Đổi',
                              small: true,
                              color: seal,
                              enabled: h.canGetSkin(s),
                              onTap: () => setState(() => h.getSkin(s)),
                            ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A mount, galloping on the spot, optionally with a rider.
class MountPreview extends StatefulWidget {
  const MountPreview({super.key, required this.mount, this.rider, this.size = 100});
  final MountDef mount;
  final HumanLook? rider;
  final double size;

  @override
  State<MountPreview> createState() => _MountPreviewState();
}

class _MountPreviewState extends State<MountPreview> with SingleTickerProviderStateMixin {
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
        painter: _MountPainter(_t, widget.mount, widget.rider),
      );
}

class _MountPainter extends CustomPainter {
  _MountPainter(this.t, this.mount, this.rider) : super(repaint: t);
  final ValueNotifier<double> t;
  final MountDef mount;
  final HumanLook? rider;

  @override
  void paint(Canvas c, Size s) {
    final time = t.value;
    // Trot for two seconds, stand for two.
    final moving = time % 4 < 2;
    c.save();
    c.translate(s.width * 0.45, s.height * 0.9);
    // About 80 units wide, 110 tall with a rider.
    final k = s.width / (rider == null ? 90 : 110);
    c.scale(k);
    drawShadow(c, 24);
    setClock(time);
    drawMount(c, mount, walk: time * 4, moving: moving, t: time);
    if (rider != null) {
      c.translate(0, -mountSeatOf(mount));
      drawChibi(c, rider!, t: time);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_MountPainter old) => old.mount != mount || old.rider != rider;
}
