import 'hero.dart';
import 'rewards.dart' show offlineCap;
import 'week_goals.dart' show weekGoalDay;
import 'world_boss.dart' show vnNow, vnDayKey;

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
/// gifts, and a nudge after 3 and 7 days. At most two land on one day; all
/// are cleared when the game is opened again.
List<Reminder> reminderPlan(HeroData h, DateTime now, {bool newbieWaiting = false}) {
  final out = <Reminder>[];
  final tomorrow = vnAt(now, 1, reminderHour, reminderMinute);
  // The hero's Mục tiêu 7 ngày day tomorrow (0 when done or not for them).
  final today = vnDayKey(now);
  final weekDayTomorrow = h.weekGoalsOpen(today) ? weekGoalDay(h, today) + 1 : 0;
  final full = now.toUtc().add(offlineCap);
  final fullHour = vnNow(full).hour;
  if (!h.canRebirth && fullHour >= 8 && fullHour < 22 && full.difference(tomorrow).inMinutes.abs() > 180) {
    out.add(Reminder(1, full, 'Bế quan đã đầy',
        '${h.name} đã bế quan đủ ${offlineCap.inHours} giờ. Về nhận kinh nghiệm và lượng nào!'));
  }
  out.add(Reminder(
    2,
    tomorrow,
    newbieWaiting ? 'Quà tân thủ đang chờ' : 'Quà mới đã sẵn sàng',
    newbieWaiting
        ? 'Quà tân thủ ngày ${h.newbieClaimed + 1} của ${h.name} đang chờ. Đủ 7 ngày nhận Bạch Mã!'
        : weekDayTomorrow > 1 && weekDayTomorrow <= 7
            ? 'Mục tiêu 7 ngày: ngày $weekDayTomorrow đã mở 3 mục tiêu mới cho ${h.name}.'
            : 'Quà đăng nhập, nhiệm vụ ngày và lượt Boss Thế Giới đã làm mới.',
  ));
  // Trang viên: the first field to ripen, in daytime and not near tomorrow's.
  final ripe = h.manorOpen ? h.manor.nextReady(now.millisecondsSinceEpoch) : null;
  if (ripe != null) {
    final at = DateTime.fromMillisecondsSinceEpoch(ripe, isUtc: true);
    final hour = vnNow(at).hour;
    if (hour >= 8 && hour < 22 && at.difference(tomorrow).inMinutes.abs() > 120) {
      out.add(Reminder(5, at, 'Ruộng linh thảo đã chín', 'Trang viên của ${h.name} có ruộng chín rồi, về thu hoạch nhé!'));
    }
  }
  out.add(Reminder(3, vnAt(now, 3, reminderHour, reminderMinute), 'Giang hồ dậy sóng',
      '${h.name} ơi, quái vật lại kéo đến. Mau trở lại hành hiệp!'));
  out.add(Reminder(4, vnAt(now, 7, reminderHour, reminderMinute), 'Giang hồ vẫn chờ',
      'Một tuần rồi, giang hồ vẫn chờ ${h.name}. Về nhận quà và xem thử thách mới nhé!'));
  return out;
}
