/// Sự kiện: boosts the developer switches on in the Firebase console
/// (`events/{id}`), no app update needed. Fields (all optional):
///
/// * `name`, `desc`: shown on a banner in town.
/// * `from`, `until`: Vietnam days (`20261101` text or a console timestamp),
///   `until` inclusive; either may be left out.
/// * `weekends`: true to run only on Saturdays and Sundays (Vietnam time)
///   inside those dates, so one document can run every weekend.
/// * `gold`, `exp`, `gems`, `iron`: multipliers for monster gold, monster
///   EXP, gem drops and Ác Mộng Thần Thiết (2 = double), 1 to 3.
/// * `wbRuns`: extra free Boss Thế Giới runs a day, 0 to 3.
///
/// When several are on at once the strongest of each boost applies.
class LiveEvent {
  const LiveEvent({
    required this.id,
    this.name = 'Sự kiện',
    this.desc = '',
    this.from = '',
    this.until = '',
    this.weekends = false,
    this.gold = 1,
    this.exp = 1,
    this.gems = 1,
    this.iron = 1,
    this.wbRuns = 0,
  });

  final String id, name, desc, from, until;
  final bool weekends;
  final double gold, exp, gems, iron;
  final int wbRuns;

  /// Running on Vietnam day [day] (`20261101`).
  bool activeOn(String day) {
    if (from.isNotEmpty && from.compareTo(day) > 0) return false;
    if (until.isNotEmpty && until.compareTo(day) < 0) return false;
    if (!weekends) return true;
    final d = DateTime.utc(int.parse(day.substring(0, 4)), int.parse(day.substring(4, 6)), int.parse(day.substring(6, 8)));
    return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
  }

  /// What it boosts, as short labels.
  List<String> get perks => [
        if (exp > 1) 'EXP quái x${_x(exp)}',
        if (gold > 1) 'Lượng x${_x(gold)}',
        if (gems > 1) 'Rơi ngọc x${_x(gems)}',
        if (iron > 1) 'Thần Thiết Ác Mộng x${_x(iron)}',
        if (wbRuns > 0) '+$wbRuns lượt Boss Thế Giới',
      ];

  static String _x(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  /// Reads a console document (dates already turned into day keys); null
  /// when it boosts nothing.
  static LiveEvent? fromMap(String id, Map<String, dynamic> m) {
    double mul(String k) {
      final v = m[k];
      return v is num ? v.toDouble().clamp(1.0, 3.0) : 1.0;
    }

    String text(String k, String or) {
      final v = m[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : or;
    }

    String day(String k) {
      final v = m[k];
      final s = v is num ? '${v.toInt()}' : (v is String ? v.trim() : '');
      return RegExp(r'^\d{8}$').hasMatch(s) ? s : '';
    }

    final runs = m['wbRuns'];
    final e = LiveEvent(
      id: id,
      name: text('name', 'Sự kiện'),
      desc: text('desc', ''),
      from: day('from'),
      until: day('until'),
      weekends: m['weekends'] == true,
      gold: mul('gold'),
      exp: mul('exp'),
      gems: mul('gems'),
      iron: mul('iron'),
      wbRuns: runs is num ? runs.toInt().clamp(0, 3) : 0,
    );
    return e.perks.isEmpty ? null : e;
  }
}

/// The events known to this device (set by the service), and what is on
/// today.
List<LiveEvent> liveEvents = const [];

/// Events running on Vietnam day [day].
List<LiveEvent> eventsOn(String day) => [for (final e in liveEvents) if (e.activeOn(day)) e];

double _best(List<LiveEvent> on, double Function(LiveEvent) f) =>
    on.fold(1.0, (b, e) => f(e) > b ? f(e) : b);

/// Today's boosts, the strongest of each among the events on [day].
class EventBoost {
  EventBoost(String day) : on = eventsOn(day);
  final List<LiveEvent> on;
  double get gold => _best(on, (e) => e.gold);
  double get exp => _best(on, (e) => e.exp);
  double get gems => _best(on, (e) => e.gems);
  double get iron => _best(on, (e) => e.iron);
  int get wbRuns => on.fold(0, (b, e) => e.wbRuns > b ? e.wbRuns : b);
}
