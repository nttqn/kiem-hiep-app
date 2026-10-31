import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/app_version.dart';

void main() {
  test('the version in the guide matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':')[1].trim().split('+').first, appVersion);
  });
}
