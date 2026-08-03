import 'package:flutter/material.dart';

import 'home_discovery_animations.dart';

/// Premium skeleton shown briefly while a profile is being revealed.
///
/// Mirrors the real [ImmersiveProfileView] layout: hero gradient, avatar
/// placeholder, two badge placeholders, and an information panel made of
/// shimmering blocks.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight = constraints.maxHeight * 0.46;
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _SkeletonHero(),
              Positioned(
                top: 18,
                left: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBadge(width: 92),
                    SizedBox(height: 10),
                    _SkeletonBadge(width: 118),
                  ],
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: const _SkeletonBadge(width: 150),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelHeight,
                child: const _SkeletonPanel(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonHero extends StatelessWidget {
  const _SkeletonHero();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF28324F), Color(0xFF1A2238)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.34),
            child: Container(
              height: 196,
              width: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A3352),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBadge extends StatelessWidget {
  const _SkeletonBadge({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: 32,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF232C47),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172039).withValues(alpha: .94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .34),
            blurRadius: 26,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Shimmer(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                children: const [
                  SkeletonLine(width: 180, height: 30),
                  SizedBox(height: 12),
                  SkeletonLine(width: 110, height: 13),
                  SizedBox(height: 30),
                  SkeletonLine(width: 90, height: 15),
                  SizedBox(height: 12),
                  SkeletonLine(width: double.infinity, height: 13),
                  SizedBox(height: 8),
                  SkeletonLine(width: 220, height: 13),
                  SizedBox(height: 28),
                  SkeletonLine(width: 90, height: 15),
                  SizedBox(height: 12),
                  _SkeletonChipRow(),
                  SizedBox(height: 28),
                  SkeletonLine(width: 90, height: 15),
                  SizedBox(height: 12),
                  SkeletonLine(width: double.infinity, height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonChipRow extends StatelessWidget {
  const _SkeletonChipRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SkeletonBlock(width: 96, height: 32, radius: 14),
        SkeletonBlock(width: 120, height: 32, radius: 14),
        SkeletonBlock(width: 84, height: 32, radius: 14),
      ],
    );
  }
}
