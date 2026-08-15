import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_data.dart';
import 'profile_management_sections.dart';
import 'profile_management_widgets.dart';
import 'profile_repository.dart';
import 'session_aware_profile_repository.dart';
import 'supabase_profile_repository.dart';
import '../../core/services/permission_manager.dart';
import 'package:image_picker/image_picker.dart';


/// The premium Profile Management flow (Phase 4.2).
///
/// Loads the finalized [UserProfile] through the injected [ProfileRepository],
/// exposes every field for inline editing, keeps an immutable "original" draft
/// for pure dirty-detection, and saves back through the repository only when
/// something actually changed. A subtle success overlay plays after saving and
/// a premium glass dialog guards against leaving with unsaved changes.
///
/// This screen contains only UI + flow orchestration. Models, validation, and
/// persistence live in their own files. Local-only — no Firebase / backend /
/// navigation changes. The preview is the shared [ProfilePreviewCard]; no new
/// preview implementation exists here.
class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

  /// Injected repository (defaults to the local implementation). A future
  /// backend repository can be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _socialController = TextEditingController();
  final _occupationController = TextEditingController();
  final _collegeController = TextEditingController();
  final _hometownController = TextEditingController();
  final _displayNameController = TextEditingController();

  /// The identity of the loaded profile — never regenerated on save.
  String _profileId = '';

  /// The immutable snapshot loaded from the repository, used for pure
  /// dirty-detection via [profileDraftEquals]. Never mutated after load.
  UserProfileDraft _original = const UserProfileDraft();

  /// The live, editable working draft.
  UserProfileDraft _draft = const UserProfileDraft();

  bool _loading = true;
  bool _notFound = false;
  bool _saving = false;
  bool _saved = false;
  final Set<String> _inFlightUploads = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    _socialController.dispose();
    _occupationController.dispose();
    _collegeController.dispose();
    _hometownController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    final draft = UserProfileDraft.fromProfile(profile);
    _bioController.text = draft.bio;
    _locationController.text = draft.location;
    if (draft.socialLinks.isNotEmpty) {
      _socialController.text = draft.socialLinks.first.url;
    }
    _occupationController.text = draft.occupation;
    _collegeController.text = draft.college;
    _hometownController.text = draft.hometown;
    _displayNameController.text = draft.displayName;
    setState(() {
      _profileId = profile.id;
      _original = draft;
      _draft = draft;
      _loading = false;
    });
  }

  /// True when the working draft differs from the loaded original.
  bool get _isDirty => !profileDraftEquals(_draft, _original);

  /// The Save CTA is enabled only when the draft is valid AND has changes.
  bool get _canSave => _draft.isComplete && _isDirty;

  void _onDraftChanged(UserProfileDraft draft) {
    setState(() => _draft = draft);
  }

  void _onPhotoAdded(ProfilePhoto photo) {
    setState(() {
      _draft = _draft.copyWith(photos: [..._draft.photos, photo]);
    });
  }

  void _onPhotoUploadUpdated(String photoId,
      {String? remoteUrl, PhotoUploadStatus? uploadStatus}) {
    final currentPhotos = [..._draft.photos];
    final index = currentPhotos.indexWhere((p) => p.id == photoId);
    if (index == -1) return;
    currentPhotos[index] = currentPhotos[index].copyWith(
      remoteUrl: remoteUrl ?? currentPhotos[index].remoteUrl,
      uploadStatus: uploadStatus ?? currentPhotos[index].uploadStatus,
    );
    setState(() {
      _draft = _draft.copyWith(photos: currentPhotos);
    });
  }

  Future<void> _replacePhoto(int index) async {
    if (_inFlightUploads.isNotEmpty) return;
    final old = _draft.photos[index];

    if (!kIsWeb) {
      final status = await PermissionManager.check(PermissionType.photos);
      if (status != PermissionStatus.granted) {
        final result =
            await PermissionManager.request(PermissionType.photos);
        if (result != PermissionStatus.granted) return;
      }
    }

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    await _uploadAndReplace(index, old, xfile);
  }

  Future<void> _uploadAndReplace(
      int index, ProfilePhoto old, XFile xfile) async {
    final draftSnapshot = _draft;
    final photoId = 'replace_${DateTime.now().millisecondsSinceEpoch}';
    final replacement = ProfilePhoto(
      id: photoId,
      assetPath: xfile.path,
      isPrimary: old.isPrimary,
      uploadStatus: PhotoUploadStatus.uploading,
    );

    final updated = [...draftSnapshot.photos];
    updated[index] = replacement;
    final newStatus = old.isPrimary
        ? VerificationStatus.notVerified
        : draftSnapshot.verificationStatus;
    setState(() => _draft = draftSnapshot.copyWith(
          photos: updated,
          verificationStatus: newStatus,
        ));
    _inFlightUploads.add(photoId);

    try {
      final storagePath = await const SupabaseProfileRepository()
          .uploadProfilePhoto(photoId, xfile);
      final updated = _draft.photos.map((p) {
        if (p.id == photoId) {
          return p.copyWith(
            remoteUrl: storagePath,
            uploadStatus: PhotoUploadStatus.uploaded,
          );
        }
        return p;
      }).toList();
      setState(() => _draft = _draft.copyWith(photos: updated));
    } catch (_) {
      final updated = _draft.photos.map((p) {
        if (p.id == photoId) {
          return p.copyWith(uploadStatus: PhotoUploadStatus.failed);
        }
        return p;
      }).toList();
      setState(() => _draft = _draft.copyWith(photos: updated));
    } finally {
      _inFlightUploads.remove(photoId);
    }
  }

  /// Persists the working draft, preserving id + createdAt (only updatedAt
  /// changes). No-ops (without writing) when nothing changed.
  Future<bool> _save() async {
    if (_saving) return false;
    if (!_isDirty) return true; // Nothing to write.
    if (!_draft.isComplete) return false;

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final profile = UserProfile.fromDraft(_draft, id: _profileId);
    try {
      await widget.repository.saveProfile(profile);
    } catch (_) {
      final newRemote = _draft.photos
          .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
          .map((p) => p.remoteUrl!)
          .toSet();
      final oldRemote = _original.photos
          .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
          .map((p) => p.remoteUrl!)
          .toSet();
      final newObjects = newRemote.difference(oldRemote);
      for (final path in newObjects) {
        try {
          await const SupabaseProfileRepository().deleteProfilePhoto(path);
        } catch (_) {}
      }
      if (!mounted) return false;
      setState(() => _saving = false);
      rethrow;
    }

    final originalRemote = _original.photos
        .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
        .map((p) => p.remoteUrl!)
        .toSet();
    final currentRemote = _draft.photos
        .where((p) => p.remoteUrl != null && p.remoteUrl!.startsWith('profiles/'))
        .map((p) => p.remoteUrl!)
        .toSet();
    final toDelete = originalRemote.difference(currentRemote);
    if (toDelete.isNotEmpty) {
      final storageRepo = const SupabaseProfileRepository();
      for (final path in toDelete) {
        try {
          await storageRepo.deleteProfilePhoto(path);
        } catch (_) {
          // best-effort cleanup
        }
      }
    }

    if (!mounted) return false;

    setState(() {
      _original = _draft;
      _saving = false;
      _saved = true;
    });
    return true;
  }

  /// Saves via the CTA, then shows the success overlay and closes.
  Future<void> _saveAndFinish() async {
    final ok = await _save();
    if (!ok || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  /// Handles a back gesture / button when there may be unsaved changes.
  Future<void> _handlePop() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final result = await UnsavedChangesDialog.show(
      context,
      saveEnabled: _draft.isComplete,
    );
    if (!mounted || result == null) return;
    switch (result) {
      case UnsavedChangesResult.cancel:
        return; // Stay on screen.
      case UnsavedChangesResult.discard:
        Navigator.of(context).pop();
      case UnsavedChangesResult.save:
        final ok = await _save();
        if (ok && mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: kIsWeb ? Colors.black : Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              _buildBody(),
              if (!_loading && !_notFound)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: SaveChangesButton(
                    enabled: _canSave,
                    loading: _saving,
                    onTap: _saveAndFinish,
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: _saved
                    ? const SaveSuccessOverlay()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }
    if (_notFound) {
      return _EmptyState(onBack: () => Navigator.of(context).maybePop());
    }
    return _buildForm();
  }

  Widget _buildForm() {
    final d = _draft;
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        _header(),
        ManagePhotosSection(
          draft: d,
          onChanged: _onDraftChanged,
          onReplace: _replacePhoto,
          onPhotoAdded: _onPhotoAdded,
          onPhotoUploadUpdated: _onPhotoUploadUpdated,
        ),
        ManageBioSection(
          controller: _bioController,
          draft: d,
          onChanged: _onDraftChanged,
        ),
        ManageInterestsSection(draft: d, onChanged: _onDraftChanged),
        ManageLanguagesSection(draft: d, onChanged: _onDraftChanged),
        ManageGenderSection(draft: d, onChanged: _onDraftChanged),
        ManageDobSection(draft: d, onChanged: _onDraftChanged),
        ManageLocationSection(
          controller: _locationController,
          draft: d,
          onChanged: _onDraftChanged,
        ),
        ManageSocialLinksSection(
          controller: _socialController,
          draft: d,
          onChanged: _onDraftChanged,
        ),
        ManageOptionalDetailsSection(
          occupationController: _occupationController,
          collegeController: _collegeController,
          hometownController: _hometownController,
          displayNameController: _displayNameController,
          draft: d,
          onChanged: _onDraftChanged,
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
      child: Row(
        children: [
          IconButton(
            onPressed: _handlePop,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit your profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Update anything, anytime.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (no saved profile) ──────────────────────────────────────────


class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EntranceFade(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 56,
                color: Color(0xFFB9C3DC),
              ),
              const SizedBox(height: 16),
              const Text(
                'No profile yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your profile first, then you can edit it here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Route (matches Conexo's premium fade + slide transition) ────────────────

/// Premium route into the Profile Management flow.
///
/// Uses the same fade + slide transition language as
/// `premiumProfileCreationRoute()` / `premiumPlanRoute()` for a consistent
/// feel across Conexo.
Route<void> premiumProfileManagementRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ProfileManagementScreen(
      repository: repository ?? const SessionAwareProfileRepository(),
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
