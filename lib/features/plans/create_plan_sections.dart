import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/services/image_normalizer.dart';
import '../../core/services/location_service.dart';
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
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickDevicePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;

      final user = AuthService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to upload a cover photo.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1A1F2E),
          ),
        );
        return;
      }

      final rawBytes = await File(picked.path).readAsBytes();
      final normalized = await ConexoImageNormalizer.normalize(rawBytes);
      final draftId = widget.draft.draftId;
      final storagePath = 'plans/${user.id}/$draftId/cover.${normalized.extension}';

      await Supabase.instance.client.storage
          .from('plan-covers')
          .uploadBinary(
            storagePath,
            normalized.bytes,
            fileOptions: FileOptions(contentType: normalized.contentType),
          );

      widget.onChanged(widget.draft.copyWith(coverAsset: storagePath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload photo. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1A1F2E),
        ),
      );
    }
  }

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
            onPickDevice: _pickDevicePhoto,
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

/// Real place search backed by the existing OS geocoding provider
/// ([LocationService]). Typing shows live suggestions (name + address); the
/// selected place captures real latitude/longitude into the draft. Manual
/// typing clears any previously selected coordinates. A "Use current location"
/// chip captures GPS coordinates + a reverse-geocoded area name.
class LocationSection extends StatefulWidget {
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
  State<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<LocationSection> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<LocationSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _showSuggestions = false;
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() => _showSuggestions = false);
    }
  }

  void _onTextChanged(String value) {
    // Manual typing keeps the text but clears any previously selected place
    // coordinates so stale lat/long never persists with a different label.
    widget.onChanged(
      widget.draft.copyWith(location: value, clearCoordinates: true),
    );
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = const [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await LocationService.searchPlaces(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _showSuggestions = results.isNotEmpty && _focusNode.hasFocus;
      });
    });
  }

  void _select(LocationSuggestion s) {
    widget.controller.text = s.displayName;
    widget.controller.selection =
        TextSelection.collapsed(offset: s.displayName.length);
    widget.onChanged(
      widget.draft.copyWith(
        location: s.displayName,
        locationAddress: s.address ?? '',
        latitude: s.latitude,
        longitude: s.longitude,
      ),
    );
    setState(() {
      _showSuggestions = false;
      _suggestions = const [];
    });
    _focusNode.unfocus();
  }

  Future<void> _useCurrentLocation() async {
    if (_detecting) return;
    setState(() => _detecting = true);
    final result = await LocationService.detectCurrentLocation();
    if (!mounted) return;
    setState(() => _detecting = false);

    if (result.isSuccess) {
      final name = (result.areaName != null && result.areaName!.isNotEmpty)
          ? result.areaName!
          : 'Current location';
      widget.controller.text = name;
      widget.controller.selection =
          TextSelection.collapsed(offset: name.length);
      widget.onChanged(
        widget.draft.copyWith(
          location: name,
          locationAddress: result.areaName ?? '',
          latitude: result.latitude,
          longitude: result.longitude,
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not detect location. Type it instead.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return CreateSection(
      title: 'Location',
      subtitle: 'Where is this happening?',
      completed: draft.hasLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _detecting ? null : _useCurrentLocation,
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
                  if (_detecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9DB2E8),
                      ),
                    )
                  else
                    const Icon(Icons.near_me_rounded,
                        size: 14, color: Color(0xFF9DB2E8)),
                  const SizedBox(width: 6),
                  const Text(
                    'Use current location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GlassTextField(
            controller: widget.controller,
            focusNode: _focusNode,
            hint: 'Search a café, park, address…',
            leadingIcon: Icons.location_on_rounded,
            onChanged: _onTextChanged,
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            _PlaceSuggestionsPanel(
              suggestions: _suggestions,
              searching: _searching,
              onSelect: _select,
            ),
          if (draft.latitude != null && draft.longitude != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF47D7A5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    draft.locationAddress.trim().isNotEmpty
                        ? draft.locationAddress.trim()
                        : 'Location pinned',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9DB2E8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Suggestions dropdown for the Plan location search (name + address rows).
class _PlaceSuggestionsPanel extends StatelessWidget {
  const _PlaceSuggestionsPanel({
    required this.suggestions,
    required this.searching,
    required this.onSelect,
  });

  final List<LocationSuggestion> suggestions;
  final bool searching;
  final ValueChanged<LocationSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
        color: const Color(0xFF141A2E),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: searching ? 1 : suggestions.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
          itemBuilder: (context, index) {
            if (searching) {
              return const SizedBox(
                height: 52,
                child: Center(
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              );
            }
            final s = suggestions[index];
            return InkWell(
              onTap: () => onSelect(s),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 18, color: Color(0xFFB7A5FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEAEEF9),
                            ),
                          ),
                          if (s.address != null && s.address!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              s.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A96B4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
