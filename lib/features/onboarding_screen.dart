import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  late final AnimationController _ambientController;
  int _pageIndex = 0;

  static const _pages = [
    _OnboardingData(
      title: 'Meet Amazing People',
      subtitle:
          'Discover genuine people around you through shared interests and real-world experiences.',
      type: _IllustrationType.people,
    ),
    _OnboardingData(
      title: 'Find People Near You',
      subtitle: 'Coffee, music, shared walks, and new conversations.',
      type: _IllustrationType.city,
    ),
    _OnboardingData(
      title: 'Create Real Connections',
      subtitle:
          'Turn strangers into lifelong friends. Join communities. Build memories.',
      type: _IllustrationType.connections,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _next() {
    if (_pageIndex == _pages.length - 1) {
      Navigator.of(
        context,
      ).pushReplacement(AppRouter.slideRoute(const LoginScreen()));
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  void _skip() {
    Navigator.of(
      context,
    ).pushReplacement(AppRouter.slideRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF090B14)),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _OnboardingBackgroundPainter(
                    _ambientController.value,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD4DAED),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          final page = _pageController.hasClients
                              ? _pageController.page ?? _pageIndex.toDouble()
                              : _pageIndex.toDouble();
                          return PageView.builder(
                            controller: _pageController,
                            itemCount: _pages.length,
                            onPageChanged: (index) =>
                                setState(() => _pageIndex = index),
                            itemBuilder: (context, index) => _OnboardingPage(
                              data: _pages[index],
                              pageOffset: index - page,
                              ambientProgress: _ambientController.value,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          children: [
                            _PremiumPageIndicator(
                              count: _pages.length,
                              currentIndex: _pageIndex,
                            ),
                            const SizedBox(height: 26),
                            _OnboardingButton(
                              label: _pageIndex == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Continue',
                              onPressed: _next,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.pageOffset,
    required this.ambientProgress,
  });

  final _OnboardingData data;
  final double pageOffset;
  final double ambientProgress;

  @override
  Widget build(BuildContext context) {
    final visibility = (1 - pageOffset.abs() * .42).clamp(0.0, 1.0);
    final textOffset = pageOffset * -32;
    return Opacity(
      opacity: visibility,
      child: Transform.translate(
        offset: Offset(textOffset, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(pageOffset * 54, 0),
                    child: _PremiumIllustration(
                      type: data.type,
                      floatProgress: ambientProgress,
                    ),
                  ),
                  const SizedBox(height: 52),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB8C1DA),
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumIllustration extends StatelessWidget {
  const _PremiumIllustration({required this.type, required this.floatProgress});

  final _IllustrationType type;
  final double floatProgress;

  @override
  Widget build(BuildContext context) {
    final floatY = math.sin(floatProgress * math.pi * 2) * 4;
    return Transform.translate(
      offset: Offset(0, floatY),
      child: SizedBox(
        height: 250,
        width: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 204,
              width: 204,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: .34),
                    const Color(0xFF7C3AED).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            if (type == _IllustrationType.people) const _PeopleIllustration(),
            if (type == _IllustrationType.city) const _CityIllustration(),
            if (type == _IllustrationType.connections)
              const _ConnectionsIllustration(),
          ],
        ),
      ),
    );
  }
}

class _PeopleIllustration extends StatelessWidget {
  const _PeopleIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const _GlassPanel(width: 190, height: 132),
      const Positioned(
        top: 42,
        left: 62,
        child: _Portrait(name: 'M', color: Color(0xFFE879A9)),
      ),
      const Positioned(
        top: 64,
        right: 60,
        child: _Portrait(name: 'J', color: Color(0xFF22D3EE)),
      ),
      Positioned(
        bottom: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2440).withValues(alpha: .92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFFF719E)),
              SizedBox(width: 7),
              Text(
                'A shared spark',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _CityIllustration extends StatelessWidget {
  const _CityIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const _GlassPanel(width: 204, height: 148),
      Positioned(
        bottom: 48,
        left: 65,
        child: _Building(height: 66, width: 31, color: const Color(0xFF7856CF)),
      ),
      Positioned(
        bottom: 48,
        left: 103,
        child: _Building(height: 92, width: 42, color: const Color(0xFF278EAA)),
      ),
      Positioned(
        bottom: 48,
        right: 63,
        child: _Building(height: 54, width: 30, color: const Color(0xFFD16391)),
      ),
      const Positioned(top: 4, right: 38, child: _EventPill()),
      const Positioned(bottom: 23, child: _ConnectionLine()),
    ],
  );
}

class _ConnectionsIllustration extends StatelessWidget {
  const _ConnectionsIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const _GlassPanel(width: 208, height: 142),
      const Positioned(
        top: 38,
        left: 63,
        child: _Portrait(name: 'A', color: Color(0xFF8B5CF6)),
      ),
      const Positioned(
        top: 43,
        right: 60,
        child: _Portrait(name: 'S', color: Color(0xFFF472A8)),
      ),
      const Positioned(
        bottom: 32,
        child: _Portrait(name: 'K', color: Color(0xFF22D3EE)),
      ),
      const Positioned(top: 82, child: _ConnectionLine()),
    ],
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .14),
          Colors.white.withValues(alpha: .035),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          blurRadius: 26,
          offset: const Offset(0, 14),
        ),
      ],
    ),
  );
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    width: 62,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [color, const Color(0xFF171D35)]),
      border: Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .35), blurRadius: 18),
      ],
    ),
    child: Center(
      child: Text(
        name,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _Building extends StatelessWidget {
  const _Building({
    required this.height,
    required this.width,
    required this.color,
  });
  final double height;
  final double width;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .75),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
  );
}

