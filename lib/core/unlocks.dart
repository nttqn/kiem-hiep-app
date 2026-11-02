import 'alchemy.dart';
import 'sect_duty.dart';
import 'tower.dart';

/// Mở khóa dần: the town's doors open as a new hero grows, so the first
/// visit shows a handful, not fourteen (1.5.0). A hero who was reborn has
/// them all.
class TownFeature {
  const TownFeature(this.id, this.label, this.openLv);
  final String id, label;
  final int openLv;
}

const townFeatures = <TownFeature>[
  TownFeature('maps', 'Luyện công', 1),
  TownFeature('quests', 'Nhiệm vụ', 1),
  TownFeature('hero', 'Nhân vật', 1),
  TownFeature('shop', 'Cửa hàng', 1),
  TownFeature('gift', 'Quà ngày', 1),
  TownFeature('dungeons', 'Vượt ải', 3),
  TownFeature('forge', 'Thợ rèn', 5),
  TownFeature('ach', 'Thành tựu', 5),
  TownFeature('activity', 'Năng động', 6),
  TownFeature('rank', 'Xếp hạng', 8),
  TownFeature('companions', 'Đồng hành', 8),
  TownFeature('sect', 'Sư môn', sectOpenLevel),
  TownFeature('alchemy', 'Luyện đan', alchemyOpenLevel),
  TownFeature('manor', 'Trang viên', 12),
  TownFeature('challenge', 'Thử thách', towerOpenLevel),
];

final Map<String, TownFeature> townFeatureById = {for (final f in townFeatures) f.id: f};

/// Level a feature opens at (1 for unknown ids).
int featureLevel(String id) => townFeatureById[id]?.openLv ?? 1;

bool featureOpen(String id, int level, int rebirths) => rebirths > 0 || level >= featureLevel(id);

/// Features that open on the way from [from] to [to] (a level-up).
List<TownFeature> featuresOpened(int from, int to) =>
    [for (final f in townFeatures) if (f.openLv > from && f.openLv <= to && f.openLv > 1) f];
