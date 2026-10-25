@Tags(['sim'])
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/luan_hoi.dart';
import 'package:kiem_hiep/core/world.dart';

import 'sim.dart';

/// A level-99 hero in good gear, reborn [rebirths] times: how fast does
/// Luân Hồi go, and do the elites kill them?
HeroData _reborn(Hanh hanh, int rebirths, {Rarity rarity = Rarity.epic}) {
  final h = HeroData(name: 'Sim', hanh: hanh);
  final rng = math.Random(7);
  h.mainQuest = mainQuests.length;
  h.rebirths = rebirths - 1;
  while (!h.canRebirth) {
    h.gainExp(h.expNeeded.toDouble());
  }
  for (final s in Slot.values) {
    h.addItem(makeItem(slot: s, level: 99, rarity: rarity, sect: h.sect, rng: rng));
  }
  h.autoSpend();
  h.autoLearn();
  h.autoEquip();
  h.rebirth();
  h.autoSpend();
  h.notices.clear();
  return h;
}

void main() {
  for (final hn in Hanh.values) {
    test('Luân Hồi pace, ${hn.name}', () {
      final h = _reborn(hn, 1);
      final rep = simulate(hn, minutes: 240, start: h);
      final marks = [30, 60, 120, 180, 240].map((m) => '${m}m:${rep.levelAtMinute[m]}').join(' ');
      // ignore: avoid_print
      print('${h.sect.name.padRight(15)} $marks  quest ${h.rbQuest}/12 deaths ${rep.deaths}');
    }, timeout: const Timeout(Duration(minutes: 10)));
  }

  // Each chapter's last elite, met at the quest's level by a hero in Quý
  // (rare) level-99 gear: seconds to win and deaths on the way.
  for (var ch = 0; ch < luanHoi.length; ch++) {
    test('finale of ${chapterLabel(ch)}', () {
      final out = <String>[];
      for (final hn in Hanh.values) {
        final h = _reborn(hn, ch + 1, rarity: Rarity.rare);
        h.rbQuest = luanHoi[ch].quests.length - 1;
        final q = h.currentMain!;
        while (h.level < q.minLv) {
          h.gainExp(h.expNeeded.toDouble());
        }
        h.autoSpend();
        h.autoLearn();
        h.hpPots = 30;
        h.mpPots = 20;
        final w = World.field(h, questMap(q)!, seed: 5)..auto = true;
        var deaths = 0;
        var t = 0.0;
        while (h.rbQuest == luanHoi[ch].quests.length - 1 && t < 600) {
          w.update(1 / 30);
          t += 1 / 30;
          for (final e in w.events) {
            if (e.kind == EvKind.heroDied) {
              deaths++;
              w.revive();
            }
          }
          w.events.clear();
        }
        out.add('${hn.name} ${h.rbQuest == luanHoi[ch].quests.length ? '${t.round()}s' : 'FAIL'} d$deaths');
      }
      // ignore: avoid_print
      print('${chapterLabel(ch)} lv${luanHoi[ch].quests.last.minLv}: ${out.join(', ')}');
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
