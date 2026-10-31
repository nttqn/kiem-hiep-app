import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/arena.dart';
import '../core/content.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/realm.dart';
import '../core/sects.dart';
import '../core/world.dart';
import 'theme.dart';

class HeroFrame extends StatelessWidget {
  const HeroFrame({super.key, required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    final h = world.hero;
    final p = world.player;
    final st = h.stats;
    return IgnorePointer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.lerp(hanhColor(h.hanh), Colors.white, 0.2)!,
                Color.lerp(hanhColor(h.hanh), Colors.black, 0.55)!,
              ]),
              border: Border.all(color: goldLight, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(h.hanh.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70, height: 1)),
                Text('${h.level}', style: titleStyle(20, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.title.isEmpty ? h.name : '${h.name} · ${h.title}',
                  style: bold.copyWith(fontSize: 13, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
              const SizedBox(height: 2),
              Bar(
                width: 190,
                height: 15,
                value: p.hp / p.maxHp,
                color: hpRed,
                label: '${p.hp.round()} / ${p.maxHp.round()}',
              ),
              if (p.shield > 0)
                Bar(width: 190, height: 4, value: p.shield / p.maxHp, color: const Color(0xFFC9A15A)),
              const SizedBox(height: 2),
              Bar(
                width: 160,
                height: 11,
                value: p.mp / st.maxMp,
                color: mpBlue,
                label: '${p.mp.round()} / ${st.maxMp.round()}',
              ),
              if (h.buffs.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    for (final e in h.buffs.entries)
                      if (pillById[e.key] case final pill?)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xAA170F0C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(pill.color).withValues(alpha: 0.8)),
                          ),
                          child: Text('${pill.name.replaceAll(' Đan', '')} ${(e.value / 60).ceil()}p',
                              style: bold.copyWith(fontSize: 10, color: Color(pill.color))),
                        ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class QuestTracker extends StatelessWidget {
  const QuestTracker({super.key, required this.hero});
  final HeroData hero;

  @override
  Widget build(BuildContext context) {
    final q = hero.currentMain;
    if (q == null) return const SizedBox.shrink();
    final locked = hero.mainLocked;
    final text = locked
        ? 'Cấp ${q.minLv} mở: ${q.title}'
        : (q.type == QuestType.kill
            ? '${q.goal} ${hero.mainProgress}/${q.count}'
            : q.goal);
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x99120A08),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: goldLight.withValues(alpha: 0.8), width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhiệm vụ · ${q.title}', style: bold.copyWith(fontSize: 11.5, color: goldLight)),
            Text(text, style: body.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// In a bí cảnh, the next step in place of the story quest.
class RealmTracker extends StatelessWidget {
  const RealmTracker({super.key, required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    final w = world;
    final step = w.lairOpen
        ? 'Phong ấn đã phá: hạ ${mobById[w.map.boss]!.name} ở phía đông'
        : 'Hạ Hộ Trận Sứ rồi chạm trận nhãn (${w.pillarsLit}/$realmPillars) để phá phong ấn';
    final buffs = w.realmBuffs.map((b) => b.label.split(':').first).join(', ');
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x99120A08),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: const Color(0xFF8CE0C8).withValues(alpha: 0.8), width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thám hiểm', style: bold.copyWith(fontSize: 11.5, color: const Color(0xFF8CE0C8))),
            Text(step, style: body.copyWith(fontSize: 11.5)),
            Text('Cứu người ${w.captivesFreed}/$realmCaptives${buffs.isEmpty ? '' : ' · Phúc: $buffs'}',
                style: body.copyWith(fontSize: 11, color: creamDim)),
          ],
        ),
      ),
    );
  }
}

class TopInfo extends StatelessWidget {
  const TopInfo({super.key, required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    final d = world.dungeon;
    final boss = world.boss;
    // The world boss never drops; its damage is shown above instead.
    final showBoss = boss != null &&
        !(d?.isWorldBoss ?? false) &&
        boss.alive &&
        (boss.state == MobState.chase ||
            (boss.x - world.player.x).abs() + (boss.y - world.player.y).abs() < 700);
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xAA120A08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withValues(alpha: 0.5)),
            ),
            child: d == null
                ? Text(world.map.name, style: bold.copyWith(fontSize: 13, color: goldLight))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.name, style: bold.copyWith(fontSize: 13, color: goldLight)),
                      const SizedBox(width: 10),
                      Text(
                        d.isWorldBoss
                            ? 'Sát thương ${fmt(world.bossDamage.round())}'
                            : d.isRealm
                            ? '${world.lairOpen ? 'Đầu lĩnh' : 'Trận nhãn ${world.pillarsLit}/$realmPillars'}'
                                ' · Rương ${world.chestsOpened}/$realmChests · ${(world.explored * 100).floor()}%'
                            : d.isArena
                                ? 'Bình máu ${arenaPotions - world.arenaPotsUsed}/$arenaPotions'
                                : world.bossWave
                                ? 'Đầu lĩnh'
                                : 'Đợt ${math.max(1, world.wave + 1)}/${d.waves.length} · còn ${world.aliveMobs}',
                        style: d.isWorldBoss
                            ? bold.copyWith(fontSize: 13, color: const Color(0xFFFF9A5A))
                            : body.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.timer, size: 14, color: world.timeLeft < 30 ? hpRed : cream),
                      Text(
                          d.isRealm
                              ? ' ${world.timeLeft.ceil() ~/ 60}:${(world.timeLeft.ceil() % 60).toString().padLeft(2, '0')}'
                              : ' ${world.timeLeft.ceil()}s',
                          style: bold.copyWith(fontSize: 13, color: world.timeLeft < 30 ? hpRed : cream)),
                      const SizedBox(width: 6),
                      for (var i = 0; i < (d.isTower || d.isWorldBoss || d.isArena || d.isRealm ? 0 : 3); i++)
                        Icon(
                          world.time <= (i == 0 ? d.timeLimit : (i == 1 ? d.twoStar : d.threeStar))
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: goldLight,
                        ),
                    ],
                  ),
          ),
          if (showBoss) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Color(boss.def.hanh.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('${boss.def.name} · Cấp ${boss.level}',
                    style: bold.copyWith(fontSize: 12, color: const Color(0xFFFFB08A))),
              ],
            ),
            Bar(
              width: 260,
              height: 12,
              value: boss.hp / boss.maxHp,
              color: const Color(0xFFB3261E),
              label: '${(boss.hp / boss.maxHp * 100).ceil()}%',
            ),
          ],
        ],
      ),
    );
  }
}

