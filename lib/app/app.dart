// 画面ルートと全画面共通テーマだけを定義し、機能ロジックは各ViewModelへ委譲する。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/exploration/exploration_view.dart';
import '../features/home/home_view.dart';
import '../features/journal/journal_view.dart';
import '../features/observation/observation_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/settings/settings_view.dart';

/// アプリ内の画面遷移を一元管理するルーター。
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const OnboardingView()),
    GoRoute(path: '/home', builder: (_, _) => const HomeView()),
    GoRoute(
      path: '/exploration/prep',
      builder: (_, _) => const ExplorationPrepView(),
    ),
    GoRoute(
      path: '/exploration/active',
      builder: (_, _) => const ExplorationView(),
    ),
    GoRoute(
      path: '/observation/:id',
      builder: (_, state) =>
          ObservationView(observationId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/review', builder: (_, _) => const ReviewView()),
    GoRoute(path: '/journal', builder: (_, _) => const JournalView()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsView()),
  ],
);

/// ルーターと共通テーマを適用するルートWidget。
class SobaNoInochiApp extends StatelessWidget {
  const SobaNoInochiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'そばのいのち',
    debugShowCheckedModeBanner: false,
    routerConfig: appRouter,
    theme: buildAppTheme(),
  );
}

ThemeData buildAppTheme() {
  const ink = Color(0xFF28332B);
  const moss = Color(0xFF526B50);
  const paper = Color(0xFFF8F6EF);
  final scheme = ColorScheme.fromSeed(
    seedColor: moss,
    brightness: Brightness.light,
    surface: paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: moss,
      onPrimary: Colors.white,
      surface: paper,
      onSurface: ink,
    ),
    scaffoldBackgroundColor: paper,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'serif',
        fontSize: 25,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'serif',
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.75, color: ink),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.65,
        color: Color(0xFF626C64),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: .7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x1A526B50)),
      ),
    ),
  );
}
