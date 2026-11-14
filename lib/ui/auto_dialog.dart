import 'package:flutter/material.dart';

import '../core/auto_config.dart';
import '../core/hero.dart';
import '../services/save.dart';
import 'theme.dart';

/// Cài đặt tự đánh, from the pause menu or the town's settings.
Future<void> showAutoSettings(BuildContext context, HeroData h) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      final c = h.autoCfg;
      void set(void Function() f) {
        setD(f);
      }

      Widget head(String t) => Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(t, style: bold.copyWith(color: goldLight, fontSize: 13)),
          );

      Widget chip(String label, bool on, VoidCallback tap) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: GestureDetector(
              onTap: tap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? Color.lerp(lacquer, jade, 0.7) : lacquerDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? goldLight : const Color(0xFF5A4A3A)),
                ),
                child: Text(label, style: small.copyWith(fontSize: 12, color: on ? cream : creamDim)),
              ),
            ),
          );

      String pct(double v) => '${(v * 100).round()}%';
      final sk = h.sect.skills;
      return AlertDialog(
        backgroundColor: lacquer,
        title: Text('Cài đặt tự đánh', style: titleStyle(20)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head('Ưu tiên mục tiêu'),
                Wrap(children: [
                  for (final t in AutoTarget.values)
                    chip(autoTargetNames[t]!, c.target == t, () => set(() => c.target = t)),
                ]),
                head('Chiêu được dùng khi tự đánh (chạm để bật/tắt)'),
                Wrap(children: [
                  for (var i = 0; i < sk.length; i++)
                    if (!sk[i].isPassive)
                      chip(sk[i].name, !c.skillsOff.contains(i), () {
                        set(() => c.skillsOff.contains(i) ? c.skillsOff.remove(i) : c.skillsOff.add(i));
                      }),
                ]),
                head('Uống thuốc Sinh lực khi dưới'),
                Wrap(children: [
                  for (final v in autoHpSteps) chip(pct(v), c.hpPot == v, () => set(() => c.hpPot = v)),
                ]),
                head('Uống thuốc Nội lực khi dưới'),
                Wrap(children: [
                  for (final v in autoMpSteps) chip(pct(v), c.mpPot == v, () => set(() => c.mpPot = v)),
                ]),
                head('Khác'),
                Wrap(children: [
                  chip('Đi nhặt đồ rơi, linh thảo', c.loot, () => set(() => c.loot = !c.loot)),
                  chip('Để dành tuyệt kỹ cho đông quái, boss', c.saveUltimate,
                      () => set(() => c.saveUltimate = !c.saveUltimate)),
                  chip('Tự cộng điểm, học chiêu khi lên cấp', c.points, () => set(() => c.points = !c.points)),
                  chip('Tự mặc đồ tốt hơn khi nhặt', c.gear, () => set(() => c.gear = !c.gear)),
                  chip('Tự đi nhiệm vụ (vào ải, đổi bản đồ)', c.questGo, () => set(() => c.questGo = !c.questGo)),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: c.isDefault
                ? null
                : () => set(() => h.autoCfg = AutoConfig()
                  ..points = c.points
                  ..gear = c.gear),
            child: const Text('Mặc định'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
        ],
      );
    }),
  );
  await SaveService.instance.save();
}
