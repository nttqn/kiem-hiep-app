/// Ngũ hành: every sect and every monster belongs to one of the five
/// phases. An attacker whose phase overcomes the target's hits harder; one
/// whose phase is overcome by the target's hits softer.
enum Hanh { kim, moc, thuy, hoa, tho }

extension HanhInfo on Hanh {
  String get label => const ['Kim', 'Mộc', 'Thủy', 'Hỏa', 'Thổ'][index];

  /// ARGB, kept as ints so the core stays free of Flutter.
  int get color => const [
        0xFFE8C547,
        0xFF4CAF50,
        0xFF3FA7E0,
        0xFFE8503A,
        0xFFB8864B,
      ][index];

  /// Kim khắc Mộc, Mộc khắc Thổ, Thổ khắc Thủy, Thủy khắc Hỏa, Hỏa khắc Kim.
  Hanh get overcomes => const [
        Hanh.moc,
        Hanh.tho,
        Hanh.hoa,
        Hanh.kim,
        Hanh.thuy,
      ][index];

  Hanh get overcomeBy =>
      Hanh.values.firstWhere((h) => h.overcomes == this);
}

const double khacBonus = 1.25;
const double biKhacMalus = 0.85;

double hanhFactor(Hanh attacker, Hanh target) {
  if (attacker.overcomes == target) return khacBonus;
  if (target.overcomes == attacker) return biKhacMalus;
  return 1;
}
