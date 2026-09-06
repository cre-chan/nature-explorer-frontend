// 保存された探索を座標なしの要約として表示する日記View。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_models.dart';
import '../shared/presentation.dart';
import 'journal_view_model.dart';

/// 完了した探索を座標なしのカードで一覧表示する画面。
class JournalView extends ConsumerStatefulWidget {
  const JournalView({super.key});
  @override
  ConsumerState<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends ConsumerState<JournalView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(journalViewModelProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalViewModelProvider);
    return AppPage(
      showBottomNav: true,
      currentIndex: 1,
      child: PagePadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('記録'),
            const SizedBox(height: 4),
            Text('自然と相棒の歩み', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.entries.isEmpty
                  ? _EmptyJournal(onExplore: () => context.go('/home'))
                  : ListView.separated(
                      itemCount: state.entries.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == state.entries.length) {
                          return const _CompanionHistory();
                        }
                        return _JournalCard(
                          entry: state.entries[index],
                          number: state.entries.length - index,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.entry, required this.number});
  final JournalEntry entry;
  final int number;
  @override
  Widget build(BuildContext context) {
    final observation = entry.observations.isEmpty
        ? null
        : entry.observations.last;
    final date = entry.savedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (observation != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.file(
                    File(observation.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE3E9DA),
                      child: const Icon(Icons.eco_outlined),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日・$number回目の探索',
                  style: const TextStyle(
                    color: Color(0xFF526B50),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${date.month}/${date.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.observations.length}つの小さな発見',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (observation?.note.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '「${observation!.note}」',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Summary(
                  icon: Icons.schedule,
                  value: formatDuration(entry.exploration.elapsedSeconds),
                  label: '探索時間',
                ),
                _Summary(
                  icon: Icons.directions_walk,
                  value: '約${entry.exploration.distanceMeters.round()}m',
                  label: '移動距離',
                ),
                _Summary(
                  icon: Icons.photo_camera_outlined,
                  value: '${entry.observations.length}枚',
                  label: '写真',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE7ECDF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF526B50)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ミドリに葉脈のような淡い模様が増えました',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 19, color: const Color(0xFF526B50)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.eco_outlined, size: 72, color: Color(0xFF8CA47E)),
        const SizedBox(height: 16),
        Text('まだ白い日記です', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '最初の探索を終えると、\n自然と相棒の記録がここに残ります。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onExplore,
          icon: const Icon(Icons.home_outlined),
          label: const Text('ホームへ戻る'),
        ),
      ],
    ),
  );
}

class _CompanionHistory extends StatelessWidget {
  const _CompanionHistory();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CompanionArt(changing: true, size: 130),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('この相棒の歩み'),
                Text('ミドリ', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '見つけた自然が、少しずつ模様に残っています。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
