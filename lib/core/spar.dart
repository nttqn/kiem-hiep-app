import 'arena.dart';
import 'content.dart';
import 'hero.dart';
import 'i18n.dart';

/// Tỉ thí (1.13.0): a friendly duel with another player's hero, picked from
/// a board ("Xem thông tin"). Fought like Lôi đài against their copy, in
/// their gear, but it moves no points: a little Uy danh, a few a day.
const int sparPerDay = 5;
const int sparWinCoins = 10;
const int sparLossCoins = 3;

DungeonDef sparDef(ArenaRival r) => DungeonDef(
      id: 'spar',
      name: tr('Tỉ thí · {rName}', {'rName': tr(r.name)}),
      mapId: 'hoason',
      level: r.level,
      waves: const [],
      timeLimit: arenaTime,
      rival: r,
      spar: true,
    );

extension Spar on HeroData {
  bool get sparOpen => arenaOpen;

  void sparRollDay(String day) {
    if (sparDay == day) return;
    sparDay = day;
    sparCount = 0;
  }

  int sparLeft(String day) {
    sparRollDay(day);
    return sparPerDay - sparCount;
  }

  /// Takes one of today's duels; false when none are left.
  bool sparStart(String day) {
    if (!sparOpen || sparLeft(day) <= 0) return false;
    sparCount++;
    return true;
  }

  List<String> sparResult(bool won) {
    final coins = won ? sparWinCoins : sparLossCoins;
    arenaCoins += coins;
    if (won) sparWins++;
    return [won ? tr('Thắng Tỉ thí!') : tr('Thua Tỉ thí, lần sau sẽ khác.'), tr('+{coins} Uy danh', {'coins': coins}), tr('Đã thắng {sparWins} trận Tỉ thí', {'sparWins': sparWins})];
  }
}
