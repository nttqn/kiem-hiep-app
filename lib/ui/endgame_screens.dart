import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/arena.dart' show arenaPotions;
import '../core/content.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/hung_thu.dart';
import '../core/ma_vuc.dart';
import '../core/nightmare.dart';
import '../core/tam_ma.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'cloud_panel.dart';
import 'hero_card.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'world_boss_screen.dart' show BossPreview;
import '../core/i18n.dart';

// The 1.8.0 endgame: Tâm Ma Ảo Cảnh, Ma Vực and Thượng Cổ Hung Thú, each
// with its own board.

/// This hero's value on an endgame board.
int endgameBoardMine(LbBoard b, HeroData h) => switch (b) {
      LbBoard.tamMa => h.tmBest,
      LbBoard.maVuc => h.maVucBoardValue,
      LbBoard.beast => h.beastBoardValue,
      _ => 0,
    };

/// A board row's value as shown.
String endgameBoardLabel(LbBoard b, LbEntry e) => switch (b) {
      LbBoard.tamMa => tr('Tầng {tm}', {'tm': e.tm}),
      LbBoard.maVuc => tr('Tầng {p0}', {'p0': e.mv % 1000}),
      LbBoard.beast => beastScoreLabel(e.ht),
      _ => '',
    };

String beastScoreLabel(int score) {
  final d = (score % 10000) ~/ 1000;
  final secs = 999 - score % 1000;
  if (d < 1 || d > 3) return '-';
  return '${beastLevels[d - 1]} · ${secs}s';
}

/// The top of an endgame board and this hero's place.
class EndgameBoard extends StatefulWidget {
  const EndgameBoard({super.key, required this.board, required this.title});
  final LbBoard board;
  final String title;

  @override
  State<EndgameBoard> createState() => _EndgameBoardState();
}

class _EndgameBoardState extends State<EndgameBoard> {
  Leaderboard get lb => Leaderboard.instance;
  HeroData get h => SaveService.instance.hero;
  List<LbEntry>? _rows;
  int? _place;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!lb.available) return;
    final slot = SaveService.instance.active;
    if (slot >= 0) await lb.submit(slot, h, force: true);
    try {
      final page = await lb.top(widget.board, limit: 30);
      final mine = endgameBoardMine(widget.board, h);
      final place = mine > 0 && !lb.hidden ? await lb.placeOf(widget.board, mine) : null;
      if (!mounted) return;
      setState(() {
        _rows = page.rows;
        _place = place;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = lb.myUid;
    Widget body;
    if (!lb.available) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tr('Đăng nhập để lên bảng xếp hạng'), style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          LButton(label: tr('Đăng nhập'), small: true, color: jade, onTap: () => showCloudPanel(context)),
        ],
      );
    } else if (_failed) {
      body = Center(child: Text(tr('Không tải được, thử lại sau.'), style: small));
    } else if (_rows == null) {
      body = const Center(child: CircularProgressIndicator(color: goldLight));
    } else if (_rows!.isEmpty) {
      body = Center(child: Text(tr('Chưa có ai. Hãy là người đầu tiên!'), style: small, textAlign: TextAlign.center));
    } else {
      body = ListView.builder(
        itemCount: _rows!.length,
        itemBuilder: (_, i) {
          final e = _rows![i];
          final mine = me != null && e.id.startsWith('${me}_');
          return GestureDetector(
            onTap: () => showLbHeroMenu(context, e, mine: mine),
            child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: mine ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: bold.copyWith(color: i < 3 ? goldLight : cream))),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: hanhColor(Hanh.values[e.hanh]), shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(e.name, style: small.copyWith(fontSize: 12, color: cream), overflow: TextOverflow.ellipsis),
                ),
                Text(endgameBoardLabel(widget.board, e),
                    style: bold.copyWith(fontSize: 12, color: const Color(0xFFFF9A5A))),
              ],
            ),
            ),
          );
        },
      );
    }
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(widget.title), style: titleStyle(18)),
          if (_place != null) Text(tr('Hạng của bạn: #{_place}', {'_place': _place}), style: bold.copyWith(color: goldLight)),
          const SizedBox(height: 4),
          Expanded(child: body),
        ],
      ),
    );
  }
}

Widget _line(String s, {Color color = cream, double size = 13}) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(s, style: body.copyWith(fontSize: size, color: color)),
    );

