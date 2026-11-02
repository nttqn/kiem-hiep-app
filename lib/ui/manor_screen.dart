import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/clock.dart';
import '../core/gold_sets.dart' show bonusLabel;
import '../core/hero.dart';
import '../core/manor.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Trang viên: the fields on the left, the silkworm house, the estate and
/// its keepsakes on the right.
class ManorScreen extends StatefulWidget {
  const ManorScreen({super.key});

  @override
  State<ManorScreen> createState() => _ManorScreenState();
}

class _ManorScreenState extends State<ManorScreen> {
  HeroData get h => SaveService.instance.hero;
  Manor get m => h.manor;
  int get _now => GameClock.nowMs();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    h.manorVisit(_now);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    SaveService.instance.save();
    super.dispose();
  }

  void _toast(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  void _done(String s) {
    SaveService.instance.save();
    setState(() {});
    if (s.isNotEmpty) _toast(s);
  }

  static String left(int ms) {
    final s = (ms / 1000).ceil();
    if (s >= 3600) return '${s ~/ 3600} giờ ${(s % 3600) ~/ 60} phút';
    if (s >= 60) return '${s ~/ 60} phút ${s % 60} giây';
    return '$s giây';
  }

  @override
  Widget build(BuildContext context) {
    final ripe = m.plots.take(m.openPlots).where((p) => p.ready(_now)).length;
    return SubScreen(
      title: 'Trang viên · Cấp ${m.level}',
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('Tơ tằm: ${fmt(m.silk)}', style: bold.copyWith(color: const Color(0xFFE8E0FF))),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Ruộng linh thảo', style: titleStyle(18)),
                      const Spacer(),
                      LButton(
                        label: ripe > 0 ? 'Thu hoạch ($ripe)' : 'Chưa có ruộng chín',
                        icon: Icons.agriculture,
                        small: true,
                        color: jade,
                        enabled: ripe > 0,
                        onTap: () => _done(h.manorHarvest(_now).join(', ')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.25,
                      children: [for (var i = 0; i < manorPlots; i++) _plot(i)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 250,
            child: ListView(
              children: [
                _silkCard(),
                const SizedBox(height: 8),
                _estateCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plot(int i) {
    final locked = i >= m.openPlots;
    final p = m.plots[i];
    final now = _now;
    final ready = p.ready(now);
    final unlockAt = [for (var l = 1; l <= manorMaxLevel; l++) if (manorPlotsAt(l) > i) l].firstOrNull ?? manorMaxLevel;
    final label = locked
        ? 'Mở ở trang viên cấp $unlockAt'
        : p.empty
            ? 'Trống · chạm để gieo'
            : ready
                ? '${herbNames[p.tier]} đã chín!'
                : '${herbNames[p.tier]} · còn ${left(p.readyAt - now)}';
    return GestureDetector(
      onTap: locked
          ? null
          : p.empty
              ? () => _sow(i)
              : ready
                  ? () => _done(h.manorHarvest(now).join(', '))
                  : null,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: lacquerDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ready ? const Color(0xFF8CE07A) : gold.withValues(alpha: 0.5), width: ready ? 2 : 1),
          ),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _FieldPainter(locked ? -1 : p.tier, p.grown(now), ready, now / 1000.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                child: Text(label,
                    style: small.copyWith(fontSize: 10.5, color: ready ? const Color(0xFF8CE07A) : cream),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sow(int i) async {
    final c = await showDialog<Crop>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Gieo hạt', style: titleStyle(20)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in crops)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.spa, color: Color(herbColors[c.tier]), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: bold.copyWith(fontSize: 13.5)),
                            Text(
                              h.cropOpen(c)
                                  ? '${left(cropMinutes(c, m.level) * 60000)} · thu ${cropYield(m.level)} cây'
                                  : 'Mở ở cấp ${c.openLv}',
                              style: small.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      LButton(
                        label: fmt(c.seedGold),
                        icon: Icons.monetization_on,
                        small: true,
                        color: jade,
                        enabled: h.cropOpen(c) && h.gold >= c.seedGold,
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                    ],
                  ),
                ),
              Text('Linh thảo dùng để luyện đan. Ruộng lớn theo giờ thật, kể cả khi tắt game.',
                  style: small.copyWith(fontSize: 11)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
    if (c == null || !mounted) return;
    if (h.manorSow(i, c, _now)) _done('Đã gieo ${c.name}');
  }

  Widget _silkCard() {
    final now = _now;
    final waiting = m.silkWaiting(now);
    final full = waiting >= (silkStoreHours * silkPerHour(m.level)).floor();
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.house_siding, color: Color(0xFFE8E0FF), size: 22),
              const SizedBox(width: 6),
              Text('Nhà tằm', style: titleStyle(17)),
            ],
          ),
          Text('Nhả ${silkPerHour(m.level).toStringAsFixed(1)} tơ mỗi giờ, chứa tối đa ${silkStoreHours.round()} giờ.',
              style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(full ? 'Đã đầy: $waiting tơ' : 'Đang chờ: $waiting tơ',
              style: bold.copyWith(color: full ? const Color(0xFFFF9A6A) : cream)),
          const SizedBox(height: 4),
          LButton(
            label: 'Thu tơ',
            icon: Icons.inventory,
            small: true,
            color: jade,
            enabled: waiting > 0,
            onTap: () => _done('+${h.manorCollectSilk(_now)} Tơ tằm'),
          ),
          const SizedBox(height: 6),
          LButton(
            label: 'Bán 10 tơ (+${fmt(10 * silkPrice(h.level))})',
            small: true,
            color: const Color(0xFF8A5A10),
            enabled: m.silk >= 10,
            onTap: () => _done('+${fmt(h.manorSellSilk(10))} lượng'),
          ),
        ],
      ),
    );
  }

  Widget _estateCard() {
    final maxed = m.level >= manorMaxLevel;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.villa, color: goldLight, size: 22),
              const SizedBox(width: 6),
              Text('Trang viên', style: titleStyle(17)),
            ],
          ),
          Text(
            maxed
                ? 'Đã đạt cấp tối đa.'
                : 'Lên cấp ${m.level + 1}: ${manorPlotsAt(m.level + 1)} ruộng, cây lớn nhanh hơn, nhiều tơ hơn, '
                    'mở thêm đồ bày biện.',
            style: small.copyWith(fontSize: 11),
          ),
          if (!maxed) ...[
            const SizedBox(height: 2),
            Text('Cần ${fmt(manorUpGold(m.level))} lượng và ${manorUpSilk(m.level)} tơ.',
                style: bold.copyWith(fontSize: 12, color: goldLight)),
            const SizedBox(height: 4),
            LButton(
              label: 'Nâng cấp',
              icon: Icons.upgrade,
              small: true,
              color: jade,
              enabled: h.manorCanUpgrade,
              onTap: () {
                if (h.manorUpgrade(_now)) _done('Trang viên lên cấp ${m.level}!');
              },
            ),
          ],
          const SizedBox(height: 6),
          LButton(
            label: 'Bày biện (${m.keepsakesOwned.length}/${keepsakes.length})',
            icon: Icons.chair,
            small: true,
            color: const Color(0xFF5A3A7A),
            onTap: _keepsakes,
          ),
        ],
      ),
    );
  }

  Future<void> _keepsakes() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: lacquer,
          title: Text('Bày biện', style: titleStyle(20)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mỗi món mua bằng tơ tằm, bày trong sảnh và cộng chỉ số mãi mãi. Hiện có ${fmt(m.silk)} tơ.',
                      style: small.copyWith(fontSize: 11.5)),
                  const SizedBox(height: 6),
                  for (final k in keepsakes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(m.keepsakesOwned.contains(k.id) ? Icons.check_circle : Icons.chair_alt,
                              color: m.keepsakesOwned.contains(k.id) ? const Color(0xFF8CE07A) : goldLight, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${k.name} · ${bonusLabel(k.bonus)} +${_pct(k.value)}', style: bold.copyWith(fontSize: 13)),
                                Text(k.desc, style: small.copyWith(fontSize: 10.5)),
                              ],
                            ),
                          ),
                          if (!m.keepsakesOwned.contains(k.id))
                            LButton(
                              label: m.level < k.openLv ? 'TV cấp ${k.openLv}' : '${k.silk} tơ',
                              small: true,
                              color: jade,
                              enabled: m.level >= k.openLv && m.silk >= k.silk,
                              onTap: () {
                                if (h.manorBuy(k)) {
                                  SaveService.instance.save();
                                  setD(() {});
                                  setState(() {});
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      ),
    );
  }
}

