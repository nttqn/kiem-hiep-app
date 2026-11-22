import 'dart:math' as math;

import 'arena.dart';
import 'content.dart';
import 'guild.dart';
import 'hero.dart';
import 'ngo_dao.dart';
import 'weekly_hunt.dart';
import 'i18n.dart';

/// Bang chiến (1.16.0): bangs fight bangs over a week. With a few Chiến
/// lệnh a day a member challenges the heroes of another bang (their copies,
/// in their gear, as in Tỉ thí); a win gives Chiến công, more against a
/// stronger foe. A bang's Chiến công is its members' summed, and the
/// week's board (Firestore `guildWar/{week}/g/{gid}`) ranks bangs by it.
/// When the week turns, everyone who fought is paid by their bang's place.
const int warPerDay = 3;

/// Chiến công for a win against an equal, the most and least a win gives,
/// and what a loss gives.
const int warWinBase = 10;
const int warWinMax = 20, warWinMin = 5;
const int warLossPts = 1;

/// Most one member can add in a week (every win at the most); the rules
/// and the board's check hold the same.
const int warMemberWeekCap = warPerDay * 7 * warWinMax;

/// Xu Bang and cống hiến for each fight.
const int warWinCoins = 8, warLossCoins = 2;
const int warWinContrib = 5;

/// Chiến công a win over a hero of power [theirs] gives a hero of [mine].
int warWinPoints(int mine, int theirs) =>
    (warWinBase * theirs / math.max(1, mine)).round().clamp(warWinMin, warWinMax);

int warPoints(bool won, int mine, int theirs) => won ? warWinPoints(mine, theirs) : warLossPts;

/// Whether a board row could be honest: no more than every member's most.
bool warPlausible(int pts, int members) => pts >= 0 && members >= 1 && members <= 60 && pts <= members * warMemberWeekCap;

DungeonDef warDef(ArenaRival r, String guildName) => DungeonDef(
      id: 'guildwar',
      name: tr('Bang chiến · {rName}{p0}', {'rName': tr(r.name), 'p0': guildName.isEmpty ? '' : ' ($guildName)'}),
      mapId: 'hoason',
      level: r.level,
      waves: const [],
      timeLimit: arenaTime,
      rival: r,
      war: true,
    );

/// What each member who fought gets for their bang's place in the week.
class WarRankReward {
  const WarRankReward(this.coins, this.iron, this.jade, [this.title = '']);
  final int coins, iron, jade;
  final String title;
}

const String warTopTitle = 'Thiên Hạ Đệ Nhất Bang';

/// [place] from 1, or 0 for a bang outside the top fifty (still paid for
/// having fought).
WarRankReward warRankReward(int place) => switch (place) {
      1 => const WarRankReward(600, 10, 3, warTopTitle),
      2 || 3 => const WarRankReward(450, 8, 2),
      >= 4 && <= 10 => const WarRankReward(300, 5, 1),
      >= 11 && <= 20 => const WarRankReward(200, 3, 0),
      >= 21 && <= 50 => const WarRankReward(120, 2, 0),
      _ => const WarRankReward(60, 1, 0),
    };

const warRankBrackets = <(String, int)>[
  ('Hạng 1', 1),
  ('Hạng 2–3', 2),
  ('Hạng 4–10', 4),
  ('Hạng 11–20', 11),
  ('Hạng 21–50', 21),
  ('Ngoài top 50', 0),
];

extension GuildWar on HeroData {
  bool get warOpen => guildOpen;

  /// A new day gives back the Chiến lệnh; a new week sets the last one's
  /// Chiến công aside to be paid by the bang's place.
  void warRollDay(String day) {
    if (gwDay != day) {
      gwDay = day;
      gwCount = 0;
      gwHit.clear();
    }
    final w = huntWeekOf(day);
    if (gwWeek != w) {
      if (gwWeek > 0 && gwPts > 0 && gwGid.isNotEmpty) {
        gwLastWeek = gwWeek;
        gwLastGid = gwGid;
        gwLastPts = gwPts;
        gwRankDue = true;
      }
      gwWeek = w;
      gwPts = 0;
      gwGid = guildId;
    }
  }

