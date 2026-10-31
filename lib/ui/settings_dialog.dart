import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/notify.dart';
import '../services/perf.dart';
import '../services/sound.dart';
import 'cloud_panel.dart';
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
          isLabelVisible: cloud.conflicts.isNotEmpty,
          smallSize: 9,
          backgroundColor: seal,
          child: const Icon(Icons.settings, color: goldLight),
        ),
      ),
    );
  }
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
              ListenableBuilder(
                listenable: CloudSave.instance,
                builder: (_, _) {
                  final cloud = CloudSave.instance;
                  if (!cloud.available) return const SizedBox.shrink();
                  final on = cloud.user != null;
                  return _Link(
                    icon: on ? Icons.cloud_done : Icons.cloud_off,
                    label: 'Lưu trữ đám mây',
                    value: cloud.conflicts.isNotEmpty ? 'Cần chọn bản lưu' : (on ? 'Đã đăng nhập' : 'Chưa đăng nhập'),
                    onTap: () {
                      Navigator.pop(ctx);
                      showCloudPanel(context);
                    },
                  );
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
