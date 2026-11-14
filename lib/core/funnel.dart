import 'hero.dart';

/// The new-player funnel: steps every hero passes, sent to analytics once
/// each (`f_lv10`, `f_q20`, `f_day1`…), so the Events list counts how many
/// heroes reached each one and shows where players stop.
const funnelLevels = [3, 5, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50, 60, 80, 99];
const funnelQuests = [3, 5, 10, 15, 20, 25, 30, 40, 56];

/// Kept in [HeroData.funnel] once a save has met the 1.14.0 step list
/// (12/25/35/45, quests 5/15/25 added): a hero from before gets the new
/// steps it already passed marked as sent, so they count new progress only.
const funnelVersion = 'f_v2';

/// Days after creation the hero was played again on.
const funnelDays = [1, 2, 3, 7];

/// Steps [h] has reached but not yet sent, on Vietnam day [today].
List<String> funnelDue(HeroData h, String today) {
  final out = <String>[];
  void step(String id, bool reached) {
    if (reached && !h.funnel.contains(id)) out.add(id);
  }

  final reborn = h.rebirths > 0;
  for (final lv in funnelLevels) {
    step('f_lv$lv', reborn || h.level >= lv);
  }
  for (final q in funnelQuests) {
    step('f_q$q', reborn || h.mainQuest >= q);
  }
  step('f_dungeon1', h.dungeonStars.isNotEmpty);
  step('f_death1', h.deaths > 0);
  step('f_cs1', reborn);
  final days = daysBetween(h.bornDay, today);
  if (days != null) {
    for (final d in funnelDays) {
      step('f_day$d', days >= d);
    }
  }
  return out;
}

/// Whole days from [from] to [to] (`20261101` style), null if either is not
/// a day.
int? daysBetween(String from, String to) {
  DateTime? p(String s) => s.length == 8 && int.tryParse(s) != null
      ? DateTime.utc(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)), int.parse(s.substring(6, 8)))
      : null;
  final a = p(from), b = p(to);
  if (a == null || b == null) return null;
  return b.difference(a).inDays;
}
