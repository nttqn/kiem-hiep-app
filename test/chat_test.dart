import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/chat.dart';

void main() {
  test('swear words are starred, everyday words are not', () {
    expect(chatCensor('đm thằng này'), '** thằng này');
    expect(chatCensor('Vui quá VCL!'), 'Vui quá ***!');
    expect(chatCensor('địttt'), '*****');
    expect(chatCensor('shiiit happens'), '****** happens');
    // Unaccented look-alikes of swears are ordinary Vietnamese.
    expect(chatCensor('lon nuoc, cac ban, buoi sang, deo nhan'), 'lon nuoc, cac ban, buoi sang, deo nhan');
    expect(chatCensor('Đông Phương Bất Bại'), 'Đông Phương Bất Bại');
  });

  test('messages are one trimmed line within the limit', () {
    expect(chatClean('  chào\n\ngiang   hồ  '), 'chào giang hồ');
    expect(chatClean('   '), '');
    final long = chatClean('a' * 300);
    expect(long.length, chatMaxLen);
    // An emoji straddling the limit is dropped whole, not split.
    final emoji = chatClean('${'a' * (chatMaxLen - 1)}😀');
    expect(emoji, 'a' * (chatMaxLen - 1));
  });

  test('ten minute cooldown', () {
    const t = 1000000000;
    expect(chatWait(null, t), Duration.zero);
    expect(chatWait(t, t), chatCooldown);
    expect(chatWait(t, t + chatCooldown.inMilliseconds), Duration.zero);
    expect(chatWaitLabel(const Duration(minutes: 7, seconds: 32)), '7:32');
    expect(chatWaitLabel(const Duration(milliseconds: 59500)), '1:00');
  });

  test('messages read from the database', () {
    final m = ChatMsg.fromMap('k', {
      'uid': 'u',
      'name': 'Kiều Phong',
      'hanh': 9,
      'level': 99,
      'text': 'đm',
      'at': 5,
    });
    expect(m, isNotNull);
    expect(m!.hanh, 4);
    expect(m.rebirths, 0);
    expect(m.text, '**');
    expect(ChatMsg.fromMap('k', 'junk'), isNull);
    expect(ChatMsg.fromMap('k', {'uid': 'u'}), isNull);
  });
}
