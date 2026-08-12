import 'profile_data.dart';

/// Pure validation layer for the Profile feature.
///
/// These helpers contain ZERO UI logic and are intentionally separate from the
/// immutable models in `profile_data.dart`. Keeping validation here means the
/// exact same rules can be reused by future Phase 4.2 Profile Management,
/// Firebase validation, and API validation without any duplication.

/// At least [kMinProfilePhotos] and at most [kMaxProfilePhotos] photos.
bool validatePhotos(List<ProfilePhoto> photos) {
  return photos.length >= kMinProfilePhotos &&
      photos.length <= kMaxProfilePhotos;
}

/// A non-empty, meaningful bio (trimmed length ≥ 10).
bool validateBio(String bio) => bio.trim().length >= 10;

/// At least [kMinInterests] interests.
bool validateInterests(List<String> interests) =>
    interests.length >= kMinInterests;

/// At least [kMinLanguages] languages.
bool validateLanguages(List<String> languages) =>
    languages.length >= kMinLanguages;

/// At least one social link with a non-empty URL.
bool validateSocialLinks(List<SocialLink> links) =>
    links.any((l) => l.url.trim().isNotEmpty);

/// Whether a date of birth is present, valid, and the user is at least 18.
///
/// Rules:
///   1. DOB must be provided (non-null).
///   2. DOB must not be in the future.
///   3. User must be at least 18 years old (calendar-accurate).
bool validateDateOfBirth(DateTime? dob) {
  if (dob == null) return false;
  final now = DateTime.now();
  final dobDay = DateTime(dob.year, dob.month, dob.day);
  final today = DateTime(now.year, now.month, now.day);
  if (dobDay.isAfter(today)) return false;
  return ageFromDate(dobDay, now: now) >= 18;
}

/// Formats a [DateTime] as an ISO date-only string (`YYYY-MM-DD`).
///
/// Used for the Supabase `profiles.date_of_birth` `DATE` column and for local
/// draft/profile JSON so both round-trip identically.
String formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Calculates whole-year age from [dob] using the actual calendar birthday.
///
/// This is NOT a naive `currentYear - birthYear`: the current year's birthday
/// must have been reached for the age to increment. Provided as a prerequisite
/// for People/Discovery, which will consume it in a later phase.
int ageFromDate(DateTime dob, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  var age = ref.year - dob.year;
  final hadBirthdayThisYear = (ref.month > dob.month) ||
      (ref.month == dob.month && ref.day >= dob.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}

/// Whether every required field of a [draft] passes validation.
///
/// Optional fields never participate here, so they can never block completion.
bool validateDraft(UserProfileDraft draft) {
  return validatePhotos(draft.photos) &&
      validateBio(draft.bio) &&
      validateInterests(draft.interests) &&
      validateLanguages(draft.languages) &&
      draft.gender.trim().isNotEmpty &&
      validateDateOfBirth(draft.dateOfBirth) &&
      draft.location.trim().isNotEmpty &&
      validateSocialLinks(draft.socialLinks);
}
