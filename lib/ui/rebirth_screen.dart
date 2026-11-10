import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/ngo_dao.dart';
import '../core/sects.dart';
import '../core/tam_ma.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'tien_screen.dart';

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
          '(thêm $rebirthPoints điểm).${h.nextRebirthPills > 0 ? ' Tiêu hao ${h.nextRebirthPills} Linh Phách Đơn.' : ''} Trang bị, kỹ năng, ngọc, linh thú, lượng và nhiệm vụ '
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
    final cap = h.expNeedAt(maxLevel);
    final atMax = h.level >= maxLevel;
    final done = h.rebirths >= maxRebirths;
    return SubScreen(
      title: done ? 'Chuyển sinh · Ngộ Đạo' : 'Chuyển sinh',
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
                          if (h.nextRebirthPills > 0)
                            _check('Linh Phách Đơn: ${h.soulPills}/${h.nextRebirthPills} viên (trừ khi chuyển sinh)',
                                h.soulPills >= h.nextRebirthPills),
                          const SizedBox(height: 4),
                          Bar(
                            value: atMax ? (h.exp / cap).clamp(0.0, 1.0) : 0,
                            color: expGold,
                            height: 13,
                            label: atMax ? '${fmt(h.exp)} / ${fmt(cap)}' : 'Cần cấp $maxLevel',
                          ),
                          const SizedBox(height: 10),
                          if (done || h.nextRebirthPills > 0) ...[
                            // Past the last rebirth, EXP goes into Linh Phách Đơn.
                            MatCount(Mat.soulPill, 'Linh Phách Đơn: ${h.soulPills} viên', style: bold.copyWith(color: const Color(0xFF9FE8FF)), size: 22),
                            const SizedBox(height: 4),
                            Bar(
                              value: h.expFull ? (h.soulExp / h.soulPillExp).clamp(0.0, 1.0) : 0,
                              color: const Color(0xFF6FC8E8),
                              height: 13,
                              label: h.expFull ? '${fmt(h.soulExp)} / ${fmt(h.soulPillExp)}' : 'Cần đầy kinh nghiệm cấp $maxLevel',
                            ),
                            _line(done
                                ? 'Kinh nghiệm dư ngưng tụ thành Linh Phách Đơn.'
                                : 'Kinh nghiệm dư ngưng tụ thành Linh Phách Đơn. Cần ${h.nextRebirthPills} viên để chuyển sinh lần ${h.rebirths + 1}.'),
                            _line('Đổi $soulPillsPerIron viên lấy 1 Thần Thiết ở Kỳ Trân Các.'),
                          ],
                          if (!done) ...[
                            const SizedBox(height: 6),
                            Text('Khi chuyển sinh', style: bold.copyWith(color: goldLight)),
                            _line('Trở về cấp $rebirthLevel, trả lại điểm tiềm năng và tặng thêm $rebirthPoints điểm.'),
                            _line('Giữ nguyên trang bị, kỹ năng, ngọc, linh thú, lượng, nhiệm vụ và thành tựu.'),
                            _line('Mỗi lần: Sinh lực ${_pct(rebirthHpAtk)}, Công lực ${_pct(rebirthHpAtk)}, '
                                'Phòng thủ ${_pct(rebirthDef)}, Kinh nghiệm nhận ${_pct(rebirthExp)}, vĩnh viễn.'),
                            if (h.rebirths + 1 >= lucChuyen)
                              _line('Lục chuyển: mỗi cấp cần gấp ${lucChuyenExpNeed.round()} lần kinh nghiệm, '
                                  'nhưng được ${pointsPerLevel + lucChuyenPoints} điểm tiềm năng (thay vì $pointsPerLevel). '
                                  'Mở U Minh Huyết Hải.'),
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
          if (done)
            SizedBox(width: 360, child: _daoPanel())
          else
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
                  // Scrolls on a short phone.
                  Expanded(
                    child: ListView(
                      children: [
                        for (var n = 1; n <= maxRebirths; n++)
                          _row([
                            '$n',
                            _pct(rebirthHpAtk * n),
                            _pct(rebirthHpAtk * n),
                            _pct(rebirthDef * n),
                            _pct(rebirthExp * n),
                          ], done: n <= h.rebirths, next: n == h.rebirths + 1),
                        const SizedBox(height: 6),
                        Text(
                          'Trang bị đang mặc vẫn dùng được sau khi chuyển sinh, nên lần sau lên cấp nhanh hơn nhiều.',
                          style: small.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _kiep() async {
    if (!h.canKiep) return;
    await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(h.kiepDef())));
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  /// Ngộ Đạo (1.12.0): the cảnh giới, its bar, what it gives and the gate.
  Widget _daoPanel() {
    final lv = h.daoLv;
    final c = Color(daoColor(lv));
    final b = daoBonuses(lv);
    final gate = daoAtGate(lv);
    final open = h.expFull;
    String pct(Bonus k) => '+${(((b[k] ?? 0) * 1000).round() / 10).toString().replaceAll('.', ',')}%';
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: c, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(daoName(lv), style: titleStyle(19, color: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Bar(
            value: open ? h.daoProgress : 0,
            color: c,
            height: 13,
            label: !open
                ? 'Cần đầy kinh nghiệm cấp $maxLevel'
                : h.daoWaiting
                    ? 'Viên mãn · chờ Độ kiếp'
                    : 'Đạo hạnh ${fmt(h.daoExp)} / ${fmt(daoCost(lv))}',
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lv > 0)
                    Text('Đang có: Sinh lực ${pct(Bonus.hpPct)}, Công lực ${pct(Bonus.atkPct)}, Phòng thủ ${pct(Bonus.defPct)}',
                        style: bold.copyWith(fontSize: 13, color: cream)),
                  if (gate) ...[
                    _line('Độ kiếp vào ${daoStages[h.kiepStage].name}: thắng Tâm Ma Kiếp trong ${kiepTime.round()} giây, '
                        'tốn ${kiepPills(lv)} Linh Phách Đơn (có ${h.soulPills}). Thua không mất gì, đánh lại được.'),
                    _line('Tâm ma biến: ${[for (final a in kiepAffixes(h.kiepStage)) tmAffixes[TmAffix.values[a]]!.name].join(', ')}.'),
                  ],
                  _line('Đã đầy cấp $maxLevel, kinh nghiệm vừa ngưng tụ Linh Phách Đơn vừa tăng Đạo hạnh.'),
                  _line('Mỗi tầng: Sinh lực, Công lực +${(daoHpAtk * 100).toStringAsFixed(1).replaceAll('.', ',')}%, '
                      'Phòng thủ +${(daoDef * 100).toStringAsFixed(1).replaceAll('.', ',')}%. Mỗi cảnh giới mới thêm '
                      '+${(daoStageHpAtk * 100).round()}% Sinh lực, Công lực.'),
                  _line('Chín tầng một cảnh giới; Chân Tiên không có giới hạn. Cảnh giới hiện trên Bảng xếp hạng.'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < daoStages.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: i <= daoStageOf(lv) ? Color(daoStages[i].color).withValues(alpha: 0.25) : lacquerDeep,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: i == daoStageOf(lv) ? Color(daoStages[i].color) : gold.withValues(alpha: 0.3)),
                          ),
                          child: Text(daoStages[i].name,
                              style: small.copyWith(
                                  fontSize: 11, color: i <= daoStageOf(lv) ? Color(daoStages[i].color) : creamDim)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (lv > 0 || gate) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (gate) ...[
                  Expanded(
                    child: LButton(
                      label: h.daoWaiting ? 'Độ kiếp' : 'Độ kiếp (chưa đủ)',
                      icon: Icons.bolt,
                      small: true,
                      enabled: h.canKiep,
                      onTap: _kiep,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Tiên khí (1.13.0): where Tiên Ngọc from the climb goes.
                Expanded(
                  child: LButton(
                    label: 'Tiên khí · ${h.tienJade}',
                    icon: Icons.diamond,
                    small: true,
                    color: const Color(0xFF2E8A7A),
                    enabled: lv > 0,
                    onTap: () async {
                      await Navigator.of(context).push(fadeRoute(const TienScreen()));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
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
