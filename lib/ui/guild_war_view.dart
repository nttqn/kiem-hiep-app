import 'package:flutter/material.dart';

import '../core/guild_war.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../core/weekly_hunt.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/analytics.dart';
import '../services/guild.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'play_screen.dart';
import 'theme.dart';

const _warTint = Color(0xFFFF8A5A);

/// Bang chiến (1.16.0), a view of the Bang hội screen: challenge another
/// bang's heroes, the week's board, and what each place pays.
class GuildWarView extends StatefulWidget {
  const GuildWarView({super.key, required this.guild, required this.members, required this.onChanged});

  final GuildInfo guild;

  /// This bang's members as the screen last read them.
  final List<GuildMember> members;

  /// Asks the screen to read the bang again (after a fight).
  final VoidCallback onChanged;

  @override
  State<GuildWarView> createState() => _GuildWarViewState();
}

class _GuildWarViewState extends State<GuildWarView> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  GuildInfo get g => widget.guild;
  String get _day => vnDayKey();

  /// 0: Khiêu chiến, 1: Xếp hạng, 2: Phần thưởng.
  int _sub = 0;
  bool _loading = true;
  String? _error;
  List<WarRow> _board = const [];
  List<GuildMember> _members = const [];
  List<(String, String)> _foes = const [];
  String? _foeId, _foeName;
  List<GuildMember>? _targets;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _members = widget.members;
    _load();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));
  }

  int get _week => h.gwWeek;

  int get _mySum {
    final row = gs.myRow;
    final mine = h.warPtsFor(g.id);
    var sum = 0;
    var seen = false;
    for (final m in _members) {
      if (m.row == row) {
        seen = true;
        sum += mine;
      } else {
        sum += m.warIn(_week);
      }
    }
    return seen ? sum : sum + mine;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    h.warRollDay(_day);
    try {
      if (h.gwRankDue) await _settle();
      await gs.pushWar(g, h, _members);
      _board = await gs.warBoard(_week);
      final foes = <String, String>{};
      for (final r in _board) {
        if (r.gid != g.id) foes[r.gid] = r.name;
      }
      for (final t in await gs.top()) {
        if (t.id != g.id && foes.length < 20) foes.putIfAbsent(t.id, () => t.name);
      }
      _foes = [for (final e in foes.entries) (e.key, e.value)];
      await SaveService.instance.save();
    } catch (e) {
      _error = 'Không tải được Bang chiến, thử lại sau.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Pays last week's Chiến công by the bang's place on that week's board.
  Future<void> _settle() async {
    final board = await gs.warBoard(h.gwLastWeek);
    final i = board.indexWhere((r) => r.gid == h.gwLastGid);
    final lines = h.warTakeRank(i < 0 ? 0 : i + 1);
    if (lines.isEmpty) return;
    await SaveService.instance.save();
    Analytics.instance.log('guild_war_rank', {'place': i + 1});
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text('Thưởng Bang chiến', style: titleStyle(20, color: _warTint)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines) Text('• $l', style: body)],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nhận'))],
      ),
    );
  }

  Future<void> _pickFoe(String id, String name) async {
    setState(() {
      _foeId = id;
      _foeName = name;
      _targets = null;
    });
    try {
      final ms = await gs.members(id);
      final mine = gs.uid;
      final bans = await Leaderboard.instance.bans();
      // Never a hero of this same account (one parked in another bang), nor
      // one banned from the boards (lbBans).
      final list = [
        for (final m in ms)
          if ((mine == null || !m.row.startsWith('${mine}_')) && !Leaderboard.bannedRow(bans, m.row)) m
      ]
        ..sort((a, b) => b.power.compareTo(a.power));
      if (mounted && _foeId == id) setState(() => _targets = list);
    } catch (_) {
      if (mounted && _foeId == id) {
        setState(() => _targets = const []);
        _toast('Không tải được thành viên bang $name.');
      }
    }
  }

  Future<void> _fight(GuildMember m) async {
    if (_busy) return;
    final day = _day;
    setState(() => _busy = true);
    try {
      final rows = await gs.rows([m.row]);
      final e = rows.isNotEmpty ? rows.first : m.toEntry();
      if (!h.warStart(m.row, day)) return;
      await SaveService.instance.save();
      if (!mounted) return;
      await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(warDef(e.toRival(), _foeName ?? ''))));
      try {
        _members = await gs.members(g.id);
      } catch (_) {}
      if (!await gs.pushWar(g, h, _members)) _toast('Chưa ghi được Chiến công lên máy chủ, sẽ thử lại.');
      try {
        _board = await gs.warBoard(_week);
      } catch (_) {}
      widget.onChanged();
    } catch (_) {
      _toast('Mạng yếu, thử lại sau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: goldLight));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: body),
          const SizedBox(height: 8),
          LButton(label: 'Thử lại', small: true, onTap: _load),
        ]),
      );
    }
    final day = _day;
    final left = h.warLeft(day);
    final place = _board.indexWhere((r) => r.gid == g.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tuần $_week · còn ${huntDaysLeft(day)} ngày · Chiến lệnh $left/$warPerDay',
          style: bold.copyWith(color: _warTint, fontSize: 12.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Chiến công: bạn ${h.warPtsFor(g.id)} · bang ${fmt(_mySum)}${place >= 0 ? ' (hạng ${place + 1})' : ''}',
          style: small.copyWith(fontSize: 11.5, color: cream),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(children: [
          _chip(0, 'Khiêu chiến'),
          _chip(1, 'Xếp hạng'),
          _chip(2, 'Phần thưởng'),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: switch (_sub) {
            1 => _boardView(),
            2 => _rewardsView(),
            _ => _challengeView(day),
          },
        ),
      ],
    );
  }

  Widget _chip(int i, String label) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: GestureDetector(
          onTap: () => setState(() => _sub = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _sub == i ? const Color(0xFF6A2A1A) : lacquerDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _sub == i ? _warTint : gold.withValues(alpha: 0.4)),
            ),
            child: Text(label, style: bold.copyWith(fontSize: 11.5)),
          ),
        ),
      );

  // ------------------------------------------------------------ challenge

  Widget _challengeView(String day) {
    if (_foes.isEmpty) {
      return Center(child: Text('Chưa có bang nào khác để khiêu chiến.', style: small));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (id, name) in _foes)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: () => _pickFoe(id, name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _foeId == id ? seal : lacquerDeep,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _foeId == id ? goldLight : _warTint.withValues(alpha: 0.5)),
                      ),
                      child: Text(name, style: bold.copyWith(fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _targetList(day)),
      ],
    );
  }

  Widget _targetList(String day) {
    if (_foeId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Chọn một bang ở trên để xem cao thủ của họ.\n'
            'Mỗi ngày $warPerDay Chiến lệnh, mỗi người một lần. Thắng người mạnh hơn được nhiều Chiến công hơn '
            '($warWinMin–$warWinMax), thua vẫn được $warLossPts.',
            style: small.copyWith(fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final t = _targets;
    if (t == null) return const Center(child: CircularProgressIndicator(color: goldLight));
    if (t.isEmpty) return Center(child: Text('Bang này chưa có ai để khiêu chiến.', style: small));
    return ListView(
      children: [for (final m in t) _targetRow(m, day)],
    );
  }

  Widget _targetRow(GuildMember m, String day) {
    final can = h.warCanHit(m.row, day);
    final fought = h.gwHit.contains(m.row);
    final pts = warWinPoints(h.power, m.power);
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: hanhColor(Hanh.values[m.hanh]), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: bold.copyWith(fontSize: 12.5, color: cream), overflow: TextOverflow.ellipsis),
                Text(
                  '${sectOf(Hanh.values[m.hanh]).name} · ${m.rebirths > 0 ? 'CS${m.rebirths} · ' : ''}Cấp ${m.level} · LC ${fmt(m.power)}',
                  style: small.copyWith(fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text('+$pts', style: bold.copyWith(fontSize: 12, color: goldLight)),
          ),
          LButton(
            label: fought ? 'Đã đánh' : 'Đánh',
            small: true,
            color: const Color(0xFF8A2A1A),
            enabled: can && !_busy,
            onTap: () => _fight(m),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ board

  Widget _boardView() {
    if (_board.isEmpty) {
      return Center(child: Text('Tuần này chưa bang nào có Chiến công.', style: small));
    }
    return ListView(
      children: [
        for (var i = 0; i < _board.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _board[i].gid == g.id ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}', style: bold.copyWith(color: i < 3 ? goldLight : cream, fontSize: 13)),
                ),
                Expanded(
                  child: Text(_board[i].name,
                      style: bold.copyWith(fontSize: 12.5, color: cream), overflow: TextOverflow.ellipsis),
                ),
                Text('${_board[i].n} người · ', style: small.copyWith(fontSize: 11)),
                Text(fmt(_board[i].pts), style: bold.copyWith(fontSize: 12.5, color: _warTint)),
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ rewards

  Widget _rewardsView() {
    return ListView(
      children: [
        Text('Hết tuần (Chủ nhật), ai có Chiến công đều nhận thưởng theo hạng của bang:',
            style: small.copyWith(fontSize: 11.5, color: cream)),
        const SizedBox(height: 4),
        for (final (label, place) in warRankBrackets) _rewardRow(label, warRankReward(place)),
        const SizedBox(height: 6),
        Text(
          'Mỗi trận: thắng +$warWinCoins xu Bang, +$warWinContrib cống hiến; thua +$warLossCoins xu Bang. '
          'Chuyển bang giữa tuần thì Chiến công tính lại từ đầu cho bang mới.',
          style: small.copyWith(fontSize: 11),
        ),
        if (h.gwWins > 0) Text('Đã thắng ${h.gwWins} trận Bang chiến', style: bold.copyWith(fontSize: 11.5, color: goldLight)),
      ],
    );
  }

  Widget _rewardRow(String label, WarRankReward r) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(label, style: bold.copyWith(fontSize: 12, color: cream))),
            Expanded(
              child: Text(
                '${r.coins} xu Bang, ${r.iron} Thần Thiết'
                '${r.jade > 0 ? ', ${r.jade} Tiên Ngọc' : ''}${r.title.isNotEmpty ? ', danh hiệu « ${r.title} »' : ''}',
                style: small.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      );
}
