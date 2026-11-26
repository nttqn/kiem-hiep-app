import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bond.dart';
import '../core/guild.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/mentor.dart';
import '../core/sects.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/guild.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'bond_view.dart';
import 'cloud_panel.dart';
import 'guild_war_view.dart';
import 'hero_card.dart';
import 'mentor_view.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'world_boss_screen.dart' show BossPreview;
import '../core/i18n.dart';
import '../core/quick_chat.dart';
import 'quick_chat_button.dart';
import 'run_gate.dart';

const _bangTint = Color(0xFF8CC8FF);

/// Bang hội and Hảo hữu (1.13.0).
class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key, this.tab = 0});

  /// 0: Bang hội, 1: Hảo hữu, 2: Sư đồ, 3: Kết duyên.
  final int tab;

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  late int _tab = widget.tab;

  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: tr(const ['Bang hội', 'Hảo hữu', 'Sư đồ', 'Kết duyên'][_tab]),
      actions: [
        tabChip(tr('Bang hội'), _tab == 0, () => setState(() => _tab = 0)),
        tabChip(tr('Hảo hữu'), _tab == 1, () => setState(() => _tab = 1)),
        tabChip(h.mentorBadge > 0 ? tr('Sư đồ ({mentorBadge})', {'mentorBadge': h.mentorBadge}) : tr('Sư đồ'), _tab == 2, () => setState(() => _tab = 2)),
        tabChip(h.bondBadge(vnDayKey()) > 0 ? tr('Kết duyên (1)') : tr('Kết duyên'), _tab == 3, () => setState(() => _tab = 3)),
      ],
      child: !gs.available
          ? Panel(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('Đăng nhập để vào bang và kết bạn'), style: bold.copyWith(color: cream)),
                    const SizedBox(height: 6),
                    Text(tr('Bang hội và Hảo hữu dùng chung tài khoản với lưu trữ đám mây.'), style: small),
                    const SizedBox(height: 12),
                    LButton(
                      label: tr('Đăng nhập'),
                      color: jade,
                      onTap: () async {
                        await showCloudPanel(context);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            )
          : switch (_tab) {
              0 => const _GuildTab(),
              1 => const _FriendsTab(),
              2 => const MentorView(),
              _ => const BondView(),
            },
    );
  }
}

// ================================================================ Bang hội

class _GuildTab extends StatefulWidget {
  const _GuildTab();

  @override
  State<_GuildTab> createState() => _GuildTabState();
}

