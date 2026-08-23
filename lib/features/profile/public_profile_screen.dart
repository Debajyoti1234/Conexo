import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_data.dart';
import 'profile_photo_resolver.dart';
import 'public_profile_data.dart';
import 'public_profile_sections.dart';
import 'public_profile_widgets.dart';

/// The premium, read-only Public Profile Viewer (Phase 4.5).
///
/// Shown when another user opens someone's profile anywhere in Conexo. It is
/// pure presentation:
///  • Accepts an immutable [PublicProfileViewData] — pre-resolves all uploaded
///    photo storage paths to signed URLs and precaches the entire gallery
///    before the hero is displayed.
///  • Computes the strength tier/completion via the pure
///    [computeProfileStrength] engine.
///  • Computes mutual interests locally through the view model.
///  • Hosted plans are static read-only placeholders (no Plans-module coupling).
///
/// Motion is limited to the approved widgets (here: staggered [EntranceFade]
/// reveals + a fade/slide route transition) with easeOutCubic / easeInOutCubic
/// — no bounce.
class PublicProfileScreen extends StatefulWidget {
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
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _ready = false;
  UserProfile? _resolvedProfile;

  @override
  void initState() {
    super.initState();
    _resolvedProfile = widget.data.profile;
    _preload();
  }

  Future<void> _preload() async {
    final profile = widget.data.profile;
    final storagePaths = profile.photos
        .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
        .map((p) => p.remoteUrl!)
        .toList();

    UserProfile resolved = profile;
    if (storagePaths.isNotEmpty) {
      final resolver = ProfilePhotoResolver.instance;
      final futures = storagePaths.map((p) => resolver.resolvePhoto(p)).toList();
      final signedResults = await Future.wait(futures);

      final updatedPhotos = [...profile.photos];
      for (var i = 0; i < updatedPhotos.length; i++) {
        final remoteUrl = updatedPhotos[i].remoteUrl;
        if (remoteUrl != null && remoteUrl.startsWith('profiles/')) {
          final idx = storagePaths.indexOf(remoteUrl);
          if (idx != -1) {
            updatedPhotos[i] = updatedPhotos[i].copyWith(remoteUrl: signedResults[idx].signedUrl);
          } else {
            updatedPhotos[i] = updatedPhotos[i].copyWith(remoteUrl: null);
          }
        }
      }
      resolved = profile.copyWith(photos: updatedPhotos);

      for (final photo in updatedPhotos) {
        final url = photo.remoteUrl;
        if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
          try {
            final provider = NetworkImage(url);
            await precacheImage(provider, context);
          } catch (_) {
            // Individual photo failure does not block the remaining gallery.
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _resolvedProfile = resolved;
        _ready = true;
      });
    }
  }

  UserProfile get _profile => _resolvedProfile ?? widget.data.profile;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final mutual = widget.data.mutualInterests;

    if (!_ready) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
              _floatingBack(context),
            ],
          ),
        ),
      );
    }

    // A profile with no primary photo AND no meaningful content → empty state.
    final hasAnyContent = profile.primaryPhoto != null ||
        profile.bio.trim().isNotEmpty ||
        profile.interests.isNotEmpty ||
        profile.languages.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: hasAnyContent
          ? _buildContent(context, mutual)
          : SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                  PublicProfileEmptyState(displayName: widget.data.displayName),
                  _floatingBack(context),
                ],
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<String> mutual,
  ) {
    final profile = _profile;
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        ListView(
          padding: const EdgeInsets.only(bottom: 40),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            // Hero is full-bleed (no horizontal padding).
            RepaintBoundary(
              child: HeroSection(
                data: PublicProfileViewData(
                  profile: profile,
                  displayName: widget.data.displayName,
                  username: widget.data.username,
                  age: widget.data.age,
                  viewerInterests: widget.data.viewerInterests,
                ),
              ),
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
                      child: HostedPlansSection(plans: PublicProfileScreen._placeholderPlans),
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
