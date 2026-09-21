import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import '../../app/theme/app_widgets.dart';
import 'profile_strength_data.dart';

/// Reusable premium widgets for Phase 4.4 — Profile Strength & Completion.
///
/// All widgets are presentational and reuse the Conexo dark-glass language
/// (GlassCard, gradients, spacing, typography). Per the approved plan,
/// [TweenAnimationBuilder] is used ONLY for the [ProfileStrengthRing] sweep;
/// every other motion uses AnimatedContainer / AnimatedSwitcher /
/// AnimatedOpacity / AnimatedScale / Fade / Slide with easeOutCubic /
/// easeInOutCubic — no bounce.

const _kDone = Color(0xFF1F9D6B);

// ── Tier palette ──────────────────────────────────────────────────────────────

/// The gradient colors used to represent a [ProfileStrengthTier].
List<Color> tierGradient(ProfileStrengthTier tier) => switch (tier) {
      ProfileStrengthTier.bronze => const [Color(0xFFC08457), Color(0xFF8A5A38)],
      ProfileStrengthTier.silver => const [Color(0xFF5C5C66), Color(0xFF8791A8)],
      ProfileStrengthTier.gold => const [Color(0xFFC98A1E), Color(0xFFE0952B)],
      ProfileStrengthTier.platinum => const [Color(0xFF1B1B1F), Color(0xFF1B1B1F)],
    };

IconData _tierIcon(ProfileStrengthTier tier) => switch (tier) {
      ProfileStrengthTier.bronze => Icons.shield_outlined,
      ProfileStrengthTier.silver => Icons.shield_moon_outlined,
      ProfileStrengthTier.gold => Icons.workspace_premium_rounded,
      ProfileStrengthTier.platinum => Icons.diamond_outlined,
    };

// ── ProfileStrengthRing ─────────────────────────────────────────────────────

/// A premium circular progress ring animated ONCE from 0 → [percentage] via
/// [TweenAnimationBuilder]. Shows the percentage + tier label in the center.
class ProfileStrengthRing extends StatelessWidget {
  const ProfileStrengthRing({
    required this.percentage,
    required this.tier,
    super.key,
    this.size = 168,
    this.strokeWidth = 14,
  });

  /// 0.0–1.0 completion ratio.
  final double percentage;
  final ProfileStrengthTier tier;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final colors = tierGradient(tier);
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: percentage.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return CustomPaint(
              painter: _RingPainter(
                progress: value,
                strokeWidth: strokeWidth,
                colors: colors,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 34,
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.cxSoft,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
  });

  final double progress;
  final double strokeWidth;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Color(0xFF1B1B1F).withValues(alpha: .08);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    const start = -math.pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.colors != colors;
}

// ── StrengthBadge ─────────────────────────────────────────────────────────────

/// A tier pill (gradient + icon + label), e.g. "Gold".
class StrengthBadge extends StatelessWidget {
  const StrengthBadge({required this.tier, super.key, this.compact = false});

