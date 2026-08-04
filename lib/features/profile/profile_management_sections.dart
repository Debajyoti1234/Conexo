import 'package:flutter/material.dart';

import 'profile_creation_sections.dart'
    show
        kInterestOptions,
        kLanguageOptions,
        kGenderOptions,
        kSocialPlatforms;
import 'profile_creation_widgets.dart';
import 'profile_data.dart';
import 'profile_management_widgets.dart';
import 'profile_validation.dart';

/// Inline-edit sections for Phase 4.2 — Profile Management.
///
/// Every section is a thin, presentational widget receiving the current
/// [UserProfileDraft] plus an `onChanged` callback and contains NO business
/// logic. They compose the Phase 4.1 reusable widgets (`PhotoGrid`,
/// `GlassTextField`, `MultiChipField`, `GenderSelector`, `SocialLinkField`) and
/// reuse the same option pools. Unlike creation, all sections are visible at
/// once (edit mode), so they use [ManagementSectionHeader] instead of the
/// progressive `SectionShell`.

/// Wraps a section header + body with consistent management spacing.
class _ManagementSection extends StatelessWidget {
  const _ManagementSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.completed = false,
  });

  final String title;
  final String? subtitle;
  final bool completed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ManagementSectionHeader(
            title: title,
            subtitle: subtitle,
            completed: completed,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── PhotosSection ────────────────────────────────────────────────────────────

class ManagePhotosSection extends StatelessWidget {
  const ManagePhotosSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  void _toggle(String asset) {
    final current = [...draft.photos];
    final existingIndex = current.indexWhere((p) => p.assetPath == asset);
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
    } else {
      if (current.length >= kMaxProfilePhotos) return;
      current.add(ProfilePhoto(id: asset, assetPath: asset));
    }
    onChanged(draft.copyWith(photos: _normalizePrimary(current)));
  }

  void _reorder(int oldIndex, int newIndex) {
    final current = [...draft.photos];
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    onChanged(draft.copyWith(photos: _normalizePrimary(current)));
  }

  /// Enforces exactly one primary photo: after any reorder/delete the first
  /// photo becomes primary and all others are not. If the primary was removed,
  /// the first remaining photo therefore becomes primary automatically.
  List<ProfilePhoto> _normalizePrimary(List<ProfilePhoto> photos) {
    return [
      for (var i = 0; i < photos.length; i++)
        photos[i].copyWith(isPrimary: i == 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Photos',
      subtitle: 'Reorder, remove, or add local portraits. '
          'Your first photo is always primary.',
      completed: validatePhotos(draft.photos),
      child: PhotoGrid(
        gallery: profilePhotoGallery,
        selected: draft.photos,
        onToggle: _toggle,
        onReorder: _reorder,
      ),
    );
  }
}

// ── BioSection ───────────────────────────────────────────────────────────────

class ManageBioSection extends StatelessWidget {
  const ManageBioSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Bio',
      subtitle: 'A short line that captures your vibe.',
      completed: validateBio(draft.bio),
      child: GlassTextField(
        controller: controller,
        hint: 'e.g. Coffee-fueled designer who loves weekend hikes.',
        icon: Icons.edit_outlined,
        maxLines: 3,
        maxLength: 160,
        onChanged: (v) => onChanged(draft.copyWith(bio: v)),
      ),
    );
  }
}

// ── InterestsSection ─────────────────────────────────────────────────────────

class ManageInterestsSection extends StatelessWidget {
  const ManageInterestsSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  void _toggle(String interest) {
    final current = [...draft.interests];
    if (current.contains(interest)) {
      current.remove(interest);
    } else {
      current.add(interest);
    }
    onChanged(draft.copyWith(interests: current));
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Interests',
      subtitle: 'Choose at least $kMinInterests.',
      completed: validateInterests(draft.interests),
      child: MultiChipField(
        options: kInterestOptions,
        selected: draft.interests,
        onToggle: _toggle,
      ),
    );
  }
}

// ── LanguagesSection ─────────────────────────────────────────────────────────

class ManageLanguagesSection extends StatelessWidget {
  const ManageLanguagesSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  void _toggle(String language) {
    final current = [...draft.languages];
    if (current.contains(language)) {
      current.remove(language);
    } else {
      current.add(language);
    }
    onChanged(draft.copyWith(languages: current));
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Languages',
      subtitle: 'Choose at least $kMinLanguages.',
      completed: validateLanguages(draft.languages),
      child: MultiChipField(
        options: kLanguageOptions,
        selected: draft.languages,
        onToggle: _toggle,
      ),
    );
  }
}

// ── GenderSection ────────────────────────────────────────────────────────────

class ManageGenderSection extends StatelessWidget {
  const ManageGenderSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Gender',
      subtitle: 'How you identify.',
      completed: draft.gender.trim().isNotEmpty,
      child: GenderSelector(
        options: kGenderOptions,
        value: draft.gender,
        onSelected: (v) => onChanged(draft.copyWith(gender: v)),
      ),
    );
  }
}

// ── LocationSection ──────────────────────────────────────────────────────────

class ManageLocationSection extends StatelessWidget {
  const ManageLocationSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Location',
      subtitle: 'Where you are based.',
      completed: draft.location.trim().isNotEmpty,
      child: GlassTextField(
        controller: controller,
        hint: 'e.g. Bengaluru, India',
        icon: Icons.location_on_outlined,
        onChanged: (v) => onChanged(draft.copyWith(location: v)),
      ),
    );
  }
}

// ── SocialLinksSection ───────────────────────────────────────────────────────

class ManageSocialLinksSection extends StatelessWidget {
  const ManageSocialLinksSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  SocialLink get _link => draft.socialLinks.isNotEmpty
      ? draft.socialLinks.first
      : const SocialLink(
          platform: 'Instagram',
          displayText: '',
          url: '',
        );

  void _setPlatform(String platform) {
    final link = _link.copyWith(platform: platform);
    onChanged(draft.copyWith(socialLinks: [link]));
  }

  void _setUrl(String url) {
    final link = _link.copyWith(url: url, displayText: url);
    onChanged(draft.copyWith(socialLinks: [link]));
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Social link',
      subtitle: 'Add at least one so people can connect.',
      completed: validateSocialLinks(draft.socialLinks),
      child: SocialLinkField(
        platforms: kSocialPlatforms,
        platform: _link.platform,
        controller: controller,
        onPlatformChanged: _setPlatform,
        onUrlChanged: _setUrl,
      ),
    );
  }
}

// ── OptionalDetailsSection ───────────────────────────────────────────────────

class ManageOptionalDetailsSection extends StatelessWidget {
  const ManageOptionalDetailsSection({
    required this.occupationController,
    required this.collegeController,
    required this.hometownController,
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final TextEditingController occupationController;
  final TextEditingController collegeController;
  final TextEditingController hometownController;
  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Optional details',
      subtitle: 'These are optional and never block saving.',
      child: Column(
        children: [
          GlassTextField(
            controller: occupationController,
            hint: 'Occupation',
            icon: Icons.work_outline_rounded,
            onChanged: (v) => onChanged(draft.copyWith(occupation: v)),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: collegeController,
            hint: 'College',
            icon: Icons.school_outlined,
            onChanged: (v) => onChanged(draft.copyWith(college: v)),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: hometownController,
            hint: 'Hometown',
            icon: Icons.home_outlined,
            onChanged: (v) => onChanged(draft.copyWith(hometown: v)),
          ),
        ],
      ),
    );
  }
}
