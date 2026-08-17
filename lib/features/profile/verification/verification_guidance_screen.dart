import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'three_angle_capture_screen.dart';
import 'verification_components.dart';
import 'verification_theme.dart';

/// Pre-capture guidance: a calm, premium three-page intro
/// (Get Verified → Before you begin → We'll capture 3 views) that leads into
/// the [ThreeAngleCaptureScreen]. Presentation only.
class VerificationGuidanceScreen extends StatefulWidget {
  const VerificationGuidanceScreen({super.key});

  @override
  State<VerificationGuidanceScreen> createState() =>
      _VerificationGuidanceScreenState();
}

class _VerificationGuidanceScreenState
    extends State<VerificationGuidanceScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _ctaLabels = ['Get Started', 'Proceed', "I'm ready"];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_page == 0) {
      Navigator.of(context).maybePop();
    } else {
      _controller.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _onCta() async {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final verified = await Navigator.of(context).push<bool>(
      verifyFadeSlideRoute(const ThreeAngleCaptureScreen()),
    );
    if (!mounted) return;
    if (verified == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VerifyColors.bgBottom,
      body: VerifyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: VerifyTopBar(onBack: _onBack),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [
                    _StartPage(),
                    _InstructionsPage(),
                    _AngleOverviewPage(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: const ExpandingDotsEffect(
                  dotHeight: 7,
                  dotWidth: 7,
                  expansionFactor: 3.4,
                  spacing: 6,
                  activeDotColor: VerifyColors.accent,
                  dotColor: Color(0x33FFFFFF),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: VerifyCta(label: _ctaLabels[_page], onTap: _onCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 1 — Get Verified ────────────────────────────────────────────────────

class _StartPage extends StatelessWidget {
  const _StartPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      children: [
        const SizedBox(height: 8),
        Center(
          child: VerifyGlowBadge(
            size: 116,
            glowStrength: .4,
            colors: [
              VerifyColors.accent.withValues(alpha: .95),
              VerifyColors.accent2.withValues(alpha: .8),
            ],
            child: VerifyGlyph(VerifyAsset.shieldFace,
                size: 58, color: Colors.white),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Get Verified',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: VerifyColors.text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Verify your identity with\nthree quick selfies.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: VerifyColors.soft),
        ),
        const SizedBox(height: 28),
        const _BenefitRow(
          asset: VerifyAsset.privacy,
          title: 'Secure & Private',
          body: 'Your photos are used only to verify you and are never shared.',
        ),
        const SizedBox(height: 14),
        const _BenefitRow(
          asset: VerifyAsset.expression,
          title: 'Quick & Easy',
          body: 'Takes less than a minute.',
        ),
        const _BenefitRowSpacer(),
        const _BenefitRow(
          asset: VerifyAsset.shieldCheck,
          title: 'High Accuracy',
          body: "Three angles help us confirm it's really you.",
        ),
      ],
    );
  }
}

class _BenefitRowSpacer extends StatelessWidget {
  const _BenefitRowSpacer();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 14);
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.asset,
    required this.title,
    required this.body,
  });

  final String asset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VerifyGlowBadge(
          size: 42,
          glowStrength: .28,
          colors: [
            VerifyColors.accent.withValues(alpha: .28),
            VerifyColors.accent2.withValues(alpha: .18),
          ],
          glowColor: VerifyColors.accent,
          child: VerifyGlyph(asset, size: 20, color: VerifyColors.accentSoft),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: VerifyColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: VerifyColors.soft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Page 2 — Before you begin ────────────────────────────────────────────────

class _InstructionsPage extends StatelessWidget {
  const _InstructionsPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        const _PageHeader(
          title: 'Before you begin',
          subtitle: 'Follow these simple steps for the best results.',
        ),
        const SizedBox(height: 18),
        const VerifyInstructionCard(
          asset: VerifyAsset.distance,
          title: 'Distance',
          body: 'Keep your face about 3–4 feet from the camera.',
        ),
        const SizedBox(height: 10),
        const VerifyInstructionCard(
          asset: VerifyAsset.lighting,
          title: 'Lighting',
          body: 'Use clear, even lighting. Avoid strong backlight.',
        ),
        const SizedBox(height: 10),
        const VerifyInstructionCard(
          asset: VerifyAsset.eyes,
          title: 'Eyes',
          body: 'Keep both eyes open and clearly visible.',
        ),
        const SizedBox(height: 10),
        const VerifyInstructionCard(
          asset: VerifyAsset.glasses,
          title: 'Glasses',
          body: 'Remove dark glasses or anything covering your eyes.',
        ),
        const SizedBox(height: 10),
        const VerifyInstructionCard(
          asset: VerifyAsset.background,
          title: 'Background',
          body: 'Choose a simple, uncluttered background.',
        ),
        const SizedBox(height: 10),
        const VerifyInstructionCard(
          asset: VerifyAsset.expression,
          title: 'Expression',
          body: 'Use a natural expression. Avoid extreme angles.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            VerifyGlyph(VerifyAsset.privacy,
                size: 18, color: VerifyColors.muted),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Your photos are used only for verification and are never shared.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: VerifyColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Page 3 — We'll capture 3 views ───────────────────────────────────────────

class _AngleOverviewPage extends StatelessWidget {
  const _AngleOverviewPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      children: [
        const _PageHeader(
          title: "We'll capture 3 views",
          subtitle: 'These views help us verify you accurately.',
        ),
        const SizedBox(height: 18),
        const VerifyAnglePreviewCard(angle: VerifyAngle.front),
        const SizedBox(height: 12),
        const VerifyAnglePreviewCard(angle: VerifyAngle.left),
        const SizedBox(height: 12),
        const VerifyAnglePreviewCard(angle: VerifyAngle.right),
        const SizedBox(height: 16),
        Row(
          children: [
            VerifyGlyph(VerifyAsset.shieldCheck,
                size: 18, color: VerifyColors.accentSoft),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Make sure your face is clearly visible in all three views.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: VerifyColors.soft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: VerifyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: VerifyColors.soft,
          ),
        ),
      ],
    );
  }
}
