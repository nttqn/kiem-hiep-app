import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/mentor.dart';
import '../core/sects.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/guild.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'theme.dart';
import '../core/i18n.dart';

const _sdTint = Color(0xFFFFC88A);

/// Sư đồ (1.19.0), the third tab of Bang hội · Hảo hữu.
class MentorView extends StatefulWidget {
  const MentorView({super.key});

  @override
  State<MentorView> createState() => _MentorViewState();
}

/// A master the hero could ask: from the listing or a strong friend.
class _Candidate {
  const _Candidate(this.row, this.name, this.hanh, this.level, this.rebirths, this.power, this.seats, this.friend);
  final String row, name;
  final int hanh, level, rebirths, power, seats;
  final bool friend;
}

class _MentorViewState extends State<MentorView> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  String get _day => vnDayKey();

  bool _loading = true;
  List<MentorMsg> _requests = const [];
  List<_Candidate> _candidates = const [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 3)));
  }

  Future<void> _save() => SaveService.instance.save();

  Future<void> _load() async {
    setState(() => _loading = true);
    final day = _day;
    h.mentorRollDay(day);
    try {
      final inbox = await gs.mentorInbox();
      final reqs = <MentorMsg>[];
      for (final m in inbox) {
        switch (m.kind) {
          case 'req':
            if (h.canTeach && h.discipleOf(m.from) == null) {
              reqs.add(m);
            } else if (h.discipleOf(m.from) != null) {
              await gs.mentorDrop(m.from);
            }
          case 'ok' || 'tc':
            if (m.from == h.sdPending) {
              h.masterAccepted();
              _toast(tr('{mName} đã nhận bạn làm đệ tử!', {'mName': m.name}));
            }
            if (m.from == h.sdMaster) {
              if (m.kind == 'tc' && m.day == day && h.sdTcDay != day) h.sdTcReady = true;
              if (m.kind == 'ok') await gs.mentorDrop(m.from);
            } else {
              await gs.mentorDrop(m.from);
            }
          case 'bye':
            if (m.from == h.sdMaster) {
              h.leaveMaster();
              _toast(tr('{mName} đã cho bạn rời sư môn.', {'mName': m.name}));
            } else if (m.from == h.sdPending) {
              h.sdPending = '';
              h.sdPendingName = '';
              _toast(tr('{mName} chưa nhận đệ tử lúc này.', {'mName': m.name}));
            } else if (h.discipleOf(m.from) != null) {
              h.dropDisciple(m.from);
              _toast(tr('Đệ tử {mName} đã rời sư môn.', {'mName': m.name}));
            }
            await gs.mentorDrop(m.from);
        }
      }
      _requests = reqs;
      // What the board says of each đệ tử.
      if (h.disciples.isNotEmpty) {
        final rows = await gs.rows([for (final d in h.disciples) d.row]);
        for (final e in rows) {
          h.seeDisciple(e.id, e.name, e.hanh, e.level, e.rebirths);
        }
      }
      if (h.sdListing) await gs.mentorList(h, h.canTeach, h.activeDisciples);
      if (h.sdListing && !h.canTeach) h.sdListing = false;
      if (h.canBaiSu && h.sdPending.isEmpty) await _findMasters();
      await _save();
    } catch (_) {
      _toast(tr('Không tải được, thử lại sau.'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _findMasters() async {
    final out = <String, _Candidate>{};
    try {
      for (final a in await gs.mentors()) {
        out[a.row] = _Candidate(a.row, a.name, a.hanh, a.level, a.rebirths, a.power, a.n, false);
      }
    } catch (_) {}
    final mine = gs.uid;
    final strong = await gs.rows([for (final f in h.friends) f.row]);
    for (final LbEntry e in strong) {
      if ((e.level >= mentorMinLevel || e.rebirths > 0) && (mine == null || !e.id.startsWith('${mine}_'))) {
        out[e.id] = _Candidate(e.id, e.name, e.hanh, e.level, e.rebirths, e.power, out[e.id]?.seats ?? 0, true);
      }
    }
    _candidates = out.values.toList()
      ..sort((a, b) => a.friend != b.friend ? (a.friend ? -1 : 1) : b.power.compareTo(a.power));
  }

  Future<void> _run(String key, Future<void> Function() job) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _ask(_Candidate c) => _run('ask', () async {
        if (!h.canBaiSu || h.sdPending.isNotEmpty) return;
        if (!await gs.mentorSend(h, c.row, 'req', _day)) {
          _toast(tr('Không gửi được, thử lại sau.'));
          return;
        }
        h.askMaster(c.row, c.name, c.hanh);
        await _save();
        _toast(tr('Đã xin bái {cName} làm sư phụ. Chờ người ấy nhận lời.', {'cName': tr(c.name)}));
      });

  Future<void> _cancelAsk() => _run('ask', () async {
        final row = h.sdPending;
        if (row.isEmpty) return;
        await gs.mentorSend(h, row, 'bye', _day);
        h.sdPending = '';
        h.sdPendingName = '';
        await _save();
        await _findMasters();
      });

  Future<void> _accept(MentorMsg m) => _run('r${m.from}', () async {
        if (!h.acceptDisciple(m.from, m.name, m.hanh, m.level)) {
          _toast(h.seatFree ? tr('Không nhận được đệ tử này (cấp quá {discipleMaxLevel}?).', {'discipleMaxLevel': discipleMaxLevel}) : tr('Đã đủ {mentorMaxDisciples} đệ tử.', {'mentorMaxDisciples': mentorMaxDisciples}));
          return;
        }
        if (!await gs.mentorSend(h, m.from, 'ok', _day)) {
          h.dropDisciple(m.from);
          _toast(tr('Không gửi được, thử lại sau.'));
          return;
        }
        await gs.mentorDrop(m.from);
        _requests = [..._requests]..remove(m);
        if (h.sdListing) await gs.mentorList(h, true, h.activeDisciples);
        await _save();
        _toast(tr('Đã nhận {mName} làm đệ tử.', {'mName': m.name}));
      });

  Future<void> _reject(MentorMsg m) => _run('r${m.from}', () async {
        await gs.mentorSend(h, m.from, 'bye', _day);
        await gs.mentorDrop(m.from);
        _requests = [..._requests]..remove(m);
      });

  Future<void> _truyenCong(Disciple d) => _run('t${d.row}', () async {
        if (!h.canTruyenCong(d.row, _day)) return;
        if (!await gs.mentorSend(h, d.row, 'tc', _day)) {
          _toast(tr('Không gửi được, thử lại sau.'));
          return;
        }
        h.sentTruyenCong(d.row, _day);
        await _save();
        _toast(tr('Đã truyền công cho {dName}. +{truyenCongEssence} Tinh Hoa', {'dName': d.name, 'truyenCongEssence': truyenCongEssence}));
      });

  Future<void> _truyenCongAll() => _run('tall', () async {
        var n = 0;
        for (final d in [...h.disciples]) {
          if (!h.canTruyenCong(d.row, _day)) continue;
          if (!await gs.mentorSend(h, d.row, 'tc', _day)) break;
          h.sentTruyenCong(d.row, _day);
          n++;
        }
        await _save();
        _toast(n > 0 ? tr('Đã truyền công cho {n} đệ tử. +{p0} Tinh Hoa', {'n': n, 'p0': n * truyenCongEssence}) : tr('Không gửi được, thử lại sau.'));
      });

  Future<void> _pay(Disciple d) async {
    final lines = h.takeMentorPay(d);
    if (lines.isEmpty) return;
    await _save();
    _toast(lines.join(' · '));
    if (mounted) setState(() {});
  }

  Future<void> _release(Disciple d) async {
    final ok = await _confirm(d.graduated ? tr('Xóa {dName} khỏi danh sách?', {'dName': d.name}) : tr('Cho {dName} rời sư môn?', {'dName': d.name}),
        d.graduated ? tr('Đệ tử đã xuất sư.') : tr('Phần thưởng mốc chưa nhận sẽ mất.'));
    if (!ok) return;
    await _run('x${d.row}', () async {
      if (!d.graduated) await gs.mentorSend(h, d.row, 'bye', _day);
      h.dropDisciple(d.row);
      if (h.sdListing) await gs.mentorList(h, true, h.activeDisciples);
      await _save();
    });
  }

  Future<void> _leave() async {
    final ok = await _confirm(tr('Rời sư môn?'), tr('Bạn sẽ mất +{p0}% EXP và quà các mốc sau.', {'p0': (discipleExpBonus * 100).round()}));
    if (!ok) return;
    await _run('leave', () async {
      await gs.mentorSend(h, h.sdMaster, 'bye', _day);
      h.leaveMaster();
      await _save();
      await _findMasters();
    });
  }

  Future<void> _takeGift() async {
    final lines = h.takeDiscipleGift();
    if (lines.isEmpty) return;
    await _save();
    _toast(lines.join(' · '));
    if (mounted) setState(() {});
  }

  Future<void> _takeTc() async {
    final xp = h.takeTruyenCong(_day);
    if (xp <= 0) return;
    await gs.mentorDrop(h.sdMaster);
    await _save();
    _toast(tr('Sư phụ truyền công: +{p0} kinh nghiệm', {'p0': fmt(xp)}));
    if (mounted) setState(() {});
  }

  Future<void> _toggleListing(bool on) => _run('list', () async {
        if (!await gs.mentorList(h, on, h.activeDisciples)) {
          _toast(tr('Không cập nhật được, thử lại sau.'));
          return;
        }
        h.sdListing = on;
        await _save();
      });

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: lacquer,
          title: Text(title, style: titleStyle(18, color: cream)),
          content: Text(text, style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Đồng ý'))),
          ],
        ),
      ) ??
      false;

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: goldLight));
    final day = _day;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: ListView(
              children: [
                if (h.hasMaster || h.sdPending.isNotEmpty || h.canBaiSu) ..._learnerPart(day),
                if (h.canTeach) ...[
                  if (h.hasMaster || h.canBaiSu) const Divider(color: gold),
                  ..._masterPart(day),
                ],
                if (!h.canTeach && !h.canBaiSu && !h.hasMaster && h.sdPending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      tr('Bái sư: nhân vật chưa chuyển sinh, cấp {discipleMaxLevel} trở xuống.\n'
                      'Nhận đệ tử: cấp {mentorMinLevel} trở lên hoặc đã chuyển sinh.', {'discipleMaxLevel': discipleMaxLevel, 'mentorMinLevel': mentorMinLevel}),
                      style: body,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 230, child: _rules()),
      ],
    );
  }

  Widget _rules() => Panel(
        border: _sdTint,
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            Text(tr('Sư đồ'), style: titleStyle(17, color: _sdTint)),
            const SizedBox(height: 4),
            Text(
              tr('Đệ tử (chưa chuyển sinh, cấp ≤ {discipleMaxLevel} khi bái sư):\n'
              '• +{p0}% EXP quái đến khi xuất sư (chuyển sinh lần đầu)\n'
              '• Quà ở mỗi mốc {first}, {p1}… {last} và xuất sư\n'
              '• Mỗi ngày nhận Truyền công: +{p2}% EXP cấp hiện tại', {'discipleMaxLevel': discipleMaxLevel, 'p0': (discipleExpBonus * 100).round(), 'first': mentorMilestones.first, 'p1': mentorMilestones[1], 'last': mentorMilestones.last, 'p2': (truyenCongShare * 100).round()}),
              style: small.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              tr('Sư phụ (cấp {mentorMinLevel}+ hoặc đã chuyển sinh), tối đa {mentorMaxDisciples} đệ tử:\n'
              '• Tinh Hoa và Thần Thiết mỗi khi đệ tử qua một mốc, nhiều nhất lúc xuất sư\n'
              '• +{truyenCongEssence} Tinh Hoa mỗi lần truyền công\n'
              '• Danh hiệu « {mentorTitle1} » (1 đệ tử xuất sư), « {mentorTitle3} » (3)', {'mentorMinLevel': mentorMinLevel, 'mentorMaxDisciples': mentorMaxDisciples, 'truyenCongEssence': truyenCongEssence, 'mentorTitle1': mentorTitle1, 'mentorTitle3': mentorTitle3}),
              style: small.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(tr('Tiến độ của đệ tử đọc từ Bảng xếp hạng, nên đệ tử cần hiện trên bảng.'),
                style: small.copyWith(fontSize: 10.5, color: creamDim)),
          ],
        ),
      );

  // ------------------------------------------------------------ as đệ tử

  List<Widget> _learnerPart(String day) {
    if (h.hasMaster) {
      final reached = h.discipleStepsReached;
      final next = h.sdGiftNext < mentorSteps ? h.sdGiftNext : -1;
      return [
        Text(tr('Sư phụ'), style: titleStyle(16, color: _sdTint)),
        _personRow(h.sdMasterName, h.sdMasterHanh, h.rebirths > 0 ? tr('Đã xuất sư') : tr('+{p0}% EXP quái', {'p0': (discipleExpBonus * 100).round()}),
            trailing: [
              if (h.rebirths == 0)
                LButton(label: tr('Rời'), small: true, color: seal, enabled: !_busy.contains('leave'), onTap: _leave),
            ]),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                h.sdTcReady && h.sdTcDay != day
                    ? tr('Sư phụ đã truyền công hôm nay.')
                    : h.sdTcDay == day
                        ? tr('Đã nhận Truyền công hôm nay.')
                        : tr('Chưa có Truyền công hôm nay.'),
                style: small.copyWith(fontSize: 11.5),
              ),
            ),
            LButton(
              label: tr('Nhận Truyền công'),
              small: true,
              color: jade,
              enabled: h.sdTcReady && h.sdTcDay != day && h.rebirths == 0,
              onTap: _takeTc,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                next < 0
                    ? tr('Đã nhận hết quà sư môn.')
                    : h.discipleGiftReady
                        ? tr('Quà mốc {p0} đã sẵn sàng.', {'p0': mentorStepName(next)})
                        : tr('Mốc tiếp: {p0} (đã qua {reached}/{mentorSteps} mốc)', {'p0': mentorStepName(next), 'reached': reached, 'mentorSteps': mentorSteps}),
                style: small.copyWith(fontSize: 11.5),
              ),
            ),
            LButton(label: tr('Nhận quà'), small: true, color: jade, enabled: h.discipleGiftReady, onTap: _takeGift),
          ],
        ),
      ];
    }
    if (h.sdPending.isNotEmpty) {
      return [
        Text(tr('Đang xin bái sư'), style: titleStyle(16, color: _sdTint)),
        _personRow(h.sdPendingName, h.sdPendingHanh, tr('Chờ người ấy nhận lời'),
            trailing: [LButton(label: tr('Hủy'), small: true, color: seal, enabled: !_busy.contains('ask'), onTap: _cancelAsk)]),
      ];
    }
    return [
      Row(
        children: [
          Expanded(child: Text(tr('Tìm sư phụ'), style: titleStyle(16, color: _sdTint))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: goldLight, size: 20)),
        ],
      ),
      if (_candidates.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            tr('Chưa thấy ai đang nhận đệ tử. Kết bạn với người chơi cấp {mentorMinLevel}+ trên Bảng xếp hạng rồi quay lại đây.', {'mentorMinLevel': mentorMinLevel}),
            style: body.copyWith(fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        )
      else
        for (final c in _candidates)
          _personRow(
            c.name,
            c.hanh,
            tr('{p0}Cấp {level} · LC {p1}'
            '{p2}', {'p0': c.rebirths > 0 ? tr('CS{rebirths} · ', {'rebirths': c.rebirths}) : '', 'level': c.level, 'p1': fmt(c.power), 'p2': c.friend ? tr(' · bạn bè') : tr(' · {seats}/{mentorMaxDisciples} đệ tử', {'seats': c.seats, 'mentorMaxDisciples': mentorMaxDisciples})}),
            trailing: [LButton(label: tr('Bái sư'), small: true, color: jade, enabled: !_busy.contains('ask'), onTap: () => _ask(c))],
          ),
    ];
  }

  // ------------------------------------------------------------ as sư phụ

  List<Widget> _masterPart(String day) {
    final canTc = h.disciples.any((d) => h.canTruyenCong(d.row, day));
    return [
      Row(
        children: [
          Expanded(child: Text(tr('Đệ tử {activeDisciples}/{mentorMaxDisciples}', {'activeDisciples': h.activeDisciples, 'mentorMaxDisciples': mentorMaxDisciples}), style: titleStyle(16, color: _sdTint))),
          Text(tr('Nhận đệ tử'), style: small.copyWith(fontSize: 11.5)),
          Switch(
            value: h.sdListing,
            activeThumbColor: jade,
            onChanged: _busy.contains('list') ? null : _toggleListing,
          ),
          LButton(label: tr('Truyền công'), small: true, color: jade, enabled: canTc && !_busy.contains('tall'), onTap: _truyenCongAll),
        ],
      ),
      if (h.disciples.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            tr('Chưa có đệ tử. Bật "Nhận đệ tử" để tân thủ tìm thấy bạn; bạn bè cấp thấp cũng có thể xin bái sư.'),
            style: body.copyWith(fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ),
      for (final d in h.disciples) _discipleRow(d, day),
      if (_requests.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(tr('Xin bái sư ({_requestsLength})', {'_requestsLength': _requests.length}), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        for (final m in _requests)
          _personRow(m.name, m.hanh, tr('Cấp {level}', {'level': m.level}), trailing: [
            LButton(
                label: tr('Nhận'),
                small: true,
                color: jade,
                enabled: h.seatFree && !_busy.contains('r${m.from}'),
                onTap: () => _accept(m)),
            const SizedBox(width: 4),
            LButton(label: tr('Từ chối'), small: true, color: seal, enabled: !_busy.contains('r${m.from}'), onTap: () => _reject(m)),
          ]),
      ],
    ];
  }

  Widget _discipleRow(Disciple d, String day) {
    final due = h.mentorPayDue(d);
    final next = d.reached < mentorSteps ? mentorStepName(d.reached) : null;
    return _personRow(
      d.name,
      d.hanh,
      d.graduated
          ? tr('Đã xuất sư')
          : tr('Cấp {level}{p0}', {'level': d.level, 'p0': next != null ? tr(' · mốc tiếp: {next}', {'next': next}) : ''}),
      onTap: () => _release(d),
      trailing: [
        if (due > 0)
          LButton(label: tr('Nhận thưởng'), small: true, color: const Color(0xFF8A4A1A), onTap: () => _pay(d))
        else if (!d.graduated)
          LButton(
            label: h.canTruyenCong(d.row, day) ? tr('Truyền công') : tr('Đã truyền'),
            small: true,
            color: jade,
            enabled: h.canTruyenCong(d.row, day) && !_busy.contains('t${d.row}'),
            onTap: () => _truyenCong(d),
          ),
      ],
    );
  }

  Widget _personRow(String name, int hanh, String line, {List<Widget> trailing = const [], VoidCallback? onTap}) {
    final hn = Hanh.values[hanh.clamp(0, 4)];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: hanhColor(hn), shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: bold.copyWith(fontSize: 12.5, color: cream), overflow: TextOverflow.ellipsis),
                  Text('${tr(sectOf(hn).name)} · $line',
                      style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}
