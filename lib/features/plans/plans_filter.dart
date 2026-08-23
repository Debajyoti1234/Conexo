import 'plans_data.dart';

/// Central, immutable filter state for the entire Plans discovery screen.
///
/// This is the single source of truth the screen rebuilds from. It is kept
/// deliberately lightweight today (category + query) but is shaped so future
/// discovery controls can be added WITHOUT touching the UI layer or the
/// pipeline signature:
///  • distanceRadiusKm
///  • visibility
///  • moods
///  • dateFilter
///  • availableNow
///
/// Those fields are intentionally declared but unused for now.
class PlansFilterState {
  const PlansFilterState({
    this.selectedCategory,
    this.query = '',
    // ── Future-ready (unused today) ──
    this.distanceRadiusKm,
    this.visibility,
    this.moods = const <String>[],
    this.dateFilter,
    this.availableNow = false,
  });

  /// The selected category label. `null` means "All".
  final String? selectedCategory;

  /// The live search query (title / host / mood / category / city).
  final String query;

  // ── Future-ready fields (declared, not yet wired into the pipeline) ──
  final double? distanceRadiusKm;
  final PlanVisibility? visibility;
  final List<String> moods;
  final String? dateFilter;
  final bool availableNow;

  bool get isAll => selectedCategory == null;
  bool get hasQuery => query.trim().isNotEmpty;

  PlansFilterState copyWith({
    String? selectedCategory,
    bool clearCategory = false,
    String? query,
    double? distanceRadiusKm,
    PlanVisibility? visibility,
    List<String>? moods,
    String? dateFilter,
    bool? availableNow,
  }) {
    return PlansFilterState(
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      query: query ?? this.query,
      distanceRadiusKm: distanceRadiusKm ?? this.distanceRadiusKm,
      visibility: visibility ?? this.visibility,
      moods: moods ?? this.moods,
      dateFilter: dateFilter ?? this.dateFilter,
      availableNow: availableNow ?? this.availableNow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlansFilterState &&
        other.selectedCategory == selectedCategory &&
        other.query == query &&
        other.distanceRadiusKm == distanceRadiusKm &&
        other.visibility == visibility &&
        other.dateFilter == dateFilter &&
        other.availableNow == availableNow;
  }

  @override
  int get hashCode => Object.hash(
        selectedCategory,
        query,
        distanceRadiusKm,
        visibility,
        dateFilter,
        availableNow,
      );
}

/// The single Plans processing pipeline — the ONLY place plans are filtered
/// and sorted. The UI never sorts independently; every section consumes the
/// list this returns.
///
/// Pipeline: `All → Category → Search → Distance-first Sort`.
///
/// The distance-first comparator is the highest-priority rule across the
/// whole app and is intentionally pure so a future backend can reuse it:
///   1. Nearest distance
///   2. Happening today
///   3. Earlier start time
///   4. Newer plans (dataset order as a stable proxy)
List<Experience> applyPipeline(
  List<Experience> all,
  PlansFilterState state,
) {
  Iterable<Experience> result = all;

  // 1) Category filter (null = All).
  if (state.selectedCategory != null) {
    final cat = state.selectedCategory!.toLowerCase();
    result = result.where((e) {
      final canonical = categoryForMood(e.category)?.toLowerCase();
      return canonical == cat;
    });
  }

  // 1.5) Visibility filter (null = all; PlanVisibility.private = private only).
  if (state.visibility != null) {
    result = result.where((e) => e.visibility == state.visibility);
  }

  // 2) Search filter (title / host / mood / category / city).
  if (state.hasQuery) {
    final q = state.query.trim().toLowerCase();
    result = result.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.host.toLowerCase().contains(q) ||
          e.mood.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.city.toLowerCase().contains(q);
    });
  }

  // 3) Distance-first sort (stable — preserves dataset order for ties as a
  //    "newer" proxy).
  final list = result.toList();
  final indexOf = <String, int>{
    for (var i = 0; i < all.length; i++) all[i].id: i,
  };

  list.sort((a, b) {
    final byDistance =
        parseDistanceKm(a.distance).compareTo(parseDistanceKm(b.distance));
    if (byDistance != 0) return byDistance;

    // Happening today first.
    final aToday = isToday(a.date) ? 0 : 1;
    final bToday = isToday(b.date) ? 0 : 1;
    if (aToday != bToday) return aToday - bToday;

    // Earlier start time.
    final byTime = parseStartMinutes(a.time).compareTo(parseStartMinutes(b.time));
    if (byTime != 0) return byTime;

    // Newer plans — later dataset index treated as newer.
    return (indexOf[b.id] ?? 0).compareTo(indexOf[a.id] ?? 0);
  });

  return list;
}
