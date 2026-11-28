import 'content.dart';
import 'i18n.dart';

/// Mộc nhân luyện công (1.27.0): a wooden man in town to hit for
/// [dummyTime] seconds, to weigh one build against another. It never hits
/// back, never falls, pays nothing and costs nothing; its defence is Boss
/// Thế Giới's (level 99), so the numbers match a boss run.
const double dummyTime = 30;

/// Where the hits came from, in [DummyReport.dmg] order.
const dummyKinds = ['Đánh thường', 'Kỹ năng', 'Độc / Thiêu', 'Hiệp khách'];

class DummyReport {
  /// Damage by [dummyKinds].
  final List<double> dmg = [0, 0, 0, 0];
  int hits = 0, crits = 0;

  double get total => dmg.fold(0, (a, b) => a + b);
  double dps(double seconds) => seconds <= 0 ? 0 : total / seconds;
  double get critRate => hits == 0 ? 0 : crits / hits;
}

DungeonDef dummyDef() => DungeonDef(
      id: 'mocnhan',
      name: tr('Mộc nhân luyện công'),
      mapId: maps.first.id,
      level: 99,
      waves: const [],
      timeLimit: dummyTime,
      dummy: true,
    );
