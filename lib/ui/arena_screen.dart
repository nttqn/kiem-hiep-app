import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/arena.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../core/world_boss.dart';
import '../render/art_figures.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Lôi đài: the hero's standing, three challengers, and the Uy danh shop.
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  HeroData get h => SaveService.instance.hero;
  String get _day => vnDayKey();
  List<ArenaRival>? _rivals;
  List<ArenaRival> _pool = const [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    h.arenaRollDay(_day);
    _load();
  }

  /// Fetches real players near the hero's power, once per visit.
  Future<void> _load() async {
    try {
      _pool = await Leaderboard.instance.arenaPool(h.power);
    } catch (_) {
      _pool = const [];
    }
    if (mounted) setState(_pick);
  }

  void _pick() {
    final seed = h.seed ^ _day.hashCode ^ (h.arenaRefresh * 7919);
    final bots = botRivals(power: h.power, level: h.level, rebirths: h.rebirths, seed: seed);
    _rivals = pickRivals(_pool, bots, h.power, seed);
  }

  Future<void> _fight(ArenaRival r) async {
    if (!h.arenaStart(_day)) return;
    await SaveService.instance.save();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(arenaDef(r))));
    h.arenaRefresh++;
    await SaveService.instance.save();
    if (mounted) setState(_pick);
  }

  void _toast(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Lôi đài',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 215, child: _standing()),
          const SizedBox(width: 8),
          Expanded(child: _challengers()),
          const SizedBox(width: 8),
          SizedBox(width: 240, child: _shop()),
        ],
      ),
    );
  }

  Widget _standing() {
    final tier = arenaTiers[h.arenaTier];
    final next = h.arenaTier + 1 < arenaTiers.length ? arenaTiers[h.arenaTier + 1] : null;
    final salary = h.arenaSalaryReady(_day);
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tier.name, style: titleStyle(22, color: Color(tier.color)), textAlign: TextAlign.center),
          Text('${h.arenaPoints} điểm', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          if (next != null)
            Text('Lên ${next.name}: ${next.min} điểm', style: small.copyWith(fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Uy danh: ${fmt(h.arenaCoins)}', style: bold.copyWith(color: goldLight), textAlign: TextAlign.center),
          Text('Thắng: ${h.arenaWins} trận', style: small, textAlign: TextAlign.center),
          const Spacer(),
          Text('Lượt đấu còn: ${h.arenaFightsLeft}', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          Text('Mỗi trận ${arenaTime.round()} giây, tối đa $arenaPotions bình máu.',
              style: small.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
          if (h.arenaAds < arenaAdFights) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.rewardedReady,
              builder: (_, ready, _) => LButton(
                label: 'Quảng cáo: +1 lượt',
                icon: Icons.ondemand_video,
                small: true,
                color: const Color(0xFF8A5A10),
                enabled: ready,
                onTap: () async {
                  final earned = await AdsService.instance.showRewarded();
                  if (!earned || !mounted) return;
                  h.arenaAddAdFight(_day);
                  SaveService.instance.save();
                  setState(() {});
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
          LButton(
            label: salary ? 'Bổng lộc hôm nay' : 'Đã nhận bổng lộc',
            icon: Icons.paid,
            small: true,
            color: jade,
            enabled: salary,
            onTap: () {
              if (!h.arenaClaimSalary(_day)) return;
              SaveService.instance.save();
              _toast('+${arenaDailyCoins(h.arenaTier)} Uy danh, '
                  '+${fmt(arenaDailyGold(h.arenaTier, h.level))} lượng');
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _challengers() {
    final rivals = _rivals;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Khiêu chiến', style: titleStyle(18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Lực chiến của bạn: ${fmt(h.power)}',
                    style: small.copyWith(color: goldLight), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Đổi đối thủ',
                onPressed: rivals == null
                    ? null
                    : () {
                        h.arenaRefresh++;
                        SaveService.instance.save();
                        setState(_pick);
                      },
                icon: const Icon(Icons.refresh, color: goldLight),
              ),
            ],
          ),
          Expanded(
            child: rivals == null
                ? const Center(child: CircularProgressIndicator(color: goldLight))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final r in rivals) Expanded(child: _rival(r))],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _rival(ArenaRival r) {
    final ratio = r.power / math.max(1, h.power);
    final (label, colr) = ratio < 0.9
        ? ('Dễ', const Color(0xFF8CE07A))
        : ratio <= 1.1
            ? ('Ngang tài', goldLight)
            : ('Khó', const Color(0xFFFF8A6A));
    final left = h.arenaFightsLeft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: lacquerDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hanhColor(r.hanh).withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.name, style: bold.copyWith(color: cream), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            Text(sectOf(r.hanh).name,
                style: small.copyWith(fontSize: 10.5, color: hanhColor(r.hanh)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            Text('Cấp ${r.level}${r.rebirths > 0 ? ' · Chuyển sinh ${r.rebirths}' : ''}',
                style: small.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
            Expanded(
              child: FittedBox(
                child: FigurePreview(hanh: r.hanh, female: r.female, scale: 1.6, gear: rivalGear(r), rebirths: r.rebirths),
              ),
            ),
            Text('Lực chiến ${fmt(r.power)}', style: small.copyWith(fontSize: 11, color: goldLight), textAlign: TextAlign.center),
            Text(r.bot ? '$label · cao thủ giang hồ' : '$label · người chơi',
                style: small.copyWith(fontSize: 10.5, color: colr), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            LButton(
              label: left > 0 ? 'Đấu' : 'Hết lượt',
              small: true,
              color: seal,
              enabled: left > 0,
              onTap: () => _fight(r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shop() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tiệm Uy danh', style: titleStyle(18)),
          Text('Uy danh: ${fmt(h.arenaCoins)}', style: bold.copyWith(color: goldLight)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (final o in arenaShop(h.level))
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
                    decoration: BoxDecoration(
                      color: lacquerDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(o.name, style: small.copyWith(fontSize: 11.5, color: cream))),
                        const SizedBox(width: 6),
                        LButton(
                          label: o.kind == ArenaWare.mount && h.ownsMount(o.id) ? 'Đã có' : fmt(o.price),
                          small: true,
                          color: jade,
                          enabled: h.arenaCoins >= o.price && !(o.kind == ArenaWare.mount && h.ownsMount(o.id)),
                          onTap: () {
                            if (!h.arenaBuy(o, _rng)) return;
                            SaveService.instance.save();
                            _toast('Đã đổi ${o.name}');
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

