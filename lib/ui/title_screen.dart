import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'create_screen.dart';
import 'theme.dart';
import 'town_screen.dart';

const gameTitle = 'Kiếm Hiệp Ngũ Hành';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: SaveService.instance,
            builder: (context, _) => Column(
              children: [
                const SizedBox(height: 14),
                Text(gameTitle.toUpperCase(), style: titleStyle(34)),
                const SizedBox(height: 4),
                Text('Ngũ hành tương khắc · Ngũ phái tranh hùng',
                    style: body.copyWith(color: goldLight.withValues(alpha: 0.85))),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slotCount; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _SlotCard(index: i),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.slots[index];
    return GestureDetector(
      onTap: () => _open(context, h),
      onLongPress: h == null ? null : () => _confirmDelete(context, h),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: SizedBox(
          width: 178,
          height: 176,
          child: h == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 44, color: gold.withValues(alpha: 0.8)),
                    const SizedBox(height: 8),
                    Text('Tạo nhân vật', style: bold.copyWith(color: goldLight)),
                    Text('Ô ${index + 1}', style: small),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: FigurePreview(hanh: h.hanh, female: h.female, scale: 1.25),
                      ),
                    ),
                    Text(h.name, style: bold.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: hanhColor(h.hanh), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('${h.sect.name} · Cấp ${h.level}', style: small.copyWith(color: cream)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LButton(label: 'Vào game', small: true, onTap: () => _open(context, h)),
                  ],
                ),
        ),
      ),
    );
  }

  void _open(BuildContext context, HeroData? h) {
    if (h == null) {
      Navigator.of(context).push(fadeRoute(CreateScreen(slot: index)));
      return;
    }
    SaveService.instance.active = index;
    Navigator.of(context).pushReplacement(fadeRoute(const TownScreen()));
  }

  Future<void> _confirmDelete(BuildContext context, HeroData h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('Xóa nhân vật?', style: titleStyle(20)),
        content: Text('${h.name} (${h.sect.name}, cấp ${h.level}) sẽ bị xóa vĩnh viễn.', style: body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Color(0xFFFF7A6A))),
          ),
        ],
      ),
    );
    if (ok == true) SaveService.instance.delete(index);
  }
}
