import 'hanh.dart';
import 'sects.dart';

/// Kinh mạch: an endless sink for skill points once every skill is
/// trained. Five channels, one per phase (ngũ hành ↔ ngũ tạng), each raising
/// one stat with diminishing returns so no channel runs away.
class MeridianDef {
  const MeridianDef(this.hanh, this.name, this.bonus, this.per, this.label);
  final Hanh hanh;
  final String name;
  final Bonus bonus;

  /// Bonus of the first point; later points give less.
  final double per;
  final String label;

  /// Bonus after [n] points: per·n / (1 + n/[meridianSoftCap]).
  double valueAt(int n) => n <= 0 ? 0 : per * n / (1 + n / meridianSoftCap);

  String text(int n) => '$label +${(valueAt(n) * 100).toStringAsFixed(1)}%';
}

/// Points where a channel gives half of its straight-line value.
const double meridianSoftCap = 50;

/// The caps the channels feed into (Stats in hero.dart), shown with them
/// (1.13.3): a player could not tell when Chí mạng or Tốc đánh was full.
const double critCap = 0.6, aspdCap = 2.0;

/// Hero level that opens the channels (any rebirth opens them too).
const int meridianLevel = 60;

const meridians = <MeridianDef>[
  MeridianDef(Hanh.kim, 'Phế Kinh', Bonus.atkPct, 0.006, 'Công lực'),
  MeridianDef(Hanh.moc, 'Can Kinh', Bonus.crit, 0.002, 'Chí mạng'),
  MeridianDef(Hanh.thuy, 'Thận Kinh', Bonus.skillDmg, 0.006, 'Uy lực kỹ năng'),
  MeridianDef(Hanh.hoa, 'Tâm Kinh', Bonus.aspd, 0.003, 'Tốc đánh'),
  MeridianDef(Hanh.tho, 'Tỳ Kinh', Bonus.hpPct, 0.008, 'Sinh lực'),
];
