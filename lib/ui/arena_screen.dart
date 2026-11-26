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
import 'dai_hoi_screen.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

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
    if (h.arenaSeasonResult.isNotEmpty) {
      SaveService.instance.save();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _seasonEnded();
        await _rankReward();
      });
    } else if (h.arenaRankDue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rankReward());
    }
  }

  /// Looks up the finished season's leaderboard place and pays the top 50
  /// (tried again next visit when offline).
  Future<void> _rankReward() async {
    if (!h.arenaRankDue || !Leaderboard.instance.available) return;
    final place = await Leaderboard.instance.placeLastSeason(h.arenaLastScore);
    if (place == null || !mounted) return;
    final lines = h.payArenaRank(place);
    await SaveService.instance.save();
    if (lines.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(tr('Thưởng xếp hạng mùa'), style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lines.first, style: bold.copyWith(color: goldLight)),
            const SizedBox(height: 6),
            for (final l in lines.skip(1)) Text('• $l', style: body),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Nhận')))],
      ),
    );
    if (mounted) setState(() {});
  }

  /// Tells how the last season ended and what it paid, once.
  Future<void> _seasonEnded() async {
    final r = h.arenaSeasonResult;
    final lines = h.arenaSeasonLines();
    if (r.length < 3 || !mounted) return;
    final tier = arenaTiers[r[1]];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(tr('Kết thúc mùa {p0}', {'p0': r[0]}), style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: ArtIcon('arena_${r[1]}', fallback: Icons.shield, size: 96, color: Color(tier.color))),
            Text(tr('Hạng cuối mùa: {tierName} ({p0} điểm)', {'tierName': tr(tier.name), 'p0': r[2]}), style: bold.copyWith(color: Color(tier.color))),
            const SizedBox(height: 6),
            for (final l in lines) Text('• $l', style: body),
            const SizedBox(height: 6),
            Text(tr('Mùa {p0} bắt đầu với {arenaPoints} điểm.', {'p0': arenaSeasonOf(_day), 'arenaPoints': h.arenaPoints}), style: small),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Nhận')))],
      ),
    );
    h.arenaSeasonResult = const [];
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  /// Season rewards by tier and this season's top players.
  void _seasonInfo() {
    final season = arenaSeasonOf(_day);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: lacquer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 340),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr('Mùa {season} · còn {p0} ngày', {'season': season, 'p0': arenaSeasonDaysLeft(_day)}), style: titleStyle(18)),
                      Text(tr('Thưởng theo hạng lúc hết mùa (cần đấu ít nhất 1 trận trong mùa):'),
                          style: small.copyWith(fontSize: 11)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView(
                          children: [
                            for (var i = arenaTiers.length - 1; i >= 0; i--) _rewardRow(i),
                          ],
                        ),
                      ),
                      Text(
                        tr('Thêm theo thứ hạng trên bảng: hạng 1 « Lôi Đài Bá Chủ » +1500 Uy danh +20 Thần Thiết; '
                        'top 3 « Lôi Đài Tam Hùng » +1000, +12; top 10 « Lôi Đài Thập Kiệt » +600, +6; top 50 +300, +3.'),
                        style: small.copyWith(fontSize: 10.5, color: goldLight),
                      ),
                      Text(
                        tr('Sang mùa mới: điểm = 1000 + một nửa phần vượt 1000. '
                        'Hết mùa ở Bạch Kim mở ngoại trang Lôi Đài Bá Chủ, ở Võ Lâm Chí Tôn mở Chí Tôn Chiến Bào.'),
                        style: small.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 250, child: _seasonTop()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardRow(int i) {
    final t = arenaTiers[i];
    final r = arenaSeasonReward(i, h.level);
    final mine = i == h.arenaTier;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: mine ? Color.lerp(lacquer, seal, 0.4) : lacquerDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mine ? goldLight : gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ArtIcon('arena_$i', fallback: Icons.shield, size: 26, color: Color(t.color)),
          const SizedBox(width: 4),
          SizedBox(width: 104, child: Text(tr(t.name), style: bold.copyWith(fontSize: 12, color: Color(t.color)))),
          Expanded(
            child: Text(
              tr('{p0} Uy danh · {p1} lượng'
              '{p2}{p3}', {'p0': fmt(r.coins), 'p1': fmt(r.gold), 'p2': r.shards > 0 ? tr(' · {shards} mảnh HK', {'shards': r.shards}) : '', 'p3': r.gemTier > 0 ? tr(' · ngọc {gemTier}', {'gemTier': r.gemTier}) : ''}),
              style: small.copyWith(fontSize: 10.5, color: cream),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonTop() {
    final lb = Leaderboard.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Cao thủ mùa này'), style: bold.copyWith(color: goldLight)),
        const SizedBox(height: 4),
        Expanded(
          child: !lb.available
              ? Text(tr('Đăng nhập (nút mây ở Thành) để xem và lên bảng Lôi đài.'), style: small)
              : FutureBuilder<LbPage>(
                  future: lb.top(LbBoard.arena, limit: 30),
                  builder: (_, snap) {
                    if (snap.hasError) return Text(tr('Không tải được bảng.'), style: small);
                    final rows = snap.data?.rows;
                    if (rows == null) return const Center(child: CircularProgressIndicator(color: goldLight));
                    if (rows.isEmpty) return Text(tr('Chưa ai lên bảng mùa này.'), style: small);
                    return ListView(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                SizedBox(width: 26, child: Text('${i + 1}', style: bold.copyWith(fontSize: 12))),
                                Expanded(
                                  child: Text(rows[i].name,
                                      style: small.copyWith(color: cream), overflow: TextOverflow.ellipsis),
                                ),
                                Text('${rows[i].arenaS % 100000}', style: bold.copyWith(fontSize: 12, color: goldLight)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
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
      title: tr('Lôi đài'),
      actions: [
        LButton(
          label: tr('Võ Lâm Đại Hội'),
          icon: Icons.emoji_events,
          small: true,
          color: const Color(0xFF8A2A1A),
          enabled: h.daiHoiOpen,
          onTap: () async {
            await Navigator.of(context).push(fadeRoute(const DaiHoiScreen()));
            if (mounted) setState(() {});
          },
        ),
      ],
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
      // The standing scrolls; the fights and buttons stay in sight on a short
      // phone (1.13.0: "Bổng lộc hôm nay" fell off the bottom).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
          Center(child: ArtIcon('arena_${h.arenaTier}', fallback: Icons.shield, size: 84, color: Color(tier.color))),
          Text(tr(tier.name), style: titleStyle(22, color: Color(tier.color)), textAlign: TextAlign.center),
          Text(tr('{arenaPoints} điểm', {'arenaPoints': h.arenaPoints}), style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          if (next != null)
            Text(tr('Lên {nextName}: {min} điểm', {'nextName': tr(next.name), 'min': next.min}), style: small.copyWith(fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(tr('Uy danh: {p0}', {'p0': fmt(h.arenaCoins)}), style: bold.copyWith(color: goldLight), textAlign: TextAlign.center),
          Text(tr('Thắng: {arenaWins} trận', {'arenaWins': h.arenaWins}), style: small, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          LButton(
            label: tr('Mùa {p0} · còn {p1} ngày', {'p0': arenaSeasonOf(_day), 'p1': arenaSeasonDaysLeft(_day)}),
            icon: Icons.emoji_events,
            small: true,
            color: const Color(0xFF5A3A7A),
            onTap: _seasonInfo,
          ),
          const SizedBox(height: 4),
          Text(tr('Mỗi trận {p0} giây, tối đa {arenaPotions} bình máu.', {'p0': arenaTime.round(), 'arenaPotions': arenaPotions}),
              style: small.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(tr('Lượt đấu còn: {arenaFightsLeft}', {'arenaFightsLeft': h.arenaFightsLeft}), style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          if (h.arenaAds < arenaAdFights) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: AdsService.instance.rewardedReady,
              builder: (_, ready, _) => LButton(
                label: tr('Quảng cáo: +1 lượt'),
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
            label: salary ? tr('Bổng lộc hôm nay') : tr('Đã nhận bổng lộc'),
            icon: Icons.paid,
            small: true,
            color: jade,
            enabled: salary,
            onTap: () {
              if (!h.arenaClaimSalary(_day)) return;
              SaveService.instance.save();
              _toast(tr('+{p0} Uy danh, '
                  '+{p1} lượng', {'p0': arenaDailyCoins(h.arenaTier), 'p1': fmt(arenaDailyGold(h.arenaTier, h.level))}));
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
              Text(tr('Khiêu chiến'), style: titleStyle(18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('Lực chiến của bạn: {p0}', {'p0': fmt(h.power)}),
                    style: small.copyWith(color: goldLight), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: tr('Đổi đối thủ'),
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
        ? (tr('Dễ'), const Color(0xFF8CE07A))
        : ratio <= 1.1
            ? (tr('Ngang tài'), goldLight)
            : (tr('Khó'), const Color(0xFFFF8A6A));
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
            Text(r.bot ? tr(r.name) : r.name, style: bold.copyWith(color: cream), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            Text(tr(sectOf(r.hanh).name),
                style: small.copyWith(fontSize: 10.5, color: hanhColor(r.hanh)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            Text(tr('{p0}Cấp {level}', {'p0': r.rebirths > 0 ? tr('CS{rebirths} · ', {'rebirths': r.rebirths}) : '', 'level': r.level}),
                style: small.copyWith(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            Expanded(
              child: FittedBox(
                child: FigurePreview(
                    hanh: r.hanh, female: r.female, scale: 1.6, gear: rivalGear(r), rebirths: r.rebirths, mount: r.mountDef),
              ),
            ),
            Text(tr('LC {p0}', {'p0': fmt(r.power)}),
                style: small.copyWith(fontSize: 11, color: goldLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            Text(r.bot ? tr('{label} · giang hồ', {'label': label}) : tr('{label} · người chơi', {'label': label}),
                style: small.copyWith(fontSize: 10.5, color: colr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            LButton(
              label: left > 0 ? tr('Đấu') : tr('Hết lượt'),
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
          Text(tr('Tiệm Uy danh'), style: titleStyle(18)),
          Text(tr('Uy danh: {p0}', {'p0': fmt(h.arenaCoins)}), style: bold.copyWith(color: goldLight)),
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
                        Expanded(child: Text(tr(o.name), style: small.copyWith(fontSize: 11.5, color: cream))),
                        const SizedBox(width: 6),
                        LButton(
                          label: o.kind == ArenaWare.mount && h.ownsMount(o.id) ? tr('Đã có') : fmt(o.price),
                          small: true,
                          color: jade,
                          enabled: h.arenaCoins >= o.price && !(o.kind == ArenaWare.mount && h.ownsMount(o.id)),
                          onTap: () {
                            if (!h.arenaBuy(o, _rng)) return;
                            SaveService.instance.save();
                            _toast(tr('Đã đổi {oName}', {'oName': tr(o.name)}));
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

