import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import '../core/content.dart';
import 'quality.dart';

/// Painted battle ground textures (assets/art/ground/{theme}.webp, tiling
/// in both directions), loaded when a battle opens. Until one is in, or if
/// it cannot be read, the ground is drawn in code as before.
class GroundTex {
  GroundTex._();

  static final Map<MapTheme, Image> _cache = {};

  /// World units one tile of the texture covers.
  static const double tile = 620;

  static Image? of(MapTheme t) => _cache[t];

  /// Loads [t]'s texture; keeps at most two (a battle and the next).
  static Future<void> load(MapTheme t) async {
    if (_cache.containsKey(t)) return;
    try {
      final data = await rootBundle.load('assets/art/ground/${t.name}.webp');
      // Half size in Chế độ máy yếu: a quarter of the memory.
      final codec = await instantiateImageCodec(Uint8List.sublistView(data), targetWidth: liteGraphics ? 384 : null);
      final img = (await codec.getNextFrame()).image;
      if (_cache.length >= 2) {
        final old = _cache.keys.first;
        _cache.remove(old)?.dispose();
      }
      _cache[t] = img;
    } catch (_) {}
  }

  static final Map<MapTheme, Paint> _paints = {};

  /// A paint that tiles [t]'s texture over world space, or null.
  static Paint? paint(MapTheme t) {
    final img = _cache[t];
    if (img == null) return null;
    final p = _paints[t];
    if (p != null && p.shader != null && _painted[t] == img) return p;
    final s = tile / img.width;
    final m = Float64List(16)
      ..[0] = s
      ..[5] = s
      ..[10] = 1
      ..[15] = 1;
    _painted[t] = img;
    return _paints[t] = Paint()
      ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, m, filterQuality: FilterQuality.medium);
  }

  static final Map<MapTheme, Image> _painted = {};
}
