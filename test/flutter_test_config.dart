import 'dart:async';

import 'package:kiem_hiep/core/weather.dart';
import 'package:kiem_hiep/core/world.dart';

/// Every test sees the same sky, whatever the clock: day, clear.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  World.debugNight = false;
  World.debugWeather = Weather.clear;
  await testMain();
}
