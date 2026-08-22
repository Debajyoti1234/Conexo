import 'package:flutter/material.dart';

import 'create_plan_data.dart';
import 'create_plan_widgets.dart';


/// Composes the 10 guided input sections for the Create Plan flow.
///
/// Each section is wrapped in [CreateSection] (title + ✓ completion badge).
/// Sections reveal progressively via [AnimatedSize] + [FadeTransition] with
/// [Curves.easeInOutCubic] — no bounce, elastic, or overshoot.
///
/// The gallery sheet is shown inline (no dialog) using [AnimatedSize].

// ── Progressive reveal helper ───────────────────────────────────────────

/// Wraps a child in a smooth AnimatedSize + FadeTransition reveal.
/// When [visible] is false the child collapses to zero height.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? child
          : const SizedBox.shrink(),
    );
  }
}

// ── Section 1: Cover ────────────────────────────────────────────────────

class CoverSection extends StatefulWidget {
  const CoverSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  State<CoverSection> createState() => _CoverSectionState();
}

class _CoverSectionState extends State<CoverSection> {
  bool _galleryOpen = false;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Cover',
      subtitle: 'Choose a cover that captures the vibe.',
      completed: widget.draft.hasCover,
      child: Column(
        children: [
          CoverPickerHero(
            coverAsset: widget.draft.coverAsset,
            onPickGallery: () => setState(() => _galleryOpen = !_galleryOpen),
          ),
          _Reveal(
            visible: _galleryOpen,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: CoverGalleryGrid(
                selected: widget.draft.coverAsset,
                onSelect: (asset) {
                  widget.onChanged(widget.draft.copyWith(coverAsset: asset));
                  setState(() => _galleryOpen = false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section 2: Title ────────────────────────────────────────────────────

class TitleSection extends StatelessWidget {
  const TitleSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'What\'s the plan?',
      completed: draft.hasTitle,
      child: GlassTextField(
        controller: controller,
        hint: 'Movie Night, UNO Night, Chai & Chuski…',
        onChanged: (v) => onChanged(draft.copyWith(title: v)),
      ),
    );
  }
}

// ── Section 3: Mood ─────────────────────────────────────────────────────

class MoodSection extends StatelessWidget {
  const MoodSection({
    required this.customController,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final TextEditingController customController;
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Mood',
      subtitle: 'What kind of vibe are you going for?',
      completed: draft.hasMood,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mood in planMoods)
                  LuxuryChip(
                    label: mood.label,
                    emoji: mood.emoji,
                    accent: mood.accent,
                    selected: draft.mood == mood.label,
                    onTap: () {
                      final updated = draft.copyWith(mood: mood.label);
                      if (!draft.hasCover && mood.cover != null) {
                        onChanged(updated.copyWith(coverAsset: mood.cover));
                      } else {
                        onChanged(updated);
                      }
                    },
                  ),
              ],
            ),
            _Reveal(
              visible: draft.mood == 'Custom',
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GlassTextField(
                  controller: customController,
                  hint: 'Name your mood…',
                  onChanged: (v) => onChanged(draft.copyWith(customMood: v)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section 4: Visibility ───────────────────────────────────────────────

class VisibilitySection extends StatelessWidget {
  const VisibilitySection({
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Visibility',
      completed: draft.hasVisibility,
      child: SegmentedVisibilityCards(
        value: draft.visibility,
        onChanged: (v) => onChanged(draft.copyWith(visibility: v)),
      ),
    );
  }
}

// ── Section 5: Location ─────────────────────────────────────────────────

class LocationSection extends StatelessWidget {
  const LocationSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Location',
      subtitle: 'Where is this happening?',
      completed: draft.hasLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (!draft.hasLocation) {
                onChanged(draft.copyWith(location: 'Near you'));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.near_me_rounded, size: 14, color: const Color(0xFF9DB2E8)),
                  const SizedBox(width: 6),
                  Text(
                    'Near you',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: draft.hasLocation
                          ? const Color(0xFF6B7799)
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GlassTextField(
            controller: controller,
            hint: 'Café, park, your place…',
            leadingIcon: Icons.location_on_rounded,
            onChanged: (v) => onChanged(draft.copyWith(location: v)),
          ),
        ],
      ),
    );
  }
}

// ── Section 6: Date ─────────────────────────────────────────────────────

class DateSection extends StatelessWidget {
  const DateSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  String get _label {
    final d = draft.date;
    if (d == null) return 'Pick a date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Date',
      completed: draft.hasDate,
      child: SelectorTile(
        icon: Icons.calendar_today_rounded,
        label: 'When',
        value: _label,
        placeholder: draft.date == null,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: draft.date ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) onChanged(draft.copyWith(date: picked));
        },
      ),
    );
  }
}

// ── Section 7: Time ─────────────────────────────────────────────────────

class TimeSection extends StatelessWidget {
  const TimeSection({
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  String get _label {
    final t = draft.time;
    if (t == null) return 'Pick a time';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Time',
      completed: draft.hasTime,
      child: SelectorTile(
        icon: Icons.schedule_rounded,
        label: 'What time',
        value: _label,
        placeholder: draft.time == null,
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: draft.time ?? TimeOfDay.now(),
          );
          if (picked != null) onChanged(draft.copyWith(time: picked));
        },
      ),
    );
  }
}

// ── Section 8: Participants ─────────────────────────────────────────────

class ParticipantsSection extends StatefulWidget {
  const ParticipantsSection({
    required this.customController,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final TextEditingController customController;
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  State<ParticipantsSection> createState() => _ParticipantsSectionState();
}

class _ParticipantsSectionState extends State<ParticipantsSection> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return CreateSection(
      title: 'Max Participants',
      completed: draft.hasParticipants,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in participantOptions)
                  LuxuryChip(
                    label: '$n',
                    selected: draft.participants == n,
                    onTap: () => widget.onChanged(
                      draft.copyWith(participants: n),
                    ),
                  ),
                LuxuryChip(
                  label: 'Custom',
                  selected: draft.participants == -1,
                  onTap: () => widget.onChanged(
                    draft.copyWith(participants: -1),
                  ),
                ),
              ],
            ),
            _Reveal(
              visible: draft.participants == -1,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GlassTextField(
                  controller: widget.customController,
                  hint: 'Enter a number…',
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    if (n != null && n > 0) {
                      widget.onChanged(draft.copyWith(customParticipants: n));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section 9: Description ──────────────────────────────────────────────

class DescriptionSection extends StatelessWidget {
  const DescriptionSection({
    required this.controller,
    required this.draft,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final PlanDraft draft;
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateSection(
      title: 'Description',
      subtitle: 'Optional — but a good one gets more people to join.',
      completed: draft.description.trim().isNotEmpty,
      child: GlassTextField(
        controller: controller,
        hint: 'Tell everyone why they should join…',
        maxLines: 4,
        onChanged: (v) => onChanged(draft.copyWith(description: v)),
      ),
    );
  }
}

// ── Progressive section list ────────────────────────────────────────────

/// Determines which stage the current draft is in for the [StageRail].
CreateStage stageFromDraft(PlanDraft d) {
  if (!d.hasCover) return CreateStage.cover;
  if (!d.hasTitle || !d.hasMood || !d.hasVisibility) return CreateStage.details;
  if (!d.hasLocation || !d.hasDate || !d.hasTime || !d.hasParticipants) {
    return CreateStage.schedule;
  }
  return CreateStage.preview;
}
