// 探索終了前の確認を、実行中画面と一時停止画面で共通化する。
import 'package:flutter/material.dart';

/// 観察件数にかかわらず、探索を終了する意思をユーザーへ確認する。
Future<bool> confirmExplorationStop(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('探索を終了しますか？'),
        content: const Text('終了すると位置記録を停止し、今回の探索を振り返ります。'),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('いいえ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('はい'),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;