class _GuildTabState extends State<_GuildTab> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  String get _day => vnDayKey();

  bool _loading = true;
  String? _error;
  GuildInfo? _g;
  List<GuildMember> _members = const [];
  List<GuildMember> _apps = const [];
  List<GuildInfo>? _list;

  /// 0: Tổng quan, 1: Thành viên, 2: Cửa hàng, 3: Kênh Bang, 4: Bang chiến.
  int _view = 0;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));
  }

  int get _total => _members.fold<int>(0, (a, m) => a + m.contrib);
  int get _bossTotal {
    final w = h.gBossWeek;
    return _members.fold<int>(0, (a, m) => a + (m.bw == w ? m.bd : 0));
  }

  /// Reads where this hero stands: their bang, or an application taken.
  Future<void> _sync() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    h.guildRollDay(_day);
    final row = gs.myRow;
    try {
      if (row == null) throw StateError('no row');
      if (!h.inGuild) {
        for (final gid in [...h.guildApplied]) {
          final m = await gs.member(gid, row);
          if (m != null) {
            final g = await gs.guild(gid);
            if (g != null) {
              h.joinGuild(g.id, g.name, m.role, g.level);
              _toast(tr('Đã được nhận vào bang {gName}!', {'gName': g.name}));
              break;
            }
          }
        }
      }
      if (!h.inGuild) {
        final led = await gs.ledByMe();
        if (led != null) {
          final (g, m) = led;
          h.joinGuild(g.id, g.name, m.role, g.level);
        }
      }
      if (h.inGuild) {
        final g = await gs.guild(h.guildId);
        final me = g == null ? null : await gs.member(h.guildId, row);
        if (g == null || me == null) {
          final name = h.guildName;
          h.leaveGuild();
          _toast(g == null ? tr('Bang {name} đã giải tán.', {'name': name}) : tr('Bạn không còn trong bang {name}.', {'name': name}));
        } else {
          var members = await gs.members(g.id);
          h.guildRole = me.role;
          h.guildName = g.name;
          // A save behind the server (another device, or the bang put back
          // on this one) must not write its smaller numbers over the row.
          if (me.contrib > h.guildContrib) h.guildContrib = me.contrib;
          if (me.bw == h.gBossWeek && me.bd > h.gBossDmg) h.gBossDmg = me.bd;
          if (me.bw > h.gBossWeek) {
            h.gBossWeek = me.bw;
            h.gBossDmg = me.bd;
          }
          // This hero's newest numbers in the sums.
          members = [for (final m in members) m.row == row ? GuildMember.of(row, me.uid, h, me.role) : m];
          h.guildLv = guildLevelOf(members.fold<int>(0, (a, m) => a + m.contrib));
          await gs.pushMine(g.id, h, me.role, all: members);
          final apps = me.role >= roleVice ? await gs.apps(g.id) : const <GuildMember>[];
          _g = g;
          unawaited(gs.claimLang(g));
          _members = members..sort((a, b) => b.role != a.role ? b.role - a.role : b.contrib - a.contrib);
          _apps = apps;
        }
      }
      if (!h.inGuild) {
        _g = null;
        _members = const [];
        _list = await gs.browse();
      }
      await SaveService.instance.save();
    } catch (e) {
      _error = tr('Không tải được, thử lại sau.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: goldLight));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: body),
          const SizedBox(height: 8),
          LButton(label: tr('Thử lại'), small: true, onTap: _sync),
        ]),
      );
    }
    final g = _g;
    if (g == null) return _outside();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 230, child: _summary(g)),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _chip(0, tr('Tổng quan')),
                    _chip(4, tr('Bang chiến')),
                    _chip(1, tr('Thành viên{p0}', {'p0': _apps.isNotEmpty ? ' (${_apps.length})' : ''})),
                    _chip(2, tr('Cửa hàng')),
                    _chip(3, tr('Kênh Bang')),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: switch (_view) {
                    1 => _membersView(g),
                    2 => _shopView(),
                    3 => _ChatView(gid: g.id),
                    4 => GuildWarView(
                        guild: g,
                        members: _members,
                        onChanged: () {
                          unawaited(gs.pushMine(g.id, h, h.guildRole));
                          if (mounted) setState(() {});
                        },
                      ),
                    _ => _overview(g),
                  },
                ),
                if (_msg != null && _view != 3 && _view != 4)
                  Text(_msg!, style: small.copyWith(color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(int i, String label) => Flexible(
        child: Padding(
          padding: const EdgeInsets.only(right: 5),
          child: GestureDetector(
            onTap: () => setState(() {
              _view = i;
              _msg = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _view == i ? seal : lacquerDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _view == i ? goldLight : gold.withValues(alpha: 0.5)),
              ),
              child: Text(label,
                  style: bold.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );

  Widget _summary(GuildInfo g) {
    final lv = guildLevelOf(_total);
    final next = lv < guildMaxLevel ? guildLevelExp[lv] : null;
    final prev = guildLevelExp[lv - 1];
    return Panel(
      border: _bangTint,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const ArtIcon('guild_crest', fallback: Icons.shield, size: 40),
            const SizedBox(width: 6),
            Expanded(child: Text(g.name, style: titleStyle(20, color: _bangTint), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          Text(tr('Cấp {lv} · {_membersLength}/{p0} người', {'lv': lv, '_membersLength': _members.length, 'p0': guildMaxMembers(lv)}), style: bold.copyWith(color: cream, fontSize: 13)),
          const SizedBox(height: 4),
          Bar(
            value: next == null ? 1 : ((_total - prev) / (next - prev)).clamp(0.0, 1.0),
            color: _bangTint,
            height: 11,
            label: next == null ? tr('Cấp tối đa') : '${fmt(_total)} / ${fmt(next)}',
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                Text(tr('Mỗi thành viên: +{p0}% EXP và lượng', {'p0': (guildPerkPerLv * lv * 100).toStringAsFixed(1)}),
                    style: small.copyWith(fontSize: 11.5, color: goldLight)),
                if (g.notice.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(g.notice, style: body.copyWith(fontSize: 12)),
                ],
                const SizedBox(height: 4),
                _kv(tr('Chức vụ'), guildRoleName(h.guildRole)),
                _kv(tr('Cống hiến'), fmt(h.guildContrib)),
                _kv(tr('Xu Bang'), fmt(h.guildCoins)),
                _kv(tr('Nhận người'), g.open ? tr('Tự do') : tr('Duyệt đơn')),
              ],
            ),
          ),
          Row(
            children: [
              if (h.guildRole >= roleVice)
                Expanded(
                  child: LButton(label: tr('Cài đặt'), small: true, color: lacquerLight, onTap: () => _settings(g)),
                ),
              if (h.guildRole >= roleVice) const SizedBox(width: 6),
              Expanded(child: LButton(label: tr('Rời bang'), small: true, color: lacquerLight, onTap: () => _leave(g))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        children: [
          Expanded(child: Text(k, style: small.copyWith(fontSize: 12))),
          Text(v, style: bold.copyWith(fontSize: 12.5, color: cream)),
        ],
      );

  // ------------------------------------------------------------ overview

  Future<void> _did(bool ok, String msg) async {
    if (!ok) return;
    await SaveService.instance.save();
    final g = _g;
    if (g != null) unawaited(gs.pushMine(g.id, h, h.guildRole));
    if (mounted) setState(() => _msg = msg);
  }

  Widget _overview(GuildInfo g) {
    final day = _day;
    h.guildRollDay(day);
    final boss = guildBossOf(day);
    final left = h.guildBossLeft(day);
    final total = _bossTotal;
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: LButton(
                label: h.gSigned ? tr('Đã điểm danh') : tr('Điểm danh +{guildSignContrib}', {'guildSignContrib': guildSignContrib}),
                icon: Icons.how_to_reg,
                small: true,
                color: jade,
                enabled: !h.gSigned,
                onTap: () => _did(h.guildSign(day), tr('Điểm danh: +{guildSignContrib} cống hiến, +{guildSignContrib} xu Bang.', {'guildSignContrib': guildSignContrib})),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LButton(
                label: tr('Quyên góp {p0} ({p1})', {'p0': fmt(h.guildDonateCost), 'p1': guildDonatesPerDay - h.gDonated}),
                icon: Icons.savings,
                small: true,
                color: const Color(0xFF8A6A1A),
                enabled: h.gDonated < guildDonatesPerDay && h.gold >= h.guildDonateCost,
                onTap: () => _did(h.guildDonate(day), tr('Quyên góp: +{guildContribPerDonate} cống hiến.', {'guildContribPerDonate': guildContribPerDonate})),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              SizedBox(width: 70, height: 70, child: FittedBox(child: BossPreview(def: boss, size: 90))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Boss Bang · {p0}', {'p0': tr(boss.name)}), style: bold.copyWith(color: const Color(0xFFFF9A5A))),
                    Text(tr('Cả bang dồn sát thương trong tuần. Mỗi ngày {guildBossRuns} lượt, {p0} giây.', {'guildBossRuns': guildBossRuns, 'p0': guildBossTime.round()}),
                        style: small.copyWith(fontSize: 11)),
                    Text(tr('Bang: {p0} · Bạn: {p1}', {'p0': fmt(total), 'p1': fmt(h.gBossDmg)}), style: bold.copyWith(fontSize: 12, color: cream)),
                  ],
                ),
              ),
              LButton(
                label: tr('Đánh ({left})', {'left': left}),
                small: true,
                enabled: left > 0,
                onTap: () async {
                  if (!RunGate.take() || !h.guildBossStart(day)) return;
                  await SaveService.instance.save();
                  if (!mounted) return;
                  await Navigator.of(context).push(fadeRoute(PlayScreen.dungeon(guildBossDef(day))));
                  if (mounted) _sync();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(tr('Rương Boss Bang (cho ai đã đánh trong tuần)'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        for (var i = 0; i < guildBossTiers.length; i++) _chest(i, total),
      ],
    );
  }

  Widget _chest(int i, int total) {
    final c = guildBossChests[i];
    final taken = h.gBossClaimed & (1 << i) != 0;
    final ready = h.guildChestReady(i, total);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(taken ? Icons.check_circle : Icons.inventory_2,
              size: 16, color: taken ? const Color(0xFF8CE07A) : total >= guildBossTiers[i] ? goldLight : creamDim),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr('{p0}: {coins} xu Bang, {iron} Thần Thiết'
              '{p1}{p2}', {'p0': fmt(guildBossTiers[i]), 'coins': c.coins, 'iron': c.iron, 'p1': c.pills > 0 ? tr(', {pills} Linh Phách Đơn', {'pills': c.pills}) : '', 'p2': c.jade > 0 ? tr(', {jade} Tiên Ngọc', {'jade': c.jade}) : ''}),
              style: small.copyWith(fontSize: 11),
              maxLines: 2,
            ),
          ),
          if (ready)
            LButton(
              label: tr('Nhận'),
              small: true,
              color: jade,
              onTap: () {
                final lines = h.guildTakeChest(i, total);
                _did(lines.isNotEmpty, lines.join(', '));
              },
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ members

  Widget _membersView(GuildInfo g) {
    return ListView(
      children: [
        if (_apps.isNotEmpty) ...[
          Text(tr('Đơn xin vào'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
          for (final a in _apps)
            _personRow(a, trailing: [
              LButton(label: tr('Nhận'), small: true, color: jade, onTap: () => _accept(g, a)),
              const SizedBox(width: 4),
              LButton(label: tr('Từ chối'), small: true, color: lacquerLight, onTap: () => _reject(g, a)),
            ]),
          const SizedBox(height: 6),
          Text(tr('Thành viên'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        ],
        for (final m in _members) GestureDetector(onTap: () => _memberMenu(g, m), child: _personRow(m)),
      ],
    );
  }

  Widget _personRow(GuildMember m, {List<Widget> trailing = const []}) {
    final mine = m.row == gs.myRow;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: mine ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
        borderRadius: BorderRadius.circular(6),
      ),
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
                  tr('{p0} · {p1}Cấp {level} · LC {p2}', {'p0': tr(sectOf(Hanh.values[m.hanh]).name), 'p1': m.rebirths > 0 ? tr('CS{rebirths} · ', {'rebirths': m.rebirths}) : '', 'level': m.level, 'p2': fmt(m.power)}),
                  style: small.copyWith(fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing.isEmpty) ...[
            if (m.role > roleMember)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(guildRoleName(m.role), style: bold.copyWith(fontSize: 11, color: _bangTint)),
              ),
            Text(fmt(m.contrib), style: bold.copyWith(fontSize: 12, color: goldLight)),
          ],
          ...trailing,
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() f, String done) async {
    try {
      await f();
      _toast(done);
    } catch (_) {
      _toast(tr('Không thực hiện được, thử lại sau.'));
    }
    await _sync();
  }

  Future<void> _accept(GuildInfo g, GuildMember a) async {
    if (_members.length >= guildMaxMembers(guildLevelOf(_total))) {
      _toast(tr('Bang đã đủ người.'));
      return;
    }
    await _run(() => gs.accept(g.id, a), tr('Đã nhận {aName}.', {'aName': tr(a.name)}));
  }

  Future<void> _reject(GuildInfo g, GuildMember a) => _run(() => gs.reject(g.id, a.row), tr('Đã từ chối {aName}.', {'aName': tr(a.name)}));

  Future<void> _memberMenu(GuildInfo g, GuildMember m) async {
    final mine = m.row == gs.myRow;
    final leader = h.guildRole == roleLeader;
    final canKick = !mine && h.guildRole > m.role && h.guildRole >= roleVice;
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(m.name, style: titleStyle(18, color: cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('{p0} · cống hiến {p1}', {'p0': guildRoleName(m.role), 'p1': fmt(m.contrib)}), style: small),
            const SizedBox(height: 10),
            LButton(label: tr('Xem thông tin'), icon: Icons.person_search, onTap: () => Navigator.pop(ctx, 'view')),
            if (leader && !mine) ...[
              const SizedBox(height: 6),
              LButton(
                label: m.role == roleVice ? tr('Hạ làm Thành viên') : tr('Phong Phó bang'),
                small: true,
                color: lacquerLight,
                onTap: () => Navigator.pop(ctx, 'role'),
              ),
              const SizedBox(height: 6),
              LButton(label: tr('Nhường Bang chủ'), small: true, color: lacquerLight, onTap: () => Navigator.pop(ctx, 'lead')),
            ],
            if (canKick) ...[
              const SizedBox(height: 6),
              LButton(label: tr('Mời khỏi bang'), small: true, color: seal, onTap: () => Navigator.pop(ctx, 'kick')),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
      ),
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'view':
        await showHeroCard(context, m.toEntry(), mine: mine);
      case 'role':
        await _run(() => gs.setRole(g, m, m.role == roleVice ? roleMember : roleVice), tr('Đã đổi chức vụ.'));
      case 'lead':
        if (await _confirm(tr('Nhường chức Bang chủ cho {mName}? Bạn sẽ thành Thành viên.', {'mName': m.name}))) {
          await _run(() => gs.handOver(g, gs.myRow!, m), tr('Đã nhường Bang chủ.'));
        }
      case 'kick':
        if (await _confirm(tr('Mời {mName} khỏi bang?', {'mName': m.name}))) await _run(() => gs.remove(g.id, m.row), tr('Đã mời {mName} khỏi bang.', {'mName': m.name}));
    }
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        content: Text(text, style: body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Đồng ý'))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leave(GuildInfo g) async {
    final alone = _members.length <= 1;
    if (h.guildRole == roleLeader && !alone) {
      _toast(tr('Bang chủ hãy nhường chức trước khi rời bang.'));
      return;
    }
    final text = h.guildRole == roleLeader
        ? tr('Bạn là người cuối cùng: rời đi sẽ giải tán bang {gName}. Xu Bang vẫn giữ lại.', {'gName': g.name})
        : tr('Rời bang {gName}? Cống hiến với bang sẽ mất, xu Bang vẫn giữ lại.', {'gName': g.name});
    if (!await _confirm(text)) return;
    try {
      if (h.guildRole == roleLeader) {
        await gs.disband(g, _members);
      } else {
        await gs.remove(g.id, gs.myRow!);
      }
      h.leaveGuild();
      await SaveService.instance.save();
    } catch (_) {
      _toast(tr('Không rời được bang, thử lại sau.'));
    }
    await _sync();
  }

  Future<void> _settings(GuildInfo g) async {
    final notice = TextEditingController(text: g.notice);
    var open = g.open;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          scrollable: true,
          backgroundColor: lacquer,
          title: Text(tr('Cài đặt bang'), style: titleStyle(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notice,
                maxLength: guildNoticeMax,
                maxLines: 2,
                style: body,
                decoration: InputDecoration(labelText: tr('Thông báo')),
              ),
              Row(
                children: [
                  Expanded(child: Text(tr('Nhận người tự do (không cần duyệt)'), style: body.copyWith(fontSize: 13))),
                  Switch(value: open, activeThumbColor: goldLight, onChanged: (v) => set(() => open = v)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Lưu'))),
          ],
        ),
      ),
    );
    if (ok == true) await _run(() => gs.setSettings(g, notice: notice.text.trim(), open: open), tr('Đã lưu.'));
  }

  // ------------------------------------------------------------ shop

  Widget _shopView() {
    final day = _day;
    return ListView(
      children: [
        Text(tr('Xu Bang: {p0} · làm mới mỗi thứ Hai', {'p0': fmt(h.guildCoins)}), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        for (final o in guildShop) _offer(o, day),
      ],
    );
  }

  Widget _offer(GuildOffer o, String day) {
    final block = h.guildBuyBlock(o, day);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('{oName} ×{n}', {'oName': tr(o.name), 'n': o.n}), style: bold.copyWith(fontSize: 13, color: cream)),
                Text(tr('{price} xu · tuần {p0}/{limit}{p1}', {'price': o.price, 'p0': h.guildBoughtOf(o), 'limit': o.limit, 'p1': o.minLv > 1 ? tr(' · bang cấp {minLv}', {'minLv': o.minLv}) : ''}),
                    style: small.copyWith(fontSize: 11)),
              ],
            ),
          ),
          LButton(
            label: block ?? tr('Đổi'),
            small: true,
            color: jade,
            enabled: block == null,
            onTap: () => _did(h.guildBuy(o, day), tr('Đã đổi {oName} ×{n}.', {'oName': tr(o.name), 'n': o.n})),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ outside

  final _search = TextEditingController();

  Widget _outside() {
    final list = _list ?? const <GuildInfo>[];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 230,
          child: Panel(
            border: _bangTint,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Chưa vào bang'), style: titleStyle(18, color: _bangTint)),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                          tr('Vào bang để nhận thêm EXP và lượng theo cấp bang, Điểm danh, Quyên góp, đánh Boss Bang '
                          'cùng nhau và đổi đồ ở Cửa hàng Bang.'),
                          style: body.copyWith(fontSize: 12.5)),
                      const SizedBox(height: 6),
                      if (h.guildApplied.isNotEmpty)
                        Text(tr('Đang chờ duyệt {guildAppliedLength} đơn.', {'guildAppliedLength': h.guildApplied.length}), style: small.copyWith(color: goldLight)),
                      if (!h.guildOpen) Text(tr('Mở ở cấp {guildOpenLevel}.', {'guildOpenLevel': guildOpenLevel}), style: small.copyWith(color: goldLight)),
                    ],
                  ),
                ),
                LButton(
                  label: tr('Lập bang · {p0} lượng', {'p0': fmt(guildCreateGold)}),
                  small: true,
                  color: jade,
                  enabled: h.guildOpen && h.gold >= guildCreateGold,
                  onTap: _create,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _search,
                          style: body.copyWith(fontSize: 13),
                          decoration: InputDecoration(
                              hintText: tr('Tìm bang theo tên'), isDense: true, contentPadding: EdgeInsets.all(8)),
                          onSubmitted: (_) => _find(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    LButton(label: tr('Tìm'), small: true, onTap: _find),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(tr('Chưa có bang nào. Hãy lập bang đầu tiên!'), style: body))
                      : ListView(children: [for (final g in list) _guildRow(g)]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    if (q.isEmpty) {
      await _sync();
      return;
    }
    try {
      final g = await gs.find(q);
      if (mounted) setState(() => _list = g == null ? const [] : [g]);
      if (g == null) _toast(tr('Không có bang "{q}".', {'q': q}));
    } catch (_) {
      _toast(tr('Không tìm được, thử lại sau.'));
    }
  }

  Widget _guildRow(GuildInfo g) {
    final applied = h.guildApplied.contains(g.id);
    final full = g.n >= guildMaxMembers(g.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(g.name, style: bold.copyWith(fontSize: 14, color: cream), overflow: TextOverflow.ellipsis)),
                  LangTag(g.language),
                ]),
                Text(
                  tr('Cấp {level} · {n}/{p0} · Bang chủ {leaderName} · {p1}', {'level': g.level, 'n': g.n, 'p0': guildMaxMembers(g.level), 'leaderName': g.leaderName, 'p1': g.open ? tr('tự do vào') : tr('duyệt đơn')}),
                  style: small.copyWith(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          LButton(
            label: applied ? tr('Đã xin') : g.open ? tr('Vào') : tr('Xin vào'),
            small: true,
            color: jade,
            enabled: h.guildOpen && !applied && !full && (g.open || h.guildApplied.length < guildMaxApplied),
            onTap: () => _join(g),
          ),
        ],
      ),
    );
  }

  Future<void> _join(GuildInfo g) async {
    try {
      final inNow = await gs.join(g, h);
      if (inNow) {
        h.joinGuild(g.id, g.name, roleMember, g.level);
        _toast(tr('Đã vào bang {gName}!', {'gName': g.name}));
      } else {
        h.guildApplied.add(g.id);
        _toast(g.open ? tr('Chưa đủ cấp để vào thẳng, đã gửi đơn.') : tr('Đã gửi đơn, chờ bang duyệt.'));
      }
      await SaveService.instance.save();
    } catch (_) {
      _toast(tr('Không gửi được, thử lại sau.'));
    }
    await _sync();
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(tr('Lập bang'), style: titleStyle(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: guildNameMax,
              style: body,
              decoration: InputDecoration(labelText: tr('Tên bang')),
            ),
            Text(tr('Tốn {p0} lượng. Tên phải từ {guildNameMin} đến {guildNameMax} ký tự và không trùng.', {'p0': fmt(guildCreateGold), 'guildNameMin': guildNameMin, 'guildNameMax': guildNameMax}),
                style: small),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Lập bang'))),
        ],
      ),
    );
    final n = name.text.trim();
    if (ok != true) return;
    if (n.length < guildNameMin || n.length > guildNameMax) {
      _toast(tr('Tên bang từ {guildNameMin} đến {guildNameMax} ký tự.', {'guildNameMin': guildNameMin, 'guildNameMax': guildNameMax}));
      return;
    }
    if (h.gold < guildCreateGold) return;
    final (id, err) = await gs.create(h, n);
    if (id == null) {
      _toast(err ?? tr('Không lập được bang.'));
      return;
    }
    h.gold -= guildCreateGold;
    h.joinGuild(id, n, roleLeader, 1);
    await SaveService.instance.save();
    _toast(tr('Đã lập bang {n}!', {'n': n}));
    await _sync();
  }
}

/// Kênh Bang: the bang's last messages, live.
class _ChatView extends StatefulWidget {
  const _ChatView({required this.gid});
  final String gid;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _text = TextEditingController();
  late final Stream<List<GuildChat>> _stream = GuildService.instance.chat(widget.gid);
  bool _sending = false;

  Future<void> _send({String? line}) async {
    final text = line ?? _text.text;
    if (_sending || text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok = await GuildService.instance.say(widget.gid, SaveService.instance.hero, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      if (line == null) _text.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Không gửi được, thử lại sau.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = GuildService.instance.myRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<List<GuildChat>>(
            stream: _stream,
            builder: (_, snap) {
              final msgs = snap.data;
              if (msgs == null) {
                return snap.hasError
                    ? Center(child: Text(tr('Không tải được kênh bang.'), style: small))
                    : const Center(child: CircularProgressIndicator(color: goldLight));
              }
              if (msgs.isEmpty) return Center(child: Text(tr('Chưa có tin nào. Chào cả bang đi!'), style: small));
              return ListView(
                reverse: true,
                children: [
                  for (final m in msgs.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${m.name}: ',
                            style: bold.copyWith(fontSize: 12, color: m.row == me ? goldLight : _bangTint)),
                        TextSpan(text: chatShow(m.text), style: body.copyWith(fontSize: 12.5)),
                      ])),
                    ),
                ],
              );
            },
          ),
        ),
        Row(
          children: [
            QuickChatButton(input: _text, onPhrase: (p) => _send(line: p), size: 34),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: _text,
                  maxLength: 120,
                  style: body.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                      hintText: tr('Nhắn cả bang…'), counterText: '', isDense: true, contentPadding: EdgeInsets.all(8)),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            LButton(label: tr('Gửi'), small: true, enabled: !_sending, onTap: _send),
          ],
        ),
      ],
    );
  }
}

