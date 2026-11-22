import 'i18n.dart';

/// Câu chat nhanh (1.24.0): ready-made lines for the World and bang chats.
///
/// A line is sent as its Vietnamese text, so older apps show it as if it
/// were typed, and each reader's app shows it in their own language
/// ([chatShow]): players of different languages in one bang can still greet,
/// thank and call each other to a boss. Nothing new is stored and the
/// server rules are unchanged.
const quickPhrases = <String>[
  'Chào mọi người!',
  'Cảm ơn nhé!',
  'Không có gì.',
  'Xin lỗi.',
  'Chúc mừng!',
  'Đánh hay lắm!',
  'Đi đánh Boss Thế Giới không?',
  'Ai đánh Bang chiến cùng không?',
  'Vào bang mình nhé!',
  'Bang mình đang nhận người.',
  'Kết bạn nhé!',
  'Cần giúp gì không?',
  'Tôi là người mới, xin chỉ giáo.',
  'Đợi mình chút.',
  'Hẹn gặp lại!',
  'Chúc ngủ ngon!',
  'Tôi nói tiếng Việt.',
  'Tôi nói tiếng Trung.',
  'Tôi nói tiếng Hàn.',
  'Tôi nói tiếng Anh.',
];

/// Emotes: the same in every language, added to what is being typed.
const quickEmotes = <String>['👋', '👍', '🙏', '😂', '😭', '😡', '❤️', '🔥', '💪', '🎉', '⚔️', '🐉'];

final Set<String> _quick = quickPhrases.toSet();

/// [text] as the reader sees it: a quick line in their language, anything
/// else as it was written.
String chatShow(String text) => _quick.contains(text) ? tr(text) : text;
