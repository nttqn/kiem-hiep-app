import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/notify.dart';
import '../services/perf.dart';
import '../services/purchase.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'auto_dialog.dart';
import 'cloud_panel.dart';
import 'language_picker.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'town_screen.dart' show showGuide;
import '../core/i18n.dart';

/// The town's gear button: the guide, cloud sign-in and the switches that
/// used to crowd the top bar.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSave.instance;
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) => IconButton(
        tooltip: tr('Cài đặt'),
        onPressed: () => showSettings(context),
        icon: Badge(
          // A cloud copy waiting for a choice.
          isLabelVisible: cloud.needsChoice,
          smallSize: 9,
          backgroundColor: seal,
          child: const Icon(Icons.settings, color: goldLight),
        ),
      ),
    );
  }
}

/// Lịch sử nạp (1.8.1): purchases made on this phone, with the store's
/// order ids to match against Play Console when a player writes in.
Future<void> showPurchaseHistory(BuildContext context) async {
  final list = await PurchaseService.instance.history();
  if (!context.mounted) return;
  String two(int v) => v.toString().padLeft(2, '0');
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text(tr('Lịch sử nạp'), style: titleStyle(20)),
      content: SizedBox(
        width: 460,
        child: list.isEmpty
            ? Text(tr('Chưa có giao dịch nào trên máy này.'), style: body)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.product} · ${two(e.at.day)}/${two(e.at.month)}/${e.at.year} ${two(e.at.hour)}:${two(e.at.minute)}',
                                style: bold.copyWith(color: goldLight)),
                            Text(tr('Nhận bởi: {hero}', {'hero': e.hero}), style: small.copyWith(color: cream)),
                            if (e.order.isNotEmpty) SelectableText(tr('Mã đơn: {order}', {'order': e.order}), style: small.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
    ),
  );
}

/// Khôi phục giao dịch (1.16.2): asks the store again; a small wait
/// dialog, then the answer.
Future<void> showRestorePurchases(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: gold)),
  );
  final text = await PurchaseService.instance.restoreNow();
  if (!context.mounted) return;
  Navigator.of(context).pop();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text(tr('Khôi phục giao dịch'), style: titleStyle(20)),
      content: SizedBox(width: 420, child: Text(text, style: body)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
    ),
  );
}

Future<void> showSettings(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text(tr('Cài đặt'), style: titleStyle(20)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Link(
                icon: Icons.translate,
                label: tr('Ngôn ngữ · 語言'),
                value: currentLang.label,
                onTap: () {
                  Navigator.pop(ctx);
                  pickLanguage(context, inTown: true);
                },
              ),
              _Link(
                icon: Icons.help_outline,
                label: tr('Bí kíp nhập môn'),
                onTap: () {
                  Navigator.pop(ctx);
                  showGuide(context);
                },
              ),
              if (SaveService.instance.active >= 0) ...[
                _Link(
                  icon: Icons.tune,
                  label: tr('Cài đặt tự đánh'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAutoSettings(context, SaveService.instance.hero);
                  },
                ),
                _Link(
                  icon: Icons.query_stats,
                  label: tr('Thống kê và kỷ lục'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(fadeRoute(const StatsScreen()));
                  },
                ),
              ],
              ListenableBuilder(
                listenable: CloudSave.instance,
                builder: (_, _) {
                  final cloud = CloudSave.instance;
                  if (!cloud.available) return const SizedBox.shrink();
                  final on = cloud.user != null;
                  return _Link(
                    icon: on ? Icons.cloud_done : Icons.cloud_off,
                    label: tr('Lưu trữ đám mây'),
                    value: cloud.switchPending ? tr('Cần chọn tài khoản') : cloud.conflicts.isNotEmpty ? tr('Cần chọn bản lưu') : (on ? tr('Đã đăng nhập') : tr('Chưa đăng nhập')),
                    onTap: () {
                      Navigator.pop(ctx);
                      showCloudPanel(context);
                    },
                  );
                },
              ),
              // Account deletion in plain sight (App Store 5.1.1(v)).
              ListenableBuilder(
                listenable: CloudSave.instance,
                builder: (_, _) => CloudSave.instance.user == null
                    ? const SizedBox.shrink()
                    : _Link(
                        icon: Icons.person_remove,
                        label: tr('Xóa tài khoản'),
                        value: tr('Xóa vĩnh viễn'),
                        onTap: () {
                          Navigator.pop(ctx);
                          confirmDeleteAccount(context);
                        },
                      ),
              ),
              _Link(
                icon: Icons.receipt_long,
                label: tr('Lịch sử nạp'),
                onTap: () {
                  Navigator.pop(ctx);
                  showPurchaseHistory(context);
                },
              ),
              _Link(
                icon: Icons.restore,
                label: tr('Khôi phục giao dịch'),
                value: tr('Bỏ quảng cáo'),
                onTap: () {
                  Navigator.pop(ctx);
                  showRestorePurchases(context);
                },
              ),
              const Divider(color: gold, height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.musicOn,
                builder: (_, on, _) => _Toggle(
                  icon: on ? Icons.music_note : Icons.music_off,
                  label: tr('Nhạc nền'),
                  on: on,
                  onChanged: (_) => SoundService.instance.toggleMusic(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.sfxOn,
                builder: (_, on, _) => _Toggle(
                  icon: on ? Icons.volume_up : Icons.volume_off,
                  label: tr('Tiếng hiệu ứng'),
                  on: on,
                  onChanged: (_) => SoundService.instance.toggleSfx(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: LiteMode.instance.on,
                builder: (_, on, _) => _Toggle(
                  icon: Icons.speed,
                  label: tr('Chế độ máy yếu'),
                  hint: tr('Bỏ rung màn hình, hiệu ứng mờ và trang trí'),
                  on: on,
                  onChanged: (_) => LiteMode.instance.toggle(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShakeSetting.instance.on,
                builder: (_, on, _) => _Toggle(
                  icon: Icons.vibration,
                  label: tr('Rung màn hình'),
                  hint: tr('Khi tung tuyệt kỹ và hạ quái lớn'),
                  on: on,
                  onChanged: (_) => ShakeSetting.instance.toggle(),
                ),
              ),
              ListenableBuilder(
                listenable: NotifyService.instance,
                builder: (_, _) {
                  final on = NotifyService.instance.enabled;
                  return _Toggle(
                    icon: on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    label: tr('Thông báo nhắc'),
                    hint: tr('Bế quan đầy, quà mới mỗi tối'),
                    on: on,
                    onChanged: (v) => NotifyService.instance.setEnabled(v),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap, this.value});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: goldLight, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: bold.copyWith(fontSize: 14))),
              if (value != null) Text(value!, style: small.copyWith(color: cream)),
              const Icon(Icons.chevron_right, color: creamDim),
            ],
          ),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onChanged, this.hint});
  final IconData icon;
  final String label;
  final String? hint;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: on ? goldLight : creamDim, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: bold.copyWith(fontSize: 14)),
                if (hint != null) Text(hint!, style: small.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(value: on, onChanged: onChanged, activeThumbColor: goldLight),
        ],
      );
}
