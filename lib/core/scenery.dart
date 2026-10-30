import 'dart:math' as math;

import 'content.dart';
import 'fishing.dart';

/// A standing thing drawn sorted with the actors (trees, rocks, pillars).
class Prop {
  const Prop(this.kind, this.x, this.y, this.s, this.v);
  final String kind;
  final double x, y;

  /// Scale and a free variant number for colour/shape jitter.
  final double s;
  final int v;
}

/// A flat thing on the ground (tufts, flowers, puddles, cracks).
class Decal {
  const Decal(this.kind, this.x, this.y, this.s, this.v);
  final String kind;
  final double x, y, s;
  final int v;
}

/// A big soft colour blob that breaks up the ground fill.
class Patch {
  const Patch(this.x, this.y, this.rx, this.ry, this.shade);
  final double x, y, rx, ry;

  /// -1 darker … 1 lighter.
  final double shade;
}

class Scenery {
  Scenery(this.theme, this.props, this.decals, this.patches);

  final MapTheme theme;
  final List<Prop> props;
  final List<Decal> decals;
  final List<Patch> patches;

  static Scenery generate(MapTheme theme, double w, double h, int seed,
      {bool arena = false}) {
    final r = math.Random(seed);
    final props = <Prop>[];
    final decals = <Decal>[];
    final patches = <Patch>[];

    for (var i = 0; i < (w * h / 90000).round(); i++) {
      patches.add(Patch(
        r.nextDouble() * w,
        r.nextDouble() * h,
        80 + r.nextDouble() * 220,
        50 + r.nextDouble() * 130,
        r.nextDouble() * 2 - 1,
      ));
    }

    final kinds = _propKinds[theme]!;
    final decalKinds = _decalKinds[theme]!;
    final n = (w * h / (arena ? 60000 : 42000)).round();
    var tries = 0;
    while (props.length < n && tries < n * 20) {
      tries++;
      final x = r.nextDouble() * w;
      final y = r.nextDouble() * h;
      if (arena) {
        // Keep the fighting floor clear; dress only the rim.
        final ex = math.min(x, w - x), ey = math.min(y, h - y);
        if (ex > 150 && ey > 150) continue;
      } else {
        // Leave the entrance and the fishing pond clear.
        if ((x - 220).abs() < 260 && (y - h / 2).abs() < 260) continue;
        if ((x - pondDx).abs() < 190 && y > h / 2 + pondDy - 70 && y < h / 2 + pondDy + 180) continue;
      }
      if (props.any((p) =>
          (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y) < 90 * 90)) {
        continue;
      }
      final k = kinds[r.nextInt(kinds.length)];
      props.add(Prop(k, x, y, 0.8 + r.nextDouble() * 0.5, r.nextInt(1000)));
    }
    // Clumps make a forest edge feel deliberate.
    if (!arena) {
      for (var i = 0; i < 10; i++) {
        final cx = r.nextDouble() * w, cy = r.nextDouble() * h;
        if ((cx - 220).abs() < 400 && (cy - h / 2).abs() < 400) continue;
        for (var k = 0; k < 5; k++) {
          final px = cx + r.nextDouble() * 160 - 80, py = cy + r.nextDouble() * 120 - 60;
          final scale = 0.9 + r.nextDouble() * 0.4, v = r.nextInt(1000);
          if ((px - pondDx).abs() < 190 && py > h / 2 + pondDy - 70 && py < h / 2 + pondDy + 180) continue;
          props.add(Prop(kinds.first, px, py, scale, v));
        }
      }
    }
    for (var i = 0; i < (w * h / 6000).round(); i++) {
      decals.add(Decal(
        decalKinds[r.nextInt(decalKinds.length)],
        r.nextDouble() * w,
        r.nextDouble() * h,
        0.7 + r.nextDouble() * 0.7,
        r.nextInt(1000),
      ));
    }
    props.sort((a, b) => a.y.compareTo(b.y));
    return Scenery(theme, props, decals, patches);
  }
}

const _propKinds = <MapTheme, List<String>>{
  MapTheme.grass: ['tree', 'tree', 'bush', 'rock', 'tree2'],
  MapTheme.bamboo: ['bamboo', 'bamboo', 'bamboo', 'rock', 'bush'],
  MapTheme.cave: ['stalagmite', 'stalagmite', 'crystal', 'rock'],
  MapTheme.desert: ['deadTree', 'rockSpire', 'pillar', 'rock'],
  MapTheme.snow: ['pine', 'pine', 'iceCrystal', 'snowRock'],
  MapTheme.volcano: ['lavaRock', 'burntTree', 'vent', 'lavaRock'],
  MapTheme.fortress: ['lantern', 'pillar', 'banner', 'brazier'],
  MapTheme.cloud: ['mistPine', 'mistPine', 'rock', 'lantern', 'mistPine'],
  MapTheme.summit: ['plum', 'plum', 'swordStone', 'pillar', 'rock'],
  MapTheme.abyss: ['rockSpire', 'deadTree', 'swordStone', 'crystal', 'brazier'],
};

const _decalKinds = <MapTheme, List<String>>{
  MapTheme.grass: ['tuft', 'tuft', 'flower', 'pebble'],
  MapTheme.bamboo: ['tuft', 'leaf', 'leaf', 'pebble'],
  MapTheme.cave: ['pebble', 'bones', 'puddle', 'crack'],
  MapTheme.desert: ['pebble', 'ripple', 'ripple', 'skull'],
  MapTheme.snow: ['snowTuft', 'ripple', 'pebble', 'icePatch'],
  MapTheme.volcano: ['crack', 'ember', 'pebble', 'pebble', 'ember'],
  MapTheme.fortress: ['tile', 'tile', 'crack', 'blood'],
  MapTheme.cloud: ['tuft', 'pebble', 'mist', 'mist', 'tuft'],
  MapTheme.summit: ['petal', 'petal', 'tile', 'crack', 'pebble'],
  MapTheme.abyss: ['crack', 'bones', 'ember', 'skull', 'crack'],
};
