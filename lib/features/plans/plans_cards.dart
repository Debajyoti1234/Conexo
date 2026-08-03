import 'package:flutter/material.dart';

import 'plans_data.dart';
import 'plans_widgets.dart';

/// The premium experience card. One reusable component renders four
/// variants (immersive / stacked / floating / compact) so the discovery
/// feed feels curated rather than repetitive. Spacing, typography,
/// glassmorphism, and press feedback stay consistent across all variants.
class ExperienceCard extends StatefulWidget {
  const ExperienceCard({
    required this.experience,
    super.key,
    this.width,
    this.onTap,
    this.variant,
  });

  final Experience experience;
  final double? width;
  final VoidCallback? onTap;

  /// Optional rail-level override so every card in a rail is consistent.
  /// Falls back to the experience's own [Experience.cardVariant].
  final CardVariant? variant;

  @override
  State<ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<ExperienceCard> {
  bool _pressed = false;
  bool _hovered = false;

  CardVariant get _variant => widget.variant ?? widget.experience.cardVariant;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          // Subtle desktop hover: slight elevation. Brighter glass + stronger
          // shadow are handled inside each variant via [hovered].
          child: AnimatedSlide(
            offset: _hovered ? const Offset(0, -0.010) : Offset.zero,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: SizedBox(width: widget.width, child: _buildVariant()),
          ),
        ),
      ),
    );
  }

  Widget _buildVariant() {
    switch (_variant) {
      case CardVariant.immersive:
        return _ImmersiveCard(experience: widget.experience, hovered: _hovered);
      case CardVariant.stacked:
        return _StackedCard(experience: widget.experience, hovered: _hovered);
      case CardVariant.floating:
        return _FloatingCard(experience: widget.experience, hovered: _hovered);
      case CardVariant.compact:
        return _CompactCard(experience: widget.experience, hovered: _hovered);
    }
  }
}

// ── Shared building blocks ──────────────────────────────────────────────

/// Consistent premium layered shadow across every variant. On hover the
/// shadow deepens slightly for a subtle sense of elevation.
BoxDecoration _cardShell(Color accent, {bool hovered = false}) => BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: hovered ? .48 : .38),
      blurRadius: hovered ? 34 : 26,
      offset: Offset(0, hovered ? 20 : 14),
    ),
    BoxShadow(
      color: accent.withValues(alpha: hovered ? .28 : .18),
      blurRadius: hovered ? 38 : 30,
      offset: const Offset(0, 6),
    ),
  ],
);

/// A faint white overlay that brightens the glass on hover. Sits above the
/// cover but ignores pointers so taps still pass through.
class _HoverGlow extends StatelessWidget {
  const _HoverGlow({required this.hovered});
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: hovered ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
            ),
          ),
        ),
      ),
    );
  }
}


/// Host row: avatar + "Title" + host name.
class _HostLine extends StatelessWidget {
  const _HostLine({required this.e, this.compact = false});
  final Experience e;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlanPortrait(
          asset: e.hostPortrait,
          accent: e.accent,
          size: compact ? 26 : 30,
          label: e.host,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Hosted by ${e.host}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFCBD4EC),
            ),
          ),
        ),
      ],
    );
  }
}

/// The compact premium info chips (Wrap so they never overflow).
class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.e, this.max});
  final Experience e;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      InfoChip(emoji: '📅', label: e.date),
      InfoChip(emoji: '⏰', label: e.time),
      InfoChip(emoji: '📍', label: e.distance),
      InfoChip(emoji: '👥', label: '${e.goingCount} Going'),
      InfoChip(emoji: '🎟', label: '${e.spotsLeft} Spots Left'),
    ];
    final shown = max == null ? chips : chips.take(max!).toList();
    return Wrap(spacing: 7, runSpacing: 7, children: shown);
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.e, this.fontSize = 19});
  final Experience e;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            e.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        MoodBadge(emoji: e.moodEmoji, mood: e.mood, accent: e.accent),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.e});
  final Experience e;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ParticipantStack(portraits: e.participants, accent: e.accent),
        const Spacer(),
        const ViewPill(),
      ],
    );
  }
}

