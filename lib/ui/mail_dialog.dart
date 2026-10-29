import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/mail.dart';
import '../core/world_boss.dart';
import '../services/analytics.dart';
import '../services/mail.dart';
import '../services/save.dart';
import 'theme.dart';

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
      title: Text('Hòm thư', style: titleStyle(20)),
      content: SizedBox(
        width: 560,
        child: mails.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Chưa có thư nào. Quà từ nhà phát triển sẽ gửi tới đây.',
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
        if (open.length > 1)
          TextButton(
            onPressed: () {
              for (final m in open) {
                _claim(m);
              }
            },
            child: const Text('Nhận tất cả'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
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
                  Text(m.title, style: bold.copyWith(color: can ? goldLight : cream)),
                  if (m.body.isNotEmpty) Text(m.body, style: body.copyWith(fontSize: 12.5)),
                  if (m.rewards.isNotEmpty)
                    Text('Quà: ${m.rewards.join(' · ')}',
                        style: small.copyWith(fontSize: 11.5, color: const Color(0xFF8CE07A))),
                  if (m.until.isNotEmpty)
                    Text('Hạn nhận đến hết ngày ${_day(m.until)}', style: small.copyWith(fontSize: 10.5)),
                  if (got != null && got.isNotEmpty)
                    Text('Đã nhận: ${got.join(', ')}', style: small.copyWith(fontSize: 11, color: cream)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (taken)
              Text('Đã nhận', style: small)
            else if (tooLow)
              Text('Cần cấp ${m.minLevel}', style: small)
            else if (m.rewards.isNotEmpty)
              LButton(label: 'Nhận', small: true, color: jade, enabled: can, onTap: () => _claim(m))
            else
              LButton(label: 'Đã đọc', small: true, color: lacquerLight, enabled: can, onTap: () => _claim(m)),
          ],
        ),
      ),
    );
  }
}
