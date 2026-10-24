import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/items.dart';
import '../services/ads.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'treasure_view.dart';
import 'theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.tab = 0});

  /// 0 the general store, 1 Kỳ Trân Các.
  final int tab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  HeroData get h => SaveService.instance.hero;
  late List<Item> _stock = _makeStock();
  late int _tab = widget.tab;

  /// Plain gear for the hero's level band; the same all day.
  List<Item> _makeStock() {
    final band = math.max(1, h.level - h.level % 5);
    final rng = math.Random(band * 31 + h.hanh.index + todayKey().hashCode);
    return [
      for (final s in Slot.values)
        makeItem(slot: s, level: band, rarity: Rarity.common, sect: h.sect, rng: rng),
      for (var i = 0; i < 3; i++)
        makeItem(
            slot: Slot.values[rng.nextInt(Slot.values.length)],
            level: band,
            rarity: Rarity.fine,
            sect: h.sect,
            rng: rng),
    ];
  }

  int _price(Item it) => it.sellPrice * 5;

  /// Last time free potions were taken this session.
  static DateTime? _lastFree;
  static const _freeGap = Duration(minutes: 10);

  Widget _freePots() {
    final wait = _lastFree == null ? Duration.zero : _freeGap - DateTime.now().difference(_lastFree!);
    if (wait > Duration.zero) {
      return Text('Thuốc miễn phí: quay lại sau ${wait.inMinutes + 1} phút', style: small);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.rewardedReady,
      builder: (_, ready, _) => LButton(
        label: ready ? 'Xem quảng cáo: +5 mỗi loại thuốc' : 'Quảng cáo đang tải…',
        icon: Icons.ondemand_video,
        small: true,
        color: const Color(0xFF8A5A10),
        enabled: ready,
        onTap: () async {
          final earned = await AdsService.instance.showRewarded();
          if (!earned || !mounted) return;
          h.hpPots += 5;
          h.mpPots += 5;
          _lastFree = DateTime.now();
          SaveService.instance.save();
          setState(() {});
        },
      ),
    );
  }

  void _buyPots(bool hp, int n) {
    final price = potionPrice(h.level);
    final can = math.min(n, h.gold ~/ price);
    if (can <= 0) return;
    h.gold -= can * price;
    if (hp) {
      h.hpPots += can;
    } else {
      h.mpPots += can;
    }
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Cửa hàng',
      actions: [
        for (final (i, name) in const [(0, 'Tạp hóa'), (1, 'Kỳ Trân Các')])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _tab == i ? seal : lacquer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _tab == i ? goldLight : gold.withValues(alpha: 0.5)),
                ),
                child: Text(name, style: bold.copyWith(fontSize: 13)),
              ),
            ),
          ),
      ],
      child: _tab == 1 ? const TreasureView() : _general(),
    );
  }

  Widget _general() {
    final price = potionPrice(h.level);
    return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 330,
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dược phẩm', style: titleStyle(20)),
                  Text('Hồi ${(potionHeal * 100).round()}% · giá theo cấp: ${fmt(price)} lượng/bình',
                      style: small),
                  const SizedBox(height: 10),
                  _potRow('Kim Sang Dược', 'Hồi sinh lực', const Color(0xFFE84B4A), h.hpPots, true),
                  const SizedBox(height: 10),
                  _potRow('Ngưng Thần Đan', 'Hồi nội lực', const Color(0xFF4A7AE8), h.mpPots, false),
                  const SizedBox(height: 12),
                  _freePots(),
                  const Spacer(),
                  Text('Mẹo: bật Tự động trong trận, nhân vật sẽ tự uống thuốc khi máu dưới 42%.',
                      style: small),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trang bị (cấp ${_stock.first.level})', style: titleStyle(20)),
                  Text('Hàng đổi khi bạn lên mỗi 5 cấp. Đồ tốt hơn rơi từ quái và đầu lĩnh.', style: small),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        mainAxisExtent: 64,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _stock.length,
                      itemBuilder: (_, i) => _stockTile(_stock[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  Widget _potRow(String name, String what, Color c, int have, bool hp) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: goldLight),
          ),
          child: const Icon(Icons.local_drink, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: bold),
              Text('$what · có $have', style: small),
            ],
          ),
        ),
        LButton(label: '+10', small: true, onTap: () => _buyPots(hp, 10)),
        const SizedBox(width: 4),
        LButton(label: '+50', small: true, onTap: () => _buyPots(hp, 50)),
      ],
    );
  }

  Widget _stockTile(Item it) {
    final price = _price(it);
    final worn = h.equip[it.slot];
    final better = worn == null || it.score > worn.score;
    return Panel(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          ItemTile(item: it, size: 46),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(it.name,
                    style: bold.copyWith(fontSize: 12.5, color: rarityColor(it.rarity)),
                    overflow: TextOverflow.ellipsis),
                Text(
                  it.base.entries.map((e) => '${e.key.label} ${e.key.format(e.value)}').join(' · '),
                  style: small.copyWith(fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
                if (better) Text('Tốt hơn đồ đang mặc', style: small.copyWith(fontSize: 10.5, color: const Color(0xFF8CE07A))),
              ],
            ),
          ),
          LButton(
            label: fmt(price),
            small: true,
            enabled: h.gold >= price && h.bag.length < bagSize,
            onTap: () {
              h.gold -= price;
              h.bag.add(it);
              _stock = List.of(_stock)..remove(it);
              SaveService.instance.save();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã mua ${it.name}. Vào Hành trang để trang bị.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
