import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/router/app_router.dart';
import '../../core/services/fcm_token_service.dart';
import '../../core/supabase/auth_service.dart';
import '../home_discovery_animations.dart';
import '../login_screen.dart';
import 'about_conexo_screen.dart';
import 'discovery_preferences_screen.dart';
import 'help_support_screen.dart';
import 'privacy_verification_screen.dart';
import 'profile_data.dart';
import 'profile_management_screen.dart';
import 'profile_navigation_mapper.dart';
import 'profile_photo_resolver.dart';
import 'profile_repository.dart';
import 'profile_strength_screen.dart';
import 'public_profile_sections.dart';
import 'safety_screen.dart';
import 'session_aware_profile_repository.dart';
import 'theme_settings_screen.dart';

/// The premium **My Profile** screen — the default destination of the Profile
/// tab once a profile exists.
///
/// It renders the canonical Public Profile view inline (same hero, same
/// sections, same spacing, same alignment) using the current user's
/// [UserProfile], and overlays the existing 3-dot menu for owner-only actions.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

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

    UserProfile? resolved = profile;
    if (resolved != null) {
      final storagePaths = resolved.photos
          .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
          .map((p) => p.remoteUrl!)
          .toList();

      if (storagePaths.isNotEmpty) {
        final resolver = ProfilePhotoResolver.instance;
        final futures = storagePaths.map((p) => resolver.resolvePhoto(p)).toList();
        final signedResults = await Future.wait(futures);

        final updatedPhotos = [...resolved.photos];
        for (var i = 0; i < updatedPhotos.length; i++) {
          final remoteUrl = updatedPhotos[i].remoteUrl;
          if (remoteUrl != null && remoteUrl.startsWith('profiles/')) {
            final idx = storagePaths.indexOf(remoteUrl);
            if (idx != -1) {
              updatedPhotos[i] = updatedPhotos[i].copyWith(remoteUrl: signedResults[idx].signedUrl);
            }
          }
        }
        resolved = resolved.copyWith(photos: updatedPhotos);
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = resolved;
      _loading = false;
    });

    if (resolved != null) {
      for (final photo in resolved.photos) {
        final url = photo.remoteUrl;
        if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
          precacheImage(NetworkImage(url), context);
        }
      }
    }
  }

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

  void _openHelpAndSupport() {
    Navigator.of(context).push(
      premiumHelpSupportRoute(),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      premiumAboutConexoRoute(),
    );
  }

  void _openTheme() {
    Navigator.of(context).push(
      premiumThemeSettingsRoute(),
    );
  }

  void _logout() async {
    try {
      // Remove this device's token association WHILE the session is still
      // valid, so the RLS-protected delete is authorized. After signOut the
      // session is gone and the delete would silently affect zero rows,
      // leaving this account able to receive notifications on a device that
      // has switched to another user.
      await FcmTokenService.stop();
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppRouter.slideRoute(const LoginScreen()),
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
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
      case _ProfileMenuAction.theme:
        _openTheme();
      case _ProfileMenuAction.logout:
        _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.cxCanvas,
        body: Center(
          child: CircularProgressIndicator(color: context.cxInk),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: context.cxCanvas,
        body: Center(
          child: Text(
            'No profile found',
            style: TextStyle(color: context.cxSoft),
          ),
        ),
      );
    }

    final data = mapUserProfileToPublicProfile(profile);

    return Scaffold(
      backgroundColor: context.cxCanvas,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 100,
            ),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              RepaintBoundary(
                child: HeroSection(
                  data: data,
                  owner: true,
                  onOpenPrivacyVerification: _openPrivacy,
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
                      child: MutualInterestsSection(mutual: const []),
                    ),
                    _gap(false),
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
      precedingVisible ? const SizedBox(height: 20) : const SizedBox.shrink();
}

class _OverflowMenuButton extends StatelessWidget {
  const _OverflowMenuButton({required this.onSelected});

  final ValueChanged<_ProfileMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 14,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: .38),
          border: Border.all(color: context.cxInk.withValues(alpha: .16)),
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
            color: light ? context.cxSurface : const Color(0xFF171F35),
            elevation: light ? 8 : 12,
            shadowColor: Colors.black.withValues(alpha: light ? .16 : .5),
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(light ? 16 : 18),
              side: BorderSide(
                color: light
                    ? context.cxInk.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .08),
              ),
            ),
            onSelected: onSelected,
            itemBuilder: (context) => [
              _item(context, _ProfileMenuAction.editProfile, Icons.edit_outlined,
                  'Edit Profile'),
              _item(context, _ProfileMenuAction.privacy, Icons.privacy_tip_outlined,
                  'Privacy & Verification'),
              _item(context, _ProfileMenuAction.discovery, Icons.tune_rounded,
                  'Discovery Preferences'),
              _item(context, _ProfileMenuAction.strength, Icons.insights_rounded,
                  'Profile Strength'),
              _item(
                  context, _ProfileMenuAction.safety, Icons.shield_outlined, 'Safety'),
              _item(context, _ProfileMenuAction.help, Icons.help_outline_rounded,
                  'Help & Support'),
              _item(context, _ProfileMenuAction.about, Icons.info_outline_rounded,
                  'About Conexo'),
              _item(context, _ProfileMenuAction.theme, Icons.brightness_6_outlined,
                  'Theme / Appearance'),
              const PopupMenuDivider(height: 12),
              _item(context, _ProfileMenuAction.logout, Icons.logout_rounded, 'Logout',
                  danger: true),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_ProfileMenuAction> _item(
    BuildContext context,
    _ProfileMenuAction value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? context.cxDanger : context.cxInk;
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

enum _ProfileMenuAction {
  editProfile,
  privacy,
  discovery,
  strength,
  safety,
  help,
  about,
  theme,
  logout,
}

Route<void> premiumMyProfileRoute({ProfileRepository? repository}) {
  return AppRouter.premiumProfileRoute(
    MyProfileScreen(
      repository: repository ?? const SessionAwareProfileRepository(),
    ),
  );
}

Route<void> premiumHelpSupportRoute() {
  return AppRouter.premiumProfileRoute(const HelpSupportScreen());
}

Route<void> premiumAboutConexoRoute() {
  return AppRouter.premiumProfileRoute(const AboutConexoScreen());
}
