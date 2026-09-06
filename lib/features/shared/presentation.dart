// 業務状態を持たない、複数機能で共有する表示部品。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 共通Scaffoldと任意の下部ナビゲーションを提供する画面枠。
class AppPage extends StatelessWidget {
  const AppPage({
    required this.child,
    this.title,
    this.showBottomNav = false,
    this.currentIndex = 0,
    super.key,
  });
  final Widget child;
  final String? title;
  final bool showBottomNav;
  final int currentIndex;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: title == null
        ? null
        : AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(title!),
            centerTitle: false,
          ),
    body: SafeArea(child: child),
    bottomNavigationBar: showBottomNav
        ? NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) =>
                context.go(['/home', '/journal', '/settings'][index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: '記録',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: '設定',
              ),
            ],
          )
        : null,
  );
}

/// 全機能で揃えるページ余白。
class PagePadding extends StatelessWidget {
  const PagePadding({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: child);
}

/// 小見出しを統一した字間と色で表示する部品。
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
    ),
  );
}

/// アイコン、見出し、補足文を1行にまとめる説明部品。
class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE7ECDF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 外部画像へ依存せず相棒を描画するCustomPaint部品。
class CompanionArt extends StatelessWidget {
  const CompanionArt({this.changing = false, this.size = 240, super.key});
  final bool changing;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: changing ? '変化の兆しが現れた相棒ミドリ' : 'いもむし型の相棒ミドリ',
    child: SizedBox(
      width: size,
      height: size * .7,
      child: CustomPaint(painter: _CompanionPainter(changing)),
    ),
  );
}

class _CompanionPainter extends CustomPainter {
  const _CompanionPainter(this.changing);
  final bool changing;
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = changing ? const Color(0xFF8EA66C) : const Color(0xFF9BB77D);
    final shadow = Paint()..color = const Color(0x1828332B);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .12,
        size.height * .72,
        size.width * .75,
        size.height * .12,
      ),
      shadow,
    );
    final centers = [
      Offset(size.width * .24, size.height * .54),
      Offset(size.width * .39, size.height * .48),
      Offset(size.width * .54, size.height * .5),
      Offset(size.width * .68, size.height * .44),
      Offset(size.width * .78, size.height * .38),
    ];
    for (var i = 0; i < centers.length; i++) {
      canvas.drawCircle(centers[i], size.width * (i == 4 ? .13 : .12), body);
      if (changing && i < 4) {
        canvas.drawArc(
          Rect.fromCircle(center: centers[i], radius: size.width * .075),
          -.8,
          1.7,
          false,
          Paint()
            ..color = const Color(0xFFD4C98C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }
    final eye = Paint()..color = const Color(0xFF28332B);
    canvas.drawCircle(Offset(size.width * .82, size.height * .34), 3.4, eye);
    canvas.drawCircle(Offset(size.width * .75, size.height * .32), 3.4, eye);
    final antenna = Paint()
      ..color = const Color(0xFF526B50)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .78, size.height * .25),
      Offset(size.width * .75, size.height * .12),
      antenna,
    );
    canvas.drawLine(
      Offset(size.width * .85, size.height * .25),
      Offset(size.width * .9, size.height * .13),
      antenna,
    );
  }

  @override
  bool shouldRepaint(covariant _CompanionPainter oldDelegate) =>
      oldDelegate.changing != changing;
}

/// 秒数を探索画面用のMM:SSへ変換する。
String formatDuration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
