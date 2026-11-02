import 'package:flutter/material.dart';

import '../core/clock.dart';
import '../core/rename.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'theme.dart';

/// Đổi tên: type a new name, watch a rewarded ad, once a week. True when
/// the hero was renamed.
Future<bool> showRenameDialog(BuildContext context) async {
  return await showDialog<bool>(context: context, builder: (_) => const _RenameDialog()) ?? false;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog();

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _ctl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _wait(int ms) {
    final d = Duration(milliseconds: ms);
    if (d.inDays > 0) return '${d.inDays} ngày ${d.inHours % 24} giờ';
    if (d.inHours > 0) return '${d.inHours} giờ ${d.inMinutes % 60} phút';
    return '${d.inMinutes + 1} phút';
  }

  Future<void> _go() async {
    final h = SaveService.instance.hero;
    final problem = h.renameProblem(_ctl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _busy = true);
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    if (!earned) {
      setState(() {
        _busy = false;
        _error = 'Cần xem hết quảng cáo để đổi tên.';
      });
      return;
    }
    final old = h.name;
    if (!h.rename(_ctl.text, GameClock.nowMs())) {
      setState(() {
        _busy = false;
        _error = 'Chưa thể đổi tên lúc này.';
      });
      return;
    }
    Analytics.instance.log('hero_rename', {'level': h.level});
    await SaveService.instance.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã đổi tên: $old → ${h.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    final now = GameClock.nowMs();
    final ready = h.canRename(now);
    return AlertDialog(
      backgroundColor: lacquer,
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      title: Text('Đổi tên', style: titleStyle(20)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tên hiện tại: ${h.name}', style: bold.copyWith(color: goldLight)),
            const SizedBox(height: 4),
            Text('Xem một quảng cáo để đổi tên. Mỗi tuần được đổi 1 lần.', style: small),
            const SizedBox(height: 10),
            if (!ready)
              Text('Lần đổi tiếp theo sau ${_wait(h.renameReadyAt - now)}.',
                  style: bold.copyWith(color: const Color(0xFFFF8A6A)))
            else
              TextField(
                controller: _ctl,
                maxLength: nameMaxLength,
                autofocus: true,
                style: body,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tên mới',
                  hintStyle: small,
                  filled: true,
                  fillColor: lacquerDeep,
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: gold),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        LButton(label: 'Đóng', small: true, color: lacquerDeep, onTap: () => Navigator.of(context).pop(false)),
        if (ready)
          ValueListenableBuilder<bool>(
            valueListenable: AdsService.instance.rewardedReady,
            builder: (_, adReady, _) => LButton(
              label: adReady ? 'Đổi tên (quảng cáo)' : 'Đang tải quảng cáo…',
              icon: Icons.ondemand_video,
              small: true,
              color: const Color(0xFF8A5A10),
              enabled: adReady && !_busy,
              onTap: _go,
            ),
          ),
      ],
    );
  }
}
