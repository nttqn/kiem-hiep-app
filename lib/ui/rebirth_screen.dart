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
import '../core/i18n.dart';

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
        title: Text(tr('Chuyển sinh lần {p0}?', {'p0': h.rebirths + 1}), style: titleStyle(20)),
        content: Text(
          tr('Nhân vật sẽ trở về cấp {rebirthLevel}. Điểm tiềm năng được trả lại để cộng lại '
          '(thêm {rebirthPoints} điểm).{p0} Trang bị, kỹ năng, ngọc, linh thú, lượng và nhiệm vụ '
          'được giữ nguyên.', {'rebirthLevel': rebirthLevel, 'rebirthPoints': rebirthPoints, 'p0': h.nextRebirthPills > 0 ? tr(' Tiêu hao {nextRebirthPills} Linh Phách Đơn.', {'nextRebirthPills': h.nextRebirthPills}) : ''}),
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Để sau'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Chuyển sinh'), style: TextStyle(color: goldLight, fontWeight: FontWeight.w800)),
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
        title: Text(tr('Chuyển sinh lần {rebirths}!', {'rebirths': h.rebirths}), style: titleStyle(22)),
        content: Text(
          tr('Đại hiệp đã thoát thai hoán cốt, trở về cấp {rebirthLevel} với '
          '{freePoints} điểm tiềm năng. Hãy vào Nhân vật để cộng điểm.', {'rebirthLevel': rebirthLevel, 'freePoints': h.freePoints}),
          style: body,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Tuyệt')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cap = h.expNeedAt(maxLevel);
    final atMax = h.level >= maxLevel;
    final done = h.rebirths >= maxRebirths;
    return SubScreen(
      title: done ? tr('Chuyển sinh · Ngộ Đạo') : tr('Chuyển sinh'),
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
                          Text(tr('Đã chuyển sinh {rebirths}/{maxRebirths} lần', {'rebirths': h.rebirths, 'maxRebirths': maxRebirths}), style: titleStyle(18, color: cream)),
                          const SizedBox(height: 8),
                          Text(tr('Điều kiện'), style: bold.copyWith(color: goldLight)),
                          _check(tr('Đạt cấp {maxLevel} (hiện tại cấp {level})', {'maxLevel': maxLevel, 'level': h.level}), atMax),
                          _check(tr('Kinh nghiệm cấp {maxLevel} đầy', {'maxLevel': maxLevel}), h.expFull),
                          if (h.nextRebirthPills > 0)
                            _check(tr('Linh Phách Đơn: {soulPills}/{nextRebirthPills} viên (trừ khi chuyển sinh)', {'soulPills': h.soulPills, 'nextRebirthPills': h.nextRebirthPills}),
                                h.soulPills >= h.nextRebirthPills),
                          const SizedBox(height: 4),
                          Bar(
                            value: atMax ? (h.exp / cap).clamp(0.0, 1.0) : 0,
                            color: expGold,
                            height: 13,
                            label: atMax ? '${fmt(h.exp)} / ${fmt(cap)}' : tr('Cần cấp {maxLevel}', {'maxLevel': maxLevel}),
                          ),
                          const SizedBox(height: 10),
                          if (done || h.nextRebirthPills > 0) ...[
                            // Past the last rebirth, EXP goes into Linh Phách Đơn.
                            MatCount(Mat.soulPill, tr('Linh Phách Đơn: {soulPills} viên', {'soulPills': h.soulPills}), style: bold.copyWith(color: const Color(0xFF9FE8FF)), size: 22),
                            const SizedBox(height: 4),
                            Bar(
                              value: h.expFull ? (h.soulExp / h.soulPillExp).clamp(0.0, 1.0) : 0,
                              color: const Color(0xFF6FC8E8),
                              height: 13,
                              label: h.expFull ? '${fmt(h.soulExp)} / ${fmt(h.soulPillExp)}' : tr('Cần đầy kinh nghiệm cấp {maxLevel}', {'maxLevel': maxLevel}),
                            ),
                            _line(done
                                ? tr('Kinh nghiệm dư ngưng tụ thành Linh Phách Đơn.')
                                : tr('Kinh nghiệm dư ngưng tụ thành Linh Phách Đơn. Cần {nextRebirthPills} viên để chuyển sinh lần {p0}.', {'nextRebirthPills': h.nextRebirthPills, 'p0': h.rebirths + 1})),
                            if (done && kiepPillsAhead(h.daoLv) > 0)
                              _line(tr('Để dành cho Độ kiếp: còn cần {p0} viên để tới {lastName}.', {'p0': fmt(kiepPillsAhead(h.daoLv)), 'lastName': tr(daoStages.last.name)})),
                            _line(tr('Đổi {soulPillsPerIron} viên lấy 1 Thần Thiết ở Kỳ Trân Các.', {'soulPillsPerIron': soulPillsPerIron})),
                          ],
                          if (!done) ...[
                            const SizedBox(height: 6),
                            Text(tr('Khi chuyển sinh'), style: bold.copyWith(color: goldLight)),
                            _line(tr('Trở về cấp {rebirthLevel}, trả lại điểm tiềm năng và tặng thêm {rebirthPoints} điểm.', {'rebirthLevel': rebirthLevel, 'rebirthPoints': rebirthPoints})),
                            _line(tr('Giữ nguyên trang bị, kỹ năng, ngọc, linh thú, lượng, nhiệm vụ và thành tựu.')),
                            _line(tr('Mỗi lần: Sinh lực {p0}, Công lực {p0}, '
                                'Phòng thủ {p1}, Kinh nghiệm nhận {p2}, vĩnh viễn.', {'p0': _pct(rebirthHpAtk), 'p1': _pct(rebirthDef), 'p2': _pct(rebirthExp)})),
                            if (h.rebirths + 1 >= lucChuyen)
                              _line(tr('Lục chuyển: mỗi cấp cần gấp {p0} lần kinh nghiệm, '
                                  'nhưng được {p1} điểm tiềm năng (thay vì {pointsPerLevel}). '
                                  'Mở U Minh Huyết Hải.', {'p0': lucChuyenExpNeed.round(), 'p1': pointsPerLevel + lucChuyenPoints, 'pointsPerLevel': pointsPerLevel})),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: LButton(
                      label: done ? tr('Đã đạt tối đa') : tr('Chuyển sinh lần {p0}', {'p0': h.rebirths + 1}),
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
                  Text(tr('Thưởng cộng dồn'), style: titleStyle(18)),
                  const SizedBox(height: 6),
                  _row([tr('Lần'), tr('Sinh lực'), tr('Công lực'), tr('Phòng thủ'), tr('Kinh nghiệm')], header: true),
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
                          tr('Trang bị đang mặc vẫn dùng được sau khi chuyển sinh, nên lần sau lên cấp nhanh hơn nhiều.'),
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
                ? tr('Cần đầy kinh nghiệm cấp {maxLevel}', {'maxLevel': maxLevel})
                : h.daoWaiting
                    ? tr('Viên mãn · chờ Độ kiếp')
                    : tr('Đạo hạnh {p0} / {p1}', {'p0': fmt(h.daoExp), 'p1': fmt(daoCost(lv))}),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lv > 0)
                    Text(tr('Đang có: Sinh lực {p0}, Công lực {p1}, Phòng thủ {p2}', {'p0': pct(Bonus.hpPct), 'p1': pct(Bonus.atkPct), 'p2': pct(Bonus.defPct)}),
                        style: bold.copyWith(fontSize: 13, color: cream)),
                  if (gate) ...[
                    _line(tr('Độ kiếp vào {p0}: thắng Tâm Ma Kiếp trong {p1} giây, '
                        'tốn {p2} Linh Phách Đơn (có {soulPills}). Thua không mất gì, đánh lại được.', {'p0': tr(daoStages[h.kiepStage].name), 'p1': kiepTime.round(), 'p2': kiepPills(lv), 'soulPills': h.soulPills})),
                    _line(tr('Tâm ma biến: {p0}.', {'p0': [for (final a in kiepAffixes(h.kiepStage)) tmAffixes[TmAffix.values[a]]!.name].join(', ')})),
                  ],
                  _line(tr('Đã đầy cấp {maxLevel}, kinh nghiệm vừa ngưng tụ Linh Phách Đơn vừa tăng Đạo hạnh.', {'maxLevel': maxLevel})),
                  _line(tr('Mỗi tầng: Sinh lực, Công lực +{p0}%, '
                      'Phòng thủ +{p1}%. Mỗi cảnh giới mới thêm '
                      '+{p2}% Sinh lực, Công lực.', {'p0': (daoHpAtk * 100).toStringAsFixed(1).replaceAll('.', ','), 'p1': (daoDef * 100).toStringAsFixed(1).replaceAll('.', ','), 'p2': (daoStageHpAtk * 100).round()})),
                  _line(tr('Chín tầng một cảnh giới; Chân Tiên không có giới hạn. Cảnh giới hiện trên Bảng xếp hạng.')),
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
                          child: Text(tr(daoStages[i].name),
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
                      label: h.daoWaiting ? tr('Độ kiếp') : tr('Độ kiếp (chưa đủ)'),
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
                    label: tr('Tiên khí · {tienJade}', {'tienJade': h.tienJade}),
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
