import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/companions.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/ui/world_boss_screen.dart' show bossArtIds;

void main() {
  test('every painted boss and companion has its picture, and every boss has one', () {
    for (final id in bossArtIds) {
      expect(mobById[id]?.boss, isTrue, reason: id);
      expect(File('assets/art/$id.webp').existsSync(), isTrue, reason: id);
    }
    for (final c in companions) {
      expect(File('assets/art/${c.id}.webp').existsSync(), isTrue, reason: c.id);
    }
    final bosses = [for (final m in [...mobs, ...festMobs]) if (m.boss) m.id];
    expect(bosses.where((id) => !bossArtIds.contains(id)), isEmpty);
  });
}