  int warLeft(String day) {
    warRollDay(day);
    return warPerDay - gwCount;
  }

  /// This week's Chiến công as it counts for the bang now joined (points
  /// won for another bang stay with that one).
  int warPtsFor(String gid) => gwGid == gid ? gwPts : 0;

  bool warCanHit(String row, String day) {
    warRollDay(day);
    return inGuild && gwCount < warPerDay && !gwHit.contains(row);
  }

  /// Takes a Chiến lệnh to fight board row [row]; false when none are left
  /// or that hero was fought today.
  bool warStart(String row, String day) {
    if (!warCanHit(row, day)) return false;
    if (gwGid != guildId) {
      // Moved to another bang this week: start over for the new one.
      gwGid = guildId;
      gwPts = 0;
    }
    gwCount++;
    gwHit.add(row);
    return true;
  }

  List<String> warResult(bool won, ArenaRival r) {
    final pts = warPoints(won, power, r.power);
    gwPts = math.min(gwPts + pts, warMemberWeekCap);
    final coins = won ? warWinCoins : warLossCoins;
    guildCoins += coins;
    if (won) {
      guildContrib += warWinContrib;
      gwWins++;
    }
    return [
      won ? tr('Thắng trận Bang chiến!') : tr('Thua trận, Chiến công an ủi.'),
      tr('+{pts} Chiến công (tuần này: {gwPts})', {'pts': pts, 'gwPts': gwPts}),
      tr('+{coins} xu Bang{p0}', {'coins': coins, 'p0': won ? tr(', +{warWinContrib} cống hiến', {'warWinContrib': warWinContrib}) : ''}),
    ];
  }

  /// Pays last week's Chiến công by the bang's [place] (0: outside the
  /// top fifty or not on the board).
  List<String> warTakeRank(int place) {
    if (!gwRankDue) return const [];
    gwRankDue = false;
    final r = warRankReward(place);
    guildCoins += r.coins;
    divineIron += r.iron;
    final lines = [
      place > 0 ? tr('Bang chiến tuần {gwLastWeek}: bang hạng {place}', {'gwLastWeek': gwLastWeek, 'place': place}) : tr('Bang chiến tuần {gwLastWeek}: cảm ơn đã tham chiến', {'gwLastWeek': gwLastWeek}),
      tr('+{coins} xu Bang', {'coins': r.coins}),
      tr('+{iron} Thần Thiết', {'iron': r.iron}),
    ];
    if (r.jade > 0 && daoOpen) {
      tienJade += r.jade;
      lines.add(tr('+{jade} Tiên Ngọc', {'jade': r.jade}));
    }
    if (r.title.isNotEmpty && seasonTitles.add(r.title)) lines.add(tr('Danh hiệu « {rTitle} »', {'rTitle': tr(r.title)}));
    return lines;
  }

  List<Object> warToJson() =>
      [gwDay, gwCount, gwHit.toList(), gwWeek, gwPts, gwGid, gwLastWeek, gwLastGid, gwLastPts, gwRankDue, gwWins];

  void warFromJson(Object? o) {
    if (o is! List || o.length < 11) return;
    try {
      gwDay = o[0] as String;
      gwCount = (o[1] as num).toInt().clamp(0, warPerDay);
      gwHit.addAll([for (final v in o[2] as List) '$v']);
      gwWeek = (o[3] as num).toInt();
      gwPts = (o[4] as num).toInt().clamp(0, warMemberWeekCap);
      gwGid = o[5] as String;
      gwLastWeek = (o[6] as num).toInt();
      gwLastGid = o[7] as String;
      gwLastPts = (o[8] as num).toInt().clamp(0, warMemberWeekCap);
      gwRankDue = o[9] == true;
      gwWins = math.max(0, (o[10] as num).toInt());
    } catch (_) {}
  }
}
