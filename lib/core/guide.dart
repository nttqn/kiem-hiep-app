import 'content.dart';
import 'hero.dart';
import 'items.dart';

/// Nên làm gì tiếp: the few things most worth doing now, best first, for
/// the town's hint strip and its list.
enum StepKind { rebirth, equip, points, skills, potions, quest, train, realm, treasure }

class NextStep {
  const NextStep(this.kind, this.title, this.text, this.action);
  final StepKind kind;
  final String title, text, action;
}

/// Potions below this are worth restocking.
const int guideLowPotions = 10;

List<NextStep> nextSteps(HeroData h, String day) {
  final out = <NextStep>[];
  if (h.canRebirth) {
    out.add(const NextStep(StepKind.rebirth, 'Chuyển sinh', 'Kinh nghiệm cấp 99 đã đầy, chuyển sinh để mạnh hơn.', 'Đi'));
  }
  final better = h.betterGearCount;
  if (better > 0) {
    out.add(NextStep(StepKind.equip, 'Đồ tốt hơn', 'Có $better món trong hành trang tốt hơn đồ đang mặc.', 'Mặc ngay'));
  }
  if (h.freePoints > 0) {
    out.add(NextStep(StepKind.points, 'Cộng điểm', 'Còn ${h.freePoints} điểm tiềm năng chưa cộng.', 'Cộng'));
  }
  if (h.skillPoints > 0) {
    out.add(NextStep(StepKind.skills, 'Học kỹ năng', 'Còn ${h.skillPoints} điểm kỹ năng chưa dùng.', 'Học'));
  }
  if (h.hpPots < guideLowPotions && h.gold >= potionPrice(h.level) * 10) {
    out.add(NextStep(StepKind.potions, 'Mua thuốc', 'Chỉ còn ${h.hpPots} Kim Sang Dược, mua thêm trước khi đi.', 'Mua'));
  }
  final q = h.currentMain;
  if (q != null && !h.mainLocked) {
    out.add(NextStep(StepKind.quest, 'Nhiệm vụ', q.goal, 'Đi ngay'));
  } else if (q != null) {
    out.add(NextStep(StepKind.train, 'Luyện cấp', 'Nhiệm vụ tiếp theo cần cấp ${q.minLv}: đánh quái ở ${trainingMap(h).name}.', 'Đi'));
  }
  h.realmRollDay(day);
  if (h.realmOpen(0) && h.realmRunsLeft > 0) {
    out.add(NextStep(StepKind.realm, 'Bí cảnh', 'Còn ${h.realmRunsLeft} lượt thám hiểm hôm nay.', 'Đi'));
  }
  if (h.tbdMaps > 0 && h.tbdSpot == null) {
    out.add(NextStep(StepKind.treasure, 'Tàng Bảo Đồ', 'Có ${h.tbdMaps} tấm, ra bản đồ luyện công rồi bấm đọc.', 'Đi'));
  } else if (h.tbdSpot != null) {
    out.add(NextStep(StepKind.treasure, 'Tàng Bảo Đồ', 'Điểm đào đang chờ ở ${mapById[h.tbdSpot!.mapId]!.name}.', 'Đi'));
  }
  return out;
}

/// The highest field map the hero's level suits.
MapDef trainingMap(HeroData h) {
  var m = maps.first;
  for (final x in maps) {
    if (x.minLv <= h.level) m = x;
  }
  return m;
}
