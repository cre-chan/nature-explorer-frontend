// 撮影済み画像に観察内容を入力するView。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/presentation.dart';
import 'observation_view_model.dart';

/// 写真を確認し、発見場所とメモを入力する画面。
class ObservationView extends ConsumerStatefulWidget {
  const ObservationView({required this.observationId, super.key});
  final String observationId;
  @override
  ConsumerState<ObservationView> createState() => _ObservationViewState();
}

class _ObservationViewState extends ConsumerState<ObservationView> {
  String foundAt = '';
  final noteController = TextEditingController();
  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(observationViewModelProvider);
    final item = ref
        .read(observationViewModelProvider.notifier)
        .find(widget.observationId);
    if (item == null) {
      return const AppPage(child: Center(child: Text('写真を読み込めませんでした')));
    }
    const choices = ['葉の上', '葉の裏', '木や樹皮', '地面の近く'];
    return AppPage(
      title: '見つけたもの',
      child: PagePadding(
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Eyebrow('撮った今、少しだけ観察'),
                Text('10秒ほど', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(item.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFE2E8D8),
                    child: const Icon(Icons.image_outlined, size: 56),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('どこで見つけましたか？', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in choices)
                  ChoiceChip(
                    label: Text(choice),
                    selected: foundAt == choice,
                    onSelected: (_) => setState(() => foundAt = choice),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('気づいたこと（任意）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLength: 120,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '例：葉のふちが、丸く少しずつ欠けていた',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: foundAt.isEmpty
                  ? null
                  : () async {
                      final saved = await ref
                          .read(observationViewModelProvider.notifier)
                          .submit(
                            widget.observationId,
                            foundAt: foundAt,
                            note: noteController.text,
                          );
                      if (saved && context.mounted) context.pop();
                    },
              icon: const Icon(Icons.check),
              label: const Text('記録して探索を続ける'),
            ),
          ],
        ),
      ),
    );
  }
}
