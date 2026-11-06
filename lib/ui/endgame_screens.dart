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
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'world_boss_screen.dart' show BossPreview;

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
      LbBoard.tamMa => 'Tầng ${e.tm}',
      LbBoard.maVuc => 'Tầng ${e.mv % 1000}',
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
          Text('Đăng nhập để lên bảng xếp hạng', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          LButton(label: 'Đăng nhập', small: true, color: jade, onTap: () => showCloudPanel(context)),
        ],
      );
    } else if (_failed) {
      body = Center(child: Text('Không tải được, thử lại sau.', style: small));
    } else if (_rows == null) {
      body = const Center(child: CircularProgressIndicator(color: goldLight));
    } else if (_rows!.isEmpty) {
      body = Center(child: Text('Chưa có ai. Hãy là người đầu tiên!', style: small, textAlign: TextAlign.center));
    } else {
      body = ListView.builder(
        itemCount: _rows!.length,
        itemBuilder: (_, i) {
          final e = _rows![i];
          final mine = me != null && e.id.startsWith('${me}_');
          return Container(
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
          );
        },
      );
    }
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: titleStyle(18)),
          if (_place != null) Text('Hạng của bạn: #$_place', style: bold.copyWith(color: goldLight)),
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
        label: 'Xem quảng cáo: +1 lượt',
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
      title: 'Tâm Ma Ảo Cảnh',
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
                  Text('Tầng $next', style: titleStyle(24), textAlign: TextAlign.center),
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
                  Text('Lực chiến Tâm Ma: ${fmt(shadow)}', style: bold.copyWith(color: const Color(0xFFC88CFF)),
                      textAlign: TextAlign.center),
                  Text('Của bạn: ${fmt(h.power)}', style: small, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  LButton(
                    label: left > 0 ? 'Khiêu chiến · $left lượt' : 'Hết lượt hôm nay',
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
                  Text('Đối mặt chính mình', style: titleStyle(20)),
                  _line('Tâm Ma là bóng tối của bạn: cùng môn phái, chiêu thức, thú cưỡi. Mỗi tầng nó mạnh thêm 5%, '
                      'nên chỉ trang bị tốt hơn mới đưa bạn lên cao hơn.'),
                  _line('Thua mất 1 lượt trong ngày ($tamMaFreeTries lượt, Nguyệt thẻ +1). Thắng thì lên tầng tiếp, không mất lượt. '
                      'Chỉ được dùng $arenaPotions bình máu mỗi trận.'),
                  const SizedBox(height: 6),
                  Text('Tâm ma tầng $next', style: bold.copyWith(color: goldLight)),
                  if (tamMaAffixes(next).isEmpty) _line('Không có', color: creamDim),
                  for (final a in tamMaAffixes(next))
                    _line('${tmAffixes[a]!.name}: ${tmAffixes[a]!.desc}', color: const Color(0xFFFF9A7A)),
                  const SizedBox(height: 6),
                  Text('Thưởng lần đầu vượt tầng', style: bold.copyWith(color: goldLight)),
                  _line('${tamMaStones(next)} Tinh Thạch, ${fmt(tamMaGold(next))} lượng'),
                  _line('Mỗi 5 tầng: thêm ngọc bậc ${tamMaGemTier(next)}. Mỗi 10 tầng: 1 Hung Thú Tinh Phách.'),
                  _line('Tinh Thạch dùng để Thăng Tinh trang bị +10 (Thợ rèn).', color: creamDim),
                  const SizedBox(height: 6),
                  Text('Tầng cao nhất: ${h.tmBest} · Tinh Thạch đang có: ${fmt(h.starStones)}',
                      style: bold.copyWith(color: cream)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 260, child: EndgameBoard(board: LbBoard.tamMa, title: 'Xếp hạng Tâm Ma')),
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
        title: Text('Quét nhanh Ma Vực', style: titleStyle(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines) Text('• $l', style: body)],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nhận'))],
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
      title: 'Ma Vực',
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
                  Text('Tầng $next', style: titleStyle(24), textAlign: TextAlign.center),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        child: Icon(Icons.blur_circular, size: 130, color: const Color(0xFFB04AFF).withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  Text('Tuần này đã lên: tầng ${h.mvBest}', style: bold.copyWith(color: cream), textAlign: TextAlign.center),
                  Text('Làm mới sau ${huntDaysLeftShown()} ngày', style: small, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  // Quét nhanh (1.8.1): up to 70% of last week's best at once.
                  if (h.maVucSweepTo > 0) ...[
                    LButton(
                      label: 'Quét nhanh tới tầng ${h.maVucSweepTo}',
                      icon: Icons.fast_forward,
                      small: true,
                      color: const Color(0xFF6A3A9A),
                      onTap: _sweep,
                    ),
                    const SizedBox(height: 6),
                  ],
                  LButton(label: 'Vào tầng $next', icon: Icons.whatshot, onTap: _go),
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
                  Text('Leo tầng mỗi tuần', style: titleStyle(20)),
                  _line('Mỗi thứ Hai Ma Vực mở lại từ tầng 1. Tầng nào lên lần đầu trong tuần đều có thưởng, '
                      'nên tuần nào cũng đáng leo lại. Mỗi 5 tầng có đầu lĩnh.'),
                  _line('Quái mạnh thêm 6% mỗi tầng. Không mang hiệp khách.'),
                  const SizedBox(height: 6),
                  Text('Ma khí tuần này', style: bold.copyWith(color: goldLight)),
                  for (var i = 0; i < all.length; i++)
                    _line('${const ['Từ tầng 1', 'Từ tầng 10', 'Từ tầng 20'][i]} · ${nmAffixes[all[i]]!.name}: ${nmAffixes[all[i]]!.desc}',
                        color: now.contains(all[i]) ? const Color(0xFFFF9A7A) : creamDim),
                  const SizedBox(height: 6),
                  Text('Thưởng tầng $next', style: bold.copyWith(color: goldLight)),
                  _line('${maVucStones(next)} Tinh Thạch, ${fmt(maVucGold(next))} lượng'
                      '${next % 5 == 0 ? ', ngọc bậc ${maVucGemTier(next)}, ${maVucIron(next)} Thần Thiết' : ''}'),
                  _line('Tinh Thạch dùng để Thăng Tinh trang bị +10 (Thợ rèn).', color: creamDim),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 260, child: EndgameBoard(board: LbBoard.maVuc, title: 'Xếp hạng tuần')),
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
      title: 'Thượng Cổ Hung Thú',
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
                  Text(b.name, style: titleStyle(24, color: hanhColor(base.hanh)), textAlign: TextAlign.center),
                  Text('Hệ ${base.hanh.label}', style: small, textAlign: TextAlign.center),
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
                    label: left > 0 ? 'Khiêu chiến · $left lượt' : 'Hết lượt hôm nay',
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
                  Text(b.desc, style: titleStyle(17)),
                  _line('Hung thú tuần này, đổi mỗi thứ Hai. Phải hạ trong ${beastTime.round()} giây. '
                      'Né vùng đỏ trước khi nó giáng xuống! Ở 60% và 30% máu nó gọi đồng bọn; dưới 30% nó cuồng nộ.'),
                  _line('$beastFreeTries lượt mỗi ngày (Nguyệt thẻ +1), dùng chung cho cả ba độ khó.'),
                  const SizedBox(height: 6),
                  Text('${beastLevels[i]} · nên có lực chiến ${fmt(beastPowers[i])}', style: bold.copyWith(color: goldLight)),
                  _line(h.htSlain(_diff) ? 'Đã hạ tuần này: lần sau chỉ thưởng ${fmt(beastGold[i] ~/ 10)} lượng.'
                      : 'Lần đầu hạ trong tuần: ${beastStones[i]} Tinh Thạch, ${beastSoulsFor(i)} Hung Thú Tinh Phách, '
                          '${fmt(beastGold[i])} lượng, ${i + 1} ngọc bậc ${beastGemTier[i]}.',
                      color: h.htSlain(_diff) ? creamDim : cream),
                  _line('Bảng xếp hạng tính độ khó cao nhất đã hạ, rồi thời gian nhanh nhất.', color: creamDim),
                  const SizedBox(height: 6),
                  Text('Thành tích tuần: ${h.htScore > 0 ? beastScoreLabel(h.htScore) : 'chưa có'}',
                      style: bold.copyWith(color: cream)),
                  Text('Tinh Phách đang có: ${h.beastSouls}', style: bold.copyWith(color: cream)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 260, child: EndgameBoard(board: LbBoard.beast, title: 'Xếp hạng tuần')),
        ],
      ),
    );
  }
}
