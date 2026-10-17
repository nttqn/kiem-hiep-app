import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/services/sync_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

SlotInfo info(int at, String data, {String name = 'A', int level = 1, double play = 0, int cs = 0}) =>
    SlotInfo(savedAt: at, data: data, name: name, sect: 'X', level: level, playSeconds: play, rebirths: cs);

HeroData hero(String name, int level, {Hanh hanh = Hanh.hoa}) {
  final h = HeroData(name: name, hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.playSeconds = level * 600.0;
  return h;
}

void main() {
  group('sync plan', () {
    test('a newer device copy that is behind the cloud one asks instead of uploading', () {
      // Android restored an old backup (level 27) after the cloud got level 50.
      final local = info(200, 'old', level: 27, play: 9000);
      final cloud = info(100, 'new', level: 50, play: 30000);
      expect(planSync([local], [cloud]), [SlotAction.ask]);
    });

    test('a newer device copy of another character asks too', () {
      expect(planSync([info(200, 'b', name: 'B', level: 60)], [info(100, 'a', name: 'A', level: 10)]),
          [SlotAction.ask]);
    });

    test('normal progress still uploads', () {
      expect(planSync([info(200, 'n', level: 31, play: 5000)], [info(100, 'o', level: 30, play: 4800)]),
          [SlotAction.upload]);
    });

    test('a rebirth (lower level, more rebirths) is progress, not a loss', () {
      final before = info(1, 'a', level: 99, play: 90000);
      final after = info(2, 'b', level: 10, play: 90100, cs: 1);
      expect(wouldLose(before, after), isFalse);
      expect(planSync([after], [before]), [SlotAction.upload]);
    });

    test('backups worth offering and which one to keep', () {
      final lv50 = info(1, 'a', level: 50);
      final lv27 = info(2, 'b', level: 27);
      expect(backupWorthOffering(lv27, lv50), isTrue);
      expect(backupWorthOffering(lv50, lv27), isFalse);
      expect(backupWorthOffering(null, lv27), isTrue);
      expect(backupWorthOffering(lv50, null), isFalse);
      expect(shouldStash(lv27, lv50), isFalse, reason: 'keep the furthest copy');
      expect(shouldStash(lv50, lv27), isTrue);
      expect(shouldStash(lv27, null), isTrue);
    });
  });

  group('device backups', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final s = SaveService.instance;
      for (var i = 0; i < slotCount; i++) {
        s.slots[i] = null;
        s.backups[i] = null;
      }
    });

    test('replacing a slot with a copy that is behind keeps the old one', () async {
      final s = SaveService.instance;
      await s.replaceSlot(0, hero('An', 50));
      expect(s.backups[0], isNull, reason: 'nothing was overwritten');
      await s.replaceSlot(0, hero('An', 27));
      expect(s.slots[0]!.level, 27);
      expect(s.backups[0]!.level, 50);
      // A second, even lower overwrite keeps the level 50 backup.
      await s.replaceSlot(0, hero('An', 5));
      expect(s.backups[0]!.level, 50);

      // It survives a restart.
      for (var i = 0; i < slotCount; i++) {
        s.slots[i] = null;
        s.backups[i] = null;
      }
      await s.load();
      expect(s.slots[0]!.level, 5);
      expect(s.backups[0]!.level, 50);
    });

    test('restoring swaps the backup in and keeps the current copy', () async {
      final s = SaveService.instance;
      await s.replaceSlot(1, hero('Binh', 50));
      await s.replaceSlot(1, hero('Binh', 27));
      await s.restore(1, s.backups[1]!);
      expect(s.slots[1]!.level, 50);
      expect(s.backups[1]!.level, 27);
      expect(s.slots[1]!.savedAt, greaterThan(0), reason: 'restamped so it wins the next sync');
    });

    test('a deleted character can be brought back', () async {
      final s = SaveService.instance;
      await s.replaceSlot(2, hero('Cuong', 33));
      await s.delete(2);
      expect(s.slots[2], isNull);
      expect(s.backups[2]!.name, 'Cuong');
      await s.restore(2, s.backups[2]!);
      expect(s.slots[2]!.level, 33);
      expect(s.backups[2], isNull);
    });
  });
}
