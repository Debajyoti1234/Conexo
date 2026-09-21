import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import 'plans_data.dart';
import 'plans_theme.dart';
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
      color: Colors.black.withValues(alpha: hovered ? .18 : .10),
      blurRadius: hovered ? 30 : 22,
      offset: Offset(0, hovered ? 14 : 10),
    ),
  ],
);

/// A faint overlay that brightens the glass on hover. Sits above the
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
              color: context.cxInk.withValues(alpha: .04),
            ),
          ),
        ),
      ),
    );
  }
}


/// Host row: avatar + "Title" + host name.
class _HostLine extends StatelessWidget {
  const _HostLine({required this.e, this.compact = false, this.onLight = false});
  final Experience e;
  final bool compact;
  final bool onLight;

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
            style: plansBody(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w500,
              color: onLight
                  ? context.cxSoft
                  : Colors.white.withValues(alpha: .92),
            ),
          ),
        ),
      ],
    );
  }
}

/// The compact info line: outlined icons + text, inline, no boxes. Shows the
/// same facts the old chips did (date, time, distance, going, spots left).
class _InfoChips extends StatelessWidget {
  const _InfoChips({
    required this.e,
    this.max,
    this.skip = 0,
    this.onLight = false,
  });
  final Experience e;
  final int? max;

  /// Number of leading facts to omit (lets a card split facts over two lines).
  final int skip;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.calendar_today_outlined, e.date),
      (Icons.schedule_outlined, e.time),
      (Icons.place_outlined, e.distance),
      (Icons.people_outline, '${e.goingCount} going'),
      (Icons.confirmation_number_outlined, '${e.spotsLeft} spots left'),
    ];
    final limited = max == null ? items : items.take(max!).toList();
    final shown = limited.skip(skip).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return PlanMetaLine(items: shown, onLight: onLight, fontSize: 12);
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.e, this.fontSize = 19, this.onLight = false});
  final Experience e;
  final double fontSize;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return Text(
      e.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: plansDisplay(
        fontSize: fontSize + 4,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        color: onLight ? context.cxInk : Colors.white,
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.e, this.onLight = false});
  final Experience e;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ParticipantStack(portraits: e.participants, accent: e.accent),
        const Spacer(),
        ViewPill(onLight: onLight),
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
              // Extra bottom scrim so serif titles and meta stay legible on
              // busy, bright photos.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x99000000),
                          Color(0xE6000000),
                        ],
                        stops: [0.38, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              _HoverGlow(hovered: hovered),
              Positioned(
                top: 14,
                left: 14,
                child: VisibilityBadge(isPublic: e.isPublic),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: MoodBadge(
                  emoji: e.moodEmoji,
                  mood: e.mood,
                  accent: e.accent,
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightLine(
                      text: e.highlight,
                      isEditorsPick: e.isEditorsPick,
                    ),
                    const SizedBox(height: 6),
                    _TitleRow(e: e, fontSize: 22),
                    const SizedBox(height: 10),
                    _InfoChips(e: e, max: 3),
                    const SizedBox(height: 6),
                    _InfoChips(e: e, max: 5, skip: 3),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _HostLine(e: e)),
                        const SizedBox(width: 10),
                        const ViewPill(),
                      ],
                    ),
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
        color: context.cxCanvas,
        border: Border.all(color: context.cxLine),
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
                    style: plansDisplay(
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _HostLine(e: e, onLight: true),
                  const SizedBox(height: 8),
                  HighlightLine(
                    text: e.highlight,
                    isEditorsPick: e.isEditorsPick,
                    onLight: true,
                  ),
                  const SizedBox(height: 12),
                  _InfoChips(e: e, max: 4, onLight: true),
                  const SizedBox(height: 14),
                  _FooterRow(e: e, onLight: true),
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
                color: context.cxCanvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.cxLine),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleRow(e: e, fontSize: 18, onLight: true),
                  const SizedBox(height: 8),
                  _HostLine(e: e, onLight: true),
                  const SizedBox(height: 8),
                  HighlightLine(
                    text: e.highlight,
                    isEditorsPick: e.isEditorsPick,
                    onLight: true,
                  ),
                  const SizedBox(height: 12),
                  _InfoChips(e: e, max: 4, onLight: true),
                  const SizedBox(height: 14),
                  _FooterRow(e: e, onLight: true),
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
        color: context.cxCanvas,
        border: Border.all(color: context.cxLine),
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
                      style: plansDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
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
                  _HostLine(e: e, compact: true, onLight: true),
                  const SizedBox(height: 10),
                  _InfoChips(e: e, max: 4, onLight: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ParticipantStack(
                        portraits: e.participants,
                        accent: e.accent,
                        size: 22,
                      ),
                      const Spacer(),
                      const ViewPill(onLight: true),
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