  final ProfileStrengthTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = tierGradient(tier);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: .45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tierIcon(tier), size: compact ? 15 : 17, color: Colors.white),
          SizedBox(width: compact ? 5 : 7),
          Text(
            tierLabel(tier),
            style: TextStyle(
              fontSize: compact ? 12.5 : 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ProfileStrengthCard ─────────────────────────────────────────────────────

/// The hero card: ring + tier badge + score summary line.
class ProfileStrengthCard extends StatelessWidget {
  const ProfileStrengthCard({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          ProfileStrengthRing(
            percentage: result.completionPercentage,
            tier: result.tier,
          ),
          const SizedBox(height: 18),
          StrengthBadge(tier: result.tier),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${result.profileScore}',
                style: TextStyle(
                  fontSize: 26,
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w600,
                  color: context.cxInk,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ 100 profile score',
                style: TextStyle(
                  fontSize: 14,
                  color: context.cxSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ProfileScoreRow ─────────────────────────────────────────────────────────

/// A labeled score row with an animated proportional bar (AnimatedContainer).
class ProfileScoreRow extends StatelessWidget {
  const ProfileScoreRow({
    required this.label,
    required this.earned,
    required this.max,
    super.key,
    this.icon,
      this.accent = const Color(0xFF1B1B1F),
  });

  final String label;
  final int earned;
  final int max;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (earned / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.cxInk,
                  ),
                ),
              ),
              Text(
                '$earned/$max',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.cxSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.cxInk.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: .7)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── SuggestionTile ────────────────────────────────────────────────────────────

/// A single actionable suggestion inside a glass tile.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [context.cxAccent, context.cxAccent]),
              boxShadow: [
                BoxShadow(
                  color: context.cxAccent.withValues(alpha: .4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.cxInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MissingItemTile ─────────────────────────────────────────────────────────

/// A single missing/remaining item row.
class MissingItemTile extends StatelessWidget {
  const MissingItemTile({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cxInk.withValues(alpha: .07),
              border: Border.all(color: context.cxInk.withValues(alpha: .14)),
            ),
            child: Icon(Icons.add_rounded, size: 18, color: context.cxSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.cxInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CompletionChecklist ─────────────────────────────────────────────────────

/// A checklist of [ProfileStrengthItem]s with done / not-done indicators.
class CompletionChecklist extends StatelessWidget {
  const CompletionChecklist({required this.items, super.key});

  final List<ProfileStrengthItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              key: ValueKey('check_${items[i].id}'),
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
              child: _ChecklistRow(item: items[i]),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final ProfileStrengthItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 26,
          width: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done
                ? const LinearGradient(colors: [_kDone, Color(0xFF0E8FA8)])
                : null,
            color: done ? null : context.cxInk.withValues(alpha: .07),
            border: done
                ? null
                : Border.all(color: context.cxInk.withValues(alpha: .16)),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle_outlined,
            size: done ? 16 : 14,
            color: done ? Colors.white : context.cxSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: done ? context.cxInk : context.cxSoft,
            ),
          ),
        ),
        Text(
          '+${item.maxPoints}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: done ? _kDone : context.cxSoft.withValues(alpha: .7),
          ),
        ),
      ],
    );
  }
}

// ── ScoreBreakdownCard ────────────────────────────────────────────────────────

/// A card visualizing the [ProfileScoreBreakdown] as a set of score rows.
class ScoreBreakdownCard extends StatelessWidget {
  const ScoreBreakdownCard({required this.breakdown, super.key});

  final ProfileScoreBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileScoreRow(
            label: 'Photos',
            icon: Icons.photo_library_outlined,
            earned: breakdown.photosScore,
            max: 20,
          ),
          ProfileScoreRow(
            label: 'Bio',
            icon: Icons.notes_rounded,
            earned: breakdown.bioScore,
            max: 12,
          ),
          ProfileScoreRow(
            label: 'Interests',
            icon: Icons.interests_rounded,
            earned: breakdown.interestsScore,
            max: 12,
          ),
          ProfileScoreRow(
            label: 'Languages',
            icon: Icons.translate_rounded,
            earned: breakdown.languagesScore,
            max: 8,
          ),
          ProfileScoreRow(
            label: 'Gender & location',
            icon: Icons.place_outlined,
            earned: breakdown.coreFieldsScore,
            max: 18,
          ),
          ProfileScoreRow(
            label: 'Optional details',
            icon: Icons.auto_awesome_outlined,
            earned: breakdown.optionalScore,
            max: 20,
            accent: context.cxAccent,
          ),
          ProfileScoreRow(
            label: 'Verification bonus',
            icon: Icons.verified_rounded,
            earned: breakdown.verificationBonus,
            max: 10,
            accent: _kDone,
          ),
          const Divider(height: 26, color: Color(0x1AFFFFFF)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total score',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.cxInk,
                  ),
                ),
              ),
              Text(
                '${breakdown.total}/100',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.cxAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── SectionTitle ────────────────────────────────────────────────────────────

/// A large section title + optional subtitle, matching profile screens.
class StrengthSectionTitle extends StatelessWidget {
  const StrengthSectionTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: context.cxInk),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13.5, color: context.cxSoft),
          ),
        ],
      ],
    );
  }
}
