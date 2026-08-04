import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import 'profile_strength_data.dart';
import 'profile_strength_widgets.dart';

/// Presentational sections for Phase 4.4 — Profile Strength & Completion.
///
/// Each section is a thin, stateless widget that renders part of a
/// [ProfileStrengthResult]. There is NO business logic, persistence, or
/// scoring here — all computation lives in `profile_strength_data.dart`.

const _kSoftText = Color(0xFFB9C3DC);

// ── OverallStrengthSection ────────────────────────────────────────────────────

/// The hero: animated ring, tier badge, and overall score.
class OverallStrengthSection extends StatelessWidget {
  const OverallStrengthSection({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StrengthSectionTitle(
          title: 'Profile Strength',
          subtitle: 'A stronger profile gets better connections.',
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 14),
        ProfileStrengthCard(result: result),
      ],
    );
  }
}

// ── CompletionChecklistSection ────────────────────────────────────────────────

/// The full checklist of required + optional + verification facets.
class CompletionChecklistSection extends StatelessWidget {
  const CompletionChecklistSection({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    final items = [...result.completedItems, ...result.remainingItems];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StrengthSectionTitle(
          title: 'Completion Checklist',
          subtitle:
              '${result.completedItems.length} of ${items.length} completed',
          icon: Icons.checklist_rounded,
        ),
        const SizedBox(height: 14),
        CompletionChecklist(items: items),
      ],
    );
  }
}

// ── MissingInformationSection ─────────────────────────────────────────────────

/// The remaining items the user still needs to add. Hidden when nothing's left.
class MissingInformationSection extends StatelessWidget {
  const MissingInformationSection({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    if (result.remainingItems.isEmpty) {
      return const _AllDoneCard(
        title: 'Nothing missing',
        message: 'Every part of your profile is complete. Beautiful work!',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StrengthSectionTitle(
          title: 'Missing Information',
          subtitle: 'Complete these to boost your score.',
          icon: Icons.playlist_add_rounded,
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < result.remainingItems.length; i++)
          Padding(
            key: ValueKey('missing_${result.remainingItems[i].id}'),
            padding: EdgeInsets.only(
              bottom: i == result.remainingItems.length - 1 ? 0 : 12,
            ),
            child: MissingItemTile(label: result.remainingItems[i].label),
          ),
      ],
    );
  }
}

// ── SuggestionsSection ────────────────────────────────────────────────────────

/// Auto-generated improvement suggestions. Hidden when there are none.
class SuggestionsSection extends StatelessWidget {
  const SuggestionsSection({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    if (result.suggestions.isEmpty) {
      return const _AllDoneCard(
        title: 'You are all set',
        message: 'No suggestions right now — your profile looks great.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StrengthSectionTitle(
          title: 'Suggestions',
          subtitle: 'Quick wins to strengthen your profile.',
          icon: Icons.tips_and_updates_outlined,
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < result.suggestions.length; i++)
          Padding(
            key: ValueKey('suggestion_$i'),
            padding: EdgeInsets.only(
              bottom: i == result.suggestions.length - 1 ? 0 : 12,
            ),
            child: SuggestionTile(text: result.suggestions[i]),
          ),
      ],
    );
  }
}

// ── ScoreBreakdownSection ─────────────────────────────────────────────────────

/// A visual per-bucket breakdown of the score.
class ScoreBreakdownSection extends StatelessWidget {
  const ScoreBreakdownSection({required this.result, super.key});

  final ProfileStrengthResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StrengthSectionTitle(
          title: 'Score Breakdown',
          subtitle: 'How each part contributes to your score.',
          icon: Icons.donut_small_rounded,
        ),
        const SizedBox(height: 14),
        ScoreBreakdownCard(breakdown: result.profileScoreBreakdown),
      ],
    );
  }
}

// ── Shared "all done" card ────────────────────────────────────────────────────

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF47D7A5), Color(0xFF22BFE0)],
              ),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kSoftText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
