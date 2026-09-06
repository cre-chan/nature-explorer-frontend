// プライバシー設定と全データ削除の操作を提供するView。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/presentation.dart';
import 'settings_view_model.dart';

/// 通知・位置記録設定と全データ削除を提供する画面。
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});
  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(settingsViewModelProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);
    return AppPage(
      showBottomNav: true,
      currentIndex: 2,
      child: PagePadding(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const Eyebrow('設定'),
                  const SizedBox(height: 4),
                  Text(
                    '自分のペースで使う',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 22),
                  Text('通知', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('小さな探索の誘い'),
                          subtitle: const Text('週2回まで・夜間は通知しません'),
                          value: state.settings.explorationInvites,
                          onChanged: (value) => ref
                              .read(settingsViewModelProvider.notifier)
                              .setInvites(value),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('成長と旅立ち'),
                          subtitle: const Text('重要な変化だけを知らせます'),
                          value: state.settings.growthNotifications,
                          onChanged: (value) => ref
                              .read(settingsViewModelProvider.notifier)
                              .setGrowth(value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '位置情報とデータ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('クエスト中の位置記録'),
                          subtitle: const Text('クエスト外では記録しません'),
                          value: state.settings.locationTracking,
                          onChanged: (value) => ref
                              .read(settingsViewModelProvider.notifier)
                              .setLocation(value),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.shield_outlined),
                          title: Text('記録されるデータ'),
                          subtitle: Text('写真・観察回答・クエスト中の経路'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECDF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF526B50),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'この試作ではデータを外部へ送信しません。正確な座標は表示せず、設定から端末内データを削除できます。',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: state.deleting
                        ? null
                        : () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('すべてのデータを削除'),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('端末内データを削除しますか？'),
        content: const Text('写真、日記、位置履歴、相棒の歩み、同意内容を削除します。元には戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ref
        .read(settingsViewModelProvider.notifier)
        .deleteAll();
    if (deleted && context.mounted) context.go('/');
  }
}
