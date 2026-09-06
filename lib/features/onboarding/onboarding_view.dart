// 同意内容を表示し、ユーザー操作をOnboardingViewModelへ渡す初回画面。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/presentation.dart';
import 'onboarding_view_model.dart';

/// 初回同意と安全案内を表示する画面。
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});
  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndRedirect());
  }

  Future<void> _loadAndRedirect() async {
    await ref.read(onboardingViewModelProvider.notifier).load();
    final state = ref.read(onboardingViewModelProvider);
    if (mounted &&
        state.accepted &&
        state.error == null &&
        state.resumePath != null) {
      context.go(state.resumePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingViewModelProvider);
    if (!state.loading && state.accepted && state.error != null) {
      return AppPage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 88,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  state.error!,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _loadAndRedirect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('位置記録の停止を再試行する'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AppPage(
      child: PagePadding(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const SizedBox(height: 34),
                  const Eyebrow('そばのいのち'),
                  const SizedBox(height: 10),
                  Text(
                    '立ち止まると、\n小さないのちが見えてくる。',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '身近な虫や葉の跡を、相棒のミドリと静かに記録します。珍しいものを見つける必要はありません。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  const CompanionArt(size: 280),
                  const SizedBox(height: 12),
                  const InfoRow(
                    icon: Icons.location_searching,
                    title: '探索中だけ位置を記録',
                    body: '経路地図や正確な座標は表示しません。30分で自動終了します。',
                  ),
                  const InfoRow(
                    icon: Icons.photo_camera_outlined,
                    title: '生き物には触れない',
                    body: '立入り可能な場所から、少し離れて撮影します。',
                  ),
                  const InfoRow(
                    icon: Icons.delete_outline,
                    title: '端末内で試す',
                    body: 'この試作では外部へ送信せず、設定からすべて削除できます。',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: state.safetyChecked,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '安全案内とデータの扱いを確認しました',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('探索するときだけ位置を記録します'),
                    onChanged: (value) => ref
                        .read(onboardingViewModelProvider.notifier)
                        .setSafetyChecked(value ?? false),
                  ),
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: state.safetyChecked
                        ? () async {
                            final accepted = await ref
                                .read(onboardingViewModelProvider.notifier)
                                .accept();
                            if (accepted && context.mounted) {
                              context.go('/home');
                            }
                          }
                        : null,
                    icon: const Icon(Icons.eco_outlined),
                    label: const Text('ミドリに会う'),
                  ),
                ],
              ),
      ),
    );
  }
}
