import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/sound.dart';

void main() {
  // 1.0.9+13 shipped looking for '.wav' (a lost interpolation) and every
  // Android effect went silent.
  test('every sound effect file exists', () {
    for (final f in SoundService.sfxFiles) {
      final path = 'assets/audio/${SoundService.sfxAsset(f)}';
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
