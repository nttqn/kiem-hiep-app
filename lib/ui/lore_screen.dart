import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/lore.dart';
import '../core/realm.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Giang Hồ Ký Sự: the nine chapters, their pages found so far, and what a
/// whole chapter grants.
class LoreScreen extends StatefulWidget {
  const LoreScreen({super.key});

  @override
  State<LoreScreen> createState() => _LoreScreenState();
}

class _LoreScreenState extends State<LoreScreen> {
  HeroData get h => SaveService.instance.hero;
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final total = loreChapters.fold<int>(0, (n, c) => n + h.lorePagesOf(c.realm));
    return SubScreen(
      title: 'Giang Hồ Ký Sự',
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('$total/$lorePageCount trang', style: bold.copyWith(color: goldLight)),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: Panel(
              padding: const EdgeInsets.all(6),
              child: ListView(
                children: [
                  for (var i = 0; i < loreChapters.length; i++) _chapterTile(i),
                  const Divider(color: gold),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Trọn ${loreChapters.length} chương: danh hiệu « $loreTitle », '
                      '${loreAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', ')}',
                      style: small.copyWith(fontSize: 11, color: h.loreAllDone ? const Color(0xFF8CE07A) : creamDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _pages(loreChapters[_sel])),
        ],
      ),
    );
  }

  Widget _chapterTile(int i) {
    final c = loreChapters[i];
    final n = h.lorePagesOf(c.realm);
    final done = n >= lorePagesPer;
    final sel = i == _sel;
    return GestureDetector(
      onTap: () => setState(() => _sel = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? goldLight : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(done ? Icons.menu_book : Icons.book_outlined, size: 18, color: done ? const Color(0xFF8CE07A) : creamDim),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: bold.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(realmById[c.realm]!.name, style: small.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('$n/$lorePagesPer', style: bold.copyWith(fontSize: 12, color: done ? const Color(0xFF8CE07A) : cream)),
          ],
        ),
      ),
    );
  }

  Widget _pages(LoreChapter c) {
    final done = h.loreDone(c.realm);
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.title, style: titleStyle(22)),
          Text(
            '${realmById[c.realm]!.name} · trọn chương: ${loreBonusLabel(c.bonus, c.value)}${done ? ' (đã nhận)' : ''}',
            style: small.copyWith(color: done ? const Color(0xFF8CE07A) : goldLight),
          ),
          const Divider(color: gold),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lorePagesPer; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: h.lorePages.contains(loreKey(c.realm, i))
                          ? Text('${i + 1}. ${c.pages[i]}', style: body.copyWith(height: 1.4, fontStyle: FontStyle.italic))
                          : Text('${i + 1}. Trang chưa tìm thấy.', style: body.copyWith(color: creamDim)),
                    ),
                ],
              ),
            ),
          ),
          Text(
            'Tìm trang ở Bí cảnh (đầu lĩnh, mật thất, bia cổ, người được cứu) và Tàng Bảo Đồ.',
            style: small.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
