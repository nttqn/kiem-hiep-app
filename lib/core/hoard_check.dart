import 'divine.dart';
import 'hero.dart';

/// Hoard check (1.24): a hero holding or having spent more Thần Thiết or
/// Mảnh Hoàng Kim than its play time could ever have earned was edited, and
/// is kept off the boards.
///
/// Measured 2026-11-23 on real saves: non-stop auto-fight in U Minh Huyết
/// Hải kills ~116 monsters a minute, ~420 Thần Thiết an hour at 6% plus
/// ~190 from its boss every 150 s, so ~610 an hour at most. Days, weeks,
/// the tower and Ác Mộng add a couple of thousand on top. The limits below
/// leave room above that; the edited save that set them (BachDoc) held
/// ~530k Thần Thiết and ~490k Mảnh Hoàng Kim in 62 hours, ten times over.

/// Thần Thiết that may come from anything but play time.
const int hoardIronBase = 2000;

/// Thần Thiết an hour of play may bring at most.
const int hoardIronPerHour = 800;

/// Mảnh Hoàng Kim held, at most, besides [hoardShardsPerHour].
const int hoardShardsBase = 5000;
const int hoardShardsPerHour = 100;

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
  return null;
}
