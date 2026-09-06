// 撮影コマンドと撮影中表示だけを担当するView。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'capture_view_model.dart';

/// 撮影ボタンと撮影中状態を表示するView。
class CaptureView extends ConsumerWidget {
  const CaptureView({required this.enabled, super.key});
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureViewModelProvider);
    return FilledButton.icon(
      onPressed: !enabled || state.capturing
          ? null
          : () async {
              final item = await ref
                  .read(captureViewModelProvider.notifier)
                  .capture();
              if (item != null && context.mounted) {
                context.push('/observation/${item.id}');
              } else if (context.mounted) {
                final error = ref.read(captureViewModelProvider).error;
                if (error != null) {
                  // カメラキャンセルは通知せず、安全な画像保存に失敗した場合だけ案内する。
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              }
            },
      icon: state.capturing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.photo_camera),
      label: const Text('写真を撮る'),
    );
  }
}
