import 'festival.dart' show dayAfter;
import 'hero.dart';
import 'i18n.dart';

/// Quà hồi quy (1.17.0): a player back after days away gets a gift and a
/// few days of extra monster EXP and gold to catch up. Firebase on
/// 2026-11-19: ~7,800 of 8,459 players seen in 30 days had not come back
/// that week; a lapsed player costs nothing to win back.
///
/// Away is counted for the whole phone: the latest login day of every
/// hero on it, so playing slot A daily never makes slot B a "returner".

/// Days away before the gift (the 3-day reminder has come and gone).
const int comebackMinDays = 5;

/// A hero takes the gift at most once in this many days.
const int comebackCooldownDays = 30;

/// Heroes below this level (never reborn) are skipped: barely started.
const int comebackMinLevel = 5;

/// Extra monster EXP and gold while the boost lasts (on top of the rest).
const double comebackExp = 0.5;
const double comebackGold = 0.5;

/// A day key as a date: `20261119` (vnDayKey) or `2026-11-9` (the
/// login day, save.dart todayKey); null if neither.
DateTime? parseDay(String d) {
  try {
    if (d.contains('-')) {
      final p = d.split('-');
      if (p.length != 3) return null;
      return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }
    if (d.length != 8) return null;
    return DateTime.utc(int.parse(d.substring(0, 4)), int.parse(d.substring(4, 6)), int.parse(d.substring(6, 8)));
  } catch (_) {
    return null;
  }
}

/// Whole days from [from] to [to] (either key style), 0 if not after.
int daysBetween(String from, String to) {
  final a = parseDay(from), b = parseDay(to);
  if (a == null || b == null) return 0;
  final n = b.difference(a).inDays;
  return n > 0 ? n : 0;
}

/// The latest login day of any hero in [slots], '' if none logged in yet.
String lastLoginOf(List<HeroData?> slots) {
  var best = '';
  DateTime? bestAt;
  for (final s in slots) {
    final at = s == null ? null : parseDay(s.lastLoginDate);
    if (at != null && (bestAt == null || at.isAfter(bestAt))) {
      best = s!.lastLoginDate;
      bestAt = at;
    }
  }
  return best;
}

/// 1 for 5-13 days away, 2 for 14-29, 3 for 30 or more; 0 for none.
int comebackTier(int days) => days >= 30 ? 3 : (days >= 14 ? 2 : (days >= comebackMinDays ? 1 : 0));

/// Days the boost lasts, counting today.
int comebackBoostDays(int tier) => tier + 1;

/// The gift tier [h] may take on [today] (a vnDayKey) with the phone away
/// since [lastLogin], or 0.
int comebackDue(HeroData h, String lastLogin, String today) {
  if (h.lastLoginDate.isEmpty || lastLogin.isEmpty) return 0;
  if (h.rebirths == 0 && h.level < comebackMinLevel) return 0;
  if (h.comebackDay.isNotEmpty && daysBetween(h.comebackDay, today) < comebackCooldownDays) return 0;
  return comebackTier(daysBetween(lastLogin, today));
}

/// Players far enough along to use endgame materials.
bool _endgame(HeroData h) => h.rebirths > 0 || h.level >= 80;

/// The gift of [tier] for [h], as (gold, potions each, Song Bội Đan,
/// Tinh Thạch, Thần Thiết, Mảnh Hoàng Kim).
(int, int, int, int, int, int) comebackGift(HeroData h, int tier) {
  final end = _endgame(h);
  return (
    3000 * (h.level + 10) * (1 + h.rebirths) * tier,
    30 * tier,
    tier,
    end ? 5 * tier : 0,
    end ? 3 * tier : 0,
    end ? 2 * tier : 0,
  );
}

/// Gives the gift and starts the boost; the lines to show.
List<String> takeComeback(HeroData h, int tier, String today) {
  if (tier <= 0) return const [];
  final (gold, pots, pills, stones, iron, shards) = comebackGift(h, tier);
  h.comebackDay = today;
  h.comebackUntil = dayAfter(today, comebackBoostDays(tier) - 1);
  h.gold += gold;
  h.hpPots += pots;
  h.mpPots += pots;
  h.pills['songboi'] = (h.pills['songboi'] ?? 0) + pills;
  h.starStones += stones;
  h.divineIron += iron;
  h.goldShards += shards;
  h.recompute();
  return [
    tr('+{p0} lượng', {'p0': _dots(gold)}),
    tr('+{pots} bình máu, +{pots} bình nội lực', {'pots': pots}),
    tr('+{pills} Song Bội Đan', {'pills': pills}),
    if (stones > 0) tr('+{stones} Tinh Thạch', {'stones': stones}),
    if (iron > 0) tr('+{iron} Thần Thiết', {'iron': iron}),
    if (shards > 0) tr('+{shards} Mảnh Hoàng Kim', {'shards': shards}),
    tr('+{p0}% EXP và lượng từ quái trong {p1} ngày', {'p0': (comebackExp * 100).round(), 'p1': comebackBoostDays(tier)}),
  ];
}

/// The boost is on for [day].
bool comebackOn(HeroData h, String day) => h.comebackUntil.isNotEmpty && h.comebackUntil.compareTo(day) >= 0;

String _dots(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => thouSep);
