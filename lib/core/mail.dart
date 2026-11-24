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
/// Ngọc, 1.13.1). 1.22: `title_zh_Hant` / `body_zh_Hant` for players in
/// that language, and `lang` (`"vi"`, `"zh_Hant"`) to post a gift to one
/// language only. One document stays one gift whatever the language.
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
    if (!langAllows(m['lang'])) return null;
    final t = localField(m, 'title');
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

    final body = localField(m, 'body');
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

// ------------------------------------------------------------- mã quà tặng

/// Mã quà tặng (1.24.2): a code the developer hands out (video, fan page)
/// as the console document `codes/{CODE}`, with the same fields as a mail.
/// Players type it in Hòm thư; each hero takes it once, kept in
/// `mailClaimed` as [giftCodeId]. The rules let a player read one code by
/// name but never list them. A code never gives Nguyệt thẻ days: those are
/// a store product, and the App Store does not allow unlocking one by code.
///
/// [raw] as typed, made the document name: spaces dropped, upper case;
/// null when it cannot be a code (3–24 of A–Z, 0–9, `_`, `-`).
String? giftCodeKey(String raw) {
  final k = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return RegExp(r'^[A-Z0-9_-]{3,24}$').hasMatch(k) ? k : null;
}

/// The claim id kept in `mailClaimed` for code [key].
String giftCodeId(String key) => 'code:$key';

/// Code [key]'s console document as a gift; null when it is not one for
/// this player's language. Its `card` field is ignored (see [giftCodeKey]).
MailDef? giftCodeFromMap(String key, Map<String, dynamic> m) {
  final d = MailDef.fromMap(giftCodeId(key), {...m, 'card': 0, 'uid': ''});
  if (d == null) return null;
  final t = localField(m, 'title');
  return t is String && t.trim().isNotEmpty
      ? d
      : MailDef(
          id: d.id,
          title: tr('Mã quà {key}', {'key': key}),
          body: d.body,
          from: d.from,
          until: d.until,
          minLevel: d.minLevel,
          gold: d.gold,
          shards: d.shards,
          iron: d.iron,
          gems: d.gems,
          gemTier: d.gemTier,
          pages: d.pages,
          hpPots: d.hpPots,
          mpPots: d.mpPots,
          jade: d.jade,
        );
}
