/// Mệt mỏi: past a few hours of fighting in one Vietnam day, monster EXP
/// tapers off, so leaving auto-fight on all day does not race far ahead of
/// players who play a normal session. Quest, dungeon and offline EXP are
/// not touched. The count starts again at midnight.
const double fatigueStart = 4 * 3600;
const double fatigueHeavy = 6 * 3600;

/// Monster EXP multiplier after [sec] seconds of fighting today.
double fatigueMul(double sec) => sec < fatigueStart ? 1 : (sec < fatigueHeavy ? 0.5 : 0.2);

/// "3 giờ 05 phút".
String fatigueLabel(double sec) {
  final m = sec ~/ 60;
  return '${m ~/ 60} giờ ${(m % 60).toString().padLeft(2, '0')} phút';
}
