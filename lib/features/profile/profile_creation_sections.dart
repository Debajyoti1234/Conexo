import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/permission_manager.dart';
import 'profile_creation_widgets.dart';
import 'profile_data.dart';
import 'profile_validation.dart';
import 'supabase_profile_repository.dart';

// ignore_for_file: use_build_context_synchronously

/// Section widgets for the Profile Creation flow.
///
/// Every section is a thin, presentational widget that receives the current
/// [UserProfileDraft] plus an `onChanged` callback and contains NO business
/// logic — all persistence, validation, and stage progression live in the
/// screen / data / validation layers. Sections only build UI and emit an
/// updated draft.

// ── Static option pools (local, no backend) ─────────────────────────────────

const kInterestOptions = <String>[
  'Music',
  'Travel',
  'Food',
  'Fitness',
  'Photography',
  'Gaming',
  'Reading',
  'Movies',
  'Art',
  'Coding',
  'Coffee',
  'Hiking',
  'Dancing',
  'Fashion',
  'Startups',
  'Pets',
];

const kLanguageOptions = <String>[
  'English',
  'Hindi',
  'Bengali',
  'Spanish',
  'French',
  'German',
  'Japanese',
  'Tamil',
  'Telugu',
  'Marathi',
];

const kGenderOptions = <String>[
  'Woman',
  'Man',
  'Non-binary',
  'Prefer not to say',
];

const kSocialPlatforms = <String>[
  'Instagram',
  'Twitter',
  'LinkedIn',
  'Website',
];

// ── PhotosSection ────────────────────────────────────────────────────────────

class PhotosSection extends StatefulWidget {
  const PhotosSection({
    required this.draft,
    required this.onChanged,
    required this.onPhotoAdded,
    required this.onPhotoUploadUpdated,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;
  final ValueChanged<ProfilePhoto> onPhotoAdded;
  final void Function(String photoId, {String? remoteUrl, PhotoUploadStatus? uploadStatus}) onPhotoUploadUpdated;

  @override
  State<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<PhotosSection> {
  /// Ensures exactly the first photo carries `isPrimary`.
  List<ProfilePhoto> _normalizePrimary(List<ProfilePhoto> photos) {
    return [
      for (var i = 0; i < photos.length; i++)
        photos[i].copyWith(isPrimary: i == 0),
    ];
  }

  final Set<String> _inFlightUploads = {};

  Future<void> _uploadAndAddPhoto(
      XFile xfile, String prefix, BuildContext context) async {
    final currentDraft = widget.draft;
    final photoId = '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
    final photo = ProfilePhoto(
      id: photoId,
      assetPath: xfile.path,
      isPrimary: currentDraft.photos.isEmpty,
      uploadStatus: PhotoUploadStatus.uploading,
    );
    widget.onPhotoAdded(photo);
    _inFlightUploads.add(photoId);

    try {
      final storagePath = await const SupabaseProfileRepository()
          .uploadProfilePhoto(photoId, xfile);
      widget.onPhotoUploadUpdated(photoId,
          remoteUrl: storagePath,
          uploadStatus: PhotoUploadStatus.uploaded);
    } catch (_) {
      widget.onPhotoUploadUpdated(photoId,
          uploadStatus: PhotoUploadStatus.failed);
    } finally {
      _inFlightUploads.remove(photoId);
    }
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    if (!kIsWeb) {
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
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;
    await _uploadAndAddPhoto(xfile, 'camera', context);
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    if (!kIsWeb) {
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
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    await _uploadAndAddPhoto(xfile, 'gallery', context);
  }

  Future<void> _showPickerDialog(BuildContext context) async {
    if (_inFlightUploads.isNotEmpty) return;
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
    return SectionShell(
      title: 'Your photos',
      subtitle: 'Pick $kMinProfilePhotos–$kMaxProfilePhotos favorites. '
          'Your first photo is your primary.',
      completed: validatePhotos(widget.draft.photos),
      child: PhotoGrid(
        selected: widget.draft.photos,
        onAddPhoto: () => _showPickerDialog(context),
        onRemove: (index) {
          final current = [...widget.draft.photos];
          current.removeAt(index);
          widget.onChanged(widget.draft.copyWith(photos: _normalizePrimary(current)));
        },
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

class BioSection extends StatelessWidget {
  const BioSection({
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
    return SectionShell(
      title: 'Your bio',
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

class InterestsSection extends StatelessWidget {
  const InterestsSection({
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
    return SectionShell(
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

class LanguagesSection extends StatelessWidget {
  const LanguagesSection({
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
    return SectionShell(
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

class GenderSection extends StatelessWidget {
  const GenderSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionShell(
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

class DobSection extends StatelessWidget {
  const DobSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final UserProfileDraft draft;
  final ValueChanged<UserProfileDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionShell(
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

class LocationSection extends StatelessWidget {
  const LocationSection({
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
    return SectionShell(
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

class SocialLinksSection extends StatelessWidget {
  const SocialLinksSection({
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
    return SectionShell(
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

/// Optional details never block completion; they simply enrich the preview.
class OptionalDetailsSection extends StatelessWidget {
  const OptionalDetailsSection({
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
    return SectionShell(
      title: 'A little more (optional)',
      subtitle: 'These are optional and never block completion.',
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
