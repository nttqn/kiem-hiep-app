import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

void main() {
  test('players on an old app get a mount for their level; known ones keep theirs', () async {
    LbEntry row(String id, {String? mount}) => LbEntry(
        id: id, name: id, hanh: 0, level: 80, rebirths: 1, power: 1000, tower: 0, mount: mount, mountLv: 7);
    Leaderboard.instance.debugEntries = [
      for (var i = 0; i < 20; i++) row('old$i'),
      row('foot', mount: ''),
      row('rider', mount: 'longma'),
    ];
    final pool = await Leaderboard.instance.arenaPool(1000);
    final old = pool.where((r) => r.name.startsWith('old')).toList();
    expect(old.where((r) => r.mountDef != null).length, greaterThan(10));
    expect(pool.firstWhere((r) => r.name == 'foot').mountDef, isNull);
    final rider = pool.firstWhere((r) => r.name == 'rider');
    expect(rider.mount, 'longma');
    expect(rider.mountLv, 7);
    Leaderboard.instance.debugEntries = null;
  });
}
