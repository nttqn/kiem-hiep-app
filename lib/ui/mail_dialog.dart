import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/mail.dart';
import '../core/world_boss.dart';
import '../services/analytics.dart';
import '../services/mail.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Hòm thư: the developer's gifts still open, each claimed once per hero.
Future<void> showMailDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _MailDialog());
}

class _MailDialog extends StatefulWidget {
  const _MailDialog();

  @override
  State<_MailDialog> createState() => _MailDialogState();
}

class _MailDialogState extends State<_MailDialog> {
  final _rng = math.Random();
  final _got = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    // Tiên Ngọc from a mail an older app took as read (1.13.2).
    final h = SaveService.instance.hero;
    for (final m in MailService.instance.mails) {
      final lines = h.mailJadeOwed([m]);
      if (lines.isNotEmpty) _got[m.id] = lines;
    }
    if (_got.isNotEmpty) SaveService.instance.save();
  }

  void _claim(MailDef m) {
    final h = SaveService.instance.hero;
    final lines = h.claimMail(m, vnDayKey(), _rng);
    if (lines.isEmpty && !h.mailClaimed.contains(m.id)) return;
    h.recompute();
    Analytics.instance.log('mail_claim', {'id': m.id});
    SaveService.instance.save();
    setState(() => _got[m.id] = lines);
  }

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final day = vnDayKey();
    final mails = MailService.instance.mails;
    final open = [for (final m in mails) if (h.canClaimMail(m, day)) m];
    return AlertDialog(
      backgroundColor: lacquer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      title: Text(tr('Hòm thư'), style: titleStyle(20)),
      content: SizedBox(
        width: 560,
        child: mails.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(tr('Chưa có thư nào. Quà từ nhà phát triển sẽ gửi tới đây.'),
                    style: body, textAlign: TextAlign.center),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in mails) _mail(m, h.canClaimMail(m, day), h.mailClaimed.contains(m.id)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await showDialog<void>(context: context, builder: (_) => const _CodeDialog());
            if (mounted) setState(() {});
          },
          child: Text(tr('Nhập mã quà')),
        ),
        if (open.length > 1)
          TextButton(
            onPressed: () {
              for (final m in open) {
                _claim(m);
              }
            },
            child: Text(tr('Nhận tất cả')),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Đóng'))),
      ],
    );
  }

  String _day(String d) => d.length == 8 ? '${int.parse(d.substring(6))}/${int.parse(d.substring(4, 6))}' : '';

  Widget _mail(MailDef m, bool can, bool taken) {
    final got = _got[m.id];
    final h = SaveService.instance.hero;
    final tooLow = !taken && !can && h.rebirths == 0 && h.level < m.minLevel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        border: can ? goldLight : gold.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(taken ? Icons.drafts : Icons.mail, color: can ? goldLight : creamDim, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(m.title), style: bold.copyWith(color: can ? goldLight : cream)),
                  if (m.body.isNotEmpty) Text(m.body, style: body.copyWith(fontSize: 12.5)),
                  if (m.rewards.isNotEmpty)
                    Text(tr('Quà: {p0}', {'p0': m.rewards.join(' · ')}),
                        style: small.copyWith(fontSize: 11.5, color: const Color(0xFF8CE07A))),
                  if (m.until.isNotEmpty)
                    Text(tr('Hạn nhận đến hết ngày {p0}', {'p0': _day(m.until)}), style: small.copyWith(fontSize: 10.5)),
                  if (got != null && got.isNotEmpty)
                    Text(tr('Đã nhận: {p0}', {'p0': got.join(', ')}), style: small.copyWith(fontSize: 11, color: cream)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (taken)
              Text(tr('Đã nhận'), style: small)
            else if (tooLow)
              Text(tr('Cần cấp {minLevel}', {'minLevel': m.minLevel}), style: small)
            else if (m.rewards.isNotEmpty)
              LButton(label: tr('Nhận'), small: true, color: jade, enabled: can, onTap: () => _claim(m))
            else
              LButton(label: tr('Đã đọc'), small: true, color: lacquerLight, enabled: can, onTap: () => _claim(m)),
          ],
        ),
      ),
    );
  }
}

/// Mã quà tặng (1.24.2): type a code, take its gift once per hero.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _field = TextEditingController();
  final _rng = math.Random();
  bool _busy = false;
  String? _say;
  List<String>? _got;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _say = null;
    });
    final (gift, why) = await MailService.instance.lookupCode(_field.text);
    if (!mounted) return;
    final h = SaveService.instance.hero;
    String? say = why;
    List<String>? got;
    if (gift != null) {
      final key = gift.id.substring(5);
      if (h.mailClaimed.contains(gift.id)) {
        say = tr('{hName} đã nhận mã này rồi.', {'hName': h.name});
      } else if (h.rebirths == 0 && h.level < gift.minLevel) {
        say = tr('Mã này cần cấp {minLevel}.', {'minLevel': gift.minLevel});
      } else {
        got = h.claimMail(gift, vnDayKey(), _rng);
        h.recompute();
        SaveService.instance.save();
        Analytics.instance.log('code_claim', {'code': key});
        say = tr(gift.title);
      }
    } else {
      Analytics.instance.log('code_fail', {'why': why ?? ''});
    }
    setState(() {
      _busy = false;
      _say = say;
      _got = got;
    });
  }

  @override
  Widget build(BuildContext context) {
    final got = _got;
    return AlertDialog(
      backgroundColor: lacquer,
      title: Text(tr('Nhập mã quà'), style: titleStyle(20)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Mã quà được phát trên kênh và trang của game. Mỗi nhân vật nhận mỗi mã một lần.'),
                  style: small.copyWith(fontSize: 11.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _field,
                enabled: !_busy,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                style: bold.copyWith(letterSpacing: 2),
                decoration: InputDecoration(hintText: tr('Mã quà'), counterText: ''),
                onSubmitted: (_) => _submit(),
              ),
              if (_say != null) ...[
                const SizedBox(height: 8),
                Text(_say!, style: bold.copyWith(color: got != null ? goldLight : cream)),
              ],
              if (got != null && got.isNotEmpty)
                Text(tr('Đã nhận: {p0}', {'p0': got.join(', ')}),
                    style: small.copyWith(fontSize: 11.5, color: const Color(0xFF8CE07A))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Đóng'))),
        LButton(label: tr('Nhận'), small: true, color: jade, enabled: !_busy, onTap: _submit),
      ],
    );
  }
}
