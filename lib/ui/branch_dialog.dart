import 'package:flutter/material.dart';

import '../core/branches.dart';
import '../core/hero.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// Lưu phái: the sect's two schools side by side, the one taken, its Tu vi
/// and what the next level costs.
Future<void> showBranchDialog(BuildContext context, HeroData h) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final list = branchesOf(h.hanh);
        final cur = h.branchDef;
        return AlertDialog(
          backgroundColor: lacquer,
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          title: Text(tr('Lưu phái · {sectName}', {'sectName': tr(h.sect.name)}), style: titleStyle(18)),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  h.branchOpen
                      ? tr('Chọn một phái hệ: đổi vài chiêu và thêm nội công riêng. '
                          'Lần đầu miễn phí, đổi sau tốn {p0} lượng; Tu vi giữ nguyên.', {'p0': fmt(branchSwitchCost(h.rebirths))})
                      : tr('Mở sau lần chuyển sinh đầu tiên.'),
                  style: small.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _card(context, h, list[i], i, () => setState(() {}))),
                      ],
                    ],
                  ),
                ),
                if (cur != null) ...[
                  const SizedBox(height: 8),
                  _tuVi(context, h, cur, () => setState(() {})),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng'))),
          ],
        );
      },
    ),
  );
}

Widget _card(BuildContext context, HeroData h, BranchDef b, int i, VoidCallback changed) {
  final taken = h.branch == i && h.branchOpen;
  final skills = {for (final s in h.sect.skills) s.id: s};
  final cost = h.branch < 0 ? 0 : branchSwitchCost(h.rebirths);
  return Panel(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    border: taken ? goldLight : gold.withValues(alpha: 0.35),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(b.name), style: titleStyle(16).copyWith(color: taken ? goldLight : cream))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: hanhColor(h.hanh).withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)),
              child: Text(tr(b.role), style: bold.copyWith(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(tr(b.desc), style: small.copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        for (final m in b.mods)
          Text('• ${skills[m.skill]?.name ?? m.skill}: ${m.note}', style: small.copyWith(fontSize: 11, color: cream)),
        const SizedBox(height: 4),
        Text(
          tr('Nội công: {p0}', {'p0': [for (final e in branchBonus(b, taken ? h.branchLv : 1).entries) branchBonusLabel(e.key, e.value)].join(', ')}),
          style: bold.copyWith(fontSize: 11, color: const Color(0xFF8CE07A)),
        ),
        const Spacer(),
        const SizedBox(height: 6),
        if (taken)
          Center(child: Text(tr('Đang theo phái này'), style: bold.copyWith(color: goldLight)))
        else
          LButton(
            label: cost == 0 ? tr('Chọn phái này') : tr('Đổi sang ({p0} lượng)', {'p0': fmt(cost)}),
            small: true,
            color: jade,
            enabled: h.branchOpen && h.gold >= cost,
            onTap: () async {
              if (cost > 0) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: lacquer,
                    title: Text(tr('Đổi lưu phái?'), style: titleStyle(18)),
                    content: Text(tr('Theo {bName} với {p0} lượng. Tu vi giữ nguyên.', {'bName': tr(b.name), 'p0': fmt(cost)}), style: body),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Thôi'))),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Đổi'))),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              if (h.pickBranch(i)) {
                SoundService.instance.cue('levelup');
                SaveService.instance.save();
              }
              changed();
            },
          ),
      ],
    ),
  );
}

Widget _tuVi(BuildContext context, HeroData h, BranchDef b, VoidCallback changed) {
  final top = h.branchLv >= maxBranchLevel;
  return Panel(
    padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Tu vi {branchLv}/{maxBranchLevel}', {'branchLv': h.branchLv, 'maxBranchLevel': maxBranchLevel}), style: bold.copyWith(color: goldLight)),
              Text(
                top
                    ? tr('Đã viên mãn: nội công ×{p0}', {'p0': branchMul(h.branchLv).toStringAsFixed(2)})
                    : tr('Nội công ×{p0} → ×{p1} · '
                        '{p2} lượng + {p3} Thần Thiết (có {divineIron})', {'p0': branchMul(h.branchLv).toStringAsFixed(2), 'p1': branchMul(h.branchLv + 1).toStringAsFixed(2), 'p2': fmt(branchGoldCost(h.branchLv)), 'p3': branchIronCost(h.branchLv), 'divineIron': h.divineIron}),
                style: small.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        LButton(
          label: tr('Tu luyện'),
          small: true,
          enabled: h.canRaiseBranch,
          onTap: () {
            if (h.raiseBranch()) {
              SoundService.instance.cue('levelup');
              SaveService.instance.save();
            }
            changed();
          },
        ),
      ],
    ),
  );
}

/// Shown on the skills tab: whether a school is still to be chosen.
bool branchWaiting(HeroData h) => h.branchOpen && h.branch < 0;

/// Skill ids the hero's school changes.
Set<String> branchSkills(HeroData h) => {for (final m in h.branchDef?.mods ?? const <BranchMod>[]) m.skill};
