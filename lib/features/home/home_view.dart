// 相棒と今日の探索導線を描画するホーム画面。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_models.dart';
import '../shared/presentation.dart';
import 'companion_view_model.dart';
import 'home_view_model.dart';

/// 相棒と探索開始導線を表示するホーム画面。
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});
  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  bool open = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeViewModelProvider.notifier).load();
      ref.read(companionViewModelProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    return AppPage(
      showBottomNav: true,
      currentIndex: 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF3F2E8), Color(0xFFDDE8DA)],
                ),
              ),
            ),
          ),
          PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Eyebrow('そばのいのち'),
                const SizedBox(height: 2),
                Text('ミドリ', style: Theme.of(context).textTheme.headlineMedium),
                Expanded(
                  child: Center(
                    child: CompanionView(
                      changing:
                          state.companion.stage == CompanionStage.changing,
                    ),
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 84,
            height: open ? 310 : 82,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => open = !open),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFBBC6B4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow('今日の小さな誘い'),
                                  Text(
                                    '葉っぱの食べあとを探してみよう',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontFamily: 'serif',
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              open
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                            ),
                          ],
                        ),
                        if (open) ...[
                          const SizedBox(height: 18),
                          Text(
                            'ゆっくり歩いて、5〜15分。\n見つからない日も観察です。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(homeViewModelProvider.notifier)
                                  .prepareNewExploration();
                              if (context.mounted) {
                                context.go('/exploration/prep');
                              }
                            },
                            icon: const Icon(Icons.explore_outlined),
                            label: Text(
                              state.journalCount > 0 ? 'もう一度、探索を始める' : '探索を始める',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CompanionViewModelの状態を相棒イラストと短い言葉へ変換するView。
class CompanionView extends ConsumerWidget {
  const CompanionView({required this.changing, super.key});
  final bool changing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companion = ref.watch(companionViewModelProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompanionArt(
          changing: companion.stage == CompanionStage.changing || changing,
          size: 330,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            companion.stage == CompanionStage.changing ? '変化の兆し' : '幼体・出会って3日目',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          companion.stage == CompanionStage.changing
              ? '「見つけた模様が、からだに残っているよ」'
              : '「葉っぱに、食べたあとがあるかもしれない」',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
