import 'dart:math' as math;

import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/world.dart';

class SimReport {
  final Map<int, int> levelAtMinute = {};
  int deaths = 0;
  int dungeonsTried = 0;
  int dungeonsCleared = 0;
  final List<String> log = [];
  late HeroData hero;
}

/// What a sensible player does in town between outings.
void townVisit(HeroData h) {
  h.autoSpend();
  h.autoLearn();
  h.autoEquip();
  // Sell the junk, keep the bag from filling.
  for (final it in List<Item>.of(h.bag)) {
    final worn = h.equip[it.slot];
    if (worn != null && it.score <= worn.score) h.sell(it);
  }
  final price = potionPrice(h.level);
  while (h.hpPots < 30 && h.gold >= price) {
    h.gold -= price;
    h.hpPots++;
  }
  while (h.mpPots < 20 && h.gold >= price) {
    h.gold -= price;
    h.mpPots++;
  }
}

/// Runs a hero through the game on autopilot for [minutes] of game time.
SimReport simulate(Hanh hanh, {int minutes = 120, int seed = 1}) {
  final rep = SimReport();
  final h = HeroData(name: 'Sim', hanh: hanh)..seed = seed;
  rep.hero = h;
  h.refreshDaily('2026-10-15');
  final rng = math.Random(seed);
  final failedUntil = <String, int>{};
  const dt = 1 / 30;
  var clock = 0.0;
  var nextMark = 1;
  void mark() {
    while (clock / 60 >= nextMark) {
      rep.levelAtMinute[nextMark] = h.level;
      nextMark++;
    }
  }

  while (clock < minutes * 60) {
    townVisit(h);
    // A dungeon whenever one at our level is not cleared yet.
    DungeonDef? dun;
    final q = h.currentMain;
    if (q != null && q.type == QuestType.dungeon && !h.mainLocked &&
        (failedUntil[q.target] ?? 0) <= h.level) {
      dun = dungeonById[q.target];
    }
    for (final d in dun == null ? dungeons : const <DungeonDef>[]) {
      if (d.level <= h.level && (h.dungeonStars[d.id] ?? 0) == 0 &&
          (failedUntil[d.id] ?? 0) <= h.level) {
        dun = d;
        break;
      }
    }
    if (dun != null) {
      rep.dungeonsTried++;
      final w = World.dungeon(h, dun, seed: rng.nextInt(1 << 30))
        ..auto = true;
      var result = '';
      while (!w.finished && clock < minutes * 60) {
        w.update(dt);
        clock += dt;
        mark();
        for (final e in w.events) {
          if (e.kind == EvKind.cleared) result = 'clear ${e.value.toInt()}*';
          if (e.kind == EvKind.failed) result = 'fail ${e.text}';
        }
        w.events.clear();
      }
      if (result.startsWith('clear')) rep.dungeonsCleared++;
      rep.log.add('${(clock / 60).toStringAsFixed(1)}m lv${h.level} '
          '${dun.name}(${dun.level}) $result '
          '${w.time.toStringAsFixed(0)}s');
      // A failed dungeon is retried only after levelling up.
      if (!result.startsWith('clear')) {
        h.dungeonStars[dun.id] = 0;
        failedUntil[dun.id] = h.level + 2;
      }
      townVisit(h);
    }
    var map = maps.first;
    for (final m in maps) {
      if (m.minLv <= h.level) map = m;
    }
    // Like pressing "Đi ngay": go where the main quest's monster lives.
    final mq = h.currentMain;
    if (mq != null && !h.mainLocked &&
        (mq.type == QuestType.kill || mq.type == QuestType.boss)) {
      map = mapOfMob(mq.target) ?? map;
    }
    final w = World.field(h, map, seed: rng.nextInt(1 << 30))..auto = true;
    final until = clock + 300;
    while (clock < until && clock < minutes * 60) {
      w.update(dt);
      clock += dt;
      mark();
      var died = false;
      for (final e in w.events) {
        if (e.kind == EvKind.heroDied) died = true;
      }
      w.events.clear();
      if (died) {
        rep.deaths++;
        rep.log.add('${(clock / 60).toStringAsFixed(1)}m lv${h.level} '
            'died in ${map.name}');
        w.revive();
        break;
      }
      if (h.bag.length > 50) break;
    }
  }
  mark();
  return rep;
}
