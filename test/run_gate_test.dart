import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/ui/run_gate.dart';

void main() {
  test('a second tap while a boss run is starting spends nothing', () async {
    expect(RunGate.take(), isTrue);
    expect(RunGate.take(), isFalse);
    expect(RunGate.take(), isFalse);
    // The battle screen came up; a moment later the next run may start.
    RunGate.opened();
    expect(RunGate.take(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(RunGate.take(), isTrue);
  });
}
