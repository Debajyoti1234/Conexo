import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/supabase/auth_service.dart';
import '../home_discovery_animations.dart';
import 'create_plan_data.dart';
import 'create_plan_preview.dart';
import 'create_plan_sections.dart';
import 'create_plan_widgets.dart';
import 'supabase_plan_repository.dart';

/// The premium Create Plan flow.
///
/// A guided, progressive experience: sections reveal one at a time as the
/// prior required field is completed, the live preview evolves continuously
/// from the moment a cover is chosen, and publishing plays a calm success
/// animation before fading back to the Plans screen.
///
/// Drafts autosave locally. Publishing goes to Supabase when authenticated.
class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({
    super.key,
    this.existingPlan,
  });

  final PublishedPlan? existingPlan;

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _repo = SupabasePlanRepository();

  final _titleController = TextEditingController();
  final _customMoodController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customParticipantsController = TextEditingController();

  PlanDraft _draft = PlanDraft(createdAt: DateTime.now());
  PlanDraft? _restorableDraft;
  bool _showRestorePrompt = false;
  String? _coverPreviewUrl;

  /// The draft as first loaded when editing an existing published plan. Used
  /// purely for dirty-tracking so "Save Changes" enables the moment ANY
  /// editable field differs from the original. `null` in create mode.
  PlanDraft? _initialDraft;

  PublishState _publishState = PublishState.idle;
  bool _published = false;

  Timer? _saveDebounce;

  /// True when editing an existing published plan (Edit mode) vs creating a
  /// brand-new plan (Create mode). The two modes are deliberately separated:
  /// Create mode autosaves a local draft and publishes a NEW plan; Edit mode
  /// never touches the draft slot and updates the SAME plans.id.
  bool get _isEditing => widget.existingPlan != null;

  /// Whether the current edit differs from the originally-loaded plan.
  bool get _isDirty {
    final initial = _initialDraft;
    if (initial == null) return false;
    return jsonEncode(_draft.toJson()) != jsonEncode(initial.toJson());
  }

  /// The action button is enabled when:
  ///   • Create mode: the draft is fully complete (ready to publish), or
  ///   • Edit mode: any editable field changed and a title is still present
  ///     (title is the one field the database requires as NOT NULL).
  bool get _canSubmit =>
      _isEditing ? (_isDirty && _draft.hasTitle) : _draft.isComplete;

  /// Edit mode saves changes to the same plan; Create mode publishes a new one.
  String get _submitLabel => _isEditing ? 'Save Changes' : 'Publish Plan';

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _loadExistingPlan(widget.existingPlan!);
    } else {
      _checkForDraft();
    }
  }

  void _loadExistingPlan(PublishedPlan plan) {
    final draft = PlanDraft.fromPublishedPlan(plan);
    _titleController.text = draft.title;
    _customMoodController.text = draft.customMood;
    _locationController.text = draft.location;
    _descriptionController.text = draft.description;
    if (draft.customParticipants != null) {
      _customParticipantsController.text = '${draft.customParticipants}';
    }
    setState(() {
      _draft = draft;
      _initialDraft = draft;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.dispose();
    _customMoodController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _customParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _checkForDraft() async {
    final saved = await _repo.loadDraft();
    if (!mounted) return;
    if (saved != null && (saved.hasCover || saved.hasTitle)) {
      setState(() {
        _restorableDraft = saved;
        _showRestorePrompt = true;
      });
    }
  }

  void _restoreDraft() {
    final saved = _restorableDraft;
    if (saved == null) return;
    _titleController.text = saved.title;
    _customMoodController.text = saved.customMood;
    _locationController.text = saved.location;
    _descriptionController.text = saved.description;
    if (saved.customParticipants != null) {
      _customParticipantsController.text = '${saved.customParticipants}';
    }
    setState(() {
      _draft = saved;
      _showRestorePrompt = false;
    });
    _resolveCoverPreviewUrl();
  }

  Future<void> _resolveCoverPreviewUrl() async {
    final asset = _draft.coverAsset;
    if (asset == null || asset.isEmpty) {
      setState(() => _coverPreviewUrl = null);
      return;
    }
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      setState(() => _coverPreviewUrl = asset);
      return;
    }
    if (asset.startsWith('assets/')) {
      setState(() => _coverPreviewUrl = null);
      return;
    }
    final signed = await _repo.getCoverSignedUrl(asset);
    if (!mounted) return;
    setState(() => _coverPreviewUrl = signed);
  }

  Future<void> _discardDraft() async {
    await _repo.clearDraft();
    if (!mounted) return;
    setState(() {
      _restorableDraft = null;
      _showRestorePrompt = false;
    });
  }

  void _onDraftChanged(PlanDraft draft) {
    setState(() => _draft = draft);
    // Edit mode must NEVER write to the local draft slot — otherwise a
    // published plan's edits would leak into My Plans → Drafts and could later
    // be re-published as a duplicate. Only Create mode autosaves a draft.
    if (_isEditing) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      _repo.saveDraft(_draft);
    });
    _resolveCoverPreviewUrl();
  }

  Future<void> _publish() async {
    if (!_canSubmit || _publishState == PublishState.loading) return;
    setState(() => _publishState = PublishState.loading);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final plan = PublishedPlan.fromDraft(_draft);
      if (widget.existingPlan != null) {
        await _repo.updatePublished(
          plan.copyWith(
            id: widget.existingPlan!.id,
            hostId: widget.existingPlan!.hostId,
            createdAt: widget.existingPlan!.createdAt,
          ),
        );
      } else {
        await _repo.savePublished(plan);
        await _repo.clearDraft();
      }
      if (!mounted) return;

      setState(() => _published = true);

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      // Force pop (bypasses the PopScope back guard) — the work is saved.
      Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _publishState = PublishState.idle);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishState = PublishState.idle);
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = stageFromDraft(_draft);
    return PopScope(
      // We fully own the back action so we can offer "Save as Draft" (new plan)
      // or "Discard changes" (editing a published plan) before leaving.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/plans/myplan.PNG',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: .35),
                ),
              ),
              _buildForm(stage),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: PublishButton(
                  enabled: _canSubmit,
                  state: _publishState,
                  label: _submitLabel,
                  onTap: _publish,
                ),
              ),
              // Preview gently scales/fades out under the success state.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: _published
                    ? PublishSuccessOverlay(isEditing: _isEditing)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles the back gesture/button.
  ///
  ///  • Edit mode with unsaved changes → "Discard changes?" (Continue / Discard).
  ///    Discarding throws away only the unsaved edits; the published plan and
  ///    its plans.id are untouched, and NO draft is created.
  ///  • New plan with content → "Leave Plan creation?" (Continue / Save as Draft).
  ///    Saving preserves the work as a draft in My Plans → Drafts.
  ///  • Otherwise → just leave.
  Future<void> _handleBack() async {
    if (!mounted) return;
    // Already saved/published — allow leaving immediately.
    if (_published) {
      Navigator.of(context).pop();
      return;
    }

    if (_isEditing) {
      if (!_isDirty) {
        Navigator.of(context).pop();
        return;
      }
      final discard = await _showEditBackDialog();
      if (discard == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Create mode.
    final hasContent = _draft.hasCover || _draft.hasTitle;
    if (!hasContent) {
      Navigator.of(context).pop();
      return;
    }
    final saveDraft = await _showCreateBackDialog();
    if (saveDraft == true && mounted) {
      _saveDebounce?.cancel();
      await _repo.saveDraft(_draft);
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// "Discard changes?" — returns true to discard unsaved edits and leave.
  Future<bool?> _showEditBackDialog() {
    return _showBackChoiceDialog(
      title: 'Discard changes?',
      message: 'Your unsaved changes will be lost. Your published plan stays '
          'exactly as it was.',
      primaryLabel: 'Continue Editing',
      secondaryLabel: 'Discard Changes',
      secondaryDanger: true,
    );
  }

  /// "Leave Plan creation?" — returns true to save the work as a draft and leave.
  Future<bool?> _showCreateBackDialog() {
    return _showBackChoiceDialog(
      title: 'Leave Plan creation?',
      message: "Your changes haven't been published yet.",
      primaryLabel: 'Continue Editing',
      secondaryLabel: 'Save as Draft',
      secondaryDanger: false,
    );
  }

  /// A shared premium glass dialog for the back-action choice.
  ///
  /// The PRIMARY button ("Continue Editing") returns `null`/`false` and keeps
  /// the user on the screen. The SECONDARY button performs the leave action
  /// (discard or save-as-draft) and returns `true`.
  Future<bool?> _showBackChoiceDialog({
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    required bool secondaryDanger,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF161E36).withValues(alpha: .98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .5),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFFB9C3DC),
                ),
              ),
              const SizedBox(height: 22),
              // Primary, safe action — stay on the screen.
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Secondary action — leave (discard or save-as-draft).
              GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: secondaryDanger
                          ? const Color(0xFFE36D9D).withValues(alpha: .5)
                          : Colors.white.withValues(alpha: .14),
                    ),
                  ),
                  child: Text(
                    secondaryLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: secondaryDanger
                          ? const Color(0xFFE36D9D)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(CreateStage stage) {
    final d = _draft;
    final editing = _isEditing;

    // Create mode reveals sections progressively as each required field is
    // completed. Edit mode reveals EVERYTHING at once so the creator can change
    // any field (title, cover, mood, visibility, location, date, time,
    // capacity, description) and immediately get "Save Changes".
    final showTitle = editing || d.hasCover;
    final showMood = editing || (showTitle && d.hasTitle);
    final showVisibility = editing || (showMood && d.hasMood);
    final showLocation = editing || (showVisibility && d.hasVisibility);
    final showDate = editing || (showLocation && d.hasLocation);
    final showTime = editing || (showDate && d.hasDate);
    final showParticipants = editing || (showTime && d.hasTime);
    final showDescription = editing || (showParticipants && d.hasParticipants);

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      children: [
        _header(),
        // The staged progress rail + draft-restore banner are Create-flow only.
        if (!editing) StageRail(active: stage),
        if (!editing) _restoreBanner(),

        CoverSection(draft: d, onChanged: _onDraftChanged),

        _reveal(
          showTitle,
          TitleSection(
            controller: _titleController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showMood,
          MoodSection(
            customController: _customMoodController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showVisibility,
          VisibilitySection(draft: d, onChanged: _onDraftChanged),
        ),
        _reveal(
          showLocation,
          LocationSection(
            controller: _locationController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(showDate, DateSection(draft: d, onChanged: _onDraftChanged)),
        _reveal(showTime, TimeSection(draft: d, onChanged: _onDraftChanged)),
        _reveal(
          showParticipants,
          ParticipantsSection(
            customController: _customParticipantsController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),
        _reveal(
          showDescription,
          DescriptionSection(
            controller: _descriptionController,
            draft: d,
            onChanged: _onDraftChanged,
          ),
        ),

        // Live preview evolves from the moment a cover is chosen.
        _reveal(d.hasCover, PlanPreviewSection(
          draft: d,
          coverPreviewUrl: _coverPreviewUrl,
        )),
      ],
    );
  }

  /// Smooth progressive reveal (AnimatedSize + FadeTransition, easeInOutCubic).
  Widget _reveal(bool visible, Widget child) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (c, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: c,
          ),

        ),
        child: visible
            ? child
            : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }

  Widget _header() {
    final isEditing = widget.existingPlan != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Edit Plan' : 'Create Plan',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEditing
                ? 'Update your plan details.'
                : 'Create a plan. Meet nearby people. Make memories.',
            style: const TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
          ),
        ],
      ),
    );
  }

  Widget _restoreBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _showRestorePrompt
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: EntranceFade(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.drafts_rounded,
                            size: 18,
                            color: Color(0xFFB7A5FF),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Continue editing your draft?',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _bannerButton(
                              label: 'Continue',
                              primary: true,
                              onTap: _restoreDraft,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _bannerButton(
                              label: 'Discard',
                              primary: false,
                              onTap: _discardDraft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _bannerButton({
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                )
              : null,
          color: primary ? null : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: primary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