Widget _adTry({required bool can, required VoidCallback onEarned}) => ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.rewardedReady,
      builder: (_, ready, _) => LButton(
        label: tr('Xem quảng cáo: +1 lượt'),
        icon: Icons.ondemand_video,
        small: true,
        color: const Color(0xFF8A5A10),
        enabled: can && ready,
        onTap: () async {
          if (await AdsService.instance.showRewarded()) onEarned();
        },
      ),
    );

// ------------------------------------------------------------ Tâm Ma

class TamMaScreen extends StatefulWidget {
  const TamMaScreen({super.key});

  @override
  State<TamMaScreen> createState() => _TamMaScreenState();
}

class _TamMaScreenState extends State<TamMaScreen> {
  HeroData get h => SaveService.instance.hero;

  Future<void> _fight() async {
    h.tmRollDay(vnDayKey());
    if (h.tmTriesLeft <= 0) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(tamMaDef(h, h.tmBest + 1))));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    h.tmRollDay(vnDayKey());
    final next = h.tmBest + 1;
    final shadow = tamMaPower(next);
    final left = h.tmTriesLeft;
    return SubScreen(
      title: tr('Tâm Ma Ảo Cảnh'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: Panel(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Tầng {next}', {'next': next}), style: titleStyle(24), textAlign: TextAlign.center),
                  Expanded(
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.5, 0.1, 0.1, 0, 10, //
                          0.1, 0.25, 0.1, 0, 0,
                          0.2, 0.1, 0.55, 0, 20,
                          0, 0, 0, 1, 0,
                        ]),
                        child: FigurePreview.of(h, scale: 2.2, aura: true),
                      ),
                    ),
                  ),
                  Text(tr('Lực chiến Tâm Ma: {p0}', {'p0': fmt(shadow)}), style: bold.copyWith(color: const Color(0xFFC88CFF)),
                      textAlign: TextAlign.center),
                  Text(tr('Của bạn: {p0}', {'p0': fmt(h.power)}), style: small, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  LButton(
                    label: left > 0 ? tr('Khiêu chiến · {left} lượt', {'left': left}) : tr('Hết lượt hôm nay'),
                    icon: Icons.whatshot,
                    enabled: left > 0,
                    onTap: _fight,
                  ),
                  if (h.tmAds < tamMaAdTries) ...[
                    const SizedBox(height: 6),
                    _adTry(
                      can: true,
                      onEarned: () {
                        h.tmAddAdTry(vnDayKey());
                        SaveService.instance.save();
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: ListView(
                children: [
                  Text(tr('Đối mặt chính mình'), style: titleStyle(20)),
                  _line(tr('Tâm Ma là bóng tối của bạn: cùng môn phái, chiêu thức, thú cưỡi. Mỗi tầng nó mạnh thêm 5%, '
                      'nên chỉ trang bị tốt hơn mới đưa bạn lên cao hơn.')),
                  _line(tr('Thua mất 1 lượt trong ngày ({tamMaFreeTries} lượt, Nguyệt thẻ +1). Thắng thì lên tầng tiếp, không mất lượt. '
                      'Chỉ được dùng {arenaPotions} bình máu mỗi trận.', {'tamMaFreeTries': tamMaFreeTries, 'arenaPotions': arenaPotions})),
                  const SizedBox(height: 6),
                  Text(tr('Tâm ma tầng {next}', {'next': next}), style: bold.copyWith(color: goldLight)),
                  if (tamMaAffixes(next).isEmpty) _line(tr('Không có'), color: creamDim),
                  for (final a in tamMaAffixes(next))
                    _line('${tr(tmAffixes[a]!.name)}: ${tr(tmAffixes[a]!.desc)}', color: const Color(0xFFFF9A7A)),
                  const SizedBox(height: 6),
                  Text(tr('Thưởng lần đầu vượt tầng'), style: bold.copyWith(color: goldLight)),
                  _line(tr('{p0} Tinh Thạch, {p1} lượng', {'p0': tamMaStones(next), 'p1': fmt(tamMaGold(next))})),
                  _line(tr('Mỗi 5 tầng: thêm ngọc bậc {p0}. Mỗi 10 tầng: 1 Hung Thú Tinh Phách.', {'p0': tamMaGemTier(next)})),
                  _line(tr('Tinh Thạch dùng để Thăng Tinh trang bị +10 (Thợ rèn).'), color: creamDim),
                  const SizedBox(height: 6),
                  Text(tr('Tầng cao nhất: {tmBest}', {'tmBest': h.tmBest}), style: bold.copyWith(color: cream)),
                  MatCount(Mat.stone, tr('Tinh Thạch đang có: {p0}', {'p0': fmt(h.starStones)}), style: bold.copyWith(color: cream), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 260, child: EndgameBoard(board: LbBoard.tamMa, title: tr('Xếp hạng Tâm Ma'))),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------ Ma Vực

class MaVucScreen extends StatefulWidget {
  const MaVucScreen({super.key});

  @override
  State<MaVucScreen> createState() => _MaVucScreenState();
}

class _MaVucScreenState extends State<MaVucScreen> {
  HeroData get h => SaveService.instance.hero;

  Future<void> _go() async {
    h.mvRollWeek();
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(maVucFloor(h.mvBest + 1, h.mvWeek))));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _sweep() async {
    final lines = h.maVucSweep(math.Random());
    if (lines.isEmpty) return;
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(tr('Quét nhanh Ma Vực'), style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines) Text('• $l', style: body)],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Nhận')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    h.mvRollWeek();
    final next = h.mvBest + 1;
    final week = h.mvWeek;
    final all = maVucWeekAffixes(week);
    final now = maVucAffixesAt(next, week);
    return SubScreen(
      title: tr('Ma Vực'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: Panel(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Tầng {next}', {'next': next}), style: titleStyle(24), textAlign: TextAlign.center),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        child: Icon(Icons.blur_circular, size: 130, color: const Color(0xFFB04AFF).withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  Text(tr('Tuần này đã lên: tầng {mvBest}', {'mvBest': h.mvBest}), style: bold.copyWith(color: cream), textAlign: TextAlign.center),
                  Text(tr('Làm mới sau {p0} ngày', {'p0': huntDaysLeftShown()}), style: small, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  // Quét nhanh (1.8.1): up to 70% of last week's best at once.
                  if (h.maVucSweepTo > 0) ...[
                    LButton(
                      label: tr('Quét nhanh tới tầng {maVucSweepTo}', {'maVucSweepTo': h.maVucSweepTo}),
                      icon: Icons.fast_forward,
                      small: true,
                      color: const Color(0xFF6A3A9A),
                      onTap: _sweep,
                    ),
                    const SizedBox(height: 6),
                  ],
                  LButton(label: tr('Vào tầng {next}', {'next': next}), icon: Icons.whatshot, onTap: _go),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: ListView(
                children: [
                  Text(tr('Leo tầng mỗi tuần'), style: titleStyle(20)),
                  _line(tr('Mỗi thứ Hai Ma Vực mở lại từ tầng 1. Tầng nào lên lần đầu trong tuần đều có thưởng, '
                      'nên tuần nào cũng đáng leo lại. Mỗi 5 tầng có đầu lĩnh.')),
                  _line(tr('Quái mạnh thêm 6% mỗi tầng. Không mang hiệp khách.')),
                  const SizedBox(height: 6),
                  Text(tr('Ma khí tuần này'), style: bold.copyWith(color: goldLight)),
                  for (var i = 0; i < all.length; i++)
                    _line('${tr(const ['Từ tầng 1', 'Từ tầng 10', 'Từ tầng 20'][i])} · ${tr(nmAffixes[all[i]]!.name)}: ${tr(nmAffixes[all[i]]!.desc)}',
                        color: now.contains(all[i]) ? const Color(0xFFFF9A7A) : creamDim),
                  const SizedBox(height: 6),
                  Text(tr('Thưởng tầng {next}', {'next': next}), style: bold.copyWith(color: goldLight)),
                  _line(tr('{p0} Tinh Thạch, {p1} lượng'
                      '{p2}', {'p0': maVucStones(next), 'p1': fmt(maVucGold(next)), 'p2': next % 5 == 0 ? tr(', ngọc bậc {p0}, {p1} Thần Thiết', {'p0': maVucGemTier(next), 'p1': maVucIron(next)}) : ''})),
                  _line(tr('Tinh Thạch dùng để Thăng Tinh trang bị +10 (Thợ rèn).'), color: creamDim),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 260, child: EndgameBoard(board: LbBoard.maVuc, title: tr('Xếp hạng tuần'))),
        ],
      ),
    );
  }
}

int huntDaysLeftShown() {
  final now = vnNow();
  return 8 - now.weekday;
}

// ------------------------------------------------------------ Hung Thú

class BeastScreen extends StatefulWidget {
  const BeastScreen({super.key});

  @override
  State<BeastScreen> createState() => _BeastScreenState();
}

class _BeastScreenState extends State<BeastScreen> {
  HeroData get h => SaveService.instance.hero;
  int _diff = 1;

  Future<void> _fight() async {
    if (!h.htStart(vnDayKey())) return;
    await SaveService.instance.save();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(beastDungeon(_diff, h.htWeek))));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    h.htRoll(vnDayKey());
    final b = beastOfWeek(h.htWeek);
    final base = mobById[b.base]!;
    final left = h.htTriesLeft;
    final i = _diff - 1;
    return SubScreen(
      title: tr('Thượng Cổ Hung Thú'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: Panel(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(b.name), style: titleStyle(24, color: hanhColor(base.hanh)), textAlign: TextAlign.center),
                  Text(tr('Hệ {hanhLabel}', {'hanhLabel': tr(base.hanh.label)}), style: small, textAlign: TextAlign.center),
                  Expanded(child: Center(child: BossPreview(def: base, size: 160))),
                  Row(
                    children: [
                      for (var d = 1; d <= 3; d++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () => setState(() => _diff = d),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: _diff == d ? seal : lacquerDeep,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _diff == d ? goldLight : gold.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  children: [
                                    Text(beastLevels[d - 1], style: bold.copyWith(fontSize: 12)),
                                    Icon(h.htSlain(d) ? Icons.check_circle : Icons.circle_outlined,
                                        size: 14, color: h.htSlain(d) ? jade : creamDim),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LButton(
                    label: left > 0 ? tr('Khiêu chiến · {left} lượt', {'left': left}) : tr('Hết lượt hôm nay'),
                    icon: Icons.whatshot,
                    enabled: left > 0,
                    onTap: _fight,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: ListView(
                children: [
                  Text(tr(b.desc), style: titleStyle(17)),
                  _line(tr('Hung thú tuần này, đổi mỗi thứ Hai. Phải hạ trong {p0} giây. '
                      'Né vùng đỏ trước khi nó giáng xuống! Ở 60% và 30% máu nó gọi đồng bọn; dưới 30% nó cuồng nộ.', {'p0': beastTime.round()})),
                  _line(tr('{beastFreeTries} lượt mỗi ngày (Nguyệt thẻ +1), dùng chung cho cả ba độ khó.', {'beastFreeTries': beastFreeTries})),
                  const SizedBox(height: 6),
                  Text(tr('{p0} · nên có lực chiến {p1}', {'p0': beastLevels[i], 'p1': fmt(beastPowers[i])}), style: bold.copyWith(color: goldLight)),
                  _line(h.htSlain(_diff) ? tr('Đã hạ tuần này: lần sau chỉ thưởng {p0} lượng.', {'p0': fmt(beastGold[i] ~/ 10)})
                      : tr('Lần đầu hạ trong tuần: {p0} Tinh Thạch, {p1} Hung Thú Tinh Phách, '
                          '{p2} lượng, {p3} ngọc bậc {p4}.', {'p0': beastStones[i], 'p1': beastSoulsFor(i), 'p2': fmt(beastGold[i]), 'p3': i + 1, 'p4': beastGemTier[i]}),
                      color: h.htSlain(_diff) ? creamDim : cream),
                  _line(tr('Bảng xếp hạng tính độ khó cao nhất đã hạ, rồi thời gian nhanh nhất.'), color: creamDim),
                  const SizedBox(height: 6),
                  Text(tr('Thành tích tuần: {p0}', {'p0': h.htScore > 0 ? beastScoreLabel(h.htScore) : tr('chưa có')}),
                      style: bold.copyWith(color: cream)),
                  MatCount(Mat.soul, tr('Tinh Phách đang có: {beastSouls}', {'beastSouls': h.beastSouls}), style: bold.copyWith(color: cream), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 260, child: EndgameBoard(board: LbBoard.beast, title: tr('Xếp hạng tuần'))),
        ],
      ),
    );
  }
}
