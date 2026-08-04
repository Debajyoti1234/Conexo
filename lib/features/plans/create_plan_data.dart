import 'package:flutter/material.dart';

import 'plans_data.dart';

/// Data layer for the premium Create Plan flow.
///
/// Everything here is local-only. Models are shaped so a future backend can
/// take over without any UI change:
///  • [PlanDraft] carries nullable `latitude`/`longitude` + `createdAt` so
///    future distance-first discovery needs no model change.
///  • [PublishedPlan] already includes `id`, `hostId`, `createdAt`,
///    `updatedAt`, `latitude`, `longitude`, `visibility`, and `status`
///    (defaults to `active`) as placeholders for backend integration.
///
/// The live preview reuses the exact Phase 3.1 [Experience] card via
/// [draftToPlan]; no second preview design exists.

// ── Cover gallery (local Conexo assets only, no network) ────────────────

/// A selectable local cover for the premium Conexo Gallery grid.
class PlanCoverOption {
  const PlanCoverOption(this.asset, this.title);
  final String asset;
  final String title;
}

const planCoverGallery = <PlanCoverOption>[
  PlanCoverOption('assets/images/plans/movie_night.jpeg', 'Movie Night'),
  PlanCoverOption('assets/images/plans/uno_night.jpeg', 'UNO Night'),
  PlanCoverOption('assets/images/plans/house_party.jpeg', 'House Party'),
  PlanCoverOption('assets/images/plans/music_jamming.jpeg', 'Music Jamming'),
  PlanCoverOption('assets/images/plans/chai_chusky.jpeg', 'Chai & Chuski'),
  PlanCoverOption('assets/images/plans/cafe_hunting.jpeg', 'Cafe Hunting'),
  PlanCoverOption('assets/images/plans/long_drive.jpeg', 'Long Drive'),
  PlanCoverOption('assets/images/plans/beach_walk.jpeg', 'Beach Walk'),
  PlanCoverOption('assets/images/plans/camping.jpeg', 'Camping'),
  PlanCoverOption('assets/images/plans/coding_session.jpeg', 'Coding Session'),
  PlanCoverOption('assets/images/plans/football.jpeg', 'Football'),
  PlanCoverOption('assets/images/plans/cycling.jpeg', 'Cycling'),
  PlanCoverOption('assets/images/plans/board_games.jpeg', 'Board Games'),
  PlanCoverOption('assets/images/plans/karaoke.jpeg', 'Karaoke'),
  PlanCoverOption('assets/images/plans/painting.jpeg', 'Painting'),
  PlanCoverOption('assets/images/plans/rooftop_lounge.jpeg', 'Rooftop Lounge'),
  PlanCoverOption('assets/images/plans/street_food.jpeg', 'Street Food'),
  PlanCoverOption('assets/images/plans/startup_meetup.jpeg', 'Startup Meetup'),
];

// ── Mood options ────────────────────────────────────────────────────────

/// A luxury mood chip option (label + emoji + accent + suggested cover).
class PlanMoodOption {
  const PlanMoodOption(this.label, this.emoji, this.accent, [this.cover]);
  final String label;
  final String emoji;
  final Color accent;
  final String? cover;
}

const _violet = Color(0xFF8B5CF6);
const _blue = Color(0xFF6C8EF5);
const _cyan = Color(0xFF22BFE0);
const _pink = Color(0xFFE36D9D);
const _orange = Color(0xFFF09A65);
const _green = Color(0xFF47D7A5);

const planMoods = <PlanMoodOption>[
  PlanMoodOption('Movie Night', '🎬', _violet,
      'assets/images/plans/movie_night.jpeg'),
  PlanMoodOption('Netflix & Chill', '📺', _violet,
      'assets/images/plans/movie_night.jpeg'),
  PlanMoodOption('UNO Night', '🃏', _pink,
      'assets/images/plans/uno_night.jpeg'),
  PlanMoodOption('House Party', '🏠', _orange,
      'assets/images/plans/house_party.jpeg'),
  PlanMoodOption('Music Jamming', '🎵', _cyan,
      'assets/images/plans/music_jamming.jpeg'),
  PlanMoodOption('Chai & Chuski', '☕', _orange,
      'assets/images/plans/chai_chusky.jpeg'),
  PlanMoodOption('Cafe Hunting', '🍮', _pink,
      'assets/images/plans/cafe_hunting.jpeg'),
  PlanMoodOption('Long Drive', '🚗', _cyan,
      'assets/images/plans/long_drive.jpeg'),
  PlanMoodOption('Beach Walk', '🌊', _cyan,
      'assets/images/plans/beach_walk.jpeg'),
  PlanMoodOption('Photography Walk', '📷', _pink,
      'assets/images/plans/cafe_hunting.jpeg'),
  PlanMoodOption('Study Together', '📖', _blue,
      'assets/images/plans/coding_session.jpeg'),
  PlanMoodOption('Coding Session', '💻', _blue,
      'assets/images/plans/coding_session.jpeg'),
  PlanMoodOption('Football', '⚽', _green,
      'assets/images/plans/football.jpeg'),
  PlanMoodOption('Badminton', '🏸', _green,
      'assets/images/plans/football.jpeg'),
  PlanMoodOption('Camping', '🏕', _green,
      'assets/images/plans/camping.jpeg'),
  PlanMoodOption('Sunset Ride', '🌇', _orange,
      'assets/images/plans/long_drive.jpeg'),
  PlanMoodOption('Custom', '✨', _violet),
];

