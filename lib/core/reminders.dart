import 'comeback.dart';
import 'festival.dart' show FestExtras, festivals, dayLabel;
import 'hero.dart';
import 'rewards.dart' show offlineCap;
import 'week_goals.dart' show weekGoalDay;
import 'world_boss.dart' show vnNow, vnDayKey;
import 'i18n.dart';

/// One reminder to set on the phone when the game is left.
class Reminder {
  const Reminder(this.id, this.at, this.title, this.body);
  final int id;

  /// When, in UTC.
  final DateTime at;
  final String title, body;
}

/// Evening hour (Vietnam time) the daily reminders come at.
const int reminderHour = 19;
const int reminderMinute = 30;

/// Vietnam [hour]:[minute] [days] days after [now], in UTC.
DateTime vnAt(DateTime now, int days, int hour, int minute) {
  final d = vnNow(now);
  return DateTime.utc(d.year, d.month, d.day + days, hour - 7, minute);
}

/// The reminders to set as [h] is left at [now]: closed-door training full
/// (unless it lands at night or near the evening one), tomorrow evening's
/// gifts, and a nudge after 3, 7, 14 and 30 days (1.17.0: the later ones
/// tell of Quà hồi quy, and a festival's first day gets its own). At most
/// two land on one day; all are cleared when the game is opened again.
List<Reminder> reminderPlan(HeroData h, DateTime now, {bool newbieWaiting = false}) {
  final out = <Reminder>[];
  final tomorrow = vnAt(now, 1, reminderHour, reminderMinute);
  // The hero's Mục tiêu 7 ngày day tomorrow (0 when done or not for them).
  final today = vnDayKey(now);
  final weekDayTomorrow = h.weekGoalsOpen(today) ? weekGoalDay(h, today) + 1 : 0;
  final full = now.toUtc().add(offlineCap);
  final fullHour = vnNow(full).hour;
  if (!h.canRebirth && fullHour >= 8 && fullHour < 22 && full.difference(tomorrow).inMinutes.abs() > 180) {
    out.add(Reminder(1, full, tr('Bế quan đã đầy'),
        tr('{hName} đã bế quan đủ {inHours} giờ. Về nhận kinh nghiệm và lượng nào!', {'hName': h.name, 'inHours': offlineCap.inHours})));
  }
  out.add(Reminder(
    2,
    tomorrow,
    newbieWaiting ? tr('Quà tân thủ đang chờ') : tr('Quà mới đã sẵn sàng'),
    newbieWaiting
        ? tr('Quà tân thủ ngày {p0} của {hName} đang chờ. Đủ 7 ngày nhận Bạch Mã!', {'p0': h.newbieClaimed + 1, 'hName': h.name})
        : weekDayTomorrow > 1 && weekDayTomorrow <= 7
            ? tr('Mục tiêu 7 ngày: ngày {weekDayTomorrow} đã mở 3 mục tiêu mới cho {hName}.', {'weekDayTomorrow': weekDayTomorrow, 'hName': h.name})
            : tr('Quà đăng nhập, nhiệm vụ ngày và lượt Boss Thế Giới đã làm mới.'),
  ));
  // Trang viên: the first field to ripen, in daytime and not near tomorrow's.
  final ripe = h.manorOpen ? h.manor.nextReady(now.millisecondsSinceEpoch) : null;
  if (ripe != null) {
    final at = DateTime.fromMillisecondsSinceEpoch(ripe, isUtc: true);
    final hour = vnNow(at).hour;
    if (hour >= 8 && hour < 22 && at.difference(tomorrow).inMinutes.abs() > 120) {
      out.add(Reminder(5, at, tr('Ruộng linh thảo đã chín'), tr('Trang viên của {hName} có ruộng chín rồi, về thu hoạch nhé!', {'hName': h.name})));
    }
  }
  // A festival opening in the next month, for heroes who may join it.
  final fest = h.festOpenFor
      ? festivals.where((f) => f.from.compareTo(today) > 0 && daysBetween(today, f.from) <= 30).firstOrNull
      : null;
  final festIn = fest == null ? 0 : daysBetween(today, fest.from);
  String festText() => tr('{landName} mở từ hôm nay đến {p0}. '
      '{hName} về hạ quái nhặt {coin} đổi ngoại trang, thú cưỡi nhé!', {'landName': fest!.landName, 'p0': dayLabel(fest.until), 'hName': h.name, 'coin': fest.coin});
  if (festIn == 1) {
    out[out.indexWhere((r) => r.id == 2)] = Reminder(2, tomorrow, tr('{festName} đã mở!', {'festName': tr(fest!.name)}), festText());
  }
  // Would Quà hồi quy be waiting [days] days from now?
  bool giftBy(int days) {
    final day = vnDayKey(now.toUtc().add(Duration(days: days)));
    return comebackDue(h, today, day) > 0;
  }
  for (final (id, days) in [(3, 3), (4, 7), (6, 14), (7, 30)]) {
    final at = vnAt(now, days, reminderHour, reminderMinute);
    if (festIn == days) {
      out.add(Reminder(id, at, tr('{festName} đã mở!', {'festName': tr(fest!.name)}), festText()));
    } else if (days == 3) {
      out.add(Reminder(id, at, tr('Giang hồ dậy sóng'), tr('{hName} ơi, quái vật lại kéo đến. Mau trở lại hành hiệp!', {'hName': h.name})));
    } else if (giftBy(days)) {
      final tier = comebackTier(days);
      out.add(Reminder(id, at, tr('Quà hồi quy đang chờ'),
          tr('{hName} vắng mặt {days} ngày rồi. Về nhận Quà hồi quy và {p0} ngày '
              '+{p1}% EXP để bắt kịp giang hồ!', {'hName': h.name, 'days': days, 'p0': comebackBoostDays(tier), 'p1': (comebackExp * 100).round()})));
    } else {
      out.add(Reminder(id, at, tr('Giang hồ vẫn chờ'),
          tr('Đã {days} ngày rồi, giang hồ vẫn chờ {hName}. Về nhận quà và xem thử thách mới nhé!', {'days': days, 'hName': h.name})));
    }
  }
  if (festIn > 1 && ![3, 7, 14, 30].contains(festIn)) {
    out.add(Reminder(8, vnAt(now, festIn, reminderHour, reminderMinute), tr('{festName} đã mở!', {'festName': tr(fest!.name)}), festText()));
  }
  return out;
}
