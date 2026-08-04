import 'package:flutter/material.dart';

import 'create_plan_data.dart';
import 'plans_data.dart';
import 'plans_filter.dart';

/// Data helpers for the My Plans management experience (Phase 3.4).
///
/// Everything here is local + demo only and PURE: values are derived
/// deterministically from immutable [Experience] and [PublishedPlan] models.
/// No new wrapper model — only lightweight status helpers and pure filters.
/// The existing [applyPipeline] is the single source of truth for sorting
/// (Distance → Date → Time), ensuring zero duplicated sort logic.

// ── Filter options ──────────────────────────────────────────────────────

/// Time-based filter for My Plans lists.
enum MyPlansFilter {
  today,
  upcoming,
  thisWeek,
  past,
}

/// Checks if an [Experience] matches the given [MyPlansFilter].
/// Pure helper — uses date heuristics from the [Experience.date] label.
bool matchesFilter(Experience e, MyPlansFilter filter) {
  final dateLabel = e.date.toLowerCase();

  switch (filter) {
    case MyPlansFilter.today:
      return dateLabel.contains('today') || dateLabel.contains('tonight');
    case MyPlansFilter.upcoming:
      // Anything not "today" and not in the past (heuristic: no "yesterday").
      return !dateLabel.contains('today') &&
          !dateLabel.contains('tonight') &&
          !dateLabel.contains('yesterday');
    case MyPlansFilter.thisWeek:
      // Broad heuristic: not past, includes "this week" or near-term labels.
      return !dateLabel.contains('yesterday') && !dateLabel.contains('last');
    case MyPlansFilter.past:
      return dateLabel.contains('yesterday') || dateLabel.contains('last');
  }
}

// ── Sorting (reuses existing pipeline) ─────────────────────────────────

/// Sorts a list of [Experience] using the SAME distance-first pipeline as
/// Plans discovery (Distance → Date → Time). This ensures a single source of
/// truth for sorting logic across the entire Plans module.
List<Experience> sortMyPlans(List<Experience> list) {
  return applyPipeline(list, const PlansFilterState());
}

// ── PublishedPlan → Experience mapping ─────────────────────────────────

/// Converts a user-published [PublishedPlan] into an [Experience] so it can
/// be rendered using the existing [ExperienceCard] with zero UI duplication.
/// Mirrors [draftToPlan] logic — derives accent/emoji from the mood label.
Experience publishedToExperience(PublishedPlan plan) {
  final mood = moodByLabel(plan.mood);
  final accent = mood?.accent ?? const Color(0xFF8B5CF6);

  String dateLabel = 'Date TBD';
  if (plan.date != null) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = plan.date!;
    dateLabel = '${months[d.month - 1]} ${d.day}';
  }

  return Experience(
    id: plan.id,
    title: plan.title,
    host: 'You',
    hostPortrait: 'assets/images/portraits/demo1.jpeg',
    coverAsset: plan.coverAsset,
    category: plan.mood,
    mood: plan.mood,
    moodEmoji: mood?.emoji ?? '✨',
    city: plan.location,
    date: dateLabel,
    time: plan.timeLabel.isNotEmpty ? plan.timeLabel : 'TBD',
    distance: plan.location,
    goingCount: 1, // Demo: placeholder
    spotsLeft: (plan.participants ?? 10) - 1, // Demo: limit minus host
    accent: accent,
    highlight: plan.description.isNotEmpty
        ? plan.description
        : 'Just created — be the first to join',
    participants: const <String>[],
    visibility: plan.visibility,
  );
}

// ── Demo seed data ──────────────────────────────────────────────────────

/// Demo hosted plans "by You" for the Hosting tab. These are lightweight
/// references to existing [experiences] (treating them as if the local user
/// created them) so the UI looks premium out of the box.
List<Experience> demoHostedPlans() {
  // Reference a few existing experiences by ID as if "You" hosted them.
  const ids = {'e01', 'e04', 'e07', 'e10'};
  return experiences.where((e) => ids.contains(e.id)).toList();
}

/// Demo joined plans for the Joined tab. References existing [experiences]
/// as if the local user joined them.
List<Experience> demoJoinedPlans() {
  // Reference a different set as "joined" plans.
  const ids = {'e02', 'e05', 'e08', 'e11', 'e14'};
  return experiences.where((e) => ids.contains(e.id)).toList();
}

// ── Insights ────────────────────────────────────────────────────────────

/// Premium glass summary cards shown at the top of My Plans.
class MyPlansInsights {
  const MyPlansInsights({
    required this.plansHosted,
    required this.plansJoined,
    required this.totalParticipants,
    required this.newConnections,
  });

  final int plansHosted;
  final int plansJoined;
  final int totalParticipants;
  final int newConnections;

  /// Computes insights from the current hosted + joined lists (demo values).
  factory MyPlansInsights.compute({
    required List<Experience> hosted,
    required List<Experience> joined,
  }) {
    return MyPlansInsights(
      plansHosted: hosted.length,
      plansJoined: joined.length,
      totalParticipants: hosted.fold<int>(
        0,
        (sum, e) => sum + e.goingCount,
      ),
      newConnections: (hosted.length + joined.length) * 2, // Demo heuristic
    );
  }
}
