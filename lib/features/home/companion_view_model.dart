// 相棒の現在状態をUIへ公開するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 相棒Repositoryの状態をViewへ公開するViewModel。
class CompanionViewModel extends Notifier<Companion> {
  @override
  Companion build() => const Companion();
  Future<void> load() async =>
      state = await ref.read(companionRepositoryProvider).load();
}

/// CompanionViewへ相棒状態を供給するProvider。
final companionViewModelProvider =
    NotifierProvider<CompanionViewModel, Companion>(CompanionViewModel.new);