// ── Variant A: immersive ────────────────────────────────────────────────

class _ImmersiveCard extends StatelessWidget {
  const _ImmersiveCard({required this.experience, this.hovered = false});
  final Experience experience;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Container(
      decoration: _cardShell(e.accent, hovered: hovered),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 348,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlanCover(asset: e.coverAsset, accent: e.accent),
              _HoverGlow(hovered: hovered),
              Positioned(
                top: 14,
                left: 14,
                child: VisibilityBadge(isPublic: e.isPublic),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightLine(
                      text: e.highlight,
                      isEditorsPick: e.isEditorsPick,
                    ),
                    const SizedBox(height: 8),
                    _TitleRow(e: e),
                    const SizedBox(height: 8),
                    _HostLine(e: e),
                    const SizedBox(height: 12),
                    _InfoChips(e: e),
                    const SizedBox(height: 14),
                    _FooterRow(e: e),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Variant B: stacked ──────────────────────────────────────────────────

class _StackedCard extends StatelessWidget {
  const _StackedCard({required this.experience, this.hovered = false});
  final Experience experience;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Container(
      decoration: _cardShell(e.accent, hovered: hovered).copyWith(
        color: const Color(0xFF141B31),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlanCover(asset: e.coverAsset, accent: e.accent, scrim: false),
                  _HoverGlow(hovered: hovered),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: MoodBadge(
                      emoji: e.moodEmoji,
                      mood: e.mood,
                      accent: e.accent,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: VisibilityBadge(isPublic: e.isPublic),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _HostLine(e: e),
                  const SizedBox(height: 8),
                  HighlightLine(
                    text: e.highlight,
                    isEditorsPick: e.isEditorsPick,
                  ),
                  const SizedBox(height: 12),
                  _InfoChips(e: e, max: 4),
                  const SizedBox(height: 14),
                  _FooterRow(e: e),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Variant C: floating ─────────────────────────────────────────────────

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.experience, this.hovered = false});
  final Experience experience;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return SizedBox(
      height: 356,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 40,
            child: Container(
              decoration: _cardShell(e.accent, hovered: hovered),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlanCover(asset: e.coverAsset, accent: e.accent),
                    _HoverGlow(hovered: hovered),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: MoodBadge(
                        emoji: e.moodEmoji,
                        mood: e.mood,
                        accent: e.accent,
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: VisibilityBadge(isPublic: e.isPublic),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF161E36).withValues(alpha: .96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .4),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleRow(e: e, fontSize: 18),
                  const SizedBox(height: 8),
                  _HostLine(e: e),
                  const SizedBox(height: 8),
                  HighlightLine(
                    text: e.highlight,
                    isEditorsPick: e.isEditorsPick,
                  ),
                  const SizedBox(height: 12),
                  _InfoChips(e: e, max: 4),
                  const SizedBox(height: 14),
                  _FooterRow(e: e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Variant D: compact ──────────────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.experience, this.hovered = false});
  final Experience experience;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Container(
      decoration: _cardShell(e.accent, hovered: hovered).copyWith(
        color: const Color(0xFF141B31),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlanCover(asset: e.coverAsset, accent: e.accent),
                  _HoverGlow(hovered: hovered),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: MoodBadge(
                      emoji: e.moodEmoji,
                      mood: e.mood,
                      accent: e.accent,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: VisibilityBadge(isPublic: e.isPublic),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HostLine(e: e, compact: true),
                  const SizedBox(height: 10),
                  _InfoChips(e: e, max: 4),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ParticipantStack(
                        portraits: e.participants,
                        accent: e.accent,
                        size: 22,
                      ),
                      const Spacer(),
                      const ViewPill(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


