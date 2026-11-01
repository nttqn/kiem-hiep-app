import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('heroes set aside for one account come back only to it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SaveService.instance;
    await s.load();
    s.slots[0] = HeroData(name: 'A0', hanh: Hanh.kim)..level = 50;
    s.slots[2] = HeroData(name: 'A2', hanh: Hanh.hoa)..level = 20;
    s.backups[1] = HeroData(name: 'Abak', hanh: Hanh.moc);
    await s.writeSlot(0);
    await s.writeSlot(2);
    await s.setOwner('uidA', 'a@x.com');

    // Account B signs in and chooses to play itself here.
    await s.archiveAndClear(s.owner);
    expect(s.hasHeroes, isFalse);
    expect(s.backups.every((b) => b == null), isTrue, reason: 'no backup of A may leak into B');
    expect(await s.restoreArchive('uidB'), isFalse);
    await s.setOwner('uidB', 'b@x.com');
    s.slots[1] = HeroData(name: 'B1', hanh: Hanh.thuy);
    await s.writeSlot(1);

    // A fresh start of the app reads the same owner and slots.
    await s.load();
    expect(s.owner, 'uidB');
    expect(s.slots[1]!.name, 'B1');
    expect(s.slots[0], isNull);

    // Back to A: B's hero is set aside, A's come back where they were.
    await s.archiveAndClear(s.owner);
    expect(await s.restoreArchive('uidA'), isTrue);
    expect(s.slots[0]!.name, 'A0');
    expect(s.slots[0]!.level, 50);
    expect(s.slots[2]!.name, 'A2');
    expect(s.backups[1]!.name, 'Abak');
    expect(s.slots[1], isNull);
    // Taken once: the archive is gone.
    expect(await s.restoreArchive('uidA'), isFalse);
    // And B's is waiting for B.
    await s.archiveAndClear('uidA');
    expect(await s.restoreArchive('uidB'), isTrue);
    expect(s.slots[1]!.name, 'B1');
  });
}
