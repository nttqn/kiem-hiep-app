import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/funnel.dart';
import 'package:kiem_hiep/core/hero.dart';

void main() {
  test('device funnel starts from every hero on the phone, without the version mark', () {
    final a = HeroData(name: 'A', hanh: Hanh.kim)..funnel.addAll(['f_lv3', 'f_lv5', funnelVersion]);
    final b = HeroData(name: 'B', hanh: Hanh.thuy)..funnel.addAll(['f_lv3', 'f_q3']);
    expect(seedDeviceFunnel([a, null, b]), {'f_lv3', 'f_lv5', 'f_q3'});
    expect(seedDeviceFunnel(const [null, null]), isEmpty);
  });

  test('a second hero on the phone sends nothing the first already sent', () {
    final first = HeroData(name: 'A', hanh: Hanh.kim)..level = 12;
    final sent = <String>{};
    for (final s in funnelDue(first, '20261117')) {
      first.funnel.add(s);
      sent.add(s);
    }
    expect(sent, contains('f_lv3'));
    final second = HeroData(name: 'B', hanh: Hanh.moc)..level = 5;
    final fresh = [for (final s in funnelDue(second, '20261117')) if (sent.add(s)) s];
    expect(fresh.where((s) => s.startsWith('f_lv')), isEmpty);
  });
}
