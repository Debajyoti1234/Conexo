import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

/// Welcome + onboarding in one screen: a full-bleed hero with three short,
/// auto-advancing beats that explain how Conexo is different.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _beats = [
    (
      'Fewer swipes.',
      'Better stories.',
      'Profiles run on prompts, not just pics — so you always know what to say first.',
    ),
    (
      'Like the',
      'little things.',
      'Tap the heart on the photo or prompt that got you. Add a line and stand out.',
    ),
    (
      'Make it',
      'a plan.',
      'Chai this Saturday? We nudge good chats off the screen and into real life.',
    ),
  ];

  final _page = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_page.hasClients) return;
      _page.animateToPage(
        (_index + 1) % _beats.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Hero photo, fading into the page.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * .54,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .55, .96],
              ).createShader(r),
              // Clip the slow zoom so it never spills past the fade mask.
              child: ClipRect(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.12, end: 1),
                  duration: const Duration(milliseconds: 2400),
                  curve: Curves.easeOutCubic,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Image.asset(
                    'assets/images/people/hero.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, .1),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Reveal(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConexoMark(size: 30),
                          SizedBox(width: 6),
                          ConexoWordmark(size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Full-bleed so beats slide across the whole screen, not the gutter.
                SizedBox(
                  height: 190,
                  child: PageView.builder(
                    controller: _page,
                    itemCount: _beats.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final b = _beats[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.$1, style: ConexoType.display(c.ink, size: 44)),
                            GradientText(b.$2, style: ConexoType.display(c.ink, size: 44)),
                            const SizedBox(height: 14),
                            Text(b.$3, style: ConexoType.body(c.inkSoft, size: 15.5)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < _beats.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 6),
                          height: 6,
                          width: i == _index ? 26 : 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: i == _index ? c.ink : c.line,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    index: 2,
                    child: CxButton(
                      label: 'Create account',
                      onTap: () => Navigator.of(context).push(cxRoute(const SignUpScreen())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Reveal(
                    index: 3,
                    child: CxButton(
                      label: 'I already have one',
                      variant: CxButtonVariant.soft,
                      onTap: () => Navigator.of(context).push(cxRoute(const SignInScreen())),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'By continuing you agree to our Terms and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: ConexoType.body(c.inkMute, size: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
