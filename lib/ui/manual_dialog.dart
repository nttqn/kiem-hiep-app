import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/manuals.dart';
import '../core/sects.dart';
import 'theme.dart';

/// A skill's bí kíp: each school with its pages, level and effect, and
/// which one the skill wears.
Future<void> showManualDialog(BuildContext context, HeroData h, SkillDef sk) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final on = h.manualOf(sk.id);
        return AlertDialog(
          backgroundColor: lacquer,
          title: Text('Bí kíp · ${sk.name}', style: titleStyle(18)),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Trang bí kíp rơi từ boss, tinh anh, Ải Ác Mộng, cá huyền thoại, hoặc đổi ở Tàng Kinh Các (Sư môn). '
                  'Mỗi chiêu dùng một thiên; đổi thiên miễn phí.',
                  style: small.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                for (final k in manualKindsFor(sk)) _row(h, sk, k, on == k, () => setState(() {})),
              ],
            ),
          ),
          actions: [
            if (on != null)
              TextButton(
                onPressed: () {
                  h.setManual(sk.id, null);
                  setState(() {});
                },
                child: const Text('Tháo bí kíp'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        );
      },
    ),
  );
}

Widget _row(HeroData h, SkillDef sk, ManualKind k, bool worn, VoidCallback changed) {
  final key = manualKey(sk.id, k);
  final pages = h.manualPagesOf(key);
  final lv = manualLevelOf(pages);
  final toNext = manualPagesToNext(pages);
  final def = manualKinds[k]!;
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      border: worn ? const Color(0xFFC88CFF) : gold.withValues(alpha: 0.4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${def.name} thiên', style: bold.copyWith(color: lv > 0 ? const Color(0xFFE0C8FF) : creamDim)),
                    const SizedBox(width: 8),
                    Text(lv > 0 ? 'Tầng $lv/$maxManualLevel' : 'Chưa lĩnh ngộ',
                        style: small.copyWith(color: lv > 0 ? cream : creamDim)),
                  ],
                ),
                Text(
                  '${manualEffect(sk, k, lv, h.hanh)}${lv == 0 ? ' (tầng 1)' : ''}',
                  style: small.copyWith(fontSize: 11, color: lv > 0 ? const Color(0xFF8CE07A) : creamDim),
                ),
                Text(
                  toNext > 0 ? '$pages trang · thêm $toNext trang lên tầng ${lv + 1}' : '$pages trang · đã đại thành',
                  style: small.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          LButton(
            label: worn ? 'Đang dùng' : 'Dùng',
            small: true,
            color: worn ? jade : const Color(0xFF5A3A7A),
            enabled: lv > 0 && !worn,
            onTap: () {
              h.setManual(sk.id, k);
              changed();
            },
          ),
        ],
      ),
    ),
  );
}
