import 'package:flutter/material.dart';

/// Data layer for the premium Plans discovery experience.
///
/// Everything here is local + demo only. Models are shaped so a future
/// backend (or cloud image source) can replace the data source without
/// touching any UI: [Experience.coverAsset] is a plain string today and can
/// become a remote URL later behind the same field.

/// Whether an experience is open to everyone or invite-only.
enum PlanVisibility { public, private }

/// The visual layout a card should use. The dataset assigns these so the
/// discovery feed feels curated rather than repetitive.
enum CardVariant {
  /// Large immersive image, glass overlay, info at the bottom. (Default)
  immersive,

  /// Image on top, content below, minimal glass.
  stacked,

  /// Edge-to-edge image with a floating information card.
  floating,

  /// Small compact premium card, used naturally inside horizontal rails.
  compact,
}

/// A browsing category shown in the horizontal category strip.
class PlanCategory {
  const PlanCategory(this.label, this.emoji, this.icon, this.color);
  final String label;
  final String emoji;
  final IconData icon;
  final Color color;
}

/// A single real-life experience someone can discover.
class Experience {
  const Experience({
    required this.id,
    required this.title,
    required this.host,
    required this.hostPortrait,
    required this.coverAsset,
    required this.category,
    required this.mood,
    required this.moodEmoji,
    required this.city,
    required this.date,
    required this.time,
    required this.distance,
    required this.goingCount,
    required this.spotsLeft,
    required this.accent,
    required this.highlight,
    required this.participants,
    this.visibility = PlanVisibility.public,
    this.cardVariant = CardVariant.immersive,
    this.isEditorsPick = false,
    this.sections = const <String>[],
    this.description = '',
    this.hostId = '',
    this.capacity = 2,
    this.locationAddress = '',
    this.distanceKm,
    this.trendingScore = 0,
    this.status = 'active',
  });

  final String id;
  final String title;
  final String host;
  final String hostPortrait;
  final String coverAsset;
  final String category;
  final String mood;
  final String moodEmoji;
  final String city;
  final String date;
  final String time;
  final String distance;
  final int goingCount;
  final int spotsLeft;
  final Color accent;
  final String highlight;
  final List<String> participants;
  final PlanVisibility visibility;
  final CardVariant cardVariant;
  final bool isEditorsPick;
  final List<String> sections;
  final String description;

  bool get isPublic => visibility == PlanVisibility.public;
  final String hostId;
  final int capacity;

  /// Optional formatted address for the plan location (e.g. "Bhubaneswar,
  /// Odisha"). Empty when no structured location is available.
  final String locationAddress;

  /// Real geographic distance from the viewer, in kilometres. Null when the
  /// viewer's location is unknown or the plan has no coordinates. Used only to
  /// rank the "Near You" rail; the display string lives in [distance].
  final double? distanceKm;

  /// Deterministic engagement score for the "Trending" rail: real joined-member
  /// count blended with plan recency. Higher = stronger recent activity. 0 when
  /// the plan does not qualify. Used only to order Trending.
  final double trendingScore;

  final String status;

  Experience copyWith({
    String? id,
    String? title,
    String? host,
    String? hostPortrait,
    String? coverAsset,
    String? category,
    String? mood,
    String? moodEmoji,
    String? city,
    String? date,
    String? time,
    String? distance,
    int? goingCount,
    int? spotsLeft,
    Color? accent,
    String? highlight,
    List<String>? participants,
    PlanVisibility? visibility,
    CardVariant? cardVariant,
    bool? isEditorsPick,
    List<String>? sections,
    String? description,
    String? hostId,
    int? capacity,
    String? locationAddress,
    double? distanceKm,
    double? trendingScore,
    String? status,
  }) {
    return Experience(
      id: id ?? this.id,
      title: title ?? this.title,
      host: host ?? this.host,
      hostPortrait: hostPortrait ?? this.hostPortrait,
      coverAsset: coverAsset ?? this.coverAsset,
      category: category ?? this.category,
      mood: mood ?? this.mood,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      city: city ?? this.city,
      date: date ?? this.date,
      time: time ?? this.time,
      distance: distance ?? this.distance,
      goingCount: goingCount ?? this.goingCount,
      spotsLeft: spotsLeft ?? this.spotsLeft,
      accent: accent ?? this.accent,
      highlight: highlight ?? this.highlight,
      participants: participants ?? this.participants,
      visibility: visibility ?? this.visibility,
      cardVariant: cardVariant ?? this.cardVariant,
      isEditorsPick: isEditorsPick ?? this.isEditorsPick,
      sections: sections ?? this.sections,
      description: description ?? this.description,
      hostId: hostId ?? this.hostId,
      capacity: capacity ?? this.capacity,
      locationAddress: locationAddress ?? this.locationAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      trendingScore: trendingScore ?? this.trendingScore,
      status: status ?? this.status,
    );
  }
}

// ── Accent palette, reused across the dataset for consistent premium colour.
const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF6C8EF5);
const _cyan = Color(0xFF22BFE0);
const _pink = Color(0xFFE36D9D);
const _orange = Color(0xFFF09A65);
const _green = Color(0xFF47D7A5);

