import 'dart:math' as math;

import 'gems.dart';
import 'hanh.dart';
import 'items.dart';
import 'sects.dart';

/// Kỳ Trân Các: six rare wares a day (gems and high-rarity gear for the
/// hero's level), bought with gold. A late-game gold sink.
class TreasureOffer {
  const TreasureOffer({this.gem, this.item, required this.price});
  final Gem? gem;
  final Item? item;
  final int price;
}

/// Gold to refresh the stock: the first refresh of the day is the
/// cheapest (or free with an ad), each next one costs more.
int treasureRefreshCost(int refreshes) => 3000 * (refreshes + 1);

/// The day's stock for a hero; the same all day for the same refresh count.
List<TreasureOffer> treasureStock({
  required int level,
  required Hanh hanh,
  required SectDef sect,
  required String day,
  required int refresh,
  required int seed,
}) {
  final rng = math.Random(day.hashCode ^ (seed * 7919) ^ (refresh * 104729));
  final out = <TreasureOffer>[];
  final topTier = math.min(maxDropTier, 1 + level ~/ 20);
  Gem gem(Hanh h) {
    final t = math.max(1, math.min(maxDropTier, topTier + (rng.nextDouble() < 0.25 ? 1 : 0) - rng.nextInt(2)));
    return Gem(h, t);
  }

  int gemPrice(Gem g, {bool own = false}) => ((own ? 1.3 : 1) * 1500 * g.tier * g.tier).round();
  // A gem of the hero's own phase, two of any phase.
  final own = gem(hanh);
  out.add(TreasureOffer(gem: own, price: gemPrice(own, own: true)));
  for (var i = 0; i < 2; i++) {
    final g = gem(Hanh.values[rng.nextInt(5)]);
    out.add(TreasureOffer(gem: g, price: gemPrice(g)));
  }
  // Three pieces of gear: mostly Sử thi, sometimes Truyền thuyết.
  for (var i = 0; i < 3; i++) {
    final x = rng.nextDouble();
    final rarity = x < 0.12 ? Rarity.legend : (x < 0.8 ? Rarity.epic : Rarity.rare);
    final it = makeItem(
      slot: Slot.values[rng.nextInt(Slot.values.length)],
      level: math.max(1, math.min(99, level)),
      rarity: rarity,
      sect: sect,
      rng: rng,
    );
    final mul = switch (rarity) {
      Rarity.legend => 30,
      Rarity.epic => 15,
      _ => 8,
    };
    out.add(TreasureOffer(item: it, price: it.sellPrice * mul));
  }
  return out;
}
