import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/hero.dart';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final m in mounts) Expanded(child: _card(m))],
    );
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
            Text(m.name,
                style: titleStyle(m.name.length > 12 ? 13.5 : 16, color: owned ? goldLight : creamDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Expanded(
              child: Opacity(
                opacity: owned ? 1 : 0.45,
                child: LayoutBuilder(
                  builder: (_, c) => Center(
                    child: MountPreview(
                      mount: m,
                      rider: ridden ? lookOfHero(h) : null,
                      size: math.max(60, math.min(c.maxWidth, c.maxHeight)),
                    ),
                  ),
                ),
              ),
            ),
            Text(m.desc, style: small.copyWith(fontSize: 10.5), maxLines: 3),
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
