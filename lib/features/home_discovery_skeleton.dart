import 'dart:ui';

import 'package:flutter/material.dart';

import 'home_discovery_animations.dart';

/// Premium skeleton shown briefly while a profile is being revealed.
///
/// Mirrors the real [ImmersiveProfileView] layout: full-bleed hero gradient,
/// badge placeholders, identity block, floating control placeholders, and
/// an information panel made of shimmering blocks.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _SkeletonHero(),
                  const IgnorePointer(child: _SkeletonScrim()),
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
                    left: 22,
                    right: 22,
                    bottom: 108,
                    child: const _SkeletonIdentity(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: _SkeletonControls(),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C31).withValues(alpha: .82),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: .1)),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
                  child: Column(
                    children: const [
                      _SkeletonPanel(),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

class _SkeletonScrim extends StatelessWidget {
  const _SkeletonScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x66000000),
            Color(0x00000000),
            Color(0x33000000),
            Color(0xE60A0F1F),
          ],
          stops: [0.0, 0.32, 0.62, 1.0],
        ),
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

class _SkeletonIdentity extends StatelessWidget {
  const _SkeletonIdentity();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLine(width: 180, height: 32),
          SizedBox(height: 10),
          SkeletonLine(width: 110, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonControls extends StatelessWidget {
  const _SkeletonControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkeletonCircle(size: 58),
        const SizedBox(width: 34),
        _SkeletonCircle(size: 82),
        const SizedBox(width: 34),
        _SkeletonCircle(size: 58),
      ],
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: const Color(0xFF232C47),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
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
