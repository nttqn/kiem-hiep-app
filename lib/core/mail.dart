import 'dart:math' as math;

import 'gems.dart' show maxGemTier;

/// Hòm thư: gifts the developer posts for every player in the Firebase
/// console (`mail/{id}`), claimed once per hero.
///
/// Fields (all optional but `title`): `title`, `body` (strings); `from`,
/// `until` (Vietnam days, `20261101` style, `until` inclusive); `minLevel`
/// (needs this level or any rebirth); and the rewards `gold`, `shards`
/// (Mảnh Hoàng Kim), `iron` (Thần Thiết), `gems` with `gemTier`, `pages`
/// (bí kíp pages, once bí kíp is open), `hpPots`, `mpPots`.
class MailDef {
  const MailDef({
    required this.id,
    required this.title,
    this.body = '',
    this.from = '',
    this.until = '',
    this.minLevel = 0,
    this.gold = 0,
    this.shards = 0,
    this.iron = 0,
    this.gems = 0,
    this.gemTier = 1,
    this.pages = 0,
    this.hpPots = 0,
    this.mpPots = 0,
  });

  final String id, title, body, from, until;
  final int minLevel, gold, shards, iron, gems, gemTier, pages, hpPots, mpPots;

  /// Open on Vietnam day [day].
  bool openOn(String day) =>
      (from.isEmpty || from.compareTo(day) <= 0) && (until.isEmpty || until.compareTo(day) >= 0);

  /// What it gives, as short labels.
  List<String> get rewards => [
        if (gold > 0) '${gold.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.')} lượng',
        if (shards > 0) '$shards Mảnh Hoàng Kim',
        if (iron > 0) '$iron Thần Thiết',
        if (gems > 0) '$gems ngọc bậc $gemTier',
        if (pages > 0) '$pages trang bí kíp',
        if (hpPots > 0) '$hpPots bình máu',
        if (mpPots > 0) '$mpPots bình nội lực',
      ];

  /// Reads a console document; null when it is not a mail. Amounts are
  /// capped so a typo cannot hand out a fortune.
  static MailDef? fromMap(String id, Map<String, dynamic> m) {
    final title = m['title'];
    if (title is! String || title.trim().isEmpty) return null;
    int n(String k, int max) {
      final v = m[k];
      return v is num ? v.toInt().clamp(0, max) : 0;
    }

    String day(String k) {
      final v = m[k];
      final s = v is num ? '${v.toInt()}' : (v is String ? v.trim() : '');
      return RegExp(r'^\d{8}$').hasMatch(s) ? s : '';
    }

    final body = m['body'];
    return MailDef(
      id: id,
      title: title.trim(),
      body: body is String ? body.trim() : '',
      from: day('from'),
      until: day('until'),
      minLevel: n('minLevel', 99),
      gold: n('gold', 100000000),
      shards: n('shards', 1000),
      iron: n('iron', 1000),
      gems: n('gems', 50),
      gemTier: math.max(1, n('gemTier', maxGemTier)),
      pages: n('pages', 50),
      hpPots: n('hpPots', 999),
      mpPots: n('mpPots', 999),
    );
  }
}
