import 'dart:async';

import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'create_plan_data.dart';
import 'create_plan_preview.dart';
import 'create_plan_sections.dart';
import 'create_plan_widgets.dart';

/// The premium Create Plan flow.
///
/// A guided, progressive experience: sections reveal one at a time as the
/// prior required field is completed, the live preview evolves continuously
/// from the moment a cover is chosen, and publishing plays a calm success
/// animation before fading back to the Plans screen.
///
/// Local-only: the draft auto-saves to SharedPreferences and the published
/// plan is stored locally. No Firebase / backend / navigation changes.
class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _store = PlanDraftStore();

  final _titleController = TextEditingController();
  final _customMoodController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customParticipantsController = TextEditingController();

  PlanDraft _draft = PlanDraft(createdAt: DateTime.now());
  PlanDraft? _restorableDraft;
  bool _showRestorePrompt = false;

  PublishState _publishState = PublishState.idle;
  bool _published = false;

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _checkForDraft();
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
    final saved = await _store.loadDraft();
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
  }

  Future<void> _discardDraft() async {
    await _store.clearDraft();
    if (!mounted) return;
    setState(() {
      _restorableDraft = null;
      _showRestorePrompt = false;
    });
  }

  void _onDraftChanged(PlanDraft draft) {
    setState(() => _draft = draft);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      _store.saveDraft(_draft);
    });
  }

  Future<void> _publish() async {
    if (!_draft.isComplete || _publishState == PublishState.loading) return;
    setState(() => _publishState = PublishState.loading);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    final plan = PublishedPlan.fromDraft(_draft);
    await _store.addPublished(plan);
    await _store.clearDraft();
    if (!mounted) return;

    setState(() => _published = true);

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final stage = stageFromDraft(_draft);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            _buildForm(stage),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: PublishButton(
                enabled: _draft.isComplete,
                state: _publishState,
                onTap: _publish,
              ),
            ),
            // Preview gently scales/fades out under the success state.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _published
                  ? const PublishSuccessOverlay()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(CreateStage stage) {
    final d = _draft;

    // Progressive gates — each section appears once the previous required
    // field is complete. The preview begins the moment a cover is chosen.
    final showTitle = d.hasCover;
    final showMood = showTitle && d.hasTitle;
    final showVisibility = showMood && d.hasMood;
    final showLocation = showVisibility && d.hasVisibility;
    final showDate = showLocation && d.hasLocation;
    final showTime = showDate && d.hasDate;
    final showParticipants = showTime && d.hasTime;
    final showDescription = showParticipants && d.hasParticipants;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        _header(),
        StageRail(active: stage),
        _restoreBanner(),

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
        _reveal(d.hasCover, PlanPreviewSection(draft: d)),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Plan',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Create a plan. Meet nearby people. Make memories.',
            style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
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
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                )
              : null,
          color: primary ? null : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
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
