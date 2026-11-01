import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/duel.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/world.dart';

import 'sim.dart';
import 'v130_realm_test.dart' show geared;

/// Both phones in one test: JSON both ways, as over the wire.
class Pair {
  Pair(this.hostHero, this.guestHero) {
    final hi = DuelInfo.of(hostHero, 'host');
    final gi = DuelInfo.of(guestHero, 'guest');
    host = World.dungeon(hostHero, duelDef(_wire(gi.toJson(), DuelInfo.fromJson)), seed: 1);
    guest = World.dungeon(guestHero, duelDef(_wire(hi.toJson(), DuelInfo.fromJson), guest: true), seed: 2);
  }

  final HeroData hostHero, guestHero;
  late final World host, guest;
  double _sendT = 0;

  static T _wire<T>(Object o, T Function(Map) f) => f(jsonDecode(jsonEncode(o)) as Map);

  void step([int frames = 1]) {
    const dt = 1 / 30;
    for (var i = 0; i < frames; i++) {
      host.update(dt);
      guest.update(dt);
      _sendT += dt;
      if (_sendT >= 1 / duelSendHz) {
        _sendT = 0;
        host.remoteIn = _wire(guest.takeInput().toJson(), DuelInput.fromJson);
        guest.applyDuelSnap(jsonDecode(jsonEncode(host.duelSnapshot(1 / duelSendHz + 0.01))) as Map);
      }
    }
  }

  Mob get guestOnHost => host.boss!;
}

void main() {
  test('a hero card survives the trip', () {
    final h = geared(40, Hanh.thuy);
    final back = DuelInfo.fromJson(jsonDecode(jsonEncode(DuelInfo.of(h, 'u1').toJson())) as Map);
    expect(back.name, h.name);
    expect(back.hanh, Hanh.thuy);
    expect(back.hp, closeTo(h.stats.maxHp, 0.01));
    expect(back.skillLv, h.skillLv);
    final inp = DuelInput.fromJson(jsonDecode(jsonEncode(DuelInput(mx: 0.5, attack: true, presses: [(3, 1)]).toJson())) as Map);
    expect(inp.presses.single, (3, 1));
    expect(inp.attack, isTrue);
  });

  test('the guest steers their hero in the host world, and sees both sides', () {
    final p = Pair(geared(30, Hanh.kim), geared(30, Hanh.hoa));
    p.step(20);
    final start = p.guestOnHost.x;
    p.guest.input.moveX = -1;
    p.step(30);
    expect(p.guestOnHost.x, lessThan(start - 50));
    // The guest's own hero is where the host says, give or take a step.
    expect((p.guest.player.x - p.guestOnHost.x).abs(), lessThan(60));
    expect((p.guest.boss!.x - p.host.player.x).abs(), lessThan(40));
    // No potions, pets or companions in a duel.
    expect(p.host.pet, isNull);
    expect(p.host.companion, isNull);
  });

  test('guest skills and hits land on the host', () {
    final p = Pair(geared(40, Hanh.tho), geared(40, Hanh.hoa));
    // Past the countdown.
    p.step((duelCountdown * 30).round() + 5);
    // Bring the guest's hero next to the host's.
    p.guestOnHost
      ..x = p.host.player.x + 60
      ..y = p.host.player.y;
    final hp = p.host.player.hp;
    p.guest.input.attack = true;
    p.guest.input.skills.add(0);
    p.step(45);
    expect(p.guestOnHost.rivalCd, isNotEmpty);
    expect(p.host.player.hp, lessThan(hp));
    // The guest sees the host's HP drop too.
    expect(p.guest.boss!.hp, closeTo(p.host.player.hp, p.host.player.maxHp * 0.05));
  });

  test('a knockout ends it for both, the right way round', () {
    final p = Pair(geared(30, Hanh.kim), geared(30, Hanh.moc));
    p.step(15);
    p.guestOnHost.hp = 1;
    p.guestOnHost
      ..x = p.host.player.x + 50
      ..y = p.host.player.y;
    p.host.auto = true;
    for (var i = 0; i < 300 && !p.host.finished; i++) {
      p.step();
    }
    p.step(4);
    expect(p.host.duelWinner, 'a');
    expect(p.guest.duelWinner, 'a');
    expect(p.guest.finished, isTrue);
  });

  test('at the bell the larger share of HP wins', () {
    expect(duelByHp(0.6, 0.4), 'a');
    expect(duelByHp(0.3, 0.5), 'b');
    expect(duelByHp(0.5, 0.505), 'draw');
    final p = Pair(geared(30, Hanh.kim), geared(30, Hanh.moc));
    p.step(5);
    p.host.player.hp = p.host.player.maxHp * 0.3;
    p.host.time = duelTime + 1;
    p.step(4);
    expect(p.host.duelWinner, 'b');
    expect(p.guest.duelWinner, 'b');
  });

  group('balance', () {
    HeroData hero(Hanh h, Rarity r, int rebirths) {
      final x = HeroData(name: h.name, hanh: h)
        ..level = maxLevel
        ..rebirths = rebirths;
      final rng = math.Random(h.index);
      for (final s in Slot.values) {
        x.addItem(makeItem(slot: s, level: maxLevel, rarity: r, sect: x.sect, rng: rng));
      }
      x.freePoints = (maxLevel - 1) * pointsPerLevel + rebirths * rebirthPoints;
      x.skillPoints = 200;
      townVisit(x);
      return x;
    }

    /// The guest rushes in, holds attack and fires every skill; the host
    /// is on autopilot. Returns (winner, seconds).
    (String, double) fight(HeroData host, HeroData guest) {
      final p = Pair(host, guest);
      p.host.auto = true;
      p.host.pauseAutoOnEvents = false;
      for (var i = 0; i < 30 * (duelTime + 5) && !p.host.finished; i++) {
        final me = p.guest.player, foe = p.guest.boss!;
        final dx = foe.x - me.x, dy = foe.y - me.y;
        final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        p.guest.input
          ..moveX = d > 120 ? dx / d : 0
          ..moveY = d > 120 ? dy / d : 0
          ..attack = true;
        if (i % 15 == 0) p.guest.input.skills.addAll([0, 1, 2, 3, 4, 5, 6]);
        p.step();
      }
      return (p.host.duelWinner, p.host.finishTime);
    }

    test('no one-shot: a big burst cannot end a fight in a few seconds', () {
      // The hardest hitters of the probe (Hỏa Long, Bạo Vũ) as the guest.
      for (final h in [Hanh.hoa, Hanh.moc, Hanh.tho]) {
        final (_, t) = fight(hero(Hanh.kim, Rarity.epic, 3), hero(h, Rarity.legend, 5));
        expect(t, greaterThan(1 / duelBurstCap + duelCountdown - 0.5), reason: '${h.name} won in ${t.toStringAsFixed(1)} s');
      }
    });

    test('the much stronger hero wins, and it takes a while', () {
      final strong = hero(Hanh.thuy, Rarity.legend, 5);
      final weak = hero(Hanh.hoa, Rarity.rare, 1);
      // ignore: avoid_print
      print('power ${strong.power} vs ${weak.power}');
      final (w, t) = fight(weak, strong);
      // ignore: avoid_print
      print('strong guest: $w in ${t.toStringAsFixed(1)} s');
      expect(w, 'b');
      expect(t, greaterThan(10));
    });
  });

  test('room codes are six digits', () {
    final r = math.Random(1);
    for (var i = 0; i < 50; i++) {
      expect(duelCode(r), matches(RegExp(r'^\d{6}$')));
    }
  });
}
