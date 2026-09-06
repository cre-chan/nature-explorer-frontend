// 中断された探索を、位置記録を再開せずに明示的なユーザー操作まで保持するView。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/presentation.dart';
import 'exploration_stop_dialog.dart';
import 'exploration_view_model.dart';

/// 位置停止状態と再開・終了の選択だけを示す専用画面。
class PausedExplorationView extends ConsumerWidget {
  const PausedExplorationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(explorationViewModelProvider);
    final exploration = state.exploration;
    if (exploration == null) {
      return AppPage(
        child: Center(
          child: FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('ホームへ戻る'),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: AppPage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_disabled,
                  size: 120,
                  color: Color(0xFF526B50),
                ),
                const SizedBox(height: 24),
                Text(
                  '位置記録を停止しています',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final resumed = await ref
                              .read(explorationViewModelProvider.notifier)
                              .togglePause();
                          if (resumed && context.mounted) {
                            context.go('/exploration/active');
                          } else if (context.mounted) {
                            final error = ref
                                .read(explorationViewModelProvider)
                                .error;
                            if (error != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(error)));
                            }
                          }
                        },
                  child: const Text('探索を再開する'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          if (!await confirmExplorationStop(context) ||
                              !context.mounted) {
                            return;
                          }
                          final completed = await ref
                              .read(explorationViewModelProvider.notifier)
                              .stop();
                          if (completed != null && context.mounted) {
                            context.go('/review');
                          } else if (context.mounted) {
                            final error = ref
                                .read(explorationViewModelProvider)
                                .error;
                            if (error != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(error)));
                            }
                          }
                        },
                  child: const Text('このまま探索を終了する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
