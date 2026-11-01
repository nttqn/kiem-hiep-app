import 'dart:math' as math;

/// The game's clock, for every daily reset, stamp and payout.
///
/// Some players set their phone's date ahead to collect tomorrow's gifts
/// (and to file scores under next week). Once the server's time is known
/// the game counts on from it with a monotonic stopwatch, which no change
/// to the phone's clock moves; it asks the server again each time the app
/// comes back. Without a connection it uses the phone's clock, but never
/// goes back before the latest time it has trusted. (The stopwatch can
/// stand still while the phone sleeps; the clock then runs behind until
/// the next answer, which is the safe side.)
class GameClock {
  GameClock._();

  /// The phone's clock and a monotonic stopwatch, swappable in tests.
  static int Function() deviceMs = () => DateTime.now().millisecondsSinceEpoch;
  static int Function() monoMs = () => _watch.elapsedMilliseconds;
  static final Stopwatch _watch = Stopwatch()..start();

  static int? _serverBase;
  static int _monoBase = 0;
  static int _floor = 0;

  /// Whether the time comes from the server this session.
  static bool get trusted => _serverBase != null;

  static int nowMs() {
    final base = _serverBase;
    if (base != null) return base + monoMs() - _monoBase;
    return math.max(deviceMs(), _floor);
  }

  static DateTime now() => DateTime.fromMillisecondsSinceEpoch(nowMs());

  /// The server said it is [serverMs] now.
  static void synced(int serverMs) {
    _serverBase = serverMs;
    _monoBase = monoMs();
    // The server is the truth, even below a floor a fast clock pushed up.
    _floor = serverMs;
  }

  /// How far the phone's clock is off the trusted one, when known.
  static int? get deviceSkewMs => _serverBase == null ? null : deviceMs() - nowMs();

  /// The latest trusted time, kept across launches.
  static int get floor => math.max(_floor, trusted ? nowMs() : 0);
  static set floor(int ms) => _floor = math.max(_floor, ms);

  /// Back to a fresh launch (tests).
  static void reset() {
    _serverBase = null;
    _monoBase = 0;
    _floor = 0;
    deviceMs = () => DateTime.now().millisecondsSinceEpoch;
    monoMs = () => _watch.elapsedMilliseconds;
  }
}
