import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/screen_awake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the screen stays on while any fight is shown, and only then', () async {
    final calls = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('kh/screen'), (c) async {
      calls.add('${c.method}:${c.arguments}');
      return null;
    });
    ScreenAwake.hold(); // a fight
    ScreenAwake.hold(); // the next one replaces it before it is gone
    ScreenAwake.release();
    expect(calls, ['keepOn:true']);
    ScreenAwake.release();
    ScreenAwake.release(); // one too many does nothing
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['keepOn:true', 'keepOn:false']);
    expect(ScreenAwake.holds, 0);
  });
}
