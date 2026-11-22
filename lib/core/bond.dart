import 'dart:math' as math;

import 'hero.dart';
import 'sects.dart' show Bonus;
import 'i18n.dart';

/// Kết duyên (1.20.0): two heroes of different accounts, Hảo hữu of each
/// other and level [bondMinLevel] (or reborn), become phu thê.
///
/// * Tình ý grows a little each day: sending Tương tư, taking the
///   partner's, calling the partner into a fight and being called by them
///   ([bondLovePer] each, once a day).
/// * Tình ý raises the Nhẫn Đồng Tâm ([bondRingNeeds]), whose HP, attack and
///   defence count only while the two stay together.
/// * The partner is an extra Trợ chiến call a day and fights beside the hero
///   at [bondHelperMul] times the usual strength.
/// * Parting clears Tình ý; a new bond waits [bondCooldownDays] days.
///
/// Requests, answers and Tương tư go through Firestore
/// (`bond/{toRow}/in/{fromRow}`, services/guild.dart), like Sư đồ.
const int bondMinLevel = 40;
const int bondLovePer = 5;
const int bondCooldownDays = 3;
const double bondHelperMul = 1.2;

/// Tình ý for each Nhẫn Đồng Tâm level (1-10).
const List<int> bondRingNeeds = [20, 60, 120, 200, 300, 450, 650, 900, 1200, 1600];
int get bondRingMax => bondRingNeeds.length;

/// Nhẫn Đồng Tâm per level: HP%, attack%, defence%.
const double bondHpPer = 0.012;
const double bondAtkPer = 0.008;
const double bondDefPer = 0.01;

int bondRingAt(int love) => bondRingNeeds.where((n) => love >= n).length;

Map<Bonus, double> bondRingBonuses(int lv) => lv <= 0
    ? const {}
    : {Bonus.hpPct: bondHpPer * lv, Bonus.atkPct: bondAtkPer * lv, Bonus.defPct: bondDefPer * lv};

/// Ring levels that give a title.
const Map<int, String> bondTitles = {3: 'Tâm Đầu Ý Hợp', 6: 'Song Kiếm Hợp Bích', 10: 'Thần Tiên Quyến Lữ'};

/// Days from Vietnam day key [a] to [b] (`yyyymmdd`); 0 when unreadable.
int bondDaysBetween(String a, String b) {
  DateTime? p(String s) {
    if (s.length != 8) return null;
    final y = int.tryParse(s.substring(0, 4)), m = int.tryParse(s.substring(4, 6)), d = int.tryParse(s.substring(6));
    return y == null || m == null || d == null ? null : DateTime.utc(y, m, d);
  }

  final x = p(a), y = p(b);
  return x == null || y == null ? 0 : y.difference(x).inDays;
}

/// The ways Tình ý is earned in a day, each once.
enum LoveWay { sent, got, called, helped }

const loveWayNames = {
  LoveWay.sent: 'Gửi Tương tư',
  LoveWay.got: 'Nhận Tương tư',
  LoveWay.called: 'Mời phu thê trợ chiến',
  LoveWay.helped: 'Được phu thê mời trợ chiến',
};

extension Bond on HeroData {
  bool get bonded => kdPartner.isNotEmpty;
  bool get bondLevelOk => level >= bondMinLevel || rebirths > 0;

  /// Days still to wait after parting, 0 when free.
  int bondWait(String day) =>
      kdPartedDay.isEmpty ? 0 : math.max(0, bondCooldownDays - bondDaysBetween(kdPartedDay, day));

  bool canBond(String day) => bondLevelOk && !bonded && kdPending.isEmpty && bondWait(day) == 0;

  int get bondRing => bonded ? bondRingAt(kdLove) : 0;

  /// Tình ý still needed for the next ring level, or 0 at the top.
  int get bondNextNeed {
    final lv = bondRingAt(kdLove);
    return lv >= bondRingMax ? 0 : bondRingNeeds[lv] - kdLove;
  }

  /// The Nhẫn Đồng Tâm's bonuses (only while bonded).
  Map<Bonus, double> bondBonuses() => bondRingBonuses(bondRing);

  void bondRollDay(String day) {
    if (kdDay == day) return;
    kdDay = day;
    kdWays.clear();
  }

  bool loveDone(LoveWay w, String day) {
    bondRollDay(day);
    return kdWays.contains(w.index);
  }

  /// Adds Tình ý for [w] once today; lines for a new ring level and titles.
  List<String> addLove(LoveWay w, String day) {
    if (!bonded || loveDone(w, day)) return const [];
    kdWays.add(w.index);
    final before = bondRingAt(kdLove);
    kdLove += bondLovePer;
    final after = bondRingAt(kdLove);
    final lines = <String>[tr('+{bondLovePer} Tình ý ({p0})', {'bondLovePer': bondLovePer, 'p0': tr(loveWayNames[w] ?? '')})];
    if (after > before) {
      lines.add(tr('Nhẫn Đồng Tâm lên cấp {after}', {'after': after}));
      bondTitles.forEach((need, t) {
        if (after >= need && seasonTitles.add(t)) lines.add(tr('Danh hiệu « {t} »', {'t': t}));
      });
      recompute();
    }
    return lines;
  }

  /// Today's Tương tư not sent yet.
  int bondBadge(String day) => bonded && !loveDone(LoveWay.sent, day) ? 1 : 0;

  // ------------------------------------------------------------ flow

  void askBond(String row, String name, int hanh, String day) {
    kdPending = row;
    kdPendingName = name;
    kdPendingHanh = hanh;
    kdPendingDay = day;
  }

  void cancelAsk() {
    kdPending = '';
    kdPendingName = '';
    kdPendingDay = '';
  }

  /// Bonded with [row] from [day]: as the one asked, or when the asked one
  /// said yes (then [row] is the pending one).
  void bondWith(String row, String name, int hanh, String day) {
    kdPartner = row;
    kdPartnerName = name;
    kdPartnerHanh = hanh;
    kdSince = day;
    kdLove = 0;
    kdWays.clear();
    kdDay = day;
    kdTtWaiting = false;
    cancelAsk();
    recompute();
  }

  /// Parted (either side): Tình ý and the ring are gone.
  void part(String day) {
    if (!bonded) return;
    kdPartner = '';
    kdPartnerName = '';
    kdSince = '';
    kdLove = 0;
    kdTtWaiting = false;
    kdPartedDay = day;
    recompute();
  }

  // ------------------------------------------------------------ save

  List<Object> bondToJson() => [
        kdPartner, kdPartnerName, kdPartnerHanh, kdSince, kdLove, kdDay, kdWays.toList(), kdPending, kdPendingName,
        kdPendingHanh, kdPendingDay, kdPartedDay, kdTtWaiting ? 1 : 0,
      ];

  void bondFromJson(Object? o) {
    if (o is! List || o.length < 13) return;
    try {
      kdPartner = o[0] as String;
      kdPartnerName = o[1] as String;
      kdPartnerHanh = (o[2] as num).toInt().clamp(0, 4);
      kdSince = o[3] as String;
      kdLove = math.max(0, (o[4] as num).toInt());
      kdDay = o[5] as String;
      kdWays
        ..clear()
        ..addAll([for (final v in o[6] as List) if (v is num && v >= 0 && v < LoveWay.values.length) v.toInt()]);
      kdPending = o[7] as String;
      kdPendingName = o[8] as String;
      kdPendingHanh = (o[9] as num).toInt().clamp(0, 4);
      kdPendingDay = o[10] as String;
      kdPartedDay = o[11] as String;
      kdTtWaiting = o[12] == 1;
    } catch (_) {}
  }
}
