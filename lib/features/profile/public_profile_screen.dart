import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_strength_data.dart';
import 'public_profile_data.dart';
import 'public_profile_sections.dart';
import 'public_profile_widgets.dart';

/// The premium, read-only Public Profile Viewer (Phase 4.5).
///
/// Shown when another user opens someone's profile anywhere in Conexo. It is
/// pure presentation:
///  • Accepts an immutable [PublicProfileViewData] — never loads
///    SharedPreferences, never uses ProfileRepository, never touches a backend.
///  • Computes the strength tier/completion via the pure
///    [computeProfileStrength] engine.
///  • Computes mutual interests locally through the view model.
///  • Hosted plans are static read-only placeholders (no Plans-module coupling).
///
/// Motion is limited to the approved widgets (here: staggered [EntranceFade]
/// reveals + a fade/slide route transition) with easeOutCubic / easeInOutCubic
/// — no bounce.
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({required this.data, super.key});

  final PublicProfileViewData data;

  /// Static read-only placeholder plans (presentation only).
  static const List<HostedPlanPlaceholder> _placeholderPlans = [
    HostedPlanPlaceholder(
      title: 'Weekend Hike',
      subtitle: 'Outdoors • Sat',
      icon: Icons.hiking_rounded,
    ),
    HostedPlanPlaceholder(
      title: 'Coffee & Chat',
      subtitle: 'Social • Sun',
      icon: Icons.coffee_rounded,
    ),
    HostedPlanPlaceholder(
      title: 'Live Music Night',
      subtitle: 'Music • Fri',
      icon: Icons.music_note_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final strength = computeProfileStrength(profile);
    final mutual = data.mutualInterests;

    // A profile with no primary photo AND no meaningful content → empty state.
    final hasAnyContent = profile.primaryPhoto != null ||
        profile.bio.trim().isNotEmpty ||
        profile.interests.isNotEmpty ||
        profile.languages.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: hasAnyContent
          ? _buildContent(context, strength, mutual)
          : SafeArea(
              child: Stack(
                children: [
                  PublicProfileEmptyState(displayName: data.displayName),
                  _floatingBack(context),
                ],
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProfileStrengthResult strength,
    List<String> mutual,
  ) {
    final profile = data.profile;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 40),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            // Hero is full-bleed (no horizontal padding).
            RepaintBoundary(
              child: HeroSection(data: data, strength: strength),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntranceFade(
                    child: AboutProfileSection(profile: profile),
                  ),
                  _gap(profile.bio.trim().isNotEmpty ||
                      profile.aboutMe.trim().isNotEmpty),
                  EntranceFade(
                    child: MutualInterestsSection(mutual: mutual),
                  ),
                  _gap(mutual.isNotEmpty),
                  EntranceFade(
                    child: InterestsProfileSection(
                      interests: profile.interests,
                    ),
                  ),
                  _gap(profile.interests.isNotEmpty),
                  EntranceFade(
                    child: LanguagesProfileSection(
                      languages: profile.languages,
                    ),
                  ),
                  _gap(profile.languages.isNotEmpty),
                  EntranceFade(
                    child: OptionalDetailsSection(profile: profile),
                  ),
                  const SizedBox(height: 20),
                  EntranceFade(
                    child: RepaintBoundary(
                      child: HostedPlansSection(plans: _placeholderPlans),
                    ),
                  ),
                  const SizedBox(height: 20),
                  EntranceFade(
                    child: SocialLinksSection(links: profile.socialLinks),
                  ),
                ],
              ),
            ),
          ],
        ),
        _floatingBack(context),
      ],
    );
  }

  /// A 20px gap emitted only when the preceding section actually rendered,
  /// keeping spacing consistent without leaving double gaps around hidden
  /// (empty) sections.
  Widget _gap(bool precedingVisible) =>
      precedingVisible ? const SizedBox(height: 20) : const SizedBox.shrink();

  Widget _floatingBack(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: PublicProfileHeader(
        onBack: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

// ── Route (matches Conexo's premium fade + slide transition) ────────────────

/// Premium route into the Public Profile Viewer.
///
/// Uses the same fade + slide transition language as the other Profile routes
/// for a consistent feel across Conexo.
Route<void> premiumPublicProfileRoute({required PublicProfileViewData data}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PublicProfileScreen(data: data),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
