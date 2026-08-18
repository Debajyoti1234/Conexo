import 'package:flutter/material.dart';

import 'profile_data.dart';
import 'public_profile_data.dart';
import 'public_profile_widgets.dart';

/// Composed, presentational sections for Phase 4.5 — Public Profile Viewer.
///
/// Each section is a thin, stateless widget that renders part of the immutable
/// [PublicProfileViewData]. There is NO business logic, persistence, or
/// networking here — sections simply arrange the reusable widgets from
/// `public_profile_widgets.dart`. Sections with no data render nothing
/// (`SizedBox.shrink`) so the screen never shows empty cards.

// ── HeroSection ───────────────────────────────────────────────────────────────

/// The large immersive hero (photo + identity + badges).
class HeroSection extends StatelessWidget {
  const HeroSection({
    required this.data,
    super.key,
    this.owner = false,
    this.onOpenPrivacyVerification,
  });

  final PublicProfileViewData data;

  /// Owner-only: renders the tappable privacy + verification status cluster
  /// beside the name/age. Defaults preserve the existing non-owner (public)
  /// rendering exactly.
  final bool owner;

  /// Owner-only shortcut invoked when the privacy or verification badge is
  /// tapped (wired to open Privacy & Verification).
  final VoidCallback? onOpenPrivacyVerification;

  @override
  Widget build(BuildContext context) {
    return ProfileHero(
      data: data,
      owner: owner,
      onOpenPrivacyVerification: onOpenPrivacyVerification,
    );
  }
}


// ── AboutProfileSection ───────────────────────────────────────────────────────

/// Bio + optional about text. Hidden when both are empty.
class AboutProfileSection extends StatelessWidget {
  const AboutProfileSection({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final hasContent =
        profile.bio.trim().isNotEmpty || profile.aboutMe.trim().isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();
    return _Section(
      title: 'About',
      icon: Icons.person_outline_rounded,
      child: AboutSection(bio: profile.bio, aboutMe: profile.aboutMe),
    );
  }
}

// ── InterestsProfileSection ───────────────────────────────────────────────────

/// Interest chips. Hidden when empty.
class InterestsProfileSection extends StatelessWidget {
  const InterestsProfileSection({required this.interests, super.key});

  final List<String> interests;

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Interests',
      icon: Icons.interests_rounded,
      child: InterestSection(interests: interests),
    );
  }
}

// ── LanguagesProfileSection ───────────────────────────────────────────────────

/// Language chips. Hidden when empty.
class LanguagesProfileSection extends StatelessWidget {
  const LanguagesProfileSection({required this.languages, super.key});

  final List<String> languages;

  @override
  Widget build(BuildContext context) {
    if (languages.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Languages',
      icon: Icons.translate_rounded,
      child: LanguageSection(languages: languages),
    );
  }
}

// ── OptionalDetailsSection ────────────────────────────────────────────────────

/// Optional details (education, company, college, hometown, website, favorite
/// activities). Hidden when none are present.
class OptionalDetailsSection extends StatelessWidget {
  const OptionalDetailsSection({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <OptionalInfoRow>[
      if (profile.location.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.place_outlined,
          label: 'Location',
          value: profile.location.trim(),
        ),
      if (profile.education.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.school_outlined,
          label: 'Education',
          value: profile.education.trim(),
        ),
      if (profile.college.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.account_balance_outlined,
          label: 'College',
          value: profile.college.trim(),
        ),
      if (profile.company.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.business_outlined,
          label: 'Company',
          value: profile.company.trim(),
        ),
      if (profile.hometown.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.home_outlined,
          label: 'Hometown',
          value: profile.hometown.trim(),
        ),
      if (profile.website.trim().isNotEmpty)
        OptionalInfoRow(
          icon: Icons.language_rounded,
          label: 'Website',
          value: profile.website.trim(),
        ),
      if (profile.favoriteActivities.isNotEmpty)
        OptionalInfoRow(
          icon: Icons.local_activity_outlined,
          label: 'Favorite activities',
          value: profile.favoriteActivities.join(', '),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Details',
      icon: Icons.info_outline_rounded,
      child: OptionalInfoSection(rows: rows),
    );
  }
}

// ── HostedPlansSection ────────────────────────────────────────────────────────

/// A read-only preview of placeholder hosted plans. Hidden when empty.
class HostedPlansSection extends StatelessWidget {
  const HostedPlansSection({required this.plans, super.key});

  final List<HostedPlanPlaceholder> plans;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Hosted plans',
      icon: Icons.event_available_outlined,
      child: HostedPlansPreview(plans: plans),
    );
  }
}

// ── MutualInterestsSection ────────────────────────────────────────────────────

/// Mutual interests (computed locally by the screen). Hidden when empty.
class MutualInterestsSection extends StatelessWidget {
  const MutualInterestsSection({required this.mutual, super.key});

  final List<String> mutual;

  @override
  Widget build(BuildContext context) {
    if (mutual.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Mutual interests',
      icon: Icons.favorite_outline_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in mutual)
            MutualInterestChip(key: ValueKey('mutual_$label'), label: label),
        ],
      ),
    );
  }
}

// ── SocialLinksSection ────────────────────────────────────────────────────────

/// Read-only social links. Hidden when none have a URL.
class SocialLinksSection extends StatelessWidget {
  const SocialLinksSection({required this.links, super.key});

  final List<SocialLink> links;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final l in links)
        if (l.url.trim().isNotEmpty || l.displayText.trim().isNotEmpty) l,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Social',
      icon: Icons.link_rounded,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              key: ValueKey('social_${visible[i].platform}_$i'),
              padding: EdgeInsets.only(bottom: i == visible.length - 1 ? 0 : 12),
              child: SocialLinkTile(link: visible[i]),
            ),
        ],
      ),
    );
  }
}

// ── Shared section shell ──────────────────────────────────────────────────────

/// A title + 14px gap + card body. Purely presentational.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.icon});

  final String title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PublicSectionTitle(title: title, icon: icon),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