class _EventPill extends StatelessWidget {
  const _EventPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF1B243E),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFF5AE1F5).withValues(alpha: .45)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF6AE5F6)),
        SizedBox(width: 4),
        Text(
          'Tonight',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine();
  @override
  Widget build(BuildContext context) => Container(
    height: 2,
    width: 78,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFFFC6B9D)]),
    ),
  );
}

class _PremiumPageIndicator extends StatelessWidget {
  const _PremiumPageIndicator({
    required this.count,
    required this.currentIndex,
  });
  final int count;
  final int currentIndex;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      count,
      (index) => AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        height: 9,
        width: index == currentIndex ? 34 : 9,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: index == currentIndex
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
                )
              : null,
          color: index == currentIndex ? null : const Color(0xFF53607D),
        ),
      ),
    ),
  );
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF8051E6), Color(0xFF248FBC)],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: .22),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              label,
              key: ValueKey(label),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: .1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OnboardingBackgroundPainter extends CustomPainter {
  const _OnboardingBackgroundPainter(this.progress);
  final double progress;
  static const _particles = [
    Offset(.08, .2),
    Offset(.2, .68),
    Offset(.38, .12),
    Offset(.58, .78),
    Offset(.76, .27),
    Offset(.91, .61),
    Offset(.48, .48),
    Offset(.26, .92),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * math.pi * 2;
    _blob(
      canvas,
      Offset(size.width * (.12 + math.sin(time * .4) * .04), size.height * .18),
      size.width * .58,
      const Color(0xFF7C3AED).withValues(alpha: .19),
    );
    _blob(
      canvas,
      Offset(
        size.width * .88,
        size.height * (.68 + math.cos(time * .33) * .05),
      ),
      size.width * .62,
      const Color(0xFF22D3EE).withValues(alpha: .11),
    );
    _blob(
      canvas,
      Offset(size.width * (.5 + math.sin(time * .24) * .05), size.height * .98),
      size.width * .43,
      const Color(0xFFFF4D8D).withValues(alpha: .08),
    );
    final paint = Paint()..color = Colors.white.withValues(alpha: .065);
    for (var index = 0; index < _particles.length; index++) {
      final item = _particles[index];
      canvas.drawCircle(
        Offset(
          item.dx * size.width + math.sin(time * .35 + index) * 5,
          item.dy * size.height + math.cos(time * .26 + index) * 7,
        ),
        index.isEven ? 1.2 : .8,
        paint,
      );
    }
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.type,
  });
  final String title;
  final String subtitle;
  final _IllustrationType type;
}

enum _IllustrationType { people, city, connections }
