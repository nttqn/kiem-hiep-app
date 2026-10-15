import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';
import 'town_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, required this.slot});
  final int slot;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  Hanh _hanh = Hanh.kim;
  bool _female = false;
  final _name = TextEditingController();

  static const _defaultNames = {
    Hanh.kim: ['Huyền Không', 'Tuệ Tâm'],
    Hanh.moc: ['Độc Cô Phong', 'Lam Phượng'],
    Hanh.thuy: ['Lăng Ba', 'Băng Tâm'],
    Hanh.hoa: ['Liệt Phong', 'Hồng Diệp'],
    Hanh.tho: ['Thanh Vân', 'Tử Yên'],
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = sectOf(_hanh);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Backdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sect list.
                SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: goldLight),
                          ),
                          Text('Chọn môn phái', style: titleStyle(18)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final h in Hanh.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _SectTab(
                            sect: sectOf(h),
                            selected: h == _hanh,
                            onTap: () => setState(() => _hanh = h),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Preview.
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            child: FigurePreview(hanh: _hanh, female: _female, scale: 3.4),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GenderChip(label: 'Nam', on: !_female, onTap: () => setState(() => _female = false)),
                          const SizedBox(width: 8),
                          _GenderChip(label: 'Nữ', on: _female, onTap: () => setState(() => _female = true)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Details.
                Expanded(
                  flex: 5,
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(s.name, style: titleStyle(24, color: hanhColor(_hanh)))),
                            _HanhBadge(hanh: _hanh),
                          ],
                        ),
                        Text(s.tagline, style: body.copyWith(fontStyle: FontStyle.italic, color: goldLight)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.desc, style: body),
                                const SizedBox(height: 6),
                                Text('Lối đánh: ${s.role}', style: small.copyWith(color: cream)),
                                Row(
                                  children: [
                                    Text('Độ khó: ', style: small.copyWith(color: cream)),
                                    for (var i = 0; i < 3; i++)
                                      Icon(i < s.difficulty ? Icons.star : Icons.star_border,
                                          size: 15, color: goldLight),
                                  ],
                                ),
                                Text(
                                  'Khắc ${_hanh.overcomes.label} (+25% sát thương) · '
                                  'bị ${_hanh.overcomeBy.label} khắc',
                                  style: small.copyWith(color: cream),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final sk in s.skills)
                                      Tooltip(
                                        message: '${sk.name} (cấp ${sk.unlock}): ${sk.desc}',
                                        child: SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: CustomPaint(painter: SkillGlyph(sk, _hanh)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: _name,
                                  maxLength: 14,
                                  style: body,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    isDense: true,
                                    hintText: _defaultNames[_hanh]![_female ? 1 : 0],
                                    hintStyle: small,
                                    filled: true,
                                    fillColor: lacquerDeep,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: gold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            LButton(label: 'Nhập môn', onTap: _create),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    var name = _name.text.trim();
    if (name.isEmpty) name = _defaultNames[_hanh]![_female ? 1 : 0];
    final h = HeroData(name: name, hanh: _hanh, female: _female);
    h.refreshDaily(todayKey());
    await SaveService.instance.create(widget.slot, h);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const TownScreen(firstVisit: true)), (_) => false);
  }
}

class _SectTab extends StatelessWidget {
  const _SectTab({required this.sect, required this.selected, required this.onTap});
  final SectDef sect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = hanhColor(sect.hanh);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Color.lerp(lacquer, c, 0.35) : lacquer.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c : gold.withValues(alpha: 0.4), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            _HanhBadge(hanh: sect.hanh, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sect.name, style: bold.copyWith(fontSize: 14)),
                  Text(sect.role.split(' · ').first, style: small.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HanhBadge extends StatelessWidget {
  const _HanhBadge({required this.hanh, this.size = 36});
  final Hanh hanh;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = hanhColor(hanh);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(c, Colors.white, 0.3)!, Color.lerp(c, Colors.black, 0.4)!]),
        border: Border.all(color: goldLight, width: 1.2),
      ),
      child: Text(hanh.label, style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: on ? seal : lacquer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? goldLight : gold.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: bold.copyWith(fontSize: 13)),
      ),
    );
  }
}
