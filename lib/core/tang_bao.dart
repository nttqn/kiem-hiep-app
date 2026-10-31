import 'dart:math' as math;

/// Tàng Bảo Đồ: treasure maps dropped by field monsters. Reading one marks a
/// spot on the field map the hero is on; digging there turns up a chest, or
/// an ambush, a guardian, now and then a way into a bí cảnh.

/// Chance per field kill, and per boss or tinh anh.
const double tbdDropChance = 0.004;
const double tbdBigChance = 0.15;

/// Maps that can drop in one Vietnam day, and the most held.
const int tbdDailyDrops = 6;
const int tbdMaxHeld = 20;

/// How close to stand to dig, and how far from the hero a spot is drawn.
const double tbdDigRadius = 56;
const double tbdMinDistance = 900;

enum TbdOutcome {
  chest('Rương báu'),
  ambush('Phục binh'),
  guardian('Hộ Bảo Tinh Anh'),
  portal('Cổng Bí cảnh');

  const TbdOutcome(this.label);
  final String label;
}

/// What a dig turns up: half the time just the chest.
TbdOutcome rollTbd(math.Random r) {
  final x = r.nextDouble();
  if (x < 0.5) return TbdOutcome.chest;
  if (x < 0.75) return TbdOutcome.ambush;
  if (x < 0.93) return TbdOutcome.guardian;
  return TbdOutcome.portal;
}

/// Monsters in an ambush.
const int tbdAmbushSize = 6;

/// The marked spot: which field map, and where.
class TbdSpot {
  const TbdSpot(this.mapId, this.x, this.y);
  final String mapId;
  final double x, y;
}

/// A compass word for the direction from (fx, fy) to (tx, ty); y grows south.
String compassWord(double fx, double fy, double tx, double ty) {
  final dx = tx - fx, dy = ty - fy;
  final ns = dy < -0.4 * dx.abs() ? 'bắc' : (dy > 0.4 * dx.abs() ? 'nam' : '');
  final ew = dx > 0.4 * dy.abs() ? 'đông' : (dx < -0.4 * dy.abs() ? 'tây' : '');
  if (ns.isNotEmpty && ew.isNotEmpty) return '$ew $ns';
  return ns.isNotEmpty ? ns : ew;
}
