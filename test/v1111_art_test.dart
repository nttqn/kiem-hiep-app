import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/companions.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/mount_skins.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/pets.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/ui/theme.dart' show itemIconPath, mapArtPath;
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

  test('every item kind and tier has its painted icon', () {
    for (final h in Hanh.values) {
      for (final slot in Slot.values) {
        for (final lv in [1, 25, 45, 65, 99]) {
          final it = Item(slot: slot, level: lv, rarity: Rarity.rare, base: const {}, bonus: const {},
              name: '${tierName(lv)} ${slotNoun(slot, sectOf(h))}');
          final path = itemIconPath(it);
          expect(path, isNotNull, reason: it.name);
          expect(File(path!).existsSync(), isTrue, reason: path);
        }
      }
      expect(File('assets/art/icons/gem_${h.name}.webp').existsSync(), isTrue);
    }
  });

  test('every sect has both paintings and every region its vignette', () {
    for (final h in Hanh.values) {
      for (final g in ['m', 'f']) {
        expect(File('assets/art/sect_${h.name}_$g.webp').existsSync(), isTrue, reason: '${h.name}_$g');
      }
    }
    for (final t in MapTheme.values) {
      expect(File(mapArtPath(t.name)).existsSync(), isTrue, reason: t.name);
      expect(File('assets/art/land_${t.name}.webp').existsSync(), isTrue, reason: t.name);
    }
  });

  test('every skill, mount and pet has its painting', () {
    for (final h in Hanh.values) {
      for (final sk in sectOf(h).skills) {
        expect(File('assets/art/icons/sk_${sk.id}.webp').existsSync(), isTrue, reason: sk.id);
      }
    }
    for (final m in mounts) {
      expect(File('assets/art/mount_${m.id}.webp').existsSync(), isTrue, reason: m.id);
    }
    for (final s in mountSkins) {
      expect(File('assets/art/mount_${s.id}.webp').existsSync(), isTrue, reason: s.id);
    }
    for (final p in pets) {
      expect(File('assets/art/pet_${p.id}.webp').existsSync(), isTrue, reason: p.id);
    }
  });
}
