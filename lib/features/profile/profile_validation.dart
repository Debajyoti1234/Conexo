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

/// Whether every required field of a [draft] passes validation.
///
/// Optional fields never participate here, so they can never block completion.
bool validateDraft(UserProfileDraft draft) {
  return validatePhotos(draft.photos) &&
      validateBio(draft.bio) &&
      validateInterests(draft.interests) &&
      validateLanguages(draft.languages) &&
      draft.gender.trim().isNotEmpty &&
      draft.location.trim().isNotEmpty &&
      validateSocialLinks(draft.socialLinks);
}
