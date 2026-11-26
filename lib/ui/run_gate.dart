/// One counted run per tap. On a slow phone the screen stays up for a
/// moment after "Đánh" / "Đánh tiếp" (the save and the fade), and every
/// extra tap used to spend another run and stack another battle screen
/// (1.24.2 review: "đang chơi thì mất hết lượt đánh boss").
///
/// [take] before spending a run; the battle screen calls [opened] once it
/// is up, which keeps the gate shut a moment longer for a stray tap on the
/// screen fading out.
class RunGate {
  RunGate._();

  static DateTime _shutUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// False while a run is already starting.
  static bool take() {
    final now = DateTime.now();
    if (now.isBefore(_shutUntil)) return false;
    // Opens again by itself should the battle never come up.
    _shutUntil = now.add(const Duration(seconds: 6));
    return true;
  }

  static void opened() {
    _shutUntil = DateTime.now().add(const Duration(milliseconds: 800));
  }
}
