import 'package:flutter/material.dart';

import '../core/arena.dart';
import '../core/dai_hoi.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../core/weekly_hunt.dart';
import '../core/world_boss.dart';
import '../render/art_figures.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Võ Lâm Đại Hội: this week's bracket of eight and the hero's next duel.
class DaiHoiScreen extends StatefulWidget {
  const DaiHoiScreen({super.key});

  @override
  State<DaiHoiScreen> createState() => _DaiHoiScreenState();
}

class _DaiHoiScreenState extends State<DaiHoiScreen> {
  HeroData get h => SaveService.instance.hero;
  int get _week => huntWeekOf(vnDayKey());
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final paid = h.daiHoiRoll(_week);
    if (paid.isNotEmpty) {
      SaveService.instance.save();
      WidgetsBinding.instance.addPostFrameCallback((_) => _tell('Thưởng Đại Hội tuần trước', paid));
    }
  }

  Future<void> _tell(String title, List<String> lines) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          backgroundColor: lacquer,
          title: Text(title, style: titleStyle(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final l in lines) Text(l, style: bold.copyWith(color: cream))],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      );

  Future<void> _enter() async {
    if (_busy) return;
    setState(() => _busy = true);
    List<ArenaRival> pool;
    try {
      pool = await Leaderboard.instance.arenaPool(h.power);
    } catch (_) {
      pool = const [];
    }
    if (!mounted) return;
    h.daiHoiEnter(_week, daiHoiEntrants(pool, h.power, h.level, h.rebirths, h.seed ^ (_week * 7919)));
    await SaveService.instance.save();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _fight() async {
    final foe = h.dhNextFoe;
    if (foe == null) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(arenaDef(foe, round: daiHoiRounds[h.dhWins]))));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _rematch() async {
    final earned = await AdsService.instance.showRewarded();
    if (!earned || !mounted) return;
    if (h.daiHoiRematch()) await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _collect() async {
    final lines = h.daiHoiCollect();
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    if (lines.isNotEmpty) await _tell('Thưởng Đại Hội', lines);
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Võ Lâm Đại Hội',
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('Còn ${huntDaysLeft(vnDayKey())} ngày', style: bold.copyWith(color: goldLight)),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _bracket()),
          const SizedBox(width: 10),
          SizedBox(width: 250, child: _side()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- bracket

  /// Winners of [round] by pair, null while still to be fought.
  List<int?> _winners(List<int?> slots, int round) => [
        for (var i = 0; i < slots.length; i += 2)
          () {
            final a = slots[i], b = slots[i + 1];
            if (a == null || b == null) return null;
            if (a == 0 || b == 0) {
              final foe = a == 0 ? b : a;
              if (h.dhWins > round) return 0;
              if (h.dhOut && h.dhWins == round) return foe;
              return null;
            }
            // The other matches of a round are known once the hero's is.
            if (h.dhWins <= round && !h.dhDone) return null;
            return h.dhJudge(a, b) ? a : b;
          }(),
      ];

  Widget _bracket() {
    if (!h.dhEntered) {
      return Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrolls on a short phone; Ghi danh stays in sight.
            Expanded(
              child: ListView(
                children: [
            Text('Đại hội tuần này', style: titleStyle(22)),
            const SizedBox(height: 6),
            Text(
              'Mỗi tuần tám cao thủ tranh ngôi Minh Chủ: bạn và bảy người khác, '
              'phần lớn là bản sao nhân vật của người chơi thật trên bảng xếp hạng. '
              'Đấu loại trực tiếp ba trận: Tứ kết, Bán kết, Chung kết, mỗi vòng đối thủ mạnh hơn. '
              'Các cặp khác phân thắng thua theo lực chiến.',
              style: body.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text('Thua một trận được đấu lại một lần (xem quảng cáo). Vô địch nhận danh hiệu « $daiHoiTitle » '
                'và lên bảng xếp hạng Minh Chủ.',
                style: small.copyWith(color: goldLight)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: LButton(
                label: _busy ? 'Đang tìm đối thủ…' : 'Ghi danh',
                icon: Icons.how_to_reg,
                color: jade,
                enabled: !_busy,
                onTap: _enter,
              ),
            ),
          ],
        ),
      );
    }
    final qf = <int?>[for (var i = 0; i < 8; i++) i];
    final sf = _winners(qf, 0);
    final fi = _winners(sf, 1);
    final champ = _winners(fi, 2);
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _column(daiHoiRounds[0], qf, sf)),
          Expanded(flex: 5, child: _column(daiHoiRounds[1], sf, fi)),
          Expanded(flex: 5, child: _column(daiHoiRounds[2], fi, champ)),
          Expanded(flex: 4, child: _column('Minh Chủ', champ, const [])),
        ],
      ),
    );
  }

  Widget _column(String title, List<int?> slots, List<int?> next) {
    return Column(
      children: [
        Text(title, style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        const SizedBox(height: 2),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < slots.length; i++)
                _entrant(slots[i], lost: next.isNotEmpty && next[i ~/ 2] != null && next[i ~/ 2] != slots[i]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entrant(int? slot, {required bool lost}) {
    final me = slot == 0;
    final name = slot == null ? '?' : (me ? h.name : h.dhFoes[slot - 1].name);
    final power = slot == null ? null : h.dhPowers[slot];
    final hanh = slot == null ? null : (me ? h.hanh : h.dhFoes[slot - 1].hanh);
    return Opacity(
      opacity: lost ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: me ? Color.lerp(lacquer, seal, 0.4) : lacquerDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hanh == null ? const Color(0xFF5A4A3A) : hanhColor(hanh).withValues(alpha: 0.7)),
        ),
        // One line each, so eight fit on a small phone.
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: bold.copyWith(fontSize: 11, color: me ? goldLight : cream,
                      decoration: lost ? TextDecoration.lineThrough : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (power != null) ...[
              const SizedBox(width: 3),
              Text(_short(power), style: small.copyWith(fontSize: 9.5)),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- side

  Widget _side() {
    final foe = h.dhNextFoe;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!h.daiHoiOpen)
            Text('Mở ở cấp $daiHoiOpenLevel.', style: bold.copyWith(color: cream))
          else if (!h.dhEntered)
            Text('Chưa ghi danh tuần này.', style: bold.copyWith(color: cream), textAlign: TextAlign.center)
          else if (h.dhWins >= 3) ...[
            Icon(Icons.emoji_events, size: 64, color: goldLight.withValues(alpha: 0.9)),
            Text('Bạn là Minh Chủ tuần này!', style: titleStyle(18), textAlign: TextAlign.center),
            Text('Thứ Hai tuần sau mở đại hội mới.', style: small, textAlign: TextAlign.center),
          ] else if (h.dhOut) ...[
            Text('Dừng bước ở ${daiHoiRounds[h.dhWins]}', style: titleStyle(18, color: const Color(0xFFFF8A6A)),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            if (h.dhUnpaid) ...[
              if (!h.dhRetried)
                ValueListenableBuilder<bool>(
                  valueListenable: AdsService.instance.rewardedReady,
                  builder: (_, ready, _) => LButton(
                    label: 'Đấu lại (quảng cáo)',
                    icon: Icons.ondemand_video,
                    small: true,
                    color: const Color(0xFF8A5A10),
                    enabled: ready,
                    onTap: _rematch,
                  ),
                ),
              const SizedBox(height: 6),
              LButton(label: 'Nhận thưởng', icon: Icons.redeem, small: true, color: jade, onTap: _collect),
            ] else
              Text('Đã nhận thưởng. Hẹn tuần sau!', style: small, textAlign: TextAlign.center),
          ] else if (foe != null) ...[
            Text('${daiHoiRounds[h.dhWins]}: đối thủ', style: bold.copyWith(color: goldLight), textAlign: TextAlign.center),
            Text(foe.name, style: titleStyle(18, color: cream), textAlign: TextAlign.center, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('${sectOf(foe.hanh).name} · Cấp ${foe.level} · ${fmt(foe.power)}',
                style: small.copyWith(fontSize: 11, color: hanhColor(foe.hanh)), textAlign: TextAlign.center),
            Expanded(
              child: FittedBox(
                child: FigurePreview(
                    hanh: foe.hanh,
                    female: foe.female,
                    scale: 1.4,
                    gear: rivalGear(foe),
                    rebirths: foe.rebirths,
                    mount: foe.mountDef),
              ),
            ),
            LButton(label: 'Vào trận', icon: Icons.sports_kabaddi, color: jade, onTap: _fight),
          ],
          if (foe == null) const Spacer(),
          const SizedBox(height: 6),
          _prizes(),
          Text('Đã vô địch: ${h.dhChamps} lần', style: small.copyWith(fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _prizes() {
    final champ = daiHoiPrize(3, h.level);
    return Text(
      'Vô địch: ${champ.coins} Uy danh, ${fmt(champ.gold)} lượng, ngọc cấp ${champ.gemTier}, '
      '${champ.shards} Mảnh Hoàng Kim, ${champ.iron} Thần Thiết. Vòng nào cũng có thưởng.',
      style: small.copyWith(fontSize: 10.5, color: goldLight),
      textAlign: TextAlign.center,
    );
  }
}

/// Lực chiến in a few characters: 17,8k, 1,2tr.
String _short(int n) {
  String one(double v) => v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', ',');
  if (n >= 1000000) return '${one(n / 1000000)}tr';
  if (n >= 1000) return '${one(n / 1000)}k';
  return '$n';
}
