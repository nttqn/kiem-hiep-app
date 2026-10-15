import 'package:flutter/material.dart';

import '../services/cloud.dart';
import '../services/save.dart';
import '../services/sync_plan.dart';
import 'theme.dart';

/// Cloud icon showing sync state; opens the cloud panel. Hidden when the
/// build has no Firebase config (web, or before setup).
class CloudButton extends StatelessWidget {
  const CloudButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSave.instance;
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        if (!cloud.available) return const SizedBox.shrink();
        final on = cloud.user != null;
        return IconButton(
          tooltip: 'Lưu trữ đám mây',
          onPressed: () => showCloudPanel(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(on ? Icons.cloud_done : Icons.cloud_off, color: on ? goldLight : creamDim),
              if (cloud.busy)
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (cloud.conflicts.isNotEmpty)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: seal, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showCloudPanel(BuildContext context) async {
  await showDialog<void>(context: context, builder: (_) => const _CloudPanel());
  if (context.mounted) await resolveConflicts(context);
}

class _CloudPanel extends StatelessWidget {
  const _CloudPanel();

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSave.instance;
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        final signedIn = cloud.user != null;
        return AlertDialog(
          backgroundColor: lacquer,
          title: Row(
            children: [
              const Icon(Icons.cloud, color: goldLight),
              const SizedBox(width: 8),
              Text('Lưu trữ đám mây', style: titleStyle(20)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!signedIn) ...[
                  Text(
                    'Đăng nhập để cất nhân vật lên mây. Cài lại game hay đổi điện thoại '
                    '(kể cả giữa Android và iPhone) vẫn giữ nguyên tiến độ.',
                    style: body.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  LButton(
                    label: 'Đăng nhập Google',
                    icon: Icons.login,
                    color: const Color(0xFF3A6AD8),
                    width: 260,
                    enabled: !cloud.busy,
                    onTap: () => cloud.signInGoogle(),
                  ),
                  if (cloud.isApplePlatform) ...[
                    const SizedBox(height: 8),
                    LButton(
                      label: 'Đăng nhập Apple',
                      icon: Icons.apple,
                      color: const Color(0xFF222222),
                      width: 260,
                      enabled: !cloud.busy,
                      onTap: () => cloud.signInApple(),
                    ),
                  ],
                ] else ...[
                  Text('Tài khoản: ${cloud.who}', style: bold),
                  const SizedBox(height: 4),
                  Text(
                    cloud.lastSync == null
                        ? 'Chưa đồng bộ'
                        : 'Đồng bộ lần cuối: ${_clock(cloud.lastSync!)}',
                    style: small,
                  ),
                  Text('Tự động lưu lên mây sau mỗi trận và khi thoát game.', style: small),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      LButton(
                        label: 'Đồng bộ ngay',
                        small: true,
                        color: jade,
                        enabled: !cloud.busy,
                        onTap: () async {
                          await cloud.flush();
                          await cloud.sync();
                        },
                      ),
                      const SizedBox(width: 8),
                      LButton(
                        label: 'Đăng xuất',
                        small: true,
                        color: const Color(0xFF5A4A3A),
                        enabled: !cloud.busy,
                        onTap: cloud.signOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: cloud.busy ? null : () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_forever, color: Color(0xFFFF7A6A), size: 18),
                    label: const Text('Xóa tài khoản và dữ liệu trên mây',
                        style: TextStyle(color: Color(0xFFFF7A6A), fontSize: 13)),
                  ),
                ],
                if (cloud.busy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (cloud.message != null) ...[
                  const SizedBox(height: 8),
                  Text(cloud.message!, style: small.copyWith(color: const Color(0xFFFF8A7A))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Xóa tài khoản?', style: titleStyle(20)),
        content: Text(
          'Mọi bản lưu trên mây và tài khoản đăng nhập của game sẽ bị xóa vĩnh viễn. '
          'Nhân vật đang có trong máy này vẫn còn, nhưng nếu gỡ game sẽ mất hẳn.',
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Color(0xFFFF7A6A))),
          ),
        ],
      ),
    );
    if (ok == true) await CloudSave.instance.deleteAccount();
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} '
      '${t.day}/${t.month}';
}

bool _resolving = false;

/// Asks, slot by slot, which copy to keep when the cloud one is newer.
Future<void> resolveConflicts(BuildContext context) async {
  final cloud = CloudSave.instance;
  if (_resolving || cloud.conflicts.isEmpty) return;
  _resolving = true;
  try {
    for (final slot in List<int>.of(cloud.conflicts)) {
      if (!context.mounted) return;
      final local = SaveService.instance.slots[slot];
      final remote = cloud.cloudSlots[slot];
      if (local == null || remote == null) continue;
      final takeCloud = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: lacquer,
          title: Text('Ô ${slot + 1}: chọn bản lưu', style: titleStyle(20)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trên mây có bản mới hơn bản trong máy này (có thể bạn đã chơi trên máy khác).',
                    style: body),
                const SizedBox(height: 10),
                _copy('Trên mây (mới hơn)', SlotInfo(
                  savedAt: remote.savedAt,
                  data: '',
                  name: remote.name,
                  level: remote.level,
                  sect: remote.sect,
                  playSeconds: remote.playSeconds,
                )),
                const SizedBox(height: 6),
                _copy('Trong máy', SlotInfo(
                  savedAt: local.savedAt,
                  data: '',
                  name: local.name,
                  level: local.level,
                  sect: local.sect.name,
                  playSeconds: local.playSeconds,
                )),
                const SizedBox(height: 8),
                Text('Bản không chọn sẽ bị ghi đè.', style: small.copyWith(color: const Color(0xFFFF8A7A))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ bản trong máy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dùng bản trên mây')),
          ],
        ),
      );
      if (takeCloud == true) {
        await cloud.takeCloud(slot);
      } else {
        await cloud.keepLocal(slot);
      }
    }
  } finally {
    _resolving = false;
  }
}

Widget _copy(String title, SlotInfo s) {
  final hours = s.playSeconds / 3600;
  final when = DateTime.fromMillisecondsSinceEpoch(s.savedAt);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: lacquerDeep,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: gold.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: small.copyWith(color: goldLight)),
        Text('${s.name} · ${s.sect} · Cấp ${s.level}', style: bold),
        Text(
          'Đã chơi ${hours.toStringAsFixed(1)} giờ · lưu lúc '
          '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')} '
          '${when.day}/${when.month}',
          style: small,
        ),
      ],
    ),
  );
}
