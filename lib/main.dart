// アプリのComposition Root。依存解決をProviderScopeへ委ねてUIを起動する。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SobaNoInochiApp()));
}
