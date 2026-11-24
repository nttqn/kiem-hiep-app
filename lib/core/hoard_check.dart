import 'divine.dart';
import 'hero.dart';

/// Hoard check (1.24.1): a hero holding or having spent more Thần Thiết or
/// Mảnh Hoàng Kim than its play time could ever have earned was edited, and
/// is kept off the boards.
///
/// Measured 2026-11-23 on real saves: non-stop auto-fight in U Minh Huyết
/// Hải kills ~116 monsters a minute, ~420 Thần Thiết an hour at 6% plus
/// ~190 from its boss every 150 s, so ~610 an hour standing in the field.
/// Before 1.24.1 leaving and re-entering brought the boss straight back, and
/// a top player (Nhân Long) farmed it every ~23 s: 28k boss kills, ~313k
/// Thần Thiết in 217 h (~1,440 an hour). That was the game's bug, not an
/// edit, so the limit leaves room for it. The edited save that set the
/// limits (BachDoc) held ~530k Thần Thiết and ~490k Mảnh Hoàng Kim in 62 h.

/// Thần Thiết that may come from anything but play time.
const int hoardIronBase = 2000;

/// Thần Thiết an hour of play may bring at most.
const int hoardIronPerHour = 2500;

/// Mảnh Hoàng Kim held, at most, besides [hoardShardsPerHour].
const int hoardShardsBase = 5000;
const int hoardShardsPerHour = 100;

/// Lượng a save may hold beyond its ledger (sổ vàng) before it counts as
/// edited; an honest save is off by none.
const int hoardGoldSlack = 1000000;

/// Lượng spent on Thần binh / Tiên binh that may come from anything but
/// play time or purchases (1.25). Measured 2026-11-24 on the top 15:
/// honest heroes spent 0.7–1.4M an hour of play, Nhân Long (the field-boss
/// bug) 2.2M; TranQuanKyy, editing gold with GameGuardian, 4.7M (1.08
/// billion in 232 h).
const int hoardDivGoldBase = 150000000;
const int hoardDivGoldPerHour = 3000000;

/// Lượng spent to take Thần binh from 0 to [lv].
int divineGoldTotal(int lv) {
  var s = 0;
  for (var i = 0; i < lv; i++) {
    s += divineGoldCost(i);
  }
  return s;
}

/// Thần Thiết spent to take Thần binh from 0 to [lv].
int divineIronTotal(int lv) {
  var s = 0;
  for (var i = 0; i < lv; i++) {
    s += divineIronAt(i);
  }
  return s;
}

/// Why [h] cannot be real, or null when it can.
String? hoardReason(HeroData h) {
  final hours = h.playSeconds / 3600;
  final iron = divineIronTotal(h.divine) + h.divineIron;
  if (iron > hoardIronBase + hoardIronPerHour * hours) return 'iron';
  if (h.goldShards > hoardShardsBase + hoardShardsPerHour * hours) return 'shards';
  if (h.goldUnaccounted > hoardGoldSlack) return 'gold';
  if (divineGoldTotal(h.divine) > hoardDivGoldBase + hoardDivGoldPerHour * hours + h.goldBought) return 'divgold';
  return null;
}
