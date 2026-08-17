import 'package:flutter/material.dart';

import 'verification_theme.dart';

/// Premium status surfaces for the verification flow: a calm processing
/// indicator, a rewarding (not childish) verified state, a soft failed state,
/// and a photo-tips helper. No confetti, no giant Material check, no cheap
/// gradients — restrained glow + subtle reveal only.

// ── Rotating verifying indicator ─────────────────────────────────────────────

class VerifyingIndicator extends StatefulWidget {
  const VerifyingIndicator({super.key, this.size = 92});

  final double size;

  @override
  State<VerifyingIndicator> createState() => _VerifyingIndicatorState();
}

class _VerifyingIndicatorState extends State<VerifyingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: VerifyColors.accent.withValues(alpha: .35),
                  blurRadius: 30,
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
          RotationTransition(
            turns: _c,
            child: Container(
              height: widget.size,
              width: widget.size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0x008B5CF6),
                    VerifyColors.accent,
                    VerifyColors.accent2,
                    Color(0x00587BE2),
                  ],
                  stops: [0.0, 0.45, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Container(
            height: widget.size - 12,
            width: widget.size - 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: VerifyColors.bgBottom,
            ),
          ),
          VerifyGlyph(VerifyAsset.shieldCheck,
              size: widget.size * .42, color: VerifyColors.accentSoft),
        ],
      ),
    );
  }
}

// ── Animated hero (glow badge + title + subtitle) ────────────────────────────

class VerifyHeroStatus extends StatefulWidget {
  const VerifyHeroStatus({
    required this.title,
    required this.subtitle,
    required this.badge,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget badge;

  @override
  State<VerifyHeroStatus> createState() => _VerifyHeroStatusState();
}

class _VerifyHeroStatusState extends State<VerifyHeroStatus> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      opacity: _in ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        scale: _in ? 1 : 0.92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.badge,
            const SizedBox(height: 26),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: VerifyColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: VerifyColors.soft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verified ────────────────────────────────────────────────────────────────

class VerifySuccessView extends StatelessWidget {
  const VerifySuccessView({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _CenteredStatus(
      hero: const VerifyHeroStatus(
        title: "You're Verified!",
        subtitle: 'Your identity has been confirmed.\nWelcome to Conexo.',
        badge: VerifyGlowBadge(
          size: 104,
          colors: [VerifyColors.verified, VerifyColors.verified2],
          glowColor: VerifyColors.verified,
          glowStrength: .5,
          child: Icon(Icons.check_rounded, size: 52, color: Colors.white),
        ),
      ),
      cta: VerifyCta(label: 'Continue to App', onTap: onContinue),
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────

class VerifyFailedView extends StatelessWidget {
  const VerifyFailedView({
    required this.onRetry,
    required this.onReviewTips,
    super.key,
    this.subtitle,
  });

  final VoidCallback onRetry;
  final VoidCallback onReviewTips;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _CenteredStatus(
      hero: VerifyHeroStatus(
        title: "We couldn't verify\nyour face",
        subtitle: subtitle ??
            "We couldn't confidently match your\nverification photos.",
        badge: VerifyGlowBadge(
          size: 104,
          colors: const [Color(0xFFF0A85A), Color(0xFFE0698F)],
          glowColor: const Color(0xFFF0A85A),
          glowStrength: .42,
          child: VerifyGlyph(VerifyAsset.alert, size: 46, color: Colors.white),
        ),
      ),
      cta: Column(
        children: [
          VerifyCta(label: 'Try Again', onTap: onRetry),
          const SizedBox(height: 6),
          VerifyTextLink(label: 'Review photo tips', onTap: onReviewTips),
        ],
      ),
    );
  }
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({required this.hero, required this.cta});

  final Widget hero;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          const Spacer(),
          hero,
          const Spacer(),
          cta,
        ],
      ),
    );
  }
}

// ── Photo tips ────────────────────────────────────────────────────────────

class VerifyTip {
  const VerifyTip(this.asset, this.title, this.body);
  final String asset;
  final String title;
  final String body;
}

const kVerifyPhotoTips = <VerifyTip>[
  VerifyTip(VerifyAsset.lighting, 'Use better lighting',
      'Avoid dim or backlit areas.'),
  VerifyTip(VerifyAsset.distance, 'Check your distance',
      'Keep 3–4 feet from the camera.'),
  VerifyTip(VerifyAsset.glasses, 'Remove glasses',
      'Avoid dark glasses or glare.'),
  VerifyTip(VerifyAsset.expression, 'Keep it natural',
      'No filters or exaggerated poses.'),
];

class VerifyTipsView extends StatelessWidget {
  const VerifyTipsView({
    required this.onGotIt,
    required this.onBack,
    super.key,
  });

  final VoidCallback onGotIt;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VerifyTopBar(onBack: onBack),
        const SizedBox(height: 6),
        const Text(
          'Photo tips',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: VerifyColors.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Follow these tips and try again.',
          style: TextStyle(fontSize: 14, color: VerifyColors.soft),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: kVerifyPhotoTips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final t = kVerifyPhotoTips[i];
              return VerifyInstructionCard(
                asset: t.asset,
                title: t.title,
                body: t.body,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        VerifyCta(label: 'Got it', onTap: onGotIt),
      ],
    );
  }
}
