import 'package:flutter/material.dart';

import '../../core/services/permission_manager.dart';
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
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

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

  void _remove(int index) {
    final current = [...draft.photos];
    current.removeAt(index);
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

  Future<void> _pickFromCamera(BuildContext context) async {
    final status = await PermissionManager.check(PermissionType.camera);
    if (status == PermissionStatus.permanentlyDenied) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
              'Camera permission has been permanently denied. Please enable it in app settings.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings')),
          ],
        ),
      );
      if (open == true) await PermissionManager.openAppSettings();
      return;
    }
    if (status != PermissionStatus.granted) {
      final result =
          await PermissionManager.request(PermissionType.camera);
      if (result != PermissionStatus.granted) return;
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    final photo = ProfilePhoto(
      id: 'camera_${DateTime.now().millisecondsSinceEpoch}',
      assetPath: xfile.path,
      isPrimary: draft.photos.isEmpty,
    );
    onChanged(draft.copyWith(photos: [...draft.photos, photo]));
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final status = await PermissionManager.check(PermissionType.photos);
    if (status == PermissionStatus.permanentlyDenied) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photos Permission Required'),
          content: const Text(
              'Photos permission has been permanently denied. Please enable it in app settings.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings')),
          ],
        ),
      );
      if (open == true) await PermissionManager.openAppSettings();
      return;
    }
    if (status != PermissionStatus.granted) {
      final result =
          await PermissionManager.request(PermissionType.photos);
      if (result != PermissionStatus.granted) return;
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    final photo = ProfilePhoto(
      id: 'gallery_${DateTime.now().millisecondsSinceEpoch}',
      assetPath: xfile.path,
      isPrimary: draft.photos.isEmpty,
    );
    onChanged(draft.copyWith(photos: [...draft.photos, photo]));
  }

  Future<void> _showPickerDialog(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF131A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                const SizedBox(height: 12),
                _PickerOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == 'camera') {
      await _pickFromCamera(context);
    } else if (choice == 'gallery') {
      await _pickFromGallery(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Photos',
      subtitle: 'Reorder, remove, or add local portraits. '
          'Your first photo is always primary.',
      completed: validatePhotos(draft.photos),
      child: PhotoGrid(
        selected: draft.photos,
        onAddPhoto: () => _showPickerDialog(context),
        onRemove: _remove,
        onReorder: _reorder,
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: .1),
            width: 1,
          ),
          color: Colors.white.withValues(alpha: .06),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFFB9C3DC)),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB9C3DC),
              ),
            ),
          ],
        ),
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

// ── DateOfBirthSection ───────────────────────────────────────────────────────

class ManageDobSection extends StatelessWidget {
  const ManageDobSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ManagementSection(
      title: 'Date of Birth',
      subtitle: 'You must be at least 18 years old. Future dates are not allowed.',
      completed: validateDateOfBirth(draft.dateOfBirth),
      child: DateOfBirthField(
        value: draft.dateOfBirth,
        onChanged: (d) => onChanged(draft.copyWith(dateOfBirth: d)),
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
      subtitle: 'Tap to use your current location, or type it.',
      completed: draft.location.trim().isNotEmpty,
        child: LocationDetectField(
          controller: controller,
          onLocationNameChanged: (v) => onChanged(draft.copyWith(location: v)),
          onLocationDetected: (name, lat, lng) => onChanged(
            draft.copyWith(
              location: name ?? draft.location,
              latitude: lat,
              longitude: lng,
            ),
          ),
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
    required this.displayNameController,
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final TextEditingController occupationController;
  final TextEditingController collegeController;
  final TextEditingController hometownController;
  final TextEditingController displayNameController;
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
            controller: displayNameController,
            hint: 'Display name',
            icon: Icons.person_outline_rounded,
            onChanged: (v) => onChanged(draft.copyWith(displayName: v)),
          ),
          const SizedBox(height: 12),
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
