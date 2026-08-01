import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../app/router/app_router.dart';
import '../app/theme/app_widgets.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _pageIndex = 0;
  static const _pages = [
    _OnboardingPage(Icons.location_on_rounded, 'Find your next moment', 'Discover gatherings, conversations, and experiences happening around you.'),
    _OnboardingPage(Icons.groups_rounded, 'Meet people naturally', 'Connect with people who share your curiosity, interests, and energy.'),
    _OnboardingPage(Icons.auto_awesome_rounded, 'Make every plan count', 'Turn a free evening into a memory worth keeping with Conexo.'),
  ];

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _next() {
    if (_pageIndex == _pages.length - 1) { Navigator.of(context).pushReplacement(AppRouter.slideRoute(const LoginScreen())); return; }
    _controller.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(children: [
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pushReplacement(AppRouter.slideRoute(const LoginScreen())), child: const Text('Skip'))),
        Expanded(child: PageView.builder(controller: _controller, itemCount: _pages.length, onPageChanged: (index) => setState(() => _pageIndex = index), itemBuilder: (_, index) => _pages[index])),
        SmoothPageIndicator(controller: _controller, count: _pages.length, effect: const ExpandingDotsEffect(activeDotColor: Color(0xFF9D82FF), dotColor: Color(0xFF36405E), dotHeight: 8, dotWidth: 8)),
        const SizedBox(height: 28),
        ConexoButton(label: _pageIndex == _pages.length - 1 ? 'Get started' : 'Continue', onPressed: _next),
      ]),
    )),
  );
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(height: 150, width: 150, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF714EEA), Color(0xFF19B7D9)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: Color(0x66714EEA), blurRadius: 42, spreadRadius: 6)]), child: Icon(icon, size: 68, color: Colors.white)),
    const SizedBox(height: 54),
    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 16),
    Text(description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55, color: const Color(0xFFAFB8D4))),
  ])));
}
