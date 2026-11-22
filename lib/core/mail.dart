import 'dart:math' as math;

import 'gems.dart' show maxRewardGemTier;
import 'i18n.dart';

/// Hòm thư: gifts the developer posts for every player in the Firebase
/// console (`mail/{id}`), claimed once per hero.
///
/// Fields (all optional; a default title stands in): `title`, `body` (strings); `from`,
/// `until` (Vietnam days, `20261101` style, `until` inclusive); `minLevel`
/// (needs this level or any rebirth); and the rewards `gold`, `shards`
/// (Mảnh Hoàng Kim), `iron` (Thần Thiết), `gems` with `gemTier`, `pages`
/// (bí kíp pages, once bí kíp is open), `hpPots`, `mpPots`, `jade` (Tiên
/// Ngọc, 1.13.1).
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
    this.jade = 0,
    this.uid = '',
    this.card = 0,
  });

  final String id, title, body, from, until;
  final int minLevel, gold, shards, iron, gems, gemTier, pages, hpPots, mpPots, jade;

  /// Only for this account (its Firebase uid, the part of a leaderboard row
  /// id before "_"); empty for everyone. Days of Nguyệt thẻ given (1.8.0).
  final String uid;
  final int card;

  /// Open on Vietnam day [day].
  bool openOn(String day) =>
      (from.isEmpty || from.compareTo(day) <= 0) && (until.isEmpty || until.compareTo(day) >= 0);

  /// What it gives, as short labels.
  List<String> get rewards => [
        if (gold > 0) tr('{p0} lượng', {'p0': gold.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => thouSep)}),
        if (shards > 0) tr('{shards} Mảnh Hoàng Kim', {'shards': shards}),
        if (iron > 0) tr('{iron} Thần Thiết', {'iron': iron}),
        if (gems > 0) tr('{gems} ngọc bậc {gemTier}', {'gems': gems, 'gemTier': gemTier}),
        if (pages > 0) tr('{pages} trang bí kíp', {'pages': pages}),
        if (hpPots > 0) tr('{hpPots} bình máu', {'hpPots': hpPots}),
        if (mpPots > 0) tr('{mpPots} bình nội lực', {'mpPots': mpPots}),
        if (jade > 0) tr('{jade} Tiên Ngọc', {'jade': jade}),
        if (card > 0) tr('{card} ngày Nguyệt thẻ', {'card': card}),
      ];

  /// Reads a console document; null when it is not a mail. Amounts are
  /// capped so a typo cannot hand out a fortune.
  static MailDef? fromMap(String id, Map<String, dynamic> m) {
    final t = m['title'];
    final title = t is String && t.trim().isNotEmpty ? t : tr('Thư từ nhà phát triển');
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
      gemTier: math.max(1, n('gemTier', maxRewardGemTier)),
      pages: n('pages', 50),
      hpPots: n('hpPots', 999),
      mpPots: n('mpPots', 999),
      jade: n('jade', 200),
      uid: m['uid'] is String ? (m['uid'] as String).trim() : '',
      card: n('card', 90),
    );
  }
}
