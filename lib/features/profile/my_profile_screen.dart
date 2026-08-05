import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'discovery_preferences_screen.dart';
import 'my_profile_hero.dart';
import 'privacy_verification_screen.dart';
import 'profile_data.dart';
import 'profile_management_screen.dart';
import 'profile_repository.dart';
import 'profile_strength_data.dart';
import 'profile_strength_screen.dart';
import 'public_profile_sections.dart';
import 'safety_screen.dart';

/// The premium **My Profile** screen — the default destination of the Profile
/// tab once a profile exists.
///
/// It reuses the existing Public Profile section widgets (About, Interests,
/// Languages, Details, Social) for a single source of truth, but swaps the
/// static public hero for a Tinder/Bumble-style [MyProfileHero] photo carousel
/// and replaces the old management dashboard with a top-right ⋮ overflow menu
/// that routes into the already-built Profile screens.
///
/// It is presentation + navigation only: it loads the finalized [UserProfile]
/// through the injected [ProfileRepository] and never mutates it. All editing
/// stays inside Edit Profile (Profile Management).
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    this.repository = const LocalProfileRepository(),
  });

  /// Injected repository (defaults to local). A future backend repository can
  /// be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _loading = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  // ── Overflow menu actions ─────────────────────────────────────────────────

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      premiumProfileManagementRoute(repository: widget.repository),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openPrivacy() async {
    await Navigator.of(context).push(
      premiumPrivacyVerificationRoute(repository: widget.repository),
    );
    if (!mounted) return;
    await _load();
  }

  void _openDiscoveryPreferences() {
    Navigator.of(context).push(
      premiumDiscoveryPreferencesRoute(repository: widget.repository),
    );
  }

  void _openProfileStrength() {
    Navigator.of(context).push(
      premiumProfileStrengthRoute(repository: widget.repository),
    );
  }

  void _openSafety() {
    Navigator.of(context).push(
      premiumSafetyRoute(repository: widget.repository),
    );
  }

  void _openHelpAndSupport() => _placeholder('Help & Support');

  void _openAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Conexo',
      applicationVersion: '1.0.0',
      applicationLegalese: '© Conexo',
      children: const [
        SizedBox(height: 12),
        Text(
          'Conexo helps you make small plans and meet people who share your '
          'rhythm.',
        ),
      ],
    );
  }

  void _logout() => _placeholder('Logout');

  void _placeholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onMenuSelected(_ProfileMenuAction action) {
    switch (action) {
      case _ProfileMenuAction.editProfile:
        _openEditProfile();
      case _ProfileMenuAction.privacy:
        _openPrivacy();
      case _ProfileMenuAction.discovery:
        _openDiscoveryPreferences();
      case _ProfileMenuAction.strength:
        _openProfileStrength();
      case _ProfileMenuAction.safety:
        _openSafety();
      case _ProfileMenuAction.help:
        _openHelpAndSupport();
      case _ProfileMenuAction.about:
        _openAbout();
      case _ProfileMenuAction.logout:
        _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      // Defensive: the Profile tab only opens this screen when a profile
      // exists, but guard gracefully just in case.
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'No profile found',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
        ),
      );
    }

    final strength = computeProfileStrength(profile);
    final displayName = _deriveDisplayName(profile);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 40),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              RepaintBoundary(
                child: MyProfileHero(
                  profile: profile,
                  strength: strength,
                  displayName: displayName,
                  onTapPhoto: () => _placeholder('Fullscreen photo'),
                ),
              ),
              const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    EntranceFade(
                      child: SocialLinksSection(links: profile.socialLinks),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _OverflowMenuButton(onSelected: _onMenuSelected),
        ],
      ),
    );
  }

  Widget _gap(bool precedingVisible) =>
      precedingVisible ? const SizedBox(height: 24) : const SizedBox.shrink();

  /// [UserProfile] carries no name field, so derive a friendly display name
  /// from the occupation/location when possible, else a neutral fallback.
  /// (Presentation-only; never invents persisted data.)
  String _deriveDisplayName(UserProfile profile) {
    final occ = profile.occupation.trim();
    if (occ.isNotEmpty) return occ;
    final loc = profile.location.trim();
    if (loc.isNotEmpty) return loc;
    return 'My Profile';
  }
}

/// The top-right ⋮ overflow menu, floating over the hero with a comfortable
/// glass affordance.
class _OverflowMenuButton extends StatelessWidget {
  const _OverflowMenuButton({required this.onSelected});

  final ValueChanged<_ProfileMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 14,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: .38),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: PopupMenuButton<_ProfileMenuAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF141B2E),
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: .5),
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.white.withValues(alpha: .08)),
            ),
            onSelected: onSelected,
            itemBuilder: (context) => [
              _item(_ProfileMenuAction.editProfile, Icons.edit_outlined,
                  'Edit Profile'),
              _item(_ProfileMenuAction.privacy, Icons.privacy_tip_outlined,
                  'Privacy & Verification'),
              _item(_ProfileMenuAction.discovery, Icons.tune_rounded,
                  'Discovery Preferences'),
              _item(_ProfileMenuAction.strength, Icons.insights_rounded,
                  'Profile Strength'),
              _item(
                  _ProfileMenuAction.safety, Icons.shield_outlined, 'Safety'),
              _item(_ProfileMenuAction.help, Icons.help_outline_rounded,
                  'Help & Support'),
              _item(_ProfileMenuAction.about, Icons.info_outline_rounded,
                  'About Conexo'),
              const PopupMenuDivider(height: 12),
              _item(_ProfileMenuAction.logout, Icons.logout_rounded, 'Logout',
                  danger: true),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single overflow-menu item (icon + label), consistently styled
  /// with generous vertical rhythm for a premium, tappable feel.
  PopupMenuItem<_ProfileMenuAction> _item(
    _ProfileMenuAction value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFE36D9D) : const Color(0xFFEAEEF9);
    return PopupMenuItem<_ProfileMenuAction>(
      value: value,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The set of actions offered by the overflow menu.
enum _ProfileMenuAction {
  editProfile,
  privacy,
  discovery,
  strength,
  safety,
  help,
  about,
  logout,
}

// ── Route ───────────────────────────────────────────────────────────────────

/// Premium route into My Profile — matches Conexo's fade + slide language for
/// a consistent feel across the Profile module.
Route<void> premiumMyProfileRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => MyProfileScreen(
      repository: repository ?? const LocalProfileRepository(),
    ),
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
