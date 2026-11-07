import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/festival.dart';
import '../core/hero.dart';
import '../core/world_boss.dart';
import '../services/purchase.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Lễ hội (1.11.0): the festival's land, today's tasks, the pack and the
/// exchange shop.
class FestScreen extends StatefulWidget {
  const FestScreen({super.key});

  @override
  State<FestScreen> createState() => _FestScreenState();
}

class _FestScreenState extends State<FestScreen> {
  HeroData get h => SaveService.instance.hero;
  final _iap = PurchaseService.instance;
  final _rng = math.Random();

  static const _ice = Color(0xFFBFE8FF);

  @override
  void initState() {
    super.initState();
    final day = vnDayKey();
    final f = festShopOn(day);
    if (f != null) h.festRoll(f, day);
    _iap.changed.addListener(_refresh);
    _iap.message.addListener(_tell);
  }

  @override
  void dispose() {
    _iap.changed.removeListener(_refresh);
    _iap.message.removeListener(_tell);
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

  @override
  Widget build(BuildContext context) {
    final day = vnDayKey();
    final f = festShopOn(day);
    if (f == null) {
      return SubScreen(
        title: 'Lễ hội',
        child: Center(child: Text('Hiện chưa có lễ hội nào. Hẹn gặp lại!', style: body)),
      );
    }
    final landOpen = festOn(day) != null;
    return SubScreen(
      title: f.name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 280, child: _left(f, day, landOpen)),
          const SizedBox(width: 8),
          Expanded(child: _shop(f)),
        ],
      ),
    );
  }

  Widget _left(FestDef f, String day, bool landOpen) {
    final tasks = h.festTaskList();
    return Panel(
      padding: const EdgeInsets.all(10),
      child: ListView(
        children: [
          Text(f.desc, style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            landOpen
                ? '${dayLabel(f.from)} – ${dayLabel(f.until)} · đổi quà đến ${dayLabel(dayAfter(f.until, f.shopDays))}'
                : 'Lễ hội đã kết thúc, còn đổi quà đến hết ${dayLabel(dayAfter(f.until, f.shopDays))}',
            style: bold.copyWith(fontSize: 11.5, color: goldLight),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.ac_unit, color: _ice, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${fmt(h.festCoins)} ${f.coin}',
                    style: titleStyle(18, color: _ice), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text('Hôm nay nhặt ${h.festEarned}/$festDayCap từ quái', style: small.copyWith(fontSize: 10.5, color: creamDim)),
          const SizedBox(height: 6),
          LButton(
            label: !h.festOpenFor ? 'Mở ở cấp $festOpenLevel' : (landOpen ? 'Vào ${f.landName}' : 'Đã đóng cửa'),
            icon: Icons.landscape,
            small: true,
            color: const Color(0xFF2A6A9A),
            enabled: landOpen && h.festOpenFor,
            onTap: () async {
              await Navigator.of(context).push(fadeRoute(PlayScreen.field(festMap(f, h))));
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Text('Nhiệm vụ hôm nay', style: titleStyle(16)),
          for (var i = 0; i < tasks.length; i++) _task(i, tasks[i], f, landOpen),
          const SizedBox(height: 8),
          _pack(f),
        ],
      ),
    );
  }

  Widget _task(int i, (String, int, int, int) t, FestDef f, bool landOpen) {
    final taken = h.festTaskTaken(i);
    final ready = !taken && t.$2 >= t.$3 && landOpen;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.$1} (+${t.$4} ${f.coin})', style: small.copyWith(fontSize: 11.5, color: cream)),
                const SizedBox(height: 2),
                Bar(value: t.$2 / t.$3, color: taken ? jade : _ice, height: 5),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: taken
                ? Text('Đã nhận', style: small.copyWith(fontSize: 11, color: jade), textAlign: TextAlign.center)
                : LButton(
                    label: ready ? 'Nhận' : '${t.$2}/${t.$3}',
                    small: true,
                    color: jade,
                    enabled: ready,
                    onTap: () {
                      final n = h.festClaimTask(i);
                      if (n > 0) {
                        SoundService.instance.cue('loot');
                        SaveService.instance.save();
                        _say('+$n ${f.coin}');
                      }
                      setState(() {});
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pack(FestDef f) {
    final price = _iap.priceOf(skuFest);
    return Panel(
      padding: const EdgeInsets.all(8),
      border: const Color(0xFFFFD34A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Gói lễ hội', style: titleStyle(15, color: goldLight)),
          Text('Một lần mỗi lễ hội cho ${h.name}: $festPackCoins ${f.coin} + $festPackStones Tinh Thạch.',
              style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          ValueListenableBuilder<bool>(
            valueListenable: _iap.busy,
            builder: (_, busy, _) => LButton(
              label: h.festPack && h.festId == f.id ? 'Đã mua' : (price == null ? 'Chưa mở bán' : 'Mua $price'),
              icon: Icons.shopping_bag,
              small: true,
              color: const Color(0xFF8A2A1A),
              enabled: !(h.festPack && h.festId == f.id) && price != null && !busy,
              onTap: () => _iap.buy(skuFest),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shop(FestDef f) {
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Đổi quà', style: titleStyle(18)),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 82,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: f.shop.length,
              itemBuilder: (_, i) => _item(f, f.shop[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(FestDef f, FestItem it) {
    final owned = h.festOwned(f, it);
    final left = it.limit - h.festBoughtOf(it);
    final can = h.festCanBuy(f, it);
    final special = it.reward == FestReward.costume || it.reward == FestReward.skin || it.reward == FestReward.title;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: special ? goldLight : gold.withValues(alpha: 0.35), width: special ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Text(festItemLabel(f, it, h),
                style: bold.copyWith(fontSize: 11.5, color: special ? goldLight : cream), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          Row(
            children: [
              Expanded(
                child: Text(owned ? 'Đã có' : 'Còn $left/${it.limit}',
                    style: small.copyWith(fontSize: 10.5, color: creamDim)),
              ),
              LButton(
                label: '${it.price}',
                icon: Icons.ac_unit,
                small: true,
                color: seal,
                enabled: can,
                onTap: () {
                  final got = h.festBuy(f, it, _rng);
                  if (got != null) {
                    SoundService.instance.cue('loot');
                    SaveService.instance.save();
                    _say('Đổi được: $got');
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