/// A field: tilled rows, and a herb growing from a sprout to a ripe plant
/// that glows in its herb's colour.
class _FieldPainter extends CustomPainter {
  _FieldPainter(this.tier, this.grown, this.ready, this.t);
  final int tier;
  final double grown;
  final bool ready;
  final double t;

  @override
  void paint(Canvas c, Size s) {
    final soil = Rect.fromLTWH(8, s.height * 0.35, s.width - 16, s.height * 0.6);
    c.drawRRect(RRect.fromRectAndRadius(soil, const Radius.circular(6)), Paint()..color = const Color(0xFF5A3A24));
    for (var k = 1; k < 4; k++) {
      final y = soil.top + soil.height * k / 4;
      c.drawLine(Offset(soil.left + 6, y), Offset(soil.right - 6, y), Paint()
        ..color = const Color(0xFF3E2616)
        ..strokeWidth = 2);
    }
    if (tier < 0) return;
    final colr = Color(herbColors[tier]);
    final n = 3;
    for (var i = 0; i < n; i++) {
      final x = soil.left + soil.width * (i + 0.5) / n;
      final base = soil.top + soil.height * 0.7;
      final hgt = 6 + grown * (s.height * 0.42);
      final sway = math.sin(t * 1.5 + i) * 2 * grown;
      c.drawLine(Offset(x, base), Offset(x + sway, base - hgt), Paint()
        ..color = const Color(0xFF4E8A3A)
        ..strokeWidth = 2.4);
      final leaf = 3 + grown * 7;
      for (final side in const [-1.0, 1.0]) {
        c.drawOval(
            Rect.fromCenter(center: Offset(x + sway * 0.6 + side * leaf * 0.7, base - hgt * 0.55), width: leaf * 1.4, height: leaf * 0.7),
            Paint()..color = const Color(0xFF5EA844));
      }
      if (grown > 0.6) {
        final r = 2 + (grown - 0.6) * 12;
        if (ready) {
          c.drawCircle(Offset(x + sway, base - hgt), r * 2.4,
              Paint()..color = colr.withValues(alpha: 0.25 + 0.15 * math.sin(t * 3 + i)));
        }
        c.drawCircle(Offset(x + sway, base - hgt), r, Paint()..color = colr);
      }
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) =>
      old.tier != tier || old.grown != grown || old.ready != ready || old.t != t;
}

/// 0.015 → "1,5%", 0.04 → "4%".
String _pct(double v) {
  final p = v * 100;
  return '${p.toStringAsFixed(p % 1 == 0 ? 0 : 1).replaceAll('.', ',')}%';
}
