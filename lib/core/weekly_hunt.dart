import 'dart:math' as math;

/// Săn quái tuần: monsters felled in a Vietnam week (Monday to Sunday) on
/// a leaderboard of its own that starts empty every Monday, so a new player
/// has a board they can climb. The top 50 are paid when the week ends.
final DateTime _huntEpoch = DateTime.utc(2026, 10, 26);

/// Most kills one week may count; also the Firestore rules' sanity bound.
const int huntWeekMax = 300000;

DateTime? _dayOf(String dayKey) {
  if (dayKey.length != 8) return null;
  final y = int.tryParse(dayKey.substring(0, 4));
  final m = int.tryParse(dayKey.substring(4, 6));
  final d = int.tryParse(dayKey.substring(6, 8));
  return y == null || m == null || d == null ? null : DateTime.utc(y, m, d);
}

/// Week number (1-based, from Monday 26/10/2026) of a `yyyymmdd` day.
int huntWeekOf(String dayKey) {
  final d = _dayOf(dayKey);
  if (d == null) return 1;
  return math.max(0, d.difference(_huntEpoch).inDays) ~/ 7 + 1;
}

/// Days left in the week of [dayKey], today included.
int huntDaysLeft(String dayKey) {
  final d = _dayOf(dayKey);
  if (d == null) return 7;
  return 7 - math.max(0, d.difference(_huntEpoch).inDays) % 7;
}

/// One number per week for the leaderboard, as the Lôi đài does: newer
/// weeks sort above older ones.
int huntScore(int week, int kills) => week * 1000000 + kills.clamp(0, huntWeekMax);

class HuntReward {
  const HuntReward(this.iron, this.gems, this.gemTier, this.title);
  final int iron, gems, gemTier;

  /// A title kept for good; empty for none.
  final String title;
}

HuntReward? huntReward(int place) => switch (place) {
      1 => const HuntReward(15, 3, 5, 'Săn Quái Vương'),
      <= 3 => const HuntReward(10, 2, 5, ''),
      <= 10 => const HuntReward(6, 2, 4, ''),
      <= 50 => const HuntReward(3, 1, 4, ''),
      _ => null,
    };
