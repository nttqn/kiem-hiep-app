import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/guild.dart';

void main() {
  test('names that cannot be a document id are turned away up front (1.13.1)', () {
    expect(GuildService.badName('Thiên Long'), isNull);
    expect(GuildService.badName('Vạn Hoa Cốc'), isNull);
    expect(GuildService.badName('Long/Hổ'), isNotNull);
    expect(GuildService.badName(' .. '), isNotNull);
    expect(GuildService.badName('__x__'), isNotNull);
  });

  test('a failed create says why instead of only "thử lại sau"', () {
    expect(GuildService.createErrorText(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
        contains('Máy chủ không nhận'));
    expect(GuildService.createErrorText(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
        contains('Mạng yếu'));
    expect(GuildService.createErrorText(FirebaseException(plugin: 'cloud_firestore', code: 'aborted')),
        contains('(aborted)'));
    expect(GuildService.createErrorText(Exception('timeout')), contains('Mạng yếu'));
  });
}
