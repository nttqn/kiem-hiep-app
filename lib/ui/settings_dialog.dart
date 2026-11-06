import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/notify.dart';
import '../services/perf.dart';
import '../services/purchase.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'auto_dialog.dart';
import 'cloud_panel.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'town_screen.dart' show showGuide;

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
        tooltip: 'Cài đặt',
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
      title: Text('Lịch sử nạp', style: titleStyle(20)),
      content: SizedBox(
        width: 460,
        child: list.isEmpty
            ? Text('Chưa có giao dịch nào trên máy này.', style: body)
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
                            Text('Nhận bởi: ${e.hero}', style: small.copyWith(color: cream)),
                            if (e.order.isNotEmpty) SelectableText('Mã đơn: ${e.order}', style: small.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
    ),
  );
}

Future<void> showSettings(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: lacquer,
      title: Text('Cài đặt', style: titleStyle(20)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Link(
                icon: Icons.help_outline,
                label: 'Bí kíp nhập môn',
                onTap: () {
                  Navigator.pop(ctx);
                  showGuide(context);
                },
              ),
              if (SaveService.instance.active >= 0) ...[
                _Link(
                  icon: Icons.tune,
                  label: 'Cài đặt tự đánh',
                  onTap: () {
                    Navigator.pop(ctx);
                    showAutoSettings(context, SaveService.instance.hero);
                  },
                ),
                _Link(
                  icon: Icons.query_stats,
                  label: 'Thống kê và kỷ lục',
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
                    label: 'Lưu trữ đám mây',
                    value: cloud.switchPending ? 'Cần chọn tài khoản' : cloud.conflicts.isNotEmpty ? 'Cần chọn bản lưu' : (on ? 'Đã đăng nhập' : 'Chưa đăng nhập'),
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
                        label: 'Xóa tài khoản',
                        value: 'Xóa vĩnh viễn',
                        onTap: () {
                          Navigator.pop(ctx);
                          confirmDeleteAccount(context);
                        },
                      ),
              ),
              _Link(
                icon: Icons.receipt_long,
                label: 'Lịch sử nạp',
                onTap: () {
                  Navigator.pop(ctx);
                  showPurchaseHistory(context);
                },
              ),
              const Divider(color: gold, height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.musicOn,
                builder: (_, on, _) => _Toggle(
                  icon: on ? Icons.music_note : Icons.music_off,
                  label: 'Nhạc nền',
                  on: on,
                  onChanged: (_) => SoundService.instance.toggleMusic(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: SoundService.instance.sfxOn,
                builder: (_, on, _) => _Toggle(
                  icon: on ? Icons.volume_up : Icons.volume_off,
                  label: 'Tiếng hiệu ứng',
                  on: on,
                  onChanged: (_) => SoundService.instance.toggleSfx(),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: LiteMode.instance.on,
                builder: (_, on, _) => _Toggle(
                  icon: Icons.speed,
                  label: 'Chế độ máy yếu',
                  hint: 'Bỏ rung màn hình, hiệu ứng mờ và trang trí',
                  on: on,
                  onChanged: (_) => LiteMode.instance.toggle(),
                ),
              ),
              ListenableBuilder(
                listenable: NotifyService.instance,
                builder: (_, _) {
                  final on = NotifyService.instance.enabled;
                  return _Toggle(
                    icon: on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    label: 'Thông báo nhắc',
                    hint: 'Bế quan đầy, quà mới mỗi tối',
                    on: on,
                    onChanged: (v) => NotifyService.instance.setEnabled(v),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
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
