import 'package:flutter/material.dart';

import '../core/news.dart';
import '../services/news.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Bảng tin (1.16.3): the notices from `news`, newest and pinned first;
/// tapping one opens it with its picture and button. [first] opens straight
/// on that notice (a `popup` one on reaching town).
Future<void> showNewsDialog(BuildContext context, {NewsDef? first}) {
  return showDialog<void>(context: context, builder: (_) => _NewsDialog(first: first));
}

class _NewsDialog extends StatefulWidget {
  const _NewsDialog({this.first});

  final NewsDef? first;

  @override
  State<_NewsDialog> createState() => _NewsDialogState();
}

class _NewsDialogState extends State<_NewsDialog> {
  NewsService get ns => NewsService.instance;
  NewsDef? _open;

  @override
  void initState() {
    super.initState();
    ns.addListener(_changed);
    final f = widget.first;
    if (f != null) _show(f);
  }

  @override
  void dispose() {
    ns.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _show(NewsDef n) {
    _open = n;
    ns.markRead(n);
  }

  String _day(String d) => d.length == 8 ? '${int.parse(d.substring(6))}/${int.parse(d.substring(4, 6))}' : '';

  @override
  Widget build(BuildContext context) {
    final n = _open;
    return AlertDialog(
      backgroundColor: lacquer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Row(
        children: [
          if (n != null)
            IconButton(
              tooltip: tr('Quay lại'),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _open = null),
              icon: const Icon(Icons.arrow_back, color: goldLight),
            ),
          Expanded(
            child: Text(n?.title ?? tr('Bảng tin'),
                style: titleStyle(20), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: SizedBox(width: 600, child: n == null ? _list() : _detail(n)),
      actions: [
        if (n != null && ns.news.contains(n) && _hasLink(n))
          LButton(
            label: n.buttonLabel,
            icon: Icons.download,
            small: true,
            color: jade,
            onTap: () async {
              final ok = await ns.open(n);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(tr('Không mở được liên kết.'))));
              }
            },
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Đóng'))),
      ],
    );
  }

  bool _hasLink(NewsDef n) => n.link.isNotEmpty || n.linkIos.isNotEmpty;

  Widget _list() {
    final list = ns.news;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(tr('Chưa có thông báo nào.'), style: body, textAlign: TextAlign.center),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [for (final n in list) _card(n)],
    );
  }

  Widget _tag(String t) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: seal, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: bold.copyWith(fontSize: 10.5)),
      );

  Widget _card(NewsDef n) {
    final read = ns.isRead(n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _show(n)),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          border: read ? gold.withValues(alpha: 0.35) : goldLight,
          child: Row(
            children: [
              if (n.image.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _picture(n.image, width: 72, height: 40),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(n.order > 0 ? Icons.push_pin : Icons.campaign,
                      color: read ? creamDim : goldLight, size: 22),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (n.tag.isNotEmpty) _tag(n.tag),
                      Expanded(
                        child: Text(tr(n.title),
                            style: bold.copyWith(color: read ? cream : goldLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    if (n.body.isNotEmpty)
                      Text(n.body.replaceAll('\n', ' '),
                          style: small.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(color: seal, shape: BoxShape.circle),
                ),
              const Icon(Icons.chevron_right, color: creamDim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(NewsDef n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (n.tag.isNotEmpty || n.from.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                if (n.tag.isNotEmpty) _tag(n.tag),
                if (n.from.isNotEmpty) Text(tr('Ngày {p0}', {'p0': _day(n.from)}), style: small.copyWith(fontSize: 11)),
                if (n.until.isNotEmpty) Text(tr(' · đến hết {p0}', {'p0': _day(n.until)}), style: small.copyWith(fontSize: 11)),
              ]),
            ),
          if (n.image.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: GestureDetector(
                    onTap: _hasLink(n) ? () => ns.open(n) : null,
                    child: _picture(n.image),
                  ),
                ),
              ),
            ),
          if (n.body.isNotEmpty) Text(n.body, style: body),
        ],
      ),
    );
  }

  Widget _picture(String url, {double? width, double? height}) => Image.network(
        url,
        width: width,
        height: height,
        fit: width == null ? BoxFit.contain : BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : SizedBox(
                width: width,
                height: height ?? 120,
                child: const Center(child: CircularProgressIndicator(color: goldLight, strokeWidth: 2)),
              ),
        errorBuilder: (_, _, _) => SizedBox(
          width: width,
          height: height ?? 0,
          child: width == null ? null : const Icon(Icons.image_not_supported, color: creamDim),
        ),
      );
}
