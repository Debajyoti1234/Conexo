import 'plans_data.dart';
import 'plans_filter.dart';

/// Data helpers for the premium Plan Details experience.
///
/// Everything here is local + demo only and *pure*: values are derived
/// deterministically from an immutable [Experience] (usually keyed off its
/// [Experience.id]) so the same plan always renders the same authentic-looking
/// details. Nothing mutates an [Experience]; it remains the single source of
/// truth for plan data. A future backend can replace these helpers without any
/// UI refactoring.

/// The local join lifecycle for a plan.
///
/// The UI only surfaces `notJoined → requested → joined` today. [cancelled]
/// exists now so adding leave/cancel later needs no model change.
enum JoinStatus { notJoined, requested, joined, cancelled }

/// A stable pseudo-random 0..(mod-1) value derived from a plan id + salt.
/// Deterministic so demo stats never flicker between rebuilds.
int _seed(String id, int salt, int mod) {
  var hash = salt & 0x7fffffff;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % mod;
}

/// Demo-only host + plan metadata derived from an immutable [Experience].
///
/// No new plan model — this simply projects extra, believable presentation
/// values from data the [Experience] already carries.
class PlanHostDetails {
  const PlanHostDetails({
    required this.rating,
    required this.isVerified,
    required this.plansHosted,
    required this.friendsJoined,
    required this.mutualInterests,
    required this.createdLabel,
  });

  final double rating; // e.g. 4.7
  final bool isVerified;
  final int plansHosted;
  final int friendsJoined;
  final int mutualInterests;
  final String createdLabel; // e.g. "2 days ago"

  factory PlanHostDetails.of(Experience e) {
    final ratingTenths = 42 + _seed(e.id, 7, 8); // 4.2 .. 4.9
    final created = _seed(e.id, 13, 6); // 0..5 → label below
    const createdLabels = [
      'just now',
      'today',
      'yesterday',
      '2 days ago',
      '3 days ago',
      'last week',
    ];
    return PlanHostDetails(
      rating: ratingTenths / 10.0,
      isVerified: _seed(e.id, 3, 10) > 3, // ~60% verified
      plansHosted: 4 + _seed(e.id, 5, 40),
      friendsJoined: _seed(e.id, 11, 6), // 0..5
      mutualInterests: 2 + _seed(e.id, 17, 10),
      createdLabel: createdLabels[created],
    );
  }
}

/// Generates 3–4 local "why join" reasons from the plan's own data. Ordering
/// is stable and purely derived — no backend, no randomness at build time.
List<String> whyJoinReasons(Experience e) {
  final reasons = <String>[];

  if (parseDistanceKm(e.distance) <= 2.0) {
    reasons.add('Perfect for meeting nearby people');
  }
  if (e.isEditorsPick) {
    reasons.add('Editor\'s pick worth showing up for');
  }
  if (e.goingCount >= 15) {
    reasons.add('Trending this weekend');
  }
  if (e.sections.contains('friends')) {
    reasons.add('A few friends are already interested');
  }
  if (e.spotsLeft <= 3) {
    reasons.add('Only a few spots left');
  }

  // Always-available fallbacks so every plan shows 3–4 reasons.
  const fallbacks = [
    'Great for first-time Conexo users',
    'Hosted by an active member',
    'A relaxed way to meet like-minded people',
    'Easy to reach and beginner friendly',
  ];
  for (final f in fallbacks) {
    if (reasons.length >= 4) break;
    if (!reasons.contains(f)) reasons.add(f);
  }

  return reasons.take(4).toList();
}

/// Similar nearby plans for the details page.
///
/// Consumes the SAME distance-first [applyPipeline] as discovery (category
/// scoped, then a broad fallback), excludes the current plan by id, and caps
/// the result at [limit] (6–8) so the rail stays light + curated. The Details
/// page never sorts or filters independently.
List<Experience> similarNearby(Experience current, {int limit = 8}) {
  // First pass: same category, distance-first.
  final scoped = applyPipeline(
    experiences,
    PlansFilterState(selectedCategory: current.category),
  ).where((e) => e.id != current.id).toList();

  if (scoped.length >= limit) return scoped.take(limit).toList();

  // Fallback: widen to all categories (still distance-first) to fill the rail.
  final broad = applyPipeline(experiences, const PlansFilterState())
      .where((e) => e.id != current.id)
      .toList();

  final result = <Experience>[...scoped];
  for (final e in broad) {
    if (result.length >= limit) break;
    if (result.every((x) => x.id != e.id)) result.add(e);
  }
  return result.take(limit).toList();
}