class RoundIcon extends StatelessWidget {
  const RoundIcon({super.key, required this.icon, required this.onTap, this.size = 38});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xCC2A1C17),
          border: Border.all(color: goldLight.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Icon(icon, color: cream, size: size * 0.55),
      ),
    );
  }
}

class AutoToggle extends StatelessWidget {
  const AutoToggle({super.key, required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? jade : const Color(0xCC2A1C17),
          border: Border.all(color: on ? goldLight : gold.withValues(alpha: 0.6), width: 1.5),
          boxShadow: on ? const [BoxShadow(color: Color(0x888CE07A), blurRadius: 8)] : null,
        ),
        child: Text('TỰ\nĐỘNG',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.5, height: 1.05, fontWeight: FontWeight.w800, color: on ? Colors.white : creamDim)),
      ),
    );
  }
}

class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    final w = 150.0;
    final h = w * world.height / world.width;
    return IgnorePointer(
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xEE1A120E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: gold.withValues(alpha: 0.7), width: 1.2),
        ),
        child: CustomPaint(painter: _MiniMapPainter(world)),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.w);
  final World w;

  @override
  void paint(Canvas c, Size s) {
    final sx = s.width / w.width, sy = s.height / w.height;
    if (w.realm != null) {
      _realm(c, s, sx, sy);
      return;
    }
    final quest = w.hero.currentMain?.target;
    final normal = Paint()..color = const Color(0xFFD8503A);
    final q = Paint()..color = const Color(0xFFFFE04A);
    for (final m in w.mobs) {
      if (!m.alive) continue;
      final o = Offset(m.x * sx, m.y * sy);
      if (m.elite) {
        c.drawCircle(o, 4, Paint()..color = const Color(0xFFFFD34A));
        c.drawCircle(o, 4, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      } else if (m.def.boss) {
        c.drawCircle(o, 4, Paint()..color = const Color(0xFFB57BF0));
        c.drawCircle(o, 4, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      } else {
        c.drawCircle(o, 1.5, m.def.id == quest ? q : normal);
      }
    }
    final p = w.player;
    c.drawCircle(Offset(p.x * sx, p.y * sy), 3.2, Paint()..color = Colors.white);
    c.drawCircle(Offset(220 * sx, w.height / 2 * sy), 3, Paint()
      ..color = const Color(0xFF7AD0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  /// Bí cảnh: only what the hero has seen, with its finds marked.
  void _realm(Canvas c, Size s, double sx, double sy) {
    final cw = fogCell * sx, ch = fogCell * sy;
    final seen = Paint()..color = const Color(0xFF4A3A2A);
    for (var r = 0; r < fogRows; r++) {
      for (var col = 0; col < fogCols; col++) {
        if (w.fog[r * fogCols + col]) c.drawRect(Rect.fromLTWH(col * cw, r * ch, cw + 0.5, ch + 0.5), seen);
      }
    }
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final o in w.realm!.pois) {
      final lair = o.kind == PoiKind.lair;
      // The lair shows from the start once its seal breaks.
      if (!w.revealedAt(o.x, o.y) && !(lair && w.lairOpen)) continue;
      if (o.done && !lair) {
        if (o.kind == PoiKind.pillar) c.drawCircle(Offset(o.x * sx, o.y * sy), 3, Paint()..color = const Color(0xFF7FE8FF));
        continue;
      }
      final at = Offset(o.x * sx, o.y * sy);
      switch (o.kind) {
        case PoiKind.chest:
          c.drawRect(Rect.fromCenter(center: at, width: 5, height: 4), Paint()..color = const Color(0xFFFFD34A));
        case PoiKind.pillar:
          c.drawCircle(at, 3, Paint()..color = const Color(0xFF8A8A9A));
          c.drawCircle(at, 3, ring);
        case PoiKind.shrine:
          c.drawCircle(at, 2.5, Paint()..color = const Color(0xFF8CE07A));
        case PoiKind.captive:
          c.drawCircle(at, 2.5, Paint()..color = Colors.white);
        case PoiKind.lair:
          c.drawCircle(at, 4.5, Paint()..color = w.lairOpen ? const Color(0xFFFF5A4A) : const Color(0xFFB57BF0));
          c.drawCircle(at, 4.5, ring);
      }
    }
    final mob = Paint()..color = const Color(0xFFD8503A);
    for (final m in w.mobs) {
      if (!m.alive || !w.revealedAt(m.x, m.y)) continue;
      c.drawCircle(Offset(m.x * sx, m.y * sy), m.big ? 3 : 1.4, m.elite ? (Paint()..color = const Color(0xFFFFD34A)) : mob);
    }
    final p = w.player;
    c.drawCircle(Offset(p.x * sx, p.y * sy), 3.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}

class ExpStrip extends StatelessWidget {
  const ExpStrip({super.key, required this.hero});
  final HeroData hero;

  @override
  Widget build(BuildContext context) {
    // Past the last rebirth the bar fills Linh Phách Đơn instead.
    final soul = hero.expFull && !hero.canRebirth;
    final v = soul
        ? (hero.soulExp / hero.soulPillExp).clamp(0.0, 1.0)
        : (hero.exp / hero.expNeeded).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Bar(
        value: v,
        color: soul ? const Color(0xFF6FC8E8) : expGold,
        height: 9,
        label: soul
            ? 'Linh Phách Đơn ${hero.soulPills} · ${(v * 100).toStringAsFixed(1)}%'
            : hero.expFull
                ? 'Kinh nghiệm đầy · có thể chuyển sinh'
                : 'Cấp ${hero.level} · ${(v * 100).toStringAsFixed(1)}%',
      ),
    );
  }
}

class JoystickView extends StatelessWidget {
  const JoystickView({super.key, required this.knob, required this.radius});
  final Offset knob;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(painter: _JoyPainter(knob, radius)),
    );
  }
}

class _JoyPainter extends CustomPainter {
  _JoyPainter(this.knob, this.radius);
  final Offset knob;
  final double radius;

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(radius, radius);
    c.drawCircle(ctr, radius, Paint()..color = const Color(0x44000000));
    c.drawCircle(ctr, radius, Paint()
      ..color = const Color(0x88F3D27A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    c.drawCircle(ctr + knob, radius * 0.42, Paint()..color = const Color(0xAAF3E6C8));
    c.drawCircle(ctr + knob, radius * 0.42, Paint()
      ..color = const Color(0xFFD9A93B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_JoyPainter old) => old.knob != knob;
}

class AttackButton extends StatefulWidget {
  const AttackButton({
    super.key,
    required this.hanh,
    required this.onDown,
    required this.onUp,
    this.engaged = false,
    this.onEngage,
  });
  final Hanh hanh;
  final VoidCallback onDown;
  final VoidCallback onUp;

  /// Fighting on its own after a tap: the button glows.
  final bool engaged;

  /// A short tap (not a hold): true to start fighting on, false to stop.
  final ValueChanged<bool>? onEngage;

  @override
  State<AttackButton> createState() => _AttackButtonState();
}

class _AttackButtonState extends State<AttackButton> {
  bool _down = false;
  bool _wasEngaged = false;
  final Stopwatch _held = Stopwatch();

  void _set(bool v) {
    setState(() => _down = v);
    if (v) {
      _wasEngaged = widget.engaged;
      _held
        ..reset()
        ..start();
      widget.onDown();
    } else {
      widget.onUp();
      // A tap toggles fighting on; a hold only attacks while held.
      widget.onEngage?.call(_held.elapsedMilliseconds < 300 && !_wasEngaged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = hanhColor(widget.hanh);
    final on = widget.engaged && !_down;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 60),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Color.lerp(c, Colors.white, 0.3)!,
              Color.lerp(c, Colors.black, 0.5)!,
            ]),
            border: Border.all(color: on ? Colors.white : goldLight, width: on ? 4 : 2.5),
            boxShadow: [
              const BoxShadow(color: Colors.black54, blurRadius: 6),
              if (on) BoxShadow(color: goldLight.withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.flash_on, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

class SkillButton extends StatelessWidget {
  const SkillButton({
    super.key,
    required this.skill,
    required this.hanh,
    required this.size,
    required this.learned,
    required this.unlockLevel,
    required this.cooldown,
    required this.onTap,
    this.cdText,
    this.noMp = false,
  });

  final SkillDef skill;
  final Hanh hanh;
  final double size;
  final bool learned;
  final int unlockLevel;
  final double cooldown;
  final String? cdText;
  final bool noMp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: learned ? (_) => onTap() : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SkillGlyph(skill, hanh, locked: !learned, cooldown: cooldown),
              ),
            ),
            if (!learned)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.white70),
                  Text('Cấp $unlockLevel', style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700)),
                ],
              ),
            if (cdText != null)
              Text(cdText!,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                  )),
            if (noMp && cdText == null)
              Positioned(
                bottom: 2,
                child: Text('Nội lực', style: TextStyle(fontSize: 9, color: Colors.lightBlue.shade100, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }
}

class PotionButton extends StatelessWidget {
  const PotionButton({super.key, required this.count, required this.color, required this.ready, required this.onTap});
  final int count;
  final Color color;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Opacity(
        opacity: count > 0 && ready ? 1 : 0.5,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xCC2A1C17),
            border: Border.all(color: color, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.local_drink, color: color, size: 24),
              Positioned(
                bottom: 2,
                right: 4,
                child: Text('$count', style: bold.copyWith(fontSize: 11, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
