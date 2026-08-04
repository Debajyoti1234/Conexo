import 'profile_data.dart';
import 'profile_validation.dart';

/// Pure profile-quality engine for Phase 4.4 — Profile Strength & Completion.
///
/// This file is 100% pure, immutable logic — NO UI, NO persistence, NO
/// networking. It is intentionally isolated so the same scoring can later be
/// reused anywhere in Conexo (Discovery ranking, profile badges, nudges) by
/// simply calling [computeProfileStrength].
///
/// Design rules baked into the score:
///  • Required fields dominate the score (70 of 100 points).
///  • Optional fields improve quality (up to 20 points).
///  • Verification adds a bonus (10 points) ONLY when
///    [VerificationStatus.verified].
///  • Profile visibility (public/private) has ZERO effect on the score.

// ── Tiers ─────────────────────────────────────────────────────────────────────

/// Strength tiers derived purely from [ProfileStrengthResult.profileScore].
enum ProfileStrengthTier { bronze, silver, gold, platinum }

/// Maps a 0–100 [score] to a [ProfileStrengthTier].
///
///  • 0–39   → bronze
///  • 40–69  → silver
///  • 70–89  → gold
///  • 90–100 → platinum
ProfileStrengthTier tierForScore(int score) {
  if (score >= 90) return ProfileStrengthTier.platinum;
  if (score >= 70) return ProfileStrengthTier.gold;
  if (score >= 40) return ProfileStrengthTier.silver;
  return ProfileStrengthTier.bronze;
}

/// The human-facing label for a tier (e.g. "Gold").
String tierLabel(ProfileStrengthTier tier) => switch (tier) {
      ProfileStrengthTier.bronze => 'Bronze',
      ProfileStrengthTier.silver => 'Silver',
      ProfileStrengthTier.gold => 'Gold',
      ProfileStrengthTier.platinum => 'Platinum',
    };

// ── Checklist items ───────────────────────────────────────────────────────────

/// Which bucket a [ProfileStrengthItem] belongs to.
enum StrengthCategory { required, optional, verification }

/// A single, immutable strength/checklist entry describing one facet of the
/// profile — whether it's satisfied, how much it's worth, and its category.
class ProfileStrengthItem {
  const ProfileStrengthItem({
    required this.id,
    required this.label,
    required this.done,
    required this.category,
    required this.earned,
    required this.maxPoints,
    this.hint,
  });

  final String id;
  final String label;
  final bool done;
  final StrengthCategory category;

  /// Points earned by this item toward the total (0..[maxPoints]).
  final int earned;

  /// Maximum points this item can contribute.
  final int maxPoints;

  /// Optional actionable hint used to generate a suggestion when not [done].
  final String? hint;
}

// ── Score breakdown ─────────────────────────────────────────────────────────

/// An immutable, per-bucket breakdown of the computed [profileScore].
///
/// The individual fields always sum to [total] (which equals
/// [ProfileStrengthResult.profileScore]).
class ProfileScoreBreakdown {
  const ProfileScoreBreakdown({
    required this.photosScore,
    required this.bioScore,
    required this.interestsScore,
    required this.languagesScore,
    required this.coreFieldsScore,
    required this.optionalScore,
    required this.verificationBonus,
  });

  /// Photos contribution (part of the required bucket).
  final int photosScore;

  /// Bio contribution (part of the required bucket).
  final int bioScore;

  /// Interests contribution (part of the required bucket).
  final int interestsScore;

  /// Languages contribution (part of the required bucket).
  final int languagesScore;

  /// Gender + location contribution (part of the required bucket).
  final int coreFieldsScore;

  /// Optional-fields contribution (occupation, education, about, etc.).
  final int optionalScore;

  /// Verification bonus (only non-zero when the profile is verified).
  final int verificationBonus;

  /// The sum of the required bucket (photos + bio + interests + languages +
  /// core fields).
  int get requiredTotal =>
      photosScore +
      bioScore +
      interestsScore +
      languagesScore +
      coreFieldsScore;

  /// The full score (required + optional + verification bonus).
  int get total => requiredTotal + optionalScore + verificationBonus;
}

// ── Result ────────────────────────────────────────────────────────────────────

/// The immutable output of [computeProfileStrength].
class ProfileStrengthResult {
  const ProfileStrengthResult({
    required this.completionPercentage,
    required this.profileScore,
    required this.tier,
    required this.completedItems,
    required this.remainingItems,
    required this.suggestions,
    required this.verificationBonus,
    required this.photoScore,
    required this.profileScoreBreakdown,
  });

  /// 0.0–1.0 ratio of satisfied REQUIRED fields (drives the ring).
  final double completionPercentage;

  /// The overall 0–100 profile score.
  final int profileScore;

  /// The tier derived from [profileScore].
  final ProfileStrengthTier tier;

  /// Items that are satisfied.
  final List<ProfileStrengthItem> completedItems;

  /// Items that still need attention.
  final List<ProfileStrengthItem> remainingItems;

  /// Auto-generated, prioritized improvement suggestions.
  final List<String> suggestions;

