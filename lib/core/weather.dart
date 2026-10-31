import 'dart:math' as math;

import 'content.dart';
import 'world_boss.dart' show vnNow;

/// Thời tiết and ngày đêm on field maps and bí cảnh, by Vietnam time: the
/// weather of each map changes every two hours, and night falls from 18:00
/// to 6:00. Night brings Dạ Yêu, rare monsters that pay more.
enum Weather {
  clear('Trời quang'),
  rain('Mưa'),
  fog('Sương mù'),
  snow('Tuyết rơi'),
  sand('Bão cát'),
  ash('Tro bụi'),
  petals('Hoa bay');

  const Weather(this.label);
  final String label;
}

/// What each land may get besides clear skies.
const _weathers = <MapTheme, List<Weather>>{
  MapTheme.grass: [Weather.rain, Weather.fog],
  MapTheme.bamboo: [Weather.rain, Weather.fog],
  MapTheme.cave: [],
  MapTheme.desert: [Weather.sand],
  MapTheme.snow: [Weather.snow, Weather.fog],
  MapTheme.volcano: [Weather.ash],
  MapTheme.fortress: [Weather.rain, Weather.fog],
  MapTheme.cloud: [Weather.fog, Weather.rain],
  MapTheme.summit: [Weather.petals, Weather.fog],
  MapTheme.abyss: [Weather.ash, Weather.fog],
};

/// Share of two-hour spells with some weather.
const double weatherChance = 0.55;

/// Night hours, Vietnam time.
bool isNight([DateTime? now]) {
  final h = vnNow(now).hour;
  return h >= 18 || h < 6;
}

/// The weather on [mapId] (of [theme]) at [now]: fixed for each two-hour
/// spell so everyone on the map sees the same sky.
Weather weatherOf(String mapId, MapTheme theme, [DateTime? now]) {
  final opts = _weathers[theme]!;
  if (opts.isEmpty) return Weather.clear;
  final t = vnNow(now);
  final spell = t.year * 10000 + t.month * 100 + t.day + (t.hour ~/ 2) * 37;
  final r = math.Random(spell * 31 + mapId.hashCode);
  if (r.nextDouble() >= weatherChance) return Weather.clear;
  return opts[r.nextInt(opts.length)];
}

/// Chance a field monster comes back as a Dạ Yêu at night, and its
/// strength and pay.
const double nightMobChance = 0.06;
const double nightMobHp = 2.2;
const double nightMobAtk = 1.25;
const double nightMobExp = 4;
const double nightMobGold = 3;