PlanMoodOption? moodByLabel(String? label) {
  if (label == null) return null;
  for (final m in planMoods) {
    if (m.label == label) return m;
  }
  return null;
}

/// Maximum participant options for the luxury chips (last is Custom).
const participantOptions = <int>[2, 4, 6, 8, 10, 15, 20];

// ── The editable draft ──────────────────────────────────────────────────

class PlanDraft {
  const PlanDraft({
    this.coverAsset,
    this.title = '',
    this.mood,
    this.customMood = '',
    this.visibility,
    this.location = '',
    this.latitude,
    this.longitude,
    this.createdAt,
    this.date,
    this.time,
    this.participants,
    this.customParticipants,
    this.description = '',
  });

  final String? coverAsset;
  final String title;
  final String? mood;
  final String customMood;
  final PlanVisibility? visibility;
  final String location;
  final double? latitude; // future distance-first (unused in UI today)
  final double? longitude; // future distance-first (unused in UI today)
  final DateTime? createdAt;
  final DateTime? date;
  final TimeOfDay? time;
  final int? participants;
  final int? customParticipants;
  final String description;

  /// The mood actually chosen (respecting the Custom text field).
  String get effectiveMood =>
      mood == 'Custom' ? customMood.trim() : (mood ?? '');

  /// The participant limit actually chosen (respecting Custom).
  int? get effectiveParticipants =>
      participants == -1 ? customParticipants : participants;

  bool get hasCover => coverAsset != null && coverAsset!.isNotEmpty;
  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasMood => effectiveMood.isNotEmpty;
  bool get hasVisibility => visibility != null;
  bool get hasLocation => location.trim().isNotEmpty;
  bool get hasDate => date != null;
  bool get hasTime => time != null;
  bool get hasParticipants => (effectiveParticipants ?? 0) > 0;

  /// All required fields complete (description is optional).
  bool get isComplete =>
      hasCover &&
      hasTitle &&
      hasMood &&
      hasVisibility &&
      hasLocation &&
      hasDate &&
      hasTime &&
      hasParticipants;

