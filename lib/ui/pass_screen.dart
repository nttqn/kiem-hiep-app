import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/battle_pass.dart';
import '../core/costumes.dart';
import '../core/hero.dart';
import '../core/pass_extras.dart';
import '../core/premium.dart';
import '../core/world_boss.dart';
import '../services/purchase.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Lệnh Bài (1.10.0): the season's 30 tiers, the free track above and the
/// Hào Kiệt (paid) track below.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  HeroData get h => SaveService.instance.hero;
  final _iap = PurchaseService.instance;
  final _rng = math.Random();
  late final ScrollController _scroll;

  static const double _colW = 104;
  static const _paidColor = Color(0xFFE8B83A);

  @override
  void initState() {
    super.initState();
    h.passRoll(vnDayKey());
    // Start at the first tier with something left to take.
    var t = 1;
    while (t < h.passTier && h.passTaken(t, paid: false) && (!h.passPaid || h.passTaken(t, paid: true))) {
      t++;
    }
    _scroll = ScrollController(initialScrollOffset: math.max(0, (t - 2) * _colW));
    _iap.changed.addListener(_refresh);
    _iap.message.addListener(_tell);
  }

  @override
  void dispose() {
    _iap.changed.removeListener(_refresh);
    _iap.message.removeListener(_tell);
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _tell() {
    final m = _iap.message.value;
    if (m == null || !mounted) return;
    _iap.message.value = null;
    _say(m);
  }

  void _say(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  void _got(List<String>? lines) {
    if (lines == null || lines.isEmpty) return;
    SoundService.instance.cue('loot');
    SaveService.instance.save();
    _say('Nhận: ${lines.join(', ')}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!h.passOpen) {
      return SubScreen(
        title: 'Lệnh Bài',
        child: Center(
          child: Panel(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Lệnh Bài mùa 1 mở từ $passOpenText.\n'
              'Mỗi mùa 4 tuần, 30 bậc, lên bậc bằng điểm Năng động. '
              'Bậc 30 nhánh Hào Kiệt có ngoại trang ${costumeById[passCostumeOf(1)]?.name ?? ''}.',
              style: body,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SubScreen(
      title: 'Lệnh Bài',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 6),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        Expanded(child: _side('Miễn phí', cream)),
                        Expanded(child: _side('Hào Kiệt', _paidColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: passTiers,
                      itemExtent: _colW,
                      itemBuilder: (_, i) => _tierColumn(i + 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _side(String label, Color color) => Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(label, style: bold.copyWith(fontSize: 11, color: color)),
        ),
      );

  Widget _header() {
    final day = vnDayKey();
    final tier = h.passTier;
    final inTier = tier >= passTiers ? passTierXp : h.passXp - tier * passTierXp;
    final waiting = h.passWaiting;
    final price = _iap.priceOf(skuPass);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Mùa ${h.passSeason}', style: titleStyle(17)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Bậc $tier/$passTiers · còn ${passDaysLeft(day)} ngày',
                          style: bold.copyWith(color: goldLight, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Bar(value: inTier / passTierXp, color: expGold, height: 6),
                const SizedBox(height: 2),
                Text(
                  tier >= passTiers
                      ? 'Đã đạt bậc tối đa mùa này.'
                      : 'Điểm Năng động = kinh nghiệm Lệnh Bài: $inTier/$passTierXp đến bậc ${tier + 1}. '
                          'Hết mùa, phần thưởng đã đạt mà chưa nhận sẽ tự gửi.',
                  style: small.copyWith(fontSize: 10.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LButton(
            label: waiting > 0 ? 'Nhận tất cả ($waiting)' : 'Nhận tất cả',
            small: true,
            enabled: waiting > 0,
            onTap: () => _got(h.passClaimAll(_rng)),
          ),
          const SizedBox(width: 6),
          if (h.passPaid)
            LButton(label: 'Hào Kiệt ✓', small: true, color: const Color(0xFF8A6A1A), enabled: false, onTap: null)
          else
            ValueListenableBuilder<bool>(
              valueListenable: _iap.busy,
              builder: (_, busy, _) => LButton(
                label: price == null ? 'Hào Kiệt: chưa mở bán' : 'Mở Hào Kiệt · $price',
                icon: Icons.workspace_premium,
                small: true,
                color: const Color(0xFF8A2A1A),
                enabled: price != null && !busy,
                onTap: _confirmBuy,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmBuy() async {
    final costume = costumeById[passCostumeOf(h.passSeason)];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Lệnh Bài Hào Kiệt · mùa ${h.passSeason}', style: titleStyle(18)),
        content: Text(
          'Mở nhánh Hào Kiệt cho ${h.name} đến hết mùa (còn ${passDaysLeft(vnDayKey())} ngày). '
          'Bậc đã đạt nhận được ngay. Gồm Tinh Thạch, Mảnh Hoàng Kim, ngọc Thánh, Tinh Phách, '
          'Tẩy Tủy Đan, và ở bậc 30: ngoại trang ${costume?.name ?? ''} cùng danh hiệu « $passPaidTitle ».',
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mua')),
        ],
      ),
    );
    if (ok == true) await _iap.buy(skuPass);
  }

  Widget _tierColumn(int t) {
    final reached = t <= h.passTier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 18,
            child: Center(
              child: Text('Bậc $t',
                  style: bold.copyWith(fontSize: 12, color: reached ? goldLight : creamDim)),
            ),
          ),
          Expanded(child: _card(t, false)),
          const SizedBox(height: 4),
          Expanded(child: _card(t, true)),
        ],
      ),
    );
  }

  Widget _card(int t, bool paid) {
    final r = paid ? passPaidReward(t) : passFreeReward(t);
    final taken = h.passTaken(t, paid: paid);
    final can = h.passCanClaim(t, paid: paid);
    final locked = paid && !h.passPaid;
    final big = t == passTiers || t % 5 == 0;
    final edge = paid ? _paidColor : gold;
    return GestureDetector(
      onTap: can ? () => _got(h.passClaim(t, paid: paid, rng: _rng)) : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: can ? Color.lerp(lacquer, seal, 0.45) : (big ? const Color(0xFF2A1E10) : lacquerDeep),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: can ? goldLight : edge.withValues(alpha: big ? 0.8 : 0.35),
            width: can || big ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  passLabels(r, h.level, h.rebirths, h.passSeason).join('\n'),
                  style: small.copyWith(fontSize: 10, color: taken ? creamDim : cream, height: 1.15),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Icon(
              taken
                  ? Icons.check_circle
                  : (locked ? Icons.lock : (can ? Icons.redeem : Icons.hourglass_empty)),
              size: 16,
              color: taken ? const Color(0xFF8CE07A) : (can ? goldLight : creamDim),
            ),
          ],
        ),
      ),
    );
  }
}