/// The 11 browsing categories (last one is Custom for user-created plans).
const planCategories = <PlanCategory>[
  PlanCategory('Chill', '☕', Icons.coffee_rounded, _pink),
  PlanCategory('House', '🏠', Icons.home_rounded, _orange),
  PlanCategory('Music', '🎵', Icons.music_note_rounded, _cyan),
  PlanCategory('Nightlife', '🌃', Icons.nightlife_rounded, _violet),
  PlanCategory('Food', '🍜', Icons.ramen_dining_rounded, _orange),
  PlanCategory('Outdoors', '🌿', Icons.park_rounded, _green),
  PlanCategory('Creative', '🎨', Icons.palette_rounded, _pink),
  PlanCategory('Professional', '💼', Icons.work_rounded, _blue),
  PlanCategory('Sports', '💪', Icons.sports_basketball_rounded, _green),
  PlanCategory('Spontaneous', '🌈', Icons.bolt_rounded, _cyan),
  PlanCategory('Custom', '✨', Icons.auto_awesome_rounded, _violet),
];

/// Top-level visibility filter appended after all browsing categories.
const privateCategory = PlanCategory(
  'Private',
  '🔒',
  Icons.lock_rounded,
  Color(0xFF8B5CF6),
);

// ── Mood → canonical Discovery category mapping ──────────────────────────

/// Maps a stored plan mood/category value to the broad Discovery category
/// label used by [planCategories]. Returns `null` for unknown values so they
/// remain visible in "All" but do not falsely match a specific category tab.
String? categoryForMood(String mood) {
  final normalized = mood.trim().toLowerCase();
  switch (normalized) {
    // Chill
    case 'movie night':
    case 'netflix & chill':
    case 'uno night':
      return 'Chill';

    // House
    case 'house party':
      return 'House';

    // Music
    case 'music jamming':
      return 'Music';

    // Food
    case 'chai & chuski':
    case 'cafe hunting':
      return 'Food';

    // Outdoors
    case 'long drive':
    case 'beach walk':
    case 'camping':
    case 'sunset ride':
      return 'Outdoors';

    // Creative
    case 'photography walk':
      return 'Creative';

    // Professional
    case 'study together':
    case 'coding session':
      return 'Professional';

    // Sports
    case 'football':
    case 'badminton':
      return 'Sports';

    // Custom
    case 'custom':
      return 'Custom';

    // Already a canonical category (defensive — preserves direct matches).
    case 'chill':
    case 'house':
    case 'music':
    case 'nightlife':
    case 'food':
    case 'outdoors':
    case 'creative':
    case 'professional':
    case 'sports':
    case 'spontaneous':
      return mood;

    default:
      return null;
  }
}

// ── Pure parse helpers (used by the central distance-first comparator) ──

/// Parses a distance label like `"2.4 km"` / `"12 km"` into kilometres.
/// Unparseable values sort last.
double parseDistanceKm(String distance) {
  final match = RegExp(r'[\d.]+').firstMatch(distance);
  if (match == null) return double.maxFinite;
  return double.tryParse(match.group(0)!) ?? double.maxFinite;
}

/// Parses a start-time label like `"6:30 PM"` into minutes-since-midnight.
/// Unparseable values sort last.
int parseStartMinutes(String time) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(time);
  if (match == null) return 24 * 60;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (hour == 12) hour = 0;
  if (isPm) hour += 12;
  return hour * 60 + minute;
}

/// Whether a date label represents "today" in the demo dataset.
bool isToday(String date) => date.trim().toLowerCase() == 'today';

/// Reorders a rail so no two adjacent cards show the same highlight line.
/// Pure + stable: only nudges an item back by one slot when it would repeat.
List<Experience> avoidAdjacentDuplicateHighlights(List<Experience> items) {
  if (items.length < 2) return items;
  final result = <Experience>[];
  final pending = List<Experience>.from(items);
  while (pending.isNotEmpty) {
    var pickIndex = 0;
    if (result.isNotEmpty) {
      final last = result.last.highlight;
      final alt = pending.indexWhere((e) => e.highlight != last);
      if (alt != -1) pickIndex = alt;
    }
    result.add(pending.removeAt(pickIndex));
  }
  return result;
}

// ── Section builders (consume the SINGLE processed pipeline output) ─────

/// Builds every rail's slice from one already-filtered + sorted list, so no
/// rail ever filters or sorts independently. Empty rails are hidden by the
/// UI. Highlight de-duplication keeps each rail feeling curated.
///
/// The "Near You" rail is the one exception: it is ordered by real geographic
/// distance (closest first) using [Experience.distanceKm], and — when the
/// viewer has a saved distance preference — restricted to plans within
/// [maxDistanceKm] (null = "Any"). Plans without a known distance are excluded
/// from Near You but remain available in the other rails.
Map<String, List<Experience>> sectionsFor(
  List<Experience> processed, {
  int? maxDistanceKm,
}) {
  List<Experience> slice(String key) => avoidAdjacentDuplicateHighlights(
        processed.where((e) => e.sections.contains(key)).toList(),
      );

  final near = processed
      .where((e) => e.distanceKm != null)
      .where((e) => maxDistanceKm == null || e.distanceKm! <= maxDistanceKm)
      .toList()
    ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));

  // Trending: ordered by real engagement + recency score (strongest first).
  final trending = processed
      .where((e) => e.sections.contains('trending'))
      .toList()
    ..sort((a, b) => b.trendingScore.compareTo(a.trendingScore));

  return {
    'featured': slice('featured'),
    'today': slice('today'),
    'trending': trending,
    'near': near,
    'friends': slice('friends'),
    'new': slice('new'),
  };
}


