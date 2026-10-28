import 'dart:math' as math;

import 'hanh.dart';
import 'sects.dart';

/// Bí kíp võ công: pages found on bosses, in Ải Ác Mộng, in the sky of a
/// lucky catch, or traded for cống hiến at the sect. Pages of one skill's
/// one school (thiên) add up to its level; each active skill wears one
/// school at a time, which reshapes how it fights.
const int manualOpenLevel = 30;

enum ManualKind { power, swift, wide, phase, endure }

class ManualKindDef {
  const ManualKindDef(this.name, this.desc);
  final String name, desc;
}

const manualKinds = {
  ManualKind.power: ManualKindDef('Cuồng Bạo', 'Tăng uy lực chiêu'),
  ManualKind.swift: ManualKindDef('Tật Phong', 'Giảm hồi chiêu và nội lực'),
  ManualKind.wide: ManualKindDef('Bao La', 'Mở rộng tầm và vùng đánh, thêm đạn'),
  ManualKind.phase: ManualKindDef('Ngũ Hành', 'Thêm hiệu ứng theo hành của môn phái'),
  ManualKind.endure: ManualKindDef('Trường Tồn', 'Kéo dài thời gian hiệu lực'),
};

/// Pages needed for levels 1..5 of a school.
const manualPagesFor = [1, 3, 6, 10, 15];
const int maxManualLevel = 5;

int manualLevelOf(int pages) => manualPagesFor.where((n) => pages >= n).length;

/// Pages still missing for the next level, or 0 at the top.
int manualPagesToNext(int pages) {
  final lv = manualLevelOf(pages);
  return lv >= maxManualLevel ? 0 : manualPagesFor[lv] - pages;
}

bool _support(SkillDef s) => s.kind == SkillKind.guard || s.kind == SkillKind.heal || s.kind == SkillKind.shield;

/// Schools a skill can learn: guards, heals and shields grow stronger,
/// quicker or longer; attacks stronger, quicker, wider or with a phase effect.
List<ManualKind> manualKindsFor(SkillDef s) {
  if (s.isPassive) return const [];
  return _support(s)
      ? const [ManualKind.power, ManualKind.swift, ManualKind.endure]
      : const [ManualKind.power, ManualKind.swift, ManualKind.wide, ManualKind.phase];
}

/// Skill indices (of the sect's list) that take a bí kíp.
List<int> manualSkills(SectDef sect) => [
      for (var i = 0; i < sect.skills.length; i++)
        if (!sect.skills[i].isPassive) i,
    ];

/// `kim1:0` style key of a skill's school.
String manualKey(String skillId, ManualKind k) => '$skillId:${k.index}';

/// The status a Ngũ Hành page adds, by the sect's phase.
(Status, double, double) _phaseStatus(Hanh h, int lv) => switch (h) {
      Hanh.kim => (Status.stun, 0, 0.4 + 0.1 * lv),
      Hanh.moc => (Status.poison, 0.25 + 0.08 * lv, 4),
      Hanh.thuy => (Status.slow, 0.25 + 0.05 * lv, 2.5),
      Hanh.hoa => (Status.burn, 0.3 + 0.1 * lv, 3),
      Hanh.tho => (Status.stun, 0, 0.5 + 0.1 * lv),
    };

/// [s] as it fights with school [k] at level [lv] (1..5).
SkillDef applyManual(SkillDef s, ManualKind k, int lv, Hanh hanh) {
  if (lv <= 0) return s;
  switch (k) {
    case ManualKind.power:
      final m = 1 + (_support(s) ? 0.08 : 0.06) * lv;
      return s.copyWith(power: s.power * m, powerPerLv: s.powerPerLv * m);
    case ManualKind.swift:
      final m = 1 - 0.05 * lv;
      return s.copyWith(cooldown: s.cooldown * m, mp: s.mp * m);
    case ManualKind.endure:
      return s.copyWith(duration: s.duration * (1 + 0.12 * lv));
    case ManualKind.wide:
      final m = 1 + 0.07 * lv;
      final more = (lv >= 3 ? 1 : 0) + (lv >= 5 ? 1 : 0);
      final count = switch (s.kind) {
        SkillKind.projectile || SkillKind.line => s.count + more,
        SkillKind.radial => s.count + 2 * more,
        _ => s.count,
      };
      return s.copyWith(
        range: s.range * m,
        radius: s.radius * m,
        spread: s.kind == SkillKind.projectile && s.count == 1 && count > 1 ? 0.35 : s.spread * m,
        count: count,
      );
    case ManualKind.phase:
      if (s.status != Status.none) {
        return s.copyWith(
          statusPower: s.statusPower * (1 + 0.12 * lv),
          statusTime: s.statusTime * (1 + 0.1 * lv),
        );
      }
      final (st, pw, t) = _phaseStatus(hanh, lv);
      return s.copyWith(
        status: st,
        statusPower: pw,
        statusTime: t,
        knock: hanh == Hanh.tho ? s.knock + 40 : s.knock,
      );
  }
}

/// One line for the school's effect at [lv].
String manualEffect(SkillDef s, ManualKind k, int lv, Hanh hanh) {
  final n = math.max(1, lv);
  String pc(double v) => '${(v * 100).round()}%';
  return switch (k) {
    ManualKind.power => '+${pc((_support(s) ? 0.08 : 0.06) * n)} uy lực',
    ManualKind.swift => '−${pc(0.05 * n)} hồi chiêu và nội lực',
    ManualKind.endure => '+${pc(0.12 * n)} thời gian hiệu lực',
    ManualKind.wide => () {
        final more = (n >= 3 ? 1 : 0) + (n >= 5 ? 1 : 0);
        final extra = switch (s.kind) {
          SkillKind.projectile || SkillKind.line => more,
          SkillKind.radial => 2 * more,
          _ => 0,
        };
        return '+${pc(0.07 * n)} tầm và vùng${extra > 0 ? ', +$extra đạn' : ''}';
      }(),
    ManualKind.phase => s.status != Status.none
        ? '+${pc(0.12 * n)} hiệu ứng sẵn có'
        : switch (hanh) {
            Hanh.kim => 'Choáng ${(0.4 + 0.1 * n).toStringAsFixed(1)} giây',
            Hanh.moc => 'Trúng độc 4 giây',
            Hanh.thuy => 'Làm chậm ${pc(0.25 + 0.05 * n)}',
            Hanh.hoa => 'Thiêu đốt 3 giây',
            Hanh.tho => 'Choáng ${(0.5 + 0.1 * n).toStringAsFixed(1)} giây, đẩy lùi',
          },
  };
}

/// A random page for one of [sect]'s active skills.
String rollManualPage(SectDef sect, math.Random rng) {
  final idx = manualSkills(sect);
  final s = sect.skills[idx[rng.nextInt(idx.length)]];
  final kinds = manualKindsFor(s);
  return manualKey(s.id, kinds[rng.nextInt(kinds.length)]);
}

/// "Bí kíp Phục Hổ Côn · Tật Phong" for a page key.
String manualPageName(SectDef sect, String key) {
  final parts = key.split(':');
  final s = sect.skills.where((s) => s.id == parts[0]).firstOrNull;
  final k = int.tryParse(parts.length > 1 ? parts[1] : '');
  if (s == null || k == null || k < 0 || k >= ManualKind.values.length) return 'Bí kíp';
  return 'Bí kíp ${s.name} · ${manualKinds[ManualKind.values[k]]!.name}';
}

// Where pages come from.
const double bossPageChance = 0.12;
const double elitePageChance = 0.06;
