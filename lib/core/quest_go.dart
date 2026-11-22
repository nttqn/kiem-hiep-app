import 'content.dart';
import 'festival.dart' show festMapPrefix;
import 'hero.dart';
import 'i18n.dart';

/// Where the story quest wants the hero next, when that is not where they
/// are (1.14.0). Players who left the autopilot running on a field kept
/// levelling past dungeon quests nobody pulled them into: the funnel showed
/// 5.9k heroes at level 15 but only 3.7k past quest 10 (an ải).
class QuestGo {
  const QuestGo.dungeon(DungeonDef this.dungeon) : map = null;
  const QuestGo.field(MapDef this.map) : dungeon = null;

  final DungeonDef? dungeon;
  final MapDef? map;

  String get label => dungeon != null ? tr('Vào ải {dungeonName}', {'dungeonName': tr(dungeon!.name)}) : tr('Đến {mapName}', {'mapName': tr(map!.name)});
  String get id => dungeon?.id ?? map!.id;
}

/// The next stop for [h]'s story quest, or null when it is locked, needs no
/// place (reach a level), or can be done right here: on the field [hereMap]
/// (null when not on a field) or in the dungeon [hereDungeon].
QuestGo? questGo(HeroData h, {String? hereMap, String? hereDungeon}) {
  final q = h.currentMain;
  if (q == null || h.mainLocked) return null;
  // 1.17.0: a festival land is a choice of its own (autopilot there farms
  // its coins); the countdown pulled players off it after six seconds.
  if (hereMap != null && hereMap.startsWith(festMapPrefix)) return null;
  if (q.type == QuestType.dungeon) {
    final d = dungeonById[q.target];
    if (d == null || d.id == hereDungeon || h.level < d.level - 2) return null;
    return QuestGo.dungeon(d);
  }
  final m = questMap(q);
  if (m == null || m.id == hereMap || h.level < m.entryLv || h.rebirths < m.rebirths) return null;
  return QuestGo.field(m);
}
