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
  Scenery(this.theme, this.props, this.decals, this.patches, [this.paths = const []]);

  final MapTheme theme;
  final List<Prop> props;
  final List<Decal> decals;
  final List<Patch> patches;

  /// Worn trails across the land, as points to join with a soft stroke.
  final List<List<(double, double)>> paths;

  static Scenery generate(MapTheme theme, double w, double h, int seed,
      {bool arena = false, bool landmarks = true}) {
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
    // Trails and a few landmarks, from their own dice so the rest of the
    // land stays as it was before they came (1.4.0).
    final paths = <List<(double, double)>>[];
    if (!arena) {
      final q = math.Random(seed ^ 0x51ed27);
      List<(double, double)> trail(double x0, double y0, double x1, double y1) {
        final pts = <(double, double)>[];
        final n = (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) / 160).ceil();
        var wob = 0.0;
        for (var i = 0; i <= n; i++) {
          final u = i / n;
          wob = (wob + (q.nextDouble() - 0.5) * 70).clamp(-160, 160);
          final nx = -(y1 - y0), ny = x1 - x0;
          final len = math.max(1, math.sqrt(nx * nx + ny * ny));
          pts.add((x0 + (x1 - x0) * u + nx / len * wob, y0 + (y1 - y0) * u + ny / len * wob));
        }
        return pts;
      }

      paths.add(trail(120, h / 2, w - 120, 200 + q.nextDouble() * (h - 400)));
      paths.add(trail(w * (0.3 + q.nextDouble() * 0.4), 120, w * (0.3 + q.nextDouble() * 0.4), h - 120));
      final kinds = _landmarks[theme] ?? const [];
      final spots = <(double, double)>[];
      var tries = 0;
      while (landmarks && spots.length < 3 && kinds.isNotEmpty && tries++ < 60) {
        final x = 500 + q.nextDouble() * (w - 800), y = 260 + q.nextDouble() * (h - 520);
        if ((x - 220).abs() < 420 && (y - h / 2).abs() < 320) continue;
        if (spots.any((s) => (s.$1 - x).abs() < 700 && (s.$2 - y).abs() < 500)) continue;
        spots.add((x, y));
        props.removeWhere((p) => (p.x - x).abs() < 150 && (p.y - y).abs() < 110);
        props.add(Prop(kinds[spots.length % kinds.length], x, y, 1, q.nextInt(1000)));
      }
    }
    // Đông Hải: nothing stands in the sea along the north edge.
    if (theme == MapTheme.sea && !arena) props.removeWhere((p) => p.y < 120);
    props.sort((a, b) => a.y.compareTo(b.y));
    return Scenery(theme, props, decals, patches, paths);
  }
}

/// Big one-off set pieces, three a land, so the map is not the same trees
/// over and over: a shrine, a gate, a pavilion, a stele on a turtle, a
/// seated stone Buddha, a pagoda, ruins, a shipwreck.
const _landmarks = <MapTheme, List<String>>{
  MapTheme.grass: ['lm_shrine', 'lm_gate'],
  MapTheme.bamboo: ['lm_pavilion', 'lm_stele'],
  MapTheme.cave: ['lm_buddha', 'lm_stele'],
  MapTheme.desert: ['lm_ruin', 'lm_buddha'],
  MapTheme.snow: ['lm_stele', 'lm_pagoda'],
  MapTheme.volcano: ['lm_ruin', 'lm_buddha'],
  MapTheme.fortress: ['lm_pagoda', 'lm_gate'],
  MapTheme.cloud: ['lm_pavilion', 'lm_pagoda'],
  MapTheme.summit: ['lm_stele', 'lm_gate'],
  MapTheme.abyss: ['lm_buddha', 'lm_ruin'],
  MapTheme.sea: ['lm_wreck', 'lm_shrine'],
  MapTheme.bloodSea: ['lm_ruin', 'lm_buddha'],
};

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
  MapTheme.sea: ['palm', 'palm', 'coral', 'rock', 'anchor', 'palm', 'coral'],
  MapTheme.bloodSea: ['rockSpire', 'deadTree', 'brazier', 'rockSpire', 'crystal'],
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
  MapTheme.sea: ['shell', 'starfish', 'ripple', 'tidePool', 'shell', 'pebble'],
  MapTheme.bloodSea: ['ember', 'bones', 'skull', 'crack', 'ember'],
};
