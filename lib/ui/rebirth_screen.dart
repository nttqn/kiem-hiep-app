import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Chuyển sinh: requirements, what is kept and reset, and the bonus ladder.
class RebirthScreen extends StatefulWidget {
  const RebirthScreen({super.key});

  @override
  State<RebirthScreen> createState() => _RebirthScreenState();
}

class _RebirthScreenState extends State<RebirthScreen> {
  HeroData get h => SaveService.instance.hero;

  String _pct(double v) => '+${(v * 100).round()}%';

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Chuyển sinh lần ${h.rebirths + 1}?', style: titleStyle(20)),
        content: Text(
          'Nhân vật sẽ trở về cấp $rebirthLevel. Điểm tiềm năng được trả lại để cộng lại '
          '(thêm $rebirthPoints điểm). Trang bị, kỹ năng, ngọc, linh thú, lượng và nhiệm vụ '
          'được giữ nguyên.',
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chuyển sinh', style: TextStyle(color: goldLight, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !h.rebirth()) return;
    h.notices.clear();
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Chuyển sinh lần ${h.rebirths}!', style: titleStyle(22)),
        content: Text(
          'Đại hiệp đã thoát thai hoán cốt, trở về cấp $rebirthLevel với '
          '${h.freePoints} điểm tiềm năng. Hãy vào Nhân vật để cộng điểm.',
          style: body,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tuyệt'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = expToNext(maxLevel);
    final atMax = h.level >= maxLevel;
    final done = h.rebirths >= maxRebirths;
    return SubScreen(
      title: 'Chuyển sinh',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The text scrolls on short screens; the button stays in view.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đã chuyển sinh ${h.rebirths}/$maxRebirths lần', style: titleStyle(18, color: cream)),
                          const SizedBox(height: 8),
                          Text('Điều kiện', style: bold.copyWith(color: goldLight)),
                          _check('Đạt cấp $maxLevel (hiện tại cấp ${h.level})', atMax),
                          _check('Kinh nghiệm cấp $maxLevel đầy', h.expFull),
                          const SizedBox(height: 4),
                          Bar(
                            value: atMax ? (h.exp / cap).clamp(0.0, 1.0) : 0,
                            color: expGold,
                            height: 13,
                            label: atMax ? '${fmt(h.exp)} / ${fmt(cap)}' : 'Cần cấp $maxLevel',
                          ),
                          const SizedBox(height: 10),
                          if (done) ...[
                            // Past the last rebirth, EXP goes into Linh Phách Đơn.
                            Text('Linh Phách Đơn: ${h.soulPills} viên', style: bold.copyWith(color: const Color(0xFF9FE8FF))),
                            const SizedBox(height: 4),
                            Bar(
                              value: h.expFull ? (h.soulExp / h.soulPillExp).clamp(0.0, 1.0) : 0,
                              color: const Color(0xFF6FC8E8),
                              height: 13,
                              label: h.expFull ? '${fmt(h.soulExp)} / ${fmt(h.soulPillExp)}' : 'Cần đầy kinh nghiệm cấp $maxLevel',
                            ),
                            _line('Kinh nghiệm dư ngưng tụ thành Linh Phách Đơn, cất dành cho lần chuyển sinh sau.'),
                            _line('Đổi $soulPillsPerIron viên lấy 1 Thần Thiết ở Kỳ Trân Các.'),
                          ] else ...[
                            Text('Khi chuyển sinh', style: bold.copyWith(color: goldLight)),
                            _line('Trở về cấp $rebirthLevel, trả lại điểm tiềm năng và tặng thêm $rebirthPoints điểm.'),
                            _line('Giữ nguyên trang bị, kỹ năng, ngọc, linh thú, lượng, nhiệm vụ và thành tựu.'),
                            _line('Mỗi lần: Sinh lực ${_pct(rebirthHpAtk)}, Công lực ${_pct(rebirthHpAtk)}, '
                                'Phòng thủ ${_pct(rebirthDef)}, Kinh nghiệm nhận ${_pct(rebirthExp)}, vĩnh viễn.'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: LButton(
                      label: done ? 'Đã đạt tối đa' : 'Chuyển sinh lần ${h.rebirths + 1}',
                      icon: Icons.autorenew,
                      width: 260,
                      enabled: h.canRebirth,
                      onTap: _confirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 330,
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Thưởng cộng dồn', style: titleStyle(18)),
                  const SizedBox(height: 6),
                  _row(['Lần', 'Sinh lực', 'Công lực', 'Phòng thủ', 'Kinh nghiệm'], header: true),
                  for (var n = 1; n <= maxRebirths; n++)
                    _row([
                      '$n',
                      _pct(rebirthHpAtk * n),
                      _pct(rebirthHpAtk * n),
                      _pct(rebirthDef * n),
                      _pct(rebirthExp * n),
                    ], done: n <= h.rebirths, next: n == h.rebirths + 1),
                  const Spacer(),
                  Text(
                    'Trang bị đang mặc vẫn dùng được sau khi chuyển sinh, nên lần sau lên cấp nhanh hơn nhiều.',
                    style: small.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _check(String text, bool ok) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 17, color: ok ? const Color(0xFF8CE07A) : creamDim),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: body.copyWith(fontSize: 13.5, color: ok ? cream : creamDim))),
          ],
        ),
      );

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: body.copyWith(fontSize: 13, color: goldLight)),
            Expanded(child: Text(text, style: body.copyWith(fontSize: 13))),
          ],
        ),
      );

  Widget _row(List<String> cells, {bool header = false, bool done = false, bool next = false}) {
    final color = header ? goldLight : (done ? const Color(0xFF8CE07A) : (next ? cream : creamDim));
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: next ? Color.lerp(lacquer, seal, 0.35) : (header ? null : lacquerDeep),
        borderRadius: BorderRadius.circular(6),
        border: next ? Border.all(color: goldLight) : null,
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 4,
              child: Text(cells[i],
                  textAlign: TextAlign.center,
                  style: (header ? bold : body).copyWith(fontSize: header ? 11 : 13, color: color)),
            ),
        ],
      ),
    );
  }
}
