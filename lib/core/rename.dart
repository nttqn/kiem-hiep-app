import 'chat.dart';
import 'hero.dart';

/// Đổi tên (1.5.0): a rewarded ad renames the hero, once a week. The old
/// names are kept so cloud sync still knows it is the same character.
const int renameCooldownMs = 7 * 24 * 3600 * 1000;
const int nameMaxLength = 14;

/// Former names kept per hero.
const int oldNamesKept = 10;

extension Rename on HeroData {
  /// When the next rename is allowed (ms; 0 = now).
  int get renameReadyAt => renamedAt <= 0 ? 0 : renamedAt + renameCooldownMs;

  bool canRename(int nowMs) => nowMs >= renameReadyAt;

  /// Why [raw] cannot be the new name, or null when it can.
  String? renameProblem(String raw) {
    final n = raw.trim();
    if (n.isEmpty) return 'Hãy nhập tên mới.';
    if (n.runes.length > nameMaxLength) return 'Tên tối đa $nameMaxLength ký tự.';
    if (n == name) return 'Tên mới trùng tên hiện tại.';
    if (chatCensor(n) != n) return 'Tên có từ ngữ không phù hợp.';
    return null;
  }

  /// Renames to [raw]; false when it is not allowed yet or not valid.
  bool rename(String raw, int nowMs) {
    final n = raw.trim();
    if (!canRename(nowMs) || renameProblem(n) != null) return false;
    oldNames.remove(name);
    oldNames.add(name);
    if (oldNames.length > oldNamesKept) oldNames.removeRange(0, oldNames.length - oldNamesKept);
    oldNames.remove(n);
    name = n;
    renamedAt = nowMs;
    return true;
  }
}
