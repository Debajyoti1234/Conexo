import 'dart:async';

import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import '../app/theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _pages = [
    _EntryPageData(
      heroAsset: 'assets/images/onboarding/people_intro.webp',
      headlineLine1: 'Meet people.',
      headlineLine2: 'Closer to you.',
      supportingCopy:
          'Discover people around you and find connections that feel natural.',
    ),
    _EntryPageData(
      heroAsset: 'assets/images/onboarding/plan_intro.webp',
      headlineLine1: 'Make plans.',
      headlineLine2: 'Make moments.',
      supportingCopy:
          'Find something happening nearby or create a moment of your own.',
    ),
    _EntryPageData(
      heroAsset: 'assets/images/onboarding/connection_intro.webp',
      headlineLine1: 'More than a profile.',
      headlineLine2: 'Real connections.',
      supportingCopy:
          'Connect around shared interests, conversations and moments.',
    ),
  ];

  static const _autoAdvanceInterval = Duration(seconds: 5);
  static const _autoAdvanceInitialDelay = Duration(milliseconds: 50);

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _startAutoTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer(_autoAdvanceInitialDelay, () {
      if (!mounted) return;
      _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
        if (!mounted) return;
        if (_pageController.hasClients) {
          final nextPage = (_pageIndex + 1) % _pages.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    });
  }

  void _restartAutoTimer() {
    if (!mounted) return;
    _startAutoTimer();
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _pageIndex = index);
    _restartAutoTimer();
  }

  void _goToCreateAccount() {
    Navigator.of(context).push(AppRouter.slideRoute(const SignupScreen()));
  }

  void _goToLogin() {
    Navigator.of(context).push(AppRouter.slideRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.cxCanvas),
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _autoTimer?.cancel();
              } else if (notification is ScrollEndNotification) {
                _restartAutoTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _EntryPage(
                data: _pages[index],
                pageIndex: index,
                currentPage: _pageIndex,
                pageController: _pageController,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageIndicators(
                      count: _pages.length,
                      currentIndex: _pageIndex,
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      label: 'Create account',
                      onPressed: _goToCreateAccount,
                    ),
                    const SizedBox(height: 14),
                    _SecondaryButton(
                      label: 'I already have one',
                      onPressed: _goToLogin,
                    ),
                    const SizedBox(height: 16),
                    _FooterLogo(),
                    const SizedBox(height: 12),
                    _TermsFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryPage extends StatelessWidget {
  const _EntryPage({
    required this.data,
    required this.pageIndex,
    required this.currentPage,
    required this.pageController,
  });

  final _EntryPageData data;
  final int pageIndex;
  final int currentPage;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final pageOffset = pageController.hasClients
        ? pageIndex - (pageController.page ?? currentPage.toDouble())
        : (pageIndex - currentPage).toDouble();

    final visibility = (1 - pageOffset.abs() * 0.3).clamp(0.0, 1.0);
    final textOffset = pageOffset * -24;
    final heroHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Static hero image - no transform during swipe
        _HeroImage(asset: data.heroAsset),
        // Static gradient - no transform during swipe
        _GradientMask(),
        // Hero text - only this moves during swipe
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: heroHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Opacity(
                opacity: visibility,
                child: Transform.translate(
                  offset: Offset(textOffset, 0),
                  child: _HeroText(
                    line1: data.headlineLine1,
                    line2: data.headlineLine2,
                    supportingCopy: data.supportingCopy,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Page content below hero (for scrolling on small screens)
        Positioned(
          top: heroHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryPageData {
  const _EntryPageData({
    required this.heroAsset,
    required this.headlineLine1,
    required this.headlineLine2,
    required this.supportingCopy,
  });

  final String heroAsset;
  final String headlineLine1;
  final String headlineLine2;
  final String supportingCopy;
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: Colors.red.withValues(alpha: 0.3),
            child: Center(
              child: Text(
                'Failed to load: $asset\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientMask extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final light = context.isLightTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: light
                ? [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.transparent,
                    context.cxCanvas.withValues(alpha: 0.05),
                    context.cxCanvas.withValues(alpha: 0.2),
                    context.cxCanvas.withValues(alpha: 0.5),
                    context.cxCanvas,
                  ]
                : [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.transparent,
                    context.cxCanvas.withValues(alpha: 0.1),
                    context.cxCanvas.withValues(alpha: 0.4),
                    context.cxCanvas.withValues(alpha: 0.8),
                    context.cxCanvas,
                  ],
            stops: const [0.0, 0.25, 0.45, 0.6, 0.75, 0.9, 1.0],
          ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({
    required this.line1,
    required this.line2,
    required this.supportingCopy,
  });

  final String line1;
  final String line2;
  final String supportingCopy;

  @override
  Widget build(BuildContext context) {
    final light = context.isLightTheme;
    final accentGradient = LinearGradient(
      colors: light
          ? [AppPalette.ink, const Color(0xFF6A3FBF)]
          : [const Color(0xFFB7A5FF), const Color(0xFF8B5CF6)],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            line1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.6,
              color: context.cxInk,
            ),
          ),
          const SizedBox(height: 2),
          ShaderMask(
            shaderCallback: (bounds) => accentGradient.createShader(bounds),
            child: Text(
              line2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 42,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -0.6,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            supportingCopy,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: context.cxSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/logo/conexo_logo2.png',
          height: 22,
          width: 22,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 6),
        Text(
          'conexo',
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.cxInk.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive ? context.cxAccent : context.cxLine,
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final light = context.isLightTheme;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: light
              ? LinearGradient(
                  colors: [context.cxInk, context.cxInk],
                )
              : LinearGradient(
                  colors: [
                    context.cxAccent,
                    context.cxAccent,
                    context.cxAccentSoft,
                  ],
                ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (light ? context.cxInk : context.cxAccent)
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final light = context.isLightTheme;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.cxSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: context.cxInk.withValues(alpha: light ? 0.15 : 0.25),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: context.cxInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          height: 1.4,
          color: context.cxMuted,
        ),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms',
            style: TextStyle(
              color: context.cxInk,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: context.cxInk.withValues(alpha: 0.3),
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: context.cxInk,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: context.cxInk.withValues(alpha: 0.3),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}