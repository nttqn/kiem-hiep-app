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

/// Asks, slot by slot, which copy to keep when sync cannot decide alone:
/// the cloud copy is newer, or the device copy is behind it or another
/// character. The copy not chosen is kept as that slot's backup, and
/// choosing the one that is further behind needs a second confirmation.
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
      final here = SlotInfo.ofHero(local);
      final other = !sameHero(here, remote);
      final cloudNewer = remote.savedAt > here.savedAt;
      final empty = SaveService.instance.slots.indexWhere((s) => s == null);
      String? choice;
      while (choice == null) {
        if (!context.mounted) return;
        final pick = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: lacquer,
            title: Text('Ô ${slot + 1}: chọn bản lưu', style: titleStyle(20)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other
                          ? 'Ô này trên mây là một nhân vật khác với nhân vật trong máy.'
                          : cloudNewer
                              ? 'Trên mây có bản mới hơn bản trong máy này (có thể bạn đã chơi trên máy khác).'
                              : 'Bản trong máy này đang kém hơn bản trên mây (có thể máy vừa khôi phục một bản sao lưu cũ).',
                      style: body,
                    ),
                    const SizedBox(height: 10),
                    _copy('Trên mây', remote, best: compareProgress(remote, here) > 0),
                    const SizedBox(height: 6),
                    _copy('Trong máy', here, best: compareProgress(here, remote) > 0),
                    const SizedBox(height: 8),
                    Text(
                      other && empty >= 0
                          ? 'Có thể giữ cả hai: nhân vật trên mây sẽ được đưa vào ô trống ${empty + 1}.'
                          : 'Bản không chọn được cất vào bản dự phòng, khôi phục được ở màn chọn nhân vật.',
                      style: small.copyWith(color: goldLight),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, 'local'), child: const Text('Giữ bản trong máy')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'cloud'), child: const Text('Dùng bản trên mây')),
              if (other && empty >= 0)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'both'),
                  child: const Text('Giữ cả hai', style: TextStyle(color: Color(0xFF8CE07A), fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        );
        if (pick == null) return;
        // Taking the copy that is further behind loses progress: ask again.
        final (kept, dropped) = pick == 'cloud' ? (remote, here) : (here, remote);
        if (pick != 'both' && sameHero(kept, dropped) && compareProgress(kept, dropped) < 0) {
          if (!context.mounted) return;
          final sure = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: lacquer,
              title: Text('Chọn bản kém hơn?', style: titleStyle(20, color: const Color(0xFFFF8A7A))),
              content: Text(
                'Bản bạn chọn (${kept.levelText}) kém hơn bản kia (${dropped.levelText}). '
                'Bản ${dropped.levelText} sẽ được cất vào bản dự phòng của ô ${slot + 1}.',
                style: body,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Chọn lại')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Vẫn chọn', style: TextStyle(color: Color(0xFFFF8A7A))),
                ),
              ],
            ),
          );
          if (sure != true) continue;
        }
        choice = pick;
      }
      switch (choice) {
        case 'cloud':
          await cloud.takeCloud(slot);
        case 'both':
          await cloud.takeCloudInto(slot, empty);
          await cloud.keepLocal(slot);
        default:
          await cloud.keepLocal(slot);
      }
    }
  } finally {
    _resolving = false;
  }
}

Widget _copy(String title, SlotInfo s, {bool best = false}) {
  final hours = s.playSeconds / 3600;
  final when = DateTime.fromMillisecondsSinceEpoch(s.savedAt);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: lacquerDeep,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: best ? const Color(0xFF8CE07A) : gold.withValues(alpha: 0.5), width: best ? 2 : 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(best ? '$title · tiến độ cao hơn' : title,
            style: small.copyWith(color: best ? const Color(0xFF8CE07A) : goldLight)),
        Text('${s.name} · ${s.sect} · ${s.levelText}', style: bold),
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
