import 'i18n.dart';
/// Bảng tin (1.16.3): notices written by hand in the Firestore console
/// (collection `news`), read by every player from the town. Besides system
/// news it can point at another game: a picture and a button that opens
/// its store page.
///
/// Fields (all optional but `title`):
/// - `title`, `body` (strings; `body` keeps its line breaks, `\n` typed in
///   the console counts as one);
/// - `tag`: a short label on the card ("Bảo trì", "Game mới"...);
/// - `image`: an https picture URL (wide pictures read best, about 2:1);
/// - `link`: the button's URL (Google Play page or any https page);
/// - `linkIos`: the URL used on iPhone/iPad instead (App Store page). A
///   notice with a `link` but no `linkIos` is not shown on iPhone, so an
///   iPhone player is never sent to Google Play;
/// - `button`: the button's label (default "Tải ngay");
/// - `from`, `until`: Vietnam days (`20261120` style, `until` inclusive),
///   or console timestamps;
/// - `order`: a number, bigger first (pinned); ties go newest `from` first;
/// - `popup`: true to open the board by itself once when the player first
///   reaches town after it is posted (use for the important ones only).
class NewsDef {
  const NewsDef({
    required this.id,
    required this.title,
    this.body = '',
    this.tag = '',
    this.image = '',
    this.link = '',
    this.linkIos = '',
    this.button = '',
    this.from = '',
    this.until = '',
    this.order = 0,
    this.popup = false,
  });

  final String id, title, body, tag, image, link, linkIos, button, from, until;
  final int order;
  final bool popup;

  bool openOn(String day) =>
      (from.isEmpty || from.compareTo(day) <= 0) && (until.isEmpty || until.compareTo(day) >= 0);

  /// The button's URL on this platform, or '' for no button.
  String linkFor({required bool ios}) => ios ? linkIos : link;

  /// Whether this notice may be shown on this platform: one that links
  /// only to Google Play stays off iPhones.
  bool showsOn({required bool ios}) => !ios || link.isEmpty || linkIos.isNotEmpty;

  String get buttonLabel => button.isEmpty ? tr('Tải ngay') : button;

  static bool _url(String s) => s.startsWith('https://') || s.startsWith('http://') || s.startsWith('market://');

  /// Reads a console document; null when it has no title.
  static NewsDef? fromMap(String id, Map<String, dynamic> m) {
    String s(String k, [int max = 4000]) {
      final v = m[k];
      if (v is! String) return '';
      final t = v.trim().replaceAll(r'\n', '\n');
      return t.length > max ? t.substring(0, max) : t;
    }

    String url(String k) {
      final v = s(k, 500);
      return _url(v) ? v : '';
    }

    String day(String k) {
      final v = m[k];
      final t = v is num ? '${v.toInt()}' : (v is String ? v.trim() : '');
      return RegExp(r'^\d{8}$').hasMatch(t) ? t : '';
    }

    final title = s('title', 80);
    if (title.isEmpty) return null;
    final o = m['order'];
    final image = url('image');
    return NewsDef(
      id: id,
      title: title,
      body: s('body'),
      tag: s('tag', 16),
      image: image.startsWith('market://') ? '' : image,
      link: url('link'),
      linkIos: url('linkIos'),
      button: s('button', 20),
      from: day('from'),
      until: day('until'),
      order: o is num ? o.toInt() : 0,
      popup: m['popup'] == true,
    );
  }

  /// The notices to show on [day], pinned first, then newest.
  static List<NewsDef> visible(Iterable<NewsDef> all, String day, {required bool ios}) => [
        for (final n in all)
          if (n.openOn(day) && n.showsOn(ios: ios)) n,
      ]..sort((a, b) {
          final o = b.order.compareTo(a.order);
          return o != 0 ? o : b.from.compareTo(a.from);
        });
}
