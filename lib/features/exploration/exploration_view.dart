// 探索準備、実行中、GPS表示、振り返りを描画するView群。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_models.dart';
import '../journal/journal_view_model.dart';
import '../observation/capture_view.dart';
import '../observation/observation_view_model.dart';
import '../shared/presentation.dart';
import 'exploration_view_model.dart';
import 'gps_status_view_model.dart';

/// 安全確認と位置記録の同意を受け取る探索準備画面。
class ExplorationPrepView extends ConsumerWidget {
  const ExplorationPrepView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explorationViewModelProvider);
    return AppPage(
      title: '探索の準備',
      child: PagePadding(
        child: ListView(
          children: [
            const Eyebrow('今日の小さな誘い'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFE5ECD9),
                      child: Icon(Icons.eco_outlined, color: Color(0xFF526B50)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '葉っぱの食べあとを\n探してみよう',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '虫そのものを見つけなくても大丈夫。葉の形や色の違いを、静かに見てみましょう。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const InfoRow(
              icon: Icons.schedule,
              title: '5〜15分を目安に',
              body: '30分で自動的に記録を終了します',
            ),
            const InfoRow(
              icon: Icons.location_searching,
              title: '探索中だけ位置を記録',
              body: '正確な座標や経路地図は表示しません',
            ),
            const InfoRow(
              icon: Icons.health_and_safety_outlined,
              title: '生き物には触れない',
              body: '道や立入り可能な場所から観察します',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: state.safetyAccepted,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                '安全案内と位置記録を確認しました',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onChanged: (value) => ref
                  .read(explorationViewModelProvider.notifier)
                  .setSafetyAccepted(value ?? false),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: !state.safetyAccepted || state.busy
                  ? null
                  : () async {
                      final started = await ref
                          .read(explorationViewModelProvider.notifier)
                          .start();
                      if (started && context.mounted) {
                        context.go('/exploration/active');
                      }
                    },
              icon: state.busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.directions_walk),
              label: const Text('探索を始める'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 探索の時間・概算距離・写真数と操作を表示する画面。
class ExplorationView extends ConsumerWidget {
  const ExplorationView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explorationViewModelProvider);
    final observations = ref.watch(observationViewModelProvider).observations;
    final exploration = state.exploration;
    if (exploration == null) {
      return const AppPage(child: Center(child: CircularProgressIndicator()));
    }
    final paused = exploration.phase == ExplorationPhase.paused;
    return PopScope(
      canPop: false,
      child: AppPage(
        title: '探索中',
        child: PagePadding(
          child: Column(
            children: [
              const GpsStatusView(),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      const Text('探索時間'),
                      const SizedBox(height: 4),
                      Text(
                        formatDuration(exploration.elapsedSeconds),
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 46,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const Divider(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Metric(
                            icon: Icons.directions_walk,
                            value: '約 ${exploration.distanceMeters.round()}m',
                          ),
                          _Metric(
                            icon: Icons.photo_camera_outlined,
                            value: '${observations.length}枚',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.eco_outlined,
                size: 48,
                color: Color(0xFF7D9471),
              ),
              const SizedBox(height: 16),
              Text(
                '足もとや葉のふちを、\nゆっくり見てみよう',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '立ち止まるときは、周りの人や自転車にも気をつけて。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (observations.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7ECDF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF526B50),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${observations.length}件の観察を記録しました',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => ref
                                .read(explorationViewModelProvider.notifier)
                                .togglePause(),
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(paused ? '再開' : '一時停止'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CaptureView(enabled: !paused && !state.busy),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: observations.isEmpty || state.busy
                    ? null
                    : () async {
                        final completed = await ref
                            .read(explorationViewModelProvider.notifier)
                            .stop();
                        if (completed != null && context.mounted) {
                          context.go('/review');
                        }
                      },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('探索を終了する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正確な座標を出さずに、位置記録中かどうかだけを示すView。
class GpsStatusView extends ConsumerWidget {
  const GpsStatusView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gps = ref.watch(gpsStatusViewModelProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: gps.paused ? const Color(0xFFF0E5D4) : const Color(0xFFE1EADF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gps.paused ? Icons.location_disabled : Icons.my_location,
            size: 16,
            color: const Color(0xFF526B50),
          ),
          const SizedBox(width: 8),
          Text(
            gps.paused ? '位置記録を一時停止中' : 'クエスト中の位置を記録中',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// AIモック確認の結果と日記保存導線を表示する画面。
class ReviewView extends ConsumerStatefulWidget {
  const ReviewView({super.key});
  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView> {
  bool requested = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!requested) {
        requested = true;
        ref.read(observationViewModelProvider.notifier).classify();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(observationViewModelProvider);
    final pending =
        state.classifying ||
        state.observations.any(
          (item) => item.classification == ClassificationStatus.pending,
        );
    final usable = state.observations
        .where((item) => item.classification == ClassificationStatus.usable)
        .length;
    final uncertain = state.observations
        .where(
          (item) => item.classification == ClassificationStatus.indeterminate,
        )
        .length;
    return AppPage(
      title: '探索のふり返り',
      child: PagePadding(
        child: Column(
          children: [
            const Spacer(),
            CompanionArt(changing: !pending, size: 290),
            const SizedBox(height: 24),
            if (pending) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                '見つけたものを、\nまとめて振り返っています',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '種名や点数ではなく、観察した特徴を確認します。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              const Eyebrow('確認できました'),
              const SizedBox(height: 10),
              Text(
                '見つけた特徴が、\nミドリの模様になりました',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                children: [
                  Chip(label: Text('観察 ${state.observations.length}件')),
                  Chip(label: Text('利用可能 $usable件')),
                  if (uncertain > 0)
                    Chip(label: Text('判別困難 $uncertain件・失敗ではありません')),
                ],
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: pending
                  ? null
                  : () async {
                      final saved = await ref
                          .read(journalViewModelProvider.notifier)
                          .saveCurrent();
                      if (saved && context.mounted) context.go('/journal');
                    },
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('自然日記に残す'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF526B50)),
      const SizedBox(width: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
