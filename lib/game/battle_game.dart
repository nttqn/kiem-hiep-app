import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/world.dart';
import '../render/world_renderer.dart';

/// Steps the [World] in small fixed slices and paints it. The HUD, buttons
/// and dialogs are Flutter widgets on top.
class BattleGame extends Game {
  BattleGame({required this.world, required this.onEvent, required this.onSound});

  final World world;
  final WorldRenderer renderer = WorldRenderer();
  final void Function(GameEvent e) onEvent;
  final void Function(String cue) onSound;

  /// Bumped about 15 times a second so the HUD rebuilds cheaply.
  final ValueNotifier<int> hudTick = ValueNotifier(0);
  bool halted = false;
  double speed = debugSpeed;

  /// Dev build only: slow the whole battle down (animations included) so a
  /// screen recorder can catch every frame; the video is sped up after.
  static double debugSpeed = 1;

  /// Dev build only: print each sound cue so a recorder can lay the game's
  /// own effects under a captured video.
  static bool debugLogSfx = false;

  double _clock = 0;
  double _sinceHud = 0;
  double _lastDt = 1 / 60;

  @override
  void update(double dt) {
    _lastDt = dt.clamp(0, 0.1).toDouble();
    if (!halted) {
      var left = _lastDt * speed;
      while (left > 0) {
        final step = left > 1 / 60 ? 1 / 60 : left;
        world.update(step);
        left -= step;
      }
      _clock += _lastDt * speed;
    }
    if (world.events.isNotEmpty) {
      final events = List<GameEvent>.of(world.events);
      world.events.clear();
      for (final e in events) {
        if (e.kind == EvKind.shake) {
          renderer.shake = (renderer.shake + e.value).clamp(0, 14).toDouble();
        } else {
          onEvent(e);
        }
      }
    }
    if (world.sounds.isNotEmpty) {
      final cues = world.sounds.toSet();
      cues.forEach(onSound);
      if (debugLogSfx) {
        for (final c in cues) {
          debugPrint('SFX $c');
        }
      }
      world.sounds.clear();
    }
    _sinceHud += dt;
    if (_sinceHud >= 1 / 15) {
      _sinceHud = 0;
      hudTick.value++;
    }
  }

  @override
  void render(Canvas canvas) {
    renderer.render(canvas, size.toSize(), world, _clock, halted ? 0 : _lastDt * speed);
  }
}
