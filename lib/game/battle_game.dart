import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/world.dart';
import '../render/quality.dart';
import '../render/vfx.dart';
import '../render/world_renderer.dart';

/// Steps the [World] in small fixed slices and paints it. The HUD, buttons
/// and dialogs are Flutter widgets on top.
class BattleGame extends Game {
  BattleGame({required this.world, required this.onEvent, required this.onSound, this.onSlow, this.onIntro});

  final World world;
  final WorldRenderer renderer = WorldRenderer();
  final void Function(GameEvent e) onEvent;
  final void Function(String cue) onSound;

  /// Called once with the frame rate when the first [slowWindow] seconds of
  /// play (after [slowSkip]) ran under [slowFps]: the phone struggles.
  final void Function(double fps)? onSlow;

  /// A boss came on stage: the screen shows their name while the camera
  /// holds on them and the fight waits.
  final void Function(Mob boss)? onIntro;

  /// Real seconds left of a crit's freeze, a falling boss's slow motion,
  /// and a boss's entrance.
  double _freeze = 0, _slow = 0, _intro = 0;

  /// Whether a boss's entrance is holding the fight.
  bool get introducing => _intro > 0;
  static const double slowSkip = 2, slowWindow = 10, slowFps = 35;
  double _perfTime = 0;
  int _perfFrames = 0;
  bool _perfDone = false;

  void _measure(double dt) {
    if (_perfDone || onSlow == null || halted) return;
    _perfTime += dt;
    if (_perfTime <= slowSkip) return;
    _perfFrames++;
    if (_perfTime < slowSkip + slowWindow) return;
    _perfDone = true;
    final fps = _perfFrames / (_perfTime - slowSkip);
    if (fps < slowFps) onSlow!(fps);
  }

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
  double _smoothDt = 1 / 60, _dtDebt = 0;
  bool _paused = false;
  double _visDt = 0;

  @override
  void update(double dt) {
    _measure(dt);
    // Frame times wobble on weak phones (16, 33, 20 ms...); moving the world
    // by each raw gap makes walking and the camera judder. Ease toward it,
    // and carry what is left over so game time never drifts.
    final raw = dt.clamp(0, 0.1).toDouble() + _dtDebt;
    _smoothDt += (raw - _smoothDt) * 0.25;
    _lastDt = raw < _smoothDt ? raw : _smoothDt;
    _dtDebt = raw - _lastDt;
    if (_dtDebt > 0.1) _dtDebt = 0;
    if (world.hitStop > 0) {
      if (world.hitStop > _freeze) _freeze = world.hitStop;
      world.hitStop = 0;
    }
    if (world.slowMo > 0) {
      _slow = world.slowMo;
      world.slowMo = 0;
    }
    final intro = world.introBoss;
    if (intro != null) {
      world.introBoss = null;
      if (intro.alive && !halted) {
        _intro = bossIntroTime;
        renderer.focus = intro;
        onIntro?.call(intro);
      }
    }
    _paused = halted;
    if (!halted) {
      if (_intro > 0) {
        // The fight waits; idle animations go on.
        _intro -= _lastDt;
        if (_intro <= 0) renderer.focus = null;
        _clock += _lastDt * speed;
      } else if (_freeze > 0) {
        // A blink of stillness as a heavy blow lands.
        _freeze -= _lastDt;
        _paused = true;
      } else {
        final slow = _slow > 0 ? 0.35 : 1.0;
        if (_slow > 0) _slow -= _lastDt;
        var left = _lastDt * speed * slow;
        while (left > 0) {
          final step = left > 1 / 60 ? 1 / 60 : left;
          world.update(step);
          left -= step;
        }
        _clock += _lastDt * speed * slow;
        _visDt = _lastDt * speed * slow;
      }
    }
    if (world.events.isNotEmpty) {
      final events = List<GameEvent>.of(world.events);
      world.events.clear();
      for (final e in events) {
        if (e.kind == EvKind.shake) {
          if (!liteGraphics) renderer.shake = (renderer.shake + e.value).clamp(0, 14).toDouble();
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
    renderer.render(canvas, size.toSize(), world, _clock, _paused ? 0 : (_intro > 0 ? _lastDt : _visDt));
  }
}
