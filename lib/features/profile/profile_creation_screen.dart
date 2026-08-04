import 'dart:async';

import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_creation_sections.dart';
import 'profile_creation_widgets.dart';
import 'profile_data.dart';
import 'profile_repository.dart';

/// The premium Profile Creation flow (Phase 4.1).
///
/// A guided, progressive experience: sections reveal one at a time as the prior
/// required field is completed, a live preview evolves continuously, the draft
/// auto-saves (debounced) to the injected [ProfileRepository], and completing
/// plays a calm success animation before fading back.
///
/// This screen contains only UI + flow orchestration. Models, validation, and
/// persistence live in their own files. Local-only — no Firebase / backend /
/// navigation changes.
class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({
    super.key,
    this.repository = const LocalProfileRepository(),
  });

  /// Injected repository (defaults to the local implementation). A future
  /// backend repository can be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _socialController = TextEditingController();
  final _occupationController = TextEditingController();
  final _collegeController = TextEditingController();
  final _hometownController = TextEditingController();

  UserProfileDraft _draft = const UserProfileDraft();
  UserProfileDraft? _restorableDraft;
  bool _showRestorePrompt = false;

  bool _saving = false;
  bool _completed = false;

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _checkForDraft();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _bioController.dispose();
    _locationController.dispose();
    _socialController.dispose();
    _occupationController.dispose();
    _collegeController.dispose();
    _hometownController.dispose();
    super.dispose();
  }

  Future<void> _checkForDraft() async {
    final saved = await widget.repository.loadDraft();
    if (!mounted) return;
    final hasContent = saved != null &&
        (saved.photos.isNotEmpty ||
            saved.bio.isNotEmpty ||
            saved.interests.isNotEmpty);
    if (hasContent) {
      setState(() {
        _restorableDraft = saved;
        _showRestorePrompt = true;
      });
    }
  }

  void _restoreDraft() {
    final saved = _restorableDraft;
    if (saved == null) return;
    _bioController.text = saved.bio;
    _locationController.text = saved.location;
    if (saved.socialLinks.isNotEmpty) {
      _socialController.text = saved.socialLinks.first.url;
    }
    _occupationController.text = saved.occupation;
    _collegeController.text = saved.college;
    _hometownController.text = saved.hometown;
    setState(() {
      _draft = saved;
      _showRestorePrompt = false;
    });
  }

  Future<void> _discardDraft() async {
    await widget.repository.clearDraft();
    if (!mounted) return;
    setState(() {
      _restorableDraft = null;
      _showRestorePrompt = false;
    });
  }

  void _onDraftChanged(UserProfileDraft draft) {
    setState(() => _draft = draft);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      widget.repository.saveDraft(_draft);
    });
  }

  Future<void> _complete() async {
    if (!_draft.isComplete || _saving) return;
    setState(() => _saving = true);

    await Future<void>.delayed(const Duration(milliseconds: 700));
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile.fromDraft(_draft, id: id);
    await widget.repository.saveProfile(profile);
    await widget.repository.clearDraft();
    if (!mounted) return;

    setState(() {
      _saving = false;
      _completed = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            _buildForm(),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: CompleteProfileButton(
                enabled: _draft.isComplete,
                loading: _saving,
                onTap: _complete,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _completed
                  ? const _CompletionOverlay()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final d = _draft;

    // Progressive gates — each section appears once the previous required
    // field is complete. The preview appears the moment a photo is chosen.
    final showBio = validatePhotosStage(d);
    final showInterests = showBio && validateBioStage(d);
    final showLanguages = showInterests && validateInterestsStage(d);
    final showGender = showLanguages && validateLanguagesStage(d);
    final showLocation = showGender && d.gender.trim().isNotEmpty;
    final showSocial = showLocation && d.location.trim().isNotEmpty;
    final showOptional = showSocial && validateSocialStage(d);
    final showPreview = d.photos.isNotEmpty;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        _header(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: CompletionMeter(progress: d.completionProgress),
        ),
        if (_showRestorePrompt)
          RestoreBanner(onRestore: _restoreDraft, onDiscard: _discardDraft),

        PhotosSection(draft: d, onChanged: _onDraftChanged),

        _reveal(
          showBio,
          BioSection(
            controller: _bioController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showInterests,
          InterestsSection(draft: d, onChanged: _onDraftChanged),
        ),
        _reveal(
          showLanguages,
          LanguagesSection(draft: d, onChanged: _onDraftChanged),
        ),
        _reveal(
          showGender,
          GenderSection(draft: d, onChanged: _onDraftChanged),
        ),
        _reveal(
          showLocation,
          LocationSection(
            controller: _locationController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showSocial,
          SocialLinksSection(
            controller: _socialController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showOptional,
          OptionalDetailsSection(
            occupationController: _occupationController,
            collegeController: _collegeController,
            hometownController: _hometownController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),

        _reveal(
          showPreview,
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live preview',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is how others will see you.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFFB9C3DC)),
                ),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: ProfilePreviewCard(data: d.toPreviewData()),
                ),
              ],
            ),
          ),
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
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Create your profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'A few steps to a premium presence.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reveals [child] with a smooth fade + size + slight slide once [show].
  Widget _reveal(bool show, Widget child) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show ? EntranceFade(child: child) : const SizedBox.shrink(),
    );
  }
}

// ── Stage helper wrappers (pure, thin) ──────────────────────────────────────
// These reuse the pure validators to drive progressive reveal without
// duplicating any rule logic.

bool validatePhotosStage(UserProfileDraft d) =>
    stageIndex(d) > ProfileStage.photos.index;
bool validateBioStage(UserProfileDraft d) =>
    stageIndex(d) > ProfileStage.bio.index;
bool validateInterestsStage(UserProfileDraft d) =>
    stageIndex(d) > ProfileStage.interests.index;
bool validateLanguagesStage(UserProfileDraft d) =>
    stageIndex(d) > ProfileStage.languages.index;
bool validateSocialStage(UserProfileDraft d) =>
    stageIndex(d) > ProfileStage.socialLinks.index;

/// Maps the current stage to its enum index for gate comparisons.
int stageIndex(UserProfileDraft d) => stageFromDraft(d).index;

// ── Completion overlay ──────────────────────────────────────────────────────

class _CompletionOverlay extends StatelessWidget {
  const _CompletionOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xF00A0F1F)),
        child: Center(
          child: EntranceFade(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 92,
                  width: 92,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF47D7A5), Color(0xFF22BFE0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x8847D7A5),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Profile complete',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are ready to connect.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Route (matches Conexo's premium fade + slide transition) ────────────────

/// Premium route into the Profile Creation flow.
///
/// Uses the same fade + slide transition language as `premiumPlanRoute()` /
/// `myPlansRoute()` for a consistent feel across Conexo.
Route<void> premiumProfileCreationRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ProfileCreationScreen(
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
