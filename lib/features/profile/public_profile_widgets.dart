import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import 'profile_data.dart';
import 'public_profile_data.dart';


/// Reusable, const, presentational widgets for Phase 4.5 — Public Profile
/// Viewer. Everything reuses the Conexo dark-glass language (GlassCard,
/// gradients, spacing, typography) and the Phase 4.4 [StrengthBadge].
///
/// Motion is limited to the approved widgets (AnimatedContainer /
/// AnimatedSwitcher / AnimatedOpacity / AnimatedScale / Fade / Slide /
/// TweenAnimationBuilder where appropriate) with easeOutCubic / easeInOutCubic
/// — no bounce.

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);
const _kBrightText = Color(0xFFEAEEF9);
const _kVerified = Color(0xFF47D7A5);

// ── PublicProfileHeader ─────────────────────────────────────────────────────

/// A slim top bar with a back button (overlaid on the hero).
class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const Spacer(),
        const _GlassIconButton(icon: Icons.more_horiz_rounded, onTap: null),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .28),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

// ── VerifiedBadge ───────────────────────────────────────────────────────────

/// A small "Verified" pill. Callers render it only when appropriate.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: _kVerified.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _kVerified.withValues(alpha: .55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: compact ? 13 : 15, color: _kVerified),
          SizedBox(width: compact ? 4 : 5),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: _kVerified,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ProfileHero ─────────────────────────────────────────────────────────────

/// A large, immersive hero with swipeable photo gallery: all photos from the
/// profile, layered gradient scrim, name, optional username + age, location,
/// occupation, and verification. Supports horizontal swipe, tap left/right
/// navigation, and animated segmented progress bars (Tinder/Bumble style).
///
/// The strength tier and completion percentage are intentionally NOT shown
/// here — those belong only to the owner's own profile, never a viewed public
/// profile.
class ProfileHero extends StatefulWidget {
  const ProfileHero({
    required this.data,
    super.key,
  });

  final PublicProfileViewData data;

  @override
  State<ProfileHero> createState() => _ProfileHeroState();
}


class _ProfileHeroState extends State<ProfileHero> {
  late final PageController _controller;
  int _index = 0;

  List<ProfilePhoto> get _photos => widget.data.profile.photos;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int target) {
    final count = _photos.length;
    if (count <= 1) return;
    final clamped = target.clamp(0, count - 1);
    if (clamped == _index) return;
    _controller.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.data.profile;
    final count = _photos.length;
    final verified =
        profile.verificationStatus == VerificationStatus.verified;
    final titleLine = widget.data.hasAge
        ? '${widget.data.displayName}, ${widget.data.age}'
        : widget.data.displayName;

    return RepaintBoundary(
      child: SizedBox(
        height: 460,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photo pager (or placeholder) ──────────────────────────────
            if (count == 0)
              const _HeroPlaceholder()
            else
              PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _HeroPhoto(
                  key: ValueKey('hero_photo_${_photos[i].id}_$i'),
                  assetPath: _photos[i].assetPath,
                ),
              ),

            // ── Tap zones (left / center / right) ─────────────────────────
            if (count > 1)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _goTo(_index - 1),
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _goTo(_index + 1),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Layered scrim for text legibility + depth ─────────────────
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x22000000),
                      Color(0xCC05070E),
                    ],
                    stops: [0.35, 0.62, 1.0],
                  ),
                ),
              ),
            ),

            // ── Segmented progress bars ───────────────────────────────────
            if (count > 1)
              Positioned(
                top: 18,
                left: 20,
                right: 20,
                child: _ProgressBars(count: count, activeIndex: _index),
              ),

            // ── Identity block ────────────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey('identity_$_index'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (verified) ...[
                      const VerifiedBadge(compact: true),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      titleLine,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.data.hasUsername) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.data.formattedUsername,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kSoftText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _HeroMetaRow(
                      location: profile.location,
                      occupation: profile.occupation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single hero photo with graceful image loading and error handling.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({
    required this.assetPath,
    super.key,
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath.trim().isEmpty) {
      return const _HeroPlaceholder();
    }
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const _HeroPlaceholder(),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent, _kAccent2],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 96,
          color: Colors.white24,
        ),
      ),
    );
  }
}