// ================================================================ Hảo hữu

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  String get _day => vnDayKey();

  bool _loading = true;
  Map<String, LbEntry> _rows = {};
  List<FriendGift> _inbox = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    h.friendRollDay(_day);
    try {
      final rows = await gs.rows([for (final f in h.friends) f.row]);
      final inbox = await gs.inbox();
      // Names and sects as now seen.
      for (final e in rows) {
        for (final f in h.friends) {
          if (f.row == e.id) {
            f.name = e.name;
            f.hanh = e.hanh;
          }
        }
      }
      _rows = {for (final e in rows) e.id: e};
      _inbox = inbox;
    } catch (_) {
      _toast(tr('Không tải được, thử lại sau.'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _gift(Friend f) async {
    if (!h.canGift(f.row, _day)) return;
    final ok = await gs.sendGift(h, f.row, _day);
    if (!ok) {
      _toast(tr('Không gửi được, thử lại sau.'));
      return;
    }
    h.markGifted(f.row, _day);
    await SaveService.instance.save();
    if (mounted) setState(() {});
  }

  Future<void> _giftAll() async {
    var n = 0;
    for (final f in [...h.friends]) {
      if (!h.canGift(f.row, _day)) continue;
      if (!await gs.sendGift(h, f.row, _day)) break;
      h.markGifted(f.row, _day);
      n++;
    }
    await SaveService.instance.save();
    _toast(n > 0 ? tr('Đã tặng quà cho {n} bạn.', {'n': n}) : tr('Không gửi được, thử lại sau.'));
    if (mounted) setState(() {});
  }

  Future<void> _takeAll() async {
    var gold = 0, n = 0;
    for (final g in [..._inbox]) {
      if (h.giftsLeft(_day) <= 0) break;
      try {
        await gs.dropGift(g.from);
      } catch (_) {
        break;
      }
      gold += h.takeGift(_day);
      n++;
      _inbox = [..._inbox]..remove(g);
    }
    await SaveService.instance.save();
    _toast(n > 0 ? tr('Nhận {n} quà: +{p0} lượng.', {'n': n, 'p0': fmt(gold)}) : tr('Hôm nay đã nhận đủ quà.'));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: goldLight));
    final day = _day;
    final canGiftAny = h.friends.any((f) => h.canGift(f.row, day));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('Bạn bè {friendsLength}/{maxFriends}', {'friendsLength': h.friends.length, 'maxFriends': maxFriends}), style: titleStyle(17)),
                    ),
                    LButton(label: tr('Tặng tất cả'), small: true, color: jade, enabled: canGiftAny, onTap: _giftAll),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: h.friends.isEmpty
                      ? Center(
                          child: Text(tr('Chưa có bạn. Chạm vào người chơi trên Bảng xếp hạng → Xem thông tin → Kết bạn.'),
                              style: body, textAlign: TextAlign.center),
                        )
                      : ListView(children: [for (final f in h.friends) _friendRow(f, day)]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 230,
          child: Panel(
            border: _bangTint,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Quà nhận được'), style: titleStyle(17, color: _bangTint)),
                Text(tr('{_inboxLength} quà chờ · hôm nay còn nhận {p0}/{friendGiftsPerDay}', {'_inboxLength': _inbox.length, 'p0': h.giftsLeft(day), 'friendGiftsPerDay': friendGiftsPerDay}),
                    style: small.copyWith(fontSize: 11.5)),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    children: [
                      for (final g in _inbox.take(20))
                        Text('• ${g.name}', style: body.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(
                          tr('Mỗi ngày tặng mỗi bạn một quà. Mỗi quà nhận được: +{p0} lượng '
                          '(tối đa {friendGiftsPerDay} quà một ngày).', {'p0': fmt(friendGiftGold(h.level, h.rebirths)), 'friendGiftsPerDay': friendGiftsPerDay}),
                          style: small.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                LButton(
                  label: tr('Nhận quà'),
                  small: true,
                  color: jade,
                  enabled: _inbox.isNotEmpty && h.giftsLeft(day) > 0,
                  onTap: _takeAll,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _friendRow(Friend f, String day) {
    final e = _rows[f.row];
    final hn = Hanh.values[f.hanh];
    final sent = !h.canGift(f.row, day);
    return GestureDetector(
      onTap: () => _friendMenu(f),
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
                  Text(f.name, style: bold.copyWith(fontSize: 12.5, color: cream), overflow: TextOverflow.ellipsis),
                  Text(
                    e == null
                        ? tr('{p0} · chưa có trên bảng', {'p0': tr(sectOf(hn).name)})
                        : tr('{p0} · {p1}Cấp {level} · LC {p2}', {'p0': tr(sectOf(hn).name), 'p1': e.rebirths > 0 ? tr('CS{rebirths} · ', {'rebirths': e.rebirths}) : '', 'level': e.level, 'p2': fmt(e.power)}),
                    style: small.copyWith(fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            LButton(
              label: sent ? tr('Đã tặng') : tr('Tặng quà'),
              small: true,
              color: jade,
              enabled: !sent,
              onTap: () => _gift(f),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _friendMenu(Friend f) async {
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(f.name, style: titleStyle(18, color: cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LButton(label: tr('Xem thông tin'), icon: Icons.person_search, onTap: () => Navigator.pop(ctx, 'view')),
            const SizedBox(height: 6),
            LButton(label: tr('Xóa bạn'), small: true, color: seal, onTap: () => Navigator.pop(ctx, 'drop')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Đóng')))],
      ),
    );
    if (!mounted) return;
    if (pick == 'view') {
      final e = _rows[f.row];
      if (e == null) {
        _toast(tr('{fName} chưa có trên bảng xếp hạng.', {'fName': f.name}));
      } else {
        await showHeroCard(context, e);
      }
      if (mounted) setState(() {});
    } else if (pick == 'drop') {
      h.removeFriend(f.row);
      await SaveService.instance.save();
      if (mounted) setState(() {});
    }
  }
}