  PlanDraft copyWith({
    String? coverAsset,
    String? title,
    String? mood,
    String? customMood,
    PlanVisibility? visibility,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? date,
    TimeOfDay? time,
    int? participants,
    int? customParticipants,
    String? description,
  }) {
    return PlanDraft(
      coverAsset: coverAsset ?? this.coverAsset,
      title: title ?? this.title,
      mood: mood ?? this.mood,
      customMood: customMood ?? this.customMood,
      visibility: visibility ?? this.visibility,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      date: date ?? this.date,
      time: time ?? this.time,
      participants: participants ?? this.participants,
      customParticipants: customParticipants ?? this.customParticipants,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'coverAsset': coverAsset,
        'title': title,
        'mood': mood,
        'customMood': customMood,
        'visibility': visibility?.name,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt?.toIso8601String(),
        'date': date?.toIso8601String(),
        'timeHour': time?.hour,
        'timeMinute': time?.minute,
        'participants': participants,
        'customParticipants': customParticipants,
        'description': description,
      };

  factory PlanDraft.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time;
    final h = json['timeHour'] as int?;
    final m = json['timeMinute'] as int?;
    if (h != null && m != null) time = TimeOfDay(hour: h, minute: m);

    PlanVisibility? visibility;
    final v = json['visibility'] as String?;
    if (v == PlanVisibility.public.name) visibility = PlanVisibility.public;
    if (v == PlanVisibility.private.name) visibility = PlanVisibility.private;

    DateTime? parseDate(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    return PlanDraft(
      coverAsset: json['coverAsset'] as String?,
      title: (json['title'] as String?) ?? '',
      mood: json['mood'] as String?,
      customMood: (json['customMood'] as String?) ?? '',
      visibility: visibility,
      location: (json['location'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: parseDate(json['createdAt']),
      date: parseDate(json['date']),
      time: time,
      participants: json['participants'] as int?,
      customParticipants: json['customParticipants'] as int?,
      description: (json['description'] as String?) ?? '',
    );
  }
}

// ── The published plan (future-ready model) ─────────────────────────────

class PublishedPlan {
  const PublishedPlan({
    required this.id,
    required this.hostId,
    required this.createdAt,
    required this.updatedAt,
    required this.coverAsset,
    required this.title,
    required this.mood,
    required this.location,
    required this.visibility,
    this.latitude,
    this.longitude,
    this.date,
    this.timeLabel = '',
    this.participants,
    this.description = '',
    this.status = 'active',
  });

  final String id;
  final String hostId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String coverAsset;
  final String title;
  final String mood;
  final String location;
  final PlanVisibility visibility;
  final double? latitude; // future distance-first
  final double? longitude; // future distance-first
  final DateTime? date;
  final String timeLabel;
  final int? participants;
  final String description;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostId': hostId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'coverAsset': coverAsset,
        'title': title,
        'mood': mood,
        'location': location,
        'visibility': visibility.name,
        'latitude': latitude,
        'longitude': longitude,
        'date': date?.toIso8601String(),
        'timeLabel': timeLabel,
        'participants': participants,
        'description': description,
        'status': status,
      };

  factory PublishedPlan.fromJson(Map<String, dynamic> json) {
    DateTime parseRequired(Object? raw) =>
        (raw is String ? DateTime.tryParse(raw) : null) ?? DateTime.now();
    DateTime? parseNullable(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    PlanVisibility visibility = PlanVisibility.public;
    final v = json['visibility'] as String?;
    if (v == PlanVisibility.private.name) visibility = PlanVisibility.private;

    return PublishedPlan(
      id: (json['id'] as String?) ?? 'plan_unknown',
      hostId: (json['hostId'] as String?) ?? 'local_user',
      createdAt: parseRequired(json['createdAt']),
      updatedAt: parseRequired(json['updatedAt']),
      coverAsset: (json['coverAsset'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      mood: (json['mood'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      visibility: visibility,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      date: parseNullable(json['date']),
      timeLabel: (json['timeLabel'] as String?) ?? '',
      participants: json['participants'] as int?,
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
    );
  }

  factory PublishedPlan.fromDraft(PlanDraft draft) {
    final now = DateTime.now();
    return PublishedPlan(
      id: 'plan_${now.microsecondsSinceEpoch}',
      hostId: 'local_user',
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
      coverAsset: draft.coverAsset ?? '',
      title: draft.title.trim(),
      mood: draft.effectiveMood,
      location: draft.location.trim(),
      visibility: draft.visibility ?? PlanVisibility.public,
      latitude: draft.latitude,
      longitude: draft.longitude,
      date: draft.date,
      participants: draft.effectiveParticipants,
      description: draft.description.trim(),
      status: 'active',
    );
  }
}

// ── Draft → Experience mapping (single source of truth for preview) ─────

String _formatDate(DateTime? date) {
  if (date == null) return 'Pick a date';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _formatTime(TimeOfDay? time) {
  if (time == null) return 'Pick a time';
  final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final m = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $period';
}

/// Builds the Phase 3.1 [Experience] used to render the live preview card.
/// Plan terminology is used for the helper; the underlying model is reused
/// unchanged until a future refactor.
Experience draftToPlan(PlanDraft draft) {
  final mood = moodByLabel(draft.mood);
  final accent = mood?.accent ?? _violet;
  final effectiveMood = draft.effectiveMood;
  final limit = draft.effectiveParticipants;

  return Experience(
    id: 'draft_preview',
    title: draft.hasTitle ? draft.title.trim() : 'Your plan title',
    host: 'You',
    hostPortrait: 'assets/images/portraits/demo1.jpeg',
    coverAsset: draft.coverAsset ?? planCoverGallery.first.asset,
    category: effectiveMood.isEmpty ? 'Plan' : effectiveMood,
    mood: effectiveMood.isEmpty ? 'Mood' : effectiveMood,
    moodEmoji: mood?.emoji ?? '✨',
    city: draft.hasLocation ? draft.location.trim() : 'Nearby',
    date: _formatDate(draft.date),
    time: _formatTime(draft.time),
    distance: draft.hasLocation ? draft.location.trim() : 'Nearby',
    goingCount: 1,
    spotsLeft: limit ?? 0,
    accent: accent,
    highlight: draft.description.trim().isEmpty
        ? 'Just created — be the first to join'
        : draft.description.trim(),
    participants: const <String>[],
    visibility: draft.visibility ?? PlanVisibility.public,
  );
}