/// Animated segmented progress bars (Tinder/Instagram-style).
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Padding(
              key: ValueKey('progress_$i'),
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      height: 3,
                      color: Colors.white.withValues(alpha: .18),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      widthFactor: i < activeIndex
                          ? 1.0
                          : (i == activeIndex ? 1.0 : 0.0),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white
                                  .withValues(alpha: i == activeIndex ? .4 : .2),
                              blurRadius: i == activeIndex ? 6 : 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({required this.location, required this.occupation});

  final String location;
  final String occupation;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (location.trim().isNotEmpty)
        _MetaChip(icon: Icons.place_outlined, label: location.trim()),
      if (occupation.trim().isNotEmpty)
        _MetaChip(icon: Icons.work_outline_rounded, label: occupation.trim()),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kSoftText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kBrightText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section shell ───────────────────────────────────────────────────────────


/// A large section title used above each section's card.
class PublicSectionTitle extends StatelessWidget {
  const PublicSectionTitle({required this.title, super.key, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: const Color(0xFFB7A5FF)),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ── AboutSection ────────────────────────────────────────────────────────────

/// The bio + optional "about me" long text.
class AboutSection extends StatelessWidget {
  const AboutSection({required this.bio, required this.aboutMe, super.key});

  final String bio;
  final String aboutMe;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.trim().isNotEmpty)
            Text(
              bio.trim(),
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.5,
                color: _kBrightText,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (bio.trim().isNotEmpty && aboutMe.trim().isNotEmpty)
            const SizedBox(height: 12),
          if (aboutMe.trim().isNotEmpty)
            Text(
              aboutMe.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: _kSoftText,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chip wrap (interests / languages / mutual) ──────────────────────────────

/// A reusable wrap of pill chips.
class ChipWrap extends StatelessWidget {
  const ChipWrap({
    required this.labels,
    super.key,
    this.icon,
    this.filled = false,
  });

  final List<String> labels;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          _Chip(
            key: ValueKey('chip_$label'),
            label: label,
            icon: icon,
            filled: filled,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    super.key,
    this.icon,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(colors: [_kAccent, _kAccent2])
            : null,
        color: filled ? null : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(30),
        border: filled
            ? null
            : Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.white : _kSoftText),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : _kBrightText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interests as chips inside a glass card.
class InterestSection extends StatelessWidget {
  const InterestSection({required this.interests, super.key});

  final List<String> interests;

  @override
  Widget build(BuildContext context) {
    return GlassCard(child: ChipWrap(labels: interests));
  }
}

/// Languages as chips inside a glass card.
class LanguageSection extends StatelessWidget {
  const LanguageSection({required this.languages, super.key});

  final List<String> languages;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: ChipWrap(labels: languages, icon: Icons.translate_rounded),
    );
  }
}

/// A single mutual-interest chip (filled/highlighted).
class MutualInterestChip extends StatelessWidget {
  const MutualInterestChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Chip(label: label, icon: Icons.favorite_rounded, filled: true);
  }
}

// ── OptionalInfoSection ─────────────────────────────────────────────────────

/// A key/value list of optional details (education, company, college, etc.).
class OptionalInfoSection extends StatelessWidget {
  const OptionalInfoSection({required this.rows, super.key});

  /// Ordered (icon, label, value) rows. Callers pass only non-empty rows.
  final List<OptionalInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              key: ValueKey('opt_${rows[i].label}'),
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 14),
              child: _OptionalRow(row: rows[i]),
            ),
        ],
      ),
    );
  }
}

/// Immutable row descriptor for [OptionalInfoSection].
class OptionalInfoRow {
  const OptionalInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _OptionalRow extends StatelessWidget {
  const _OptionalRow({required this.row});

  final OptionalInfoRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .06),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Icon(row.icon, size: 17, color: _kSoftText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kSoftText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _kBrightText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── SocialLinkTile ──────────────────────────────────────────────────────────

/// A single non-interactive social link row (read-only presentation).
class SocialLinkTile extends StatelessWidget {
  const SocialLinkTile({required this.link, super.key});

  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    final display =
        link.displayText.trim().isNotEmpty ? link.displayText.trim() : link.url.trim();
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_kAccent, _kAccent2]),
            ),
            child: const Icon(Icons.link_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.platform.trim().isNotEmpty ? link.platform.trim() : 'Link',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kSoftText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kBrightText,
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

// ── CommonConnectionsCard ───────────────────────────────────────────────────

/// A read-only placeholder card indicating shared connections.
class CommonConnectionsCard extends StatelessWidget {
  const CommonConnectionsCard({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_kAccent, _kAccent2]),
            ),
            child: const Icon(Icons.group_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1 ? '1 connection in common' : '$count connections in common',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _kBrightText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'You may know some of the same people.',
                  style: TextStyle(fontSize: 12.5, color: _kSoftText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── HostedPlansPreview ──────────────────────────────────────────────────────

/// A read-only, horizontally scrolling preview of placeholder hosted plans.
///
/// These are static placeholders only — there is no Plans-module coupling,
/// no data source, and nothing is tappable.
class HostedPlansPreview extends StatelessWidget {
  const HostedPlansPreview({required this.plans, super.key});

  final List<HostedPlanPlaceholder> plans;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: plans.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _HostedPlanCard(
          key: ValueKey('plan_${plans[i].title}'),
          plan: plans[i],
        ),
      ),
    );
  }
}

/// Immutable placeholder descriptor for a hosted plan preview card.
class HostedPlanPlaceholder {
  const HostedPlanPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _HostedPlanCard extends StatelessWidget {
  const _HostedPlanCard({required this.plan, super.key});

  final HostedPlanPlaceholder plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .08),
            Colors.white.withValues(alpha: .03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kAccent.withValues(alpha: .2),
            ),
            child: Icon(plan.icon, size: 20, color: const Color(0xFFB7A5FF)),
          ),
          const Spacer(),
          Text(
            plan.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kBrightText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            plan.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _kSoftText),
          ),
        ],
      ),
    );
  }
}

// ── PublicProfileEmptyState ─────────────────────────────────────────────────

/// A graceful empty state used when the profile has no displayable content.
class PublicProfileEmptyState extends StatelessWidget {
  const PublicProfileEmptyState({required this.displayName, super.key});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded, size: 56, color: _kSoftText),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'This profile has nothing to show yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kSoftText),
            ),
          ],
        ),
      ),
    );
  }
}
