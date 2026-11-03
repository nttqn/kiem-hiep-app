import 'dart:math' as math;

import 'arena.dart';
import 'hanh.dart';

/// Võ Lâm Đại Hội: a weekly bracket of eight, the hero and seven others
/// (other players' heroes from the public board, as on the Lôi đài, or
/// invented ones). Three knock-out duels to the title; the other matches
/// are judged by lực chiến and the week's luck. One entry a week, one lost
/// match may be fought again for an ad.
const int daiHoiOpenLevel = 30;

/// Rounds: tứ kết, bán kết, chung kết.
const daiHoiRounds = ['Tứ kết', 'Bán kết', 'Chung kết'];

/// Kept for good by every champion.
const String daiHoiTitle = 'Võ Lâm Minh Chủ';

/// Bracket slots, in tứ kết pairs (0-1, 2-3, 4-5, 6-7); slot 0 is the hero.
/// Each pair of slots holds entrants near this share of the hero's power.
const _slotPower = [1.0, 0.85, 1.05, 0.95, 1.22, 1.1, 1.15, 1.0];

ArenaRival _bot(math.Random r, double k, int power, int level, int rebirths) {
  final b = botRivals(power: (power * k).round(), level: level, rebirths: rebirths, seed: r.nextInt(1 << 30));
  return b[1];
}

/// The seven others for this week, from [pool] where it has someone near
/// each slot's power, invented otherwise. Stable for a week by [seed].
List<ArenaRival> daiHoiEntrants(List<ArenaRival> pool, int power, int level, int rebirths, int seed) {
  final r = math.Random(seed);
  final left = List<ArenaRival>.of(pool)..shuffle(r);
  return [
    for (var s = 1; s < 8; s++)
      () {
        final want = power * _slotPower[s];
        final k = left.indexWhere((c) => (c.power - want).abs() <= want * 0.08);
        return k < 0 ? _bot(r, _slotPower[s], power, level, rebirths) : left.removeAt(k);
      }(),
  ];
}

/// Who wins a match the hero is not in: the stronger, three times in four
/// when even, more often the wider the gap; fixed by [seed].
bool daiHoiFirstWins(int a, int b, int seed) {
  final ratio = a / math.max(1, b);
  final p = 1 / (1 + math.pow(ratio, -6));
  return math.Random(seed).nextDouble() < p;
}

/// Slot (1..7) of the hero's opponent in [round], with the bracket's other
/// matches played out by [daiHoiFirstWins]. [power] is the entrants' lực
/// chiến by slot (slot 0 the hero, who has won every round before).
int daiHoiOpponent(List<int> power, int round, int seed) {
  if (round == 0) return 1;
  // Winner of a pair of slots, by the rounds below it.
  int winner(int from, int size) {
    if (size == 1) return from;
    final a = winner(from, size ~/ 2), b = winner(from + size ~/ 2, size ~/ 2);
    if (a == 0) return 0;
    if (b == 0) return 0;
    return daiHoiFirstWins(power[a], power[b], seed ^ (a * 31 + b * 977)) ? a : b;
  }

  final size = 1 << round;
  return winner(size, size);
}

class DaiHoiPrize {
  const DaiHoiPrize(this.coins, this.gold, this.gemTier, this.shards, this.iron);
  final int coins, gold, gemTier, shards, iron;
}

/// What the hero takes home by how far they got: [wins] matches won (3 is
/// the title).
DaiHoiPrize daiHoiPrize(int wins, int level) => DaiHoiPrize(
      const [40, 120, 250, 500][wins],
      (300 + level * 40) * const [1, 3, 6, 12][wins],
      const [0, 3, 4, 6][wins],
      const [0, 2, 5, 12][wins],
      const [0, 0, 2, 5][wins],
    );

/// A rival as kept in the save: the bracket must not change when the board
/// does.
List<Object> rivalToJson(ArenaRival r) =>
    [r.name, r.hanh.index, r.level, r.rebirths, r.power, r.female, r.title, r.bot, r.mount, r.mountLv, r.skin];

ArenaRival? rivalFromJson(Object? raw) {
  if (raw is! List || raw.length < 8) return null;
  try {
    return ArenaRival(
      name: raw[0] as String,
      hanh: Hanh.values[(raw[1] as int).clamp(0, 4)],
      level: raw[2] as int,
      rebirths: raw[3] as int,
      power: raw[4] as int,
      female: raw[5] as bool,
      title: raw[6] as String,
      bot: raw[7] as bool,
      mount: raw.length > 9 ? raw[8] as String : '',
      mountLv: raw.length > 9 ? raw[9] as int : 1,
      skin: raw.length > 10 ? raw[10] as String : '',
    );
  } catch (_) {
    return null;
  }
}
