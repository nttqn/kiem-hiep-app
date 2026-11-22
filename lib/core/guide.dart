import 'content.dart';
import 'hero.dart';
import 'items.dart';
import 'newbie.dart';
import 'i18n.dart';

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
    out.add(NextStep(StepKind.rebirth, tr('Chuyển sinh'), tr('Kinh nghiệm cấp 99 đã đầy, chuyển sinh để mạnh hơn.'), tr('Đi')));
  }
  final better = h.betterGearCount;
  if (better > 0) {
    out.add(NextStep(StepKind.equip, tr('Đồ tốt hơn'), tr('Có {better} món trong hành trang tốt hơn đồ đang mặc.', {'better': better}), tr('Mặc ngay')));
  }
  if (h.freePoints > 0) {
    out.add(NextStep(StepKind.points, tr('Cộng điểm'), tr('Còn {freePoints} điểm tiềm năng chưa cộng.', {'freePoints': h.freePoints}), tr('Cộng')));
  }
  if (h.skillPoints > 0) {
    out.add(NextStep(StepKind.skills, tr('Học kỹ năng'), tr('Còn {skillPoints} điểm kỹ năng chưa dùng.', {'skillPoints': h.skillPoints}), tr('Học')));
  }
  if (h.hpPots < guideLowPotions && h.gold >= potionPrice(h.level) * 10) {
    out.add(NextStep(StepKind.potions, tr('Mua thuốc'), tr('Chỉ còn {hpPots} Kim Sang Dược, mua thêm trước khi đi.', {'hpPots': h.hpPots}), tr('Mua')));
  }
  final q = h.currentMain;
  if (q != null && !h.mainLocked) {
    out.add(NextStep(StepKind.quest, tr('Nhiệm vụ'), q.goal, tr('Đi ngay')));
  } else if (q != null) {
    out.add(NextStep(StepKind.train, tr('Luyện cấp'), tr('Nhiệm vụ tiếp theo cần cấp {minLv}: đánh quái ở {p0}.', {'minLv': q.minLv, 'p0': tr(trainingMap(h).name)}), tr('Đi')));
  }
  h.realmRollDay(day);
  if (h.realmOpen(0) && h.realmRunsLeft > 0) {
    out.add(NextStep(StepKind.realm, tr('Bí cảnh'), tr('Còn {realmRunsLeft} lượt thám hiểm hôm nay.', {'realmRunsLeft': h.realmRunsLeft}), tr('Đi')));
  }
  if (h.tbdMaps > 0 && h.tbdSpot == null) {
    out.add(NextStep(StepKind.treasure, tr('Tàng Bảo Đồ'), tr('Có {tbdMaps} tấm, ra bản đồ luyện công rồi bấm đọc.', {'tbdMaps': h.tbdMaps}), tr('Đi')));
  } else if (h.tbdSpot != null) {
    out.add(NextStep(StepKind.treasure, tr('Tàng Bảo Đồ'), tr('Điểm đào đang chờ ở {p0}.', {'p0': tr(mapById[h.tbdSpot!.mapId]!.name)}), tr('Đi')));
  }
  // 1.10.0: a hero not yet reborn is shown the way there.
  if (h.rebirths == 0 && h.level >= 30 && h.level < maxLevel) {
    final gift = nextLevelGift(h.level);
    out.add(NextStep(
      StepKind.train,
      tr('Hướng tới chuyển sinh'),
      tr('Còn {p0} cấp đến 99. Chuyển sinh: +{rebirthPoints} điểm tiềm năng, '
          '+{p1}% sinh lực và công, +{p2}% kinh nghiệm. '
          '{p3}Luyện ở {p4}, làm Bí cảnh và Truy Nã mỗi ngày.', {'p0': maxLevel - h.level, 'rebirthPoints': rebirthPoints, 'p1': (rebirthHpAtk * 100).round(), 'p2': (rebirthExp * 100).round(), 'p3': gift != null ? tr('Quà mốc cấp {gift} đang chờ. ', {'gift': gift}) : '', 'p4': tr(trainingMap(h).name)}),
      tr('Đi'),
    ));
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
