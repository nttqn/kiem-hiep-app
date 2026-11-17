import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/version.dart';

void main() {
  test('versions compare part by part', () {
    expect(compareVersions('1.3.1', '1.4.0'), -1);
    expect(compareVersions('1.10.0', '1.9.9'), 1);
    expect(compareVersions('1.4', '1.4.0'), 0);
    expect(compareVersions('1.4.0+27', '1.4.0'), 0);
    expect(compareVersions('2.0.0', '1.99.99'), 1);
  });

  test('an update is offered once a day, required below the minimum', () {
    UpdatePlan p({bool available = true, String? min, bool snoozed = false}) =>
        updatePlan(available: available, current: '1.3.1', min: min, snoozedToday: snoozed);
    expect(p(available: false), UpdatePlan.none);
    expect(p(), UpdatePlan.offer);
    expect(p(snoozed: true), UpdatePlan.none);
    expect(p(min: '1.3.1'), UpdatePlan.offer);
    expect(p(min: '1.4.0', snoozed: true), UpdatePlan.force);
    expect(p(min: ''), UpdatePlan.offer);
  });

  test('mustUpdate blocks only versions below min', () {
    expect(mustUpdate('1.16.1', '1.16.2'), isTrue);
    expect(mustUpdate('1.9.9', '1.16.2'), isTrue);
    expect(mustUpdate('1.16.2', '1.16.2'), isFalse);
    expect(mustUpdate('1.17.0', '1.16.2'), isFalse);
    expect(mustUpdate('1.16.1', null), isFalse);
    expect(mustUpdate('1.16.1', ' '), isFalse);
  });
}