  /// The verification bonus that was applied (0 unless verified).
  final int verificationBonus;

  /// The photos-only score (surfaced for quick display).
  final int photoScore;

  /// The full per-bucket breakdown.
  final ProfileScoreBreakdown profileScoreBreakdown;

  /// A convenience 0–100 completion integer.
  int get completionPercent => (completionPercentage * 100).round();
}

// ── Point budget (sums to 100) ────────────────────────────────────────────────

const int _kPhotosMax = 20;
const int _kBioMax = 12;
const int _kInterestsMax = 12;
const int _kLanguagesMax = 8;
const int _kGenderMax = 9;
const int _kLocationMax = 9;
// Required subtotal = 70.

const int _kOptionalMax = 20;
const int _kVerificationBonus = 10;
// Optional (20) + verification (10) + required (70) = 100.

// ── The pure engine ───────────────────────────────────────────────────────────

/// Computes a complete, immutable [ProfileStrengthResult] for [profile].
///
/// Pure and deterministic: identical inputs always produce identical output,
/// with no side effects. Visibility never influences the result.
ProfileStrengthResult computeProfileStrength(UserProfile profile) {
  // ── Photos: full credit at [kMaxProfilePhotos], with the minimum required
  // count guaranteeing a solid baseline. ──
  final photoCount = profile.photos.length;
  final photosDone = validatePhotos(profile.photos);
  final photosScore = _scaleTo(
    value: photoCount,
    min: 0,
    max: kMaxProfilePhotos,
    maxPoints: _kPhotosMax,
  );

  // ── Bio: credit once it meets the minimum meaningful length, scaled a bit
  // by how fleshed-out it is up to ~160 chars. ──
  final bioDone = validateBio(profile.bio);
  final bioLen = profile.bio.trim().length;
  final bioScore = bioDone
      ? _scaleFrom(
          value: bioLen,
          floor: 10,
          ceil: 160,
          floorPoints: (_kBioMax * 0.6).round(),
          maxPoints: _kBioMax,
        )
      : _scaleTo(value: bioLen, min: 0, max: 10, maxPoints: (_kBioMax * 0.5).round());

  // ── Interests / languages: scale to sensible "great profile" counts. ──
  final interestsDone = validateInterests(profile.interests);
  final interestsScore = _scaleTo(
    value: profile.interests.length,
    min: 0,
    max: 6,
    maxPoints: _kInterestsMax,
  );

  final languagesDone = validateLanguages(profile.languages);
  final languagesScore = _scaleTo(
    value: profile.languages.length,
    min: 0,
    max: 4,
    maxPoints: _kLanguagesMax,
  );

  // ── Core single-value required fields. ──
  final genderDone = profile.gender.trim().isNotEmpty;
  final locationDone = profile.location.trim().isNotEmpty;
  final genderScore = genderDone ? _kGenderMax : 0;
  final locationScore = locationDone ? _kLocationMax : 0;
  final coreFieldsScore = genderScore + locationScore;

  // ── Optional quality fields (each worth a small slice, capped at 20). ──
  final optional = <_OptionalField>[
    _OptionalField('occupation', 'Add your occupation',
        profile.occupation.trim().isNotEmpty, 4),
    _OptionalField('education', 'Add your education',
        profile.education.trim().isNotEmpty, 4),
    _OptionalField('aboutMe', 'Tell more about yourself',
        profile.aboutMe.trim().isNotEmpty, 4),
    _OptionalField(
        'activities',
        'Add your favorite activities',
        profile.favoriteActivities.isNotEmpty,
        3),
    _OptionalField(
        'social',
        'Link a social account',
        validateSocialLinks(profile.socialLinks),
        3),
    _OptionalField('hometown', 'Add your hometown',
        profile.hometown.trim().isNotEmpty, 2),
  ];
  var optionalScore = 0;
  for (final f in optional) {
    if (f.done) optionalScore += f.points;
  }
  if (optionalScore > _kOptionalMax) optionalScore = _kOptionalMax;

  // ── Verification bonus (only when verified). ──
  final verified = profile.verificationStatus == VerificationStatus.verified;
  final verificationBonus = verified ? _kVerificationBonus : 0;

  final breakdown = ProfileScoreBreakdown(
    photosScore: photosScore,
    bioScore: bioScore,
    interestsScore: interestsScore,
    languagesScore: languagesScore,
    coreFieldsScore: coreFieldsScore,
    optionalScore: optionalScore,
    verificationBonus: verificationBonus,
  );

  var totalScore = breakdown.total;
  if (totalScore > 100) totalScore = 100;
  if (totalScore < 0) totalScore = 0;

  // ── Required-field completion ratio (7 required facets). ──
  const requiredCount = 7;
  var requiredDone = 0;
  if (photosDone) requiredDone++;
  if (bioDone) requiredDone++;
  if (interestsDone) requiredDone++;
  if (languagesDone) requiredDone++;
  if (genderDone) requiredDone++;
  if (locationDone) requiredDone++;
  if (validateSocialLinks(profile.socialLinks)) requiredDone++;
  final completion = requiredDone / requiredCount;

  // ── Build the checklist items (required + optional + verification). ──
  final items = <ProfileStrengthItem>[
    ProfileStrengthItem(
      id: 'photos',
      label: photosDone
          ? 'Photos added ($photoCount/$kMaxProfilePhotos)'
          : 'Add at least $kMinProfilePhotos photos',
      done: photosDone,
      category: StrengthCategory.required,
      earned: photosScore,
      maxPoints: _kPhotosMax,
      hint: photoCount < kMaxProfilePhotos ? 'Add another profile photo' : null,
    ),
    ProfileStrengthItem(
      id: 'bio',
      label: bioDone ? 'Bio written' : 'Complete your bio',
      done: bioDone,
      category: StrengthCategory.required,
      earned: bioScore,
      maxPoints: _kBioMax,
      hint: 'Complete your bio',
    ),
    ProfileStrengthItem(
      id: 'interests',
      label: interestsDone
          ? 'Interests added'
          : 'Add at least $kMinInterests interests',
      done: interestsDone,
      category: StrengthCategory.required,
      earned: interestsScore,
      maxPoints: _kInterestsMax,
      hint: 'Add more interests',
    ),
    ProfileStrengthItem(
      id: 'languages',
      label: languagesDone
          ? 'Languages added'
          : 'Add at least $kMinLanguages languages',
      done: languagesDone,
      category: StrengthCategory.required,
      earned: languagesScore,
      maxPoints: _kLanguagesMax,
      hint: 'Add the languages you speak',
    ),
    ProfileStrengthItem(
      id: 'gender',
      label: genderDone ? 'Gender set' : 'Add your gender',
      done: genderDone,
      category: StrengthCategory.required,
      earned: genderScore,
      maxPoints: _kGenderMax,
      hint: 'Add your gender',
    ),
    ProfileStrengthItem(
      id: 'location',
      label: locationDone ? 'Location set' : 'Add your location',
      done: locationDone,
      category: StrengthCategory.required,
      earned: locationScore,
      maxPoints: _kLocationMax,
      hint: 'Add your location',
    ),
    for (final f in optional)
      ProfileStrengthItem(
        id: f.id,
        label: f.done ? _optionalDoneLabel(f.id) : f.hint,
        done: f.done,
        category: StrengthCategory.optional,
        earned: f.done ? f.points : 0,
        maxPoints: f.points,
        hint: f.hint,
      ),
    ProfileStrengthItem(
      id: 'verification',
      label: verified ? 'Identity verified' : 'Verify your identity',
      done: verified,
      category: StrengthCategory.verification,
      earned: verificationBonus,
      maxPoints: _kVerificationBonus,
      hint: 'Verify your identity',
    ),
  ];

  final completed = [for (final i in items) if (i.done) i];
  final remaining = [for (final i in items) if (!i.done) i];

  // ── Suggestions: prioritize required, then verification, then optional. ──
  final suggestions = <String>[];
  void addHints(StrengthCategory category) {
    for (final i in remaining) {
      if (i.category == category && i.hint != null) {
        if (!suggestions.contains(i.hint)) suggestions.add(i.hint!);
      }
    }
  }

  addHints(StrengthCategory.required);
  addHints(StrengthCategory.verification);
  addHints(StrengthCategory.optional);

  return ProfileStrengthResult(
    completionPercentage: completion,
    profileScore: totalScore,
    tier: tierForScore(totalScore),
    completedItems: completed,
    remainingItems: remaining,
    suggestions: suggestions,
    verificationBonus: verificationBonus,
    photoScore: photosScore,
    profileScoreBreakdown: breakdown,
  );
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// A tiny value object describing an optional-quality field.
class _OptionalField {
  const _OptionalField(this.id, this.hint, this.done, this.points);
  final String id;
  final String hint;
  final bool done;
  final int points;
}

String _optionalDoneLabel(String id) => switch (id) {
      'occupation' => 'Occupation added',
      'education' => 'Education added',
      'aboutMe' => 'About section added',
      'activities' => 'Favorite activities added',
      'social' => 'Social account linked',
      'hometown' => 'Hometown added',
      _ => 'Added',
    };

/// Linearly scales [value] in the range [min]..[max] to 0..[maxPoints],
/// clamped to [maxPoints].
int _scaleTo({
  required int value,
  required int min,
  required int max,
  required int maxPoints,
}) {
  if (max <= min) return value > min ? maxPoints : 0;
  final clamped = value.clamp(min, max);
  final ratio = (clamped - min) / (max - min);
  return (ratio * maxPoints).round();
}

/// Scales [value] from [floor]..[ceil] starting at [floorPoints] up to
/// [maxPoints] (used when a field earns a solid baseline once valid).
int _scaleFrom({
  required int value,
  required int floor,
  required int ceil,
  required int floorPoints,
  required int maxPoints,
}) {
  if (value <= floor) return floorPoints;
  if (value >= ceil) return maxPoints;
  final ratio = (value - floor) / (ceil - floor);
  return (floorPoints + ratio * (maxPoints - floorPoints)).round();
}
