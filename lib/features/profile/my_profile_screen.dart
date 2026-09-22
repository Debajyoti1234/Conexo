import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/router/app_router.dart';
import '../../core/services/fcm_token_service.dart';
import '../../core/supabase/auth_service.dart';
import '../login_screen.dart';
import 'about_conexo_screen.dart';
import 'discovery_preferences_screen.dart';
import 'help_support_screen.dart';
import 'privacy_verification_screen.dart';
import 'profile_data.dart';
import 'profile_management_screen.dart'
    show premiumProfileManagementRoute;
import 'profile_photo_resolver.dart';
import 'profile_repository.dart';
import 'profile_strength_data.dart';
import 'profile_strength_screen.dart'
    show premiumProfileStrengthRoute;
import 'public_profile_data.dart';
import 'public_profile_screen.dart';
import 'public_profile_widgets.dart';
import 'safety_screen.dart'
    show premiumSafetyRoute;
import 'session_aware_profile_repository.dart';
import 'theme_settings_screen.dart'
    show premiumThemeSettingsRoute;

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

    final primaryPhoto = profile.primaryPhoto;
    final primaryPhotoUrl = primaryPhoto?.remoteUrl;
    final hasAge = profile.dateOfBirth != null;
    final age = hasAge
        ? DateTime.now().difference(profile.dateOfBirth!).inDays ~/ 365
        : null;

    return Scaffold(
      backgroundColor: context.cxCanvas,
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 96,
          ),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildAvatarSection(context, primaryPhotoUrl),
            const SizedBox(height: 16),
            _buildIdentitySection(context, profile, age, hasAge),
            const SizedBox(height: 20),
            _buildActionRow(context, profile),
            const SizedBox(height: 24),
            _buildProfileStrengthSection(context, profile),
            const SizedBox(height: 24),
            _buildPhotosSection(context, profile),
            const SizedBox(height: 24),
            _buildProfileContent(context, profile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Text(
            'You',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.cxInk,
              fontFamily: 'Fraunces',
            ),
          ),
          const Spacer(),
          _SettingsButton(onTap: _openSettings),
        ],
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SettingsSheet(
        onEditProfile: _openEditProfile,
        onPrivacy: _openPrivacy,
        onDiscovery: _openDiscoveryPreferences,
        onStrength: _openProfileStrength,
        onSafety: _openSafety,
        onHelp: _openHelpAndSupport,
        onAbout: _openAbout,
        onTheme: _openTheme,
        onLogout: _logout,
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, String? photoUrl) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6),
                  const Color(0xFF06B6D4),
                  const Color(0xFFEC4899),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cxCanvas,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatarImage(photoUrl),
            ),
          ),
          _EditBadge(onTap: _openEditProfile),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String? photoUrl) {
    if (photoUrl != null &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, image, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return image;
          return Stack(
            fit: StackFit.expand,
            children: [
              _AvatarPlaceholder(),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: image,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => _AvatarPlaceholder(),
      );
    }
    return _AvatarPlaceholder();
  }

  Widget _buildIdentitySection(
    BuildContext context,
    UserProfile profile,
    int? age,
    bool hasAge,
  ) {
    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName
        : 'Unknown';
    final titleLine = hasAge && age != null
        ? '$displayName, $age'
        : displayName;

    final occupation = profile.occupation.trim().isNotEmpty
        ? profile.occupation
        : null;
    final location = profile.location.trim().isNotEmpty
        ? profile.location
        : null;

    String? secondaryLine;
    if (occupation != null && location != null) {
      secondaryLine = '$occupation · $location';
    } else if (occupation != null) {
      secondaryLine = occupation;
    } else if (location != null) {
      secondaryLine = location;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                titleLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: context.cxInk,
                  fontFamily: 'Fraunces',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OwnerPrivacyBadge(
              visibility: profile.profileVisibility,
              onTap: _openPrivacy,
            ),
            const SizedBox(width: 6),
            OwnerVerificationBadge(
              status: profile.verificationStatus,
              onTap: _openPrivacy,
            ),
          ],
        ),
        if (secondaryLine != null) ...[
          const SizedBox(height: 6),
          Text(
            secondaryLine,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.cxSoft,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _PrimaryActionPill(
              label: 'Edit Profile',
              icon: Icons.edit_outlined,
              onTap: _openEditProfile,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SecondaryActionPill(
              label: 'Preview',
              icon: Icons.visibility_outlined,
              onTap: _openPreview,
            ),
          ),
        ],
      ),
    );
  }

  void _openPreview() {
    Navigator.of(context).push(
      AppRouter.premiumProfileRoute(
        PublicProfileScreen(
          data: PublicProfileViewData(
            profile: _profile!,
            displayName: _profile!.displayName,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStrengthSection(BuildContext context, UserProfile profile) {
    final strength = computeProfileStrength(profile);
    final percentage = (strength.completionPercentage * 100).round();
    final light = Theme.of(context).brightness == Brightness.light;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: _openProfileStrength,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: light ? Colors.white : const Color(0xFF182039),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: light ? context.cxInk.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: light ? 0.03 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile strength',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.cxInk,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.cxInk,
                      fontFamily: 'Fraunces',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: light ? context.cxInk.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: strength.completionPercentage.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: light
                              ? [const Color(0xFF6A3FBF), const Color(0xFF8B5CF6)]
                              : [const Color(0xFF8B5CF6), const Color(0xFF9D82FF)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              if (strength.suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strength.suggestions.first,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cxSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'About', icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _buildAboutCard(context, profile),
          _gap(profile.bio.trim().isNotEmpty || profile.aboutMe.trim().isNotEmpty),
          _SectionTitle(title: 'Interests', icon: Icons.interests_rounded),
          const SizedBox(height: 12),
          _buildInterestsCard(context, profile),
          _gap(profile.interests.isNotEmpty),
          _SectionTitle(title: 'Languages', icon: Icons.translate_rounded),
          const SizedBox(height: 12),
          _buildLanguagesCard(context, profile),
          _gap(profile.languages.isNotEmpty),
          _SectionTitle(title: 'Details', icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
          _buildOptionalDetailsCard(context, profile),
          _gap(_hasOptionalDetails(profile)),
          _SectionTitle(title: 'Social', icon: Icons.link_rounded),
          const SizedBox(height: 12),
          _buildSocialLinksCard(context, profile),
        ],
      ),
    );
  }

  bool _hasOptionalDetails(UserProfile profile) {
    return profile.location.trim().isNotEmpty ||
        profile.education.trim().isNotEmpty ||
        profile.college.trim().isNotEmpty ||
        profile.company.trim().isNotEmpty ||
        profile.hometown.trim().isNotEmpty ||
        profile.website.trim().isNotEmpty ||
        profile.favoriteActivities.isNotEmpty;
  }

  Widget _buildAboutCard(BuildContext context, UserProfile profile) {
    final hasBio = profile.bio.trim().isNotEmpty;
    final hasAboutMe = profile.aboutMe.trim().isNotEmpty;
    if (!hasBio && !hasAboutMe) return const SizedBox.shrink();

    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBio)
            Text(
              profile.bio.trim(),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: context.cxInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (hasBio && hasAboutMe) const SizedBox(height: 10),
          if (hasAboutMe)
            Text(
              profile.aboutMe.trim(),
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: context.cxSoft,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInterestsCard(BuildContext context, UserProfile profile) {
    if (profile.interests.isEmpty) return const SizedBox.shrink();
    return _ProfileCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final interest in profile.interests)
            _InterestChip(label: interest),
        ],
      ),
    );
  }

  Widget _buildLanguagesCard(BuildContext context, UserProfile profile) {
    if (profile.languages.isEmpty) return const SizedBox.shrink();
    return _ProfileCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final lang in profile.languages)
            _InterestChip(label: lang, icon: Icons.translate_rounded),
        ],
      ),
    );
  }

  Widget _buildOptionalDetailsCard(
    BuildContext context,
    UserProfile profile,
  ) {
    final rows = <_OptionalInfoRow>[
      if (profile.location.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.place_outlined,
          label: 'Location',
          value: profile.location.trim(),
        ),
      if (profile.education.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.school_outlined,
          label: 'Education',
          value: profile.education.trim(),
        ),
      if (profile.college.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.account_balance_outlined,
          label: 'College',
          value: profile.college.trim(),
        ),
      if (profile.company.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.business_outlined,
          label: 'Company',
          value: profile.company.trim(),
        ),
      if (profile.hometown.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.home_outlined,
          label: 'Hometown',
          value: profile.hometown.trim(),
        ),
      if (profile.website.trim().isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.language_rounded,
          label: 'Website',
          value: profile.website.trim(),
        ),
      if (profile.favoriteActivities.isNotEmpty)
        _OptionalInfoRow(
          icon: Icons.local_activity_outlined,
          label: 'Favorite activities',
          value: profile.favoriteActivities.join(', '),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _ProfileCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 14),
              child: _OptionalRow(row: rows[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksCard(BuildContext context, UserProfile profile) {
    final visible = [
      for (final l in profile.socialLinks)
        if (l.url.trim().isNotEmpty || l.displayText.trim().isNotEmpty) l,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();
    return _ProfileCard(
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == visible.length - 1 ? 0 : 12),
              child: _SocialLinkRow(link: visible[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context, UserProfile profile) {
    if (profile.photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your photos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
          const SizedBox(height: 16),
          _PhotosCard(photos: profile.photos),
        ],
      ),
    );
  }

Widget _gap(bool precedingVisible) =>
      precedingVisible ? const SizedBox(height: 20) : const SizedBox.shrink();
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

// ── Helper widgets ──────────────────────────────────────────────────────────────

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.cxAccent, context.cxAccent],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 56,
          color: Colors.white24,
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: light ? Colors.white : const Color(0xFF171F35),
      shape: const CircleBorder(),
      elevation: light ? 4 : 8,
      shadowColor: Colors.black.withValues(alpha: light ? 0.12 : 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.settings_rounded,
            size: 22,
            color: light ? context.cxInk : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.onEditProfile,
    required this.onPrivacy,
    required this.onDiscovery,
    required this.onStrength,
    required this.onSafety,
    required this.onHelp,
    required this.onAbout,
    required this.onTheme,
    required this.onLogout,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onPrivacy;
  final VoidCallback onDiscovery;
  final VoidCallback onStrength;
  final VoidCallback onSafety;
  final VoidCallback onHelp;
  final VoidCallback onAbout;
  final VoidCallback onTheme;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: light ? context.cxCanvas : const Color(0xFF0B1020),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.cxLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SheetItem(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () { Navigator.pop(context); onEditProfile(); },
              ),
              _SheetItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy & Verification',
                onTap: () { Navigator.pop(context); onPrivacy(); },
              ),
              _SheetItem(
                icon: Icons.tune_rounded,
                label: 'Discovery Preferences',
                onTap: () { Navigator.pop(context); onDiscovery(); },
              ),
              _SheetItem(
                icon: Icons.insights_rounded,
                label: 'Profile Strength',
                onTap: () { Navigator.pop(context); onStrength(); },
              ),
              _SheetItem(
                icon: Icons.shield_outlined,
                label: 'Safety',
                onTap: () { Navigator.pop(context); onSafety(); },
              ),
              _SheetItem(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () { Navigator.pop(context); onHelp(); },
              ),
              _SheetItem(
                icon: Icons.info_outline_rounded,
                label: 'About Conexo',
                onTap: () { Navigator.pop(context); onAbout(); },
              ),
              _SheetItem(
                icon: Icons.brightness_6_outlined,
                label: 'Theme / Appearance',
                onTap: () { Navigator.pop(context); onTheme(); },
              ),
              const Divider(height: 32),
              _SheetItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                danger: true,
                onTap: () { Navigator.pop(context); onLogout(); },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.cxDanger : context.cxInk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cxInk,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.edit_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _PrimaryActionPill extends StatelessWidget {
  const _PrimaryActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: light ? context.cxInk : context.cxAccent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionPill extends StatelessWidget {
  const _SecondaryActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: light ? context.cxSurface : const Color(0xFF171F35),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: light ? context.cxInk : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: light ? context.cxInk : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: context.cxInk),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: context.cxInk,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFFFFFFF) : const Color(0xFF182039),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: light ? context.cxInk.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.04 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: light ? context.cxInk.withValues(alpha: 0.05) : context.cxInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.cxLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: context.cxSoft),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalInfoRow {
  const _OptionalInfoRow({
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
  final _OptionalInfoRow row;

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
            color: context.cxInk.withValues(alpha: 0.06),
            border: Border.all(color: context.cxInk.withValues(alpha: 0.1)),
          ),
          child: Icon(row.icon, size: 17, color: context.cxSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cxSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.cxInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialLinkRow extends StatelessWidget {
  const _SocialLinkRow({required this.link});
  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    final display = link.displayText.trim().isNotEmpty
        ? link.displayText.trim()
        : link.url.trim();
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [context.cxAccent, context.cxAccent]),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cxSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.cxInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.photos});
  final List<ProfilePhoto> photos;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: light ? Colors.white : const Color(0xFF182039),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: light ? context.cxInk.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.03 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < photos.length; i++) ...[
              _PhotoTile(photo: photos[i]),
              if (i < photos.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final ProfilePhoto photo;

  @override
  Widget build(BuildContext context) {
    final photoUrl = photo.remoteUrl;
    // 3:4 portrait aspect ratio
    const double tileWidth = 140;
    const double tileHeight = tileWidth * 4 / 3;
    
    return SizedBox(
      width: tileWidth,
      height: tileHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null &&
                (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')))
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              _AvatarPlaceholder(),
            if (photo.isPrimary)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.cxAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
