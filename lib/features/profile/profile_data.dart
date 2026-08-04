import 'profile_validation.dart';

/// Immutable data layer for Phase 4.1 — Profile Creation.
///
/// Everything here is pure, immutable data + JSON (de)serialization. There is
/// NO validation logic in this file — that lives in `profile_validation.dart`
/// so the same rules can be reused by future Profile Management, Firebase, or
/// API layers without touching the models. There is also NO UI logic here.
///
/// The models are shaped so a future backend can take over with zero UI change:
///  • [ProfilePhoto] already carries a `remoteUrl` + `uploadStatus` placeholder.
///  • [UserProfileDraft] and [UserProfile] carry `latitude`/`longitude`,
///    `verificationStatus`, `profileVisibility`, and timestamps as
///    forward-looking placeholders.

// ── Local portrait gallery (local Conexo assets only, no network) ─────────

/// Selectable local portrait assets used by the Photos section. No gallery,
/// camera, or permissions are ever required — these ship with the app.
const profilePhotoGallery = <String>[
  'assets/images/portraits/demo1.jpeg',
  'assets/images/portraits/demo2.jpeg',
  'assets/images/portraits/demo3.jpeg',
  'assets/images/portraits/demo4.jpeg',
  'assets/images/portraits/demo5.jpeg',
  'assets/images/portraits/demo6.jpeg',
];

/// Minimum / maximum number of profile photos.
const int kMinProfilePhotos = 3;
const int kMaxProfilePhotos = 6;

/// Minimum interests / languages required for a complete profile.
const int kMinInterests = 3;
const int kMinLanguages = 2;

// ── Placeholder enums for future backend integration ──────────────────────

/// Verification state. Local-only builds default to [notVerified]; the
/// pending / verified states are set by a future backend verification flow.
enum VerificationStatus { notVerified, pending, verified }

/// Profile discovery visibility. [public] can appear in nearby discovery;
/// [private] is hidden from People Discovery (informational only in this build).
enum ProfileVisibility { public, private }

/// Parses a persisted [VerificationStatus], migrating legacy values.
///
/// Backward compatible: the legacy `"none"` maps to [VerificationStatus.notVerified].
VerificationStatus _verificationFromJson(Object? raw) {
  switch (raw) {
    case 'none': // legacy
    case 'notVerified':
      return VerificationStatus.notVerified;
    case 'pending':
      return VerificationStatus.pending;
    case 'verified':
      return VerificationStatus.verified;
    default:
      return VerificationStatus.notVerified;
  }
}

/// Parses a persisted [ProfileVisibility], migrating legacy values.
///
/// Backward compatible: legacy `"everyone"` → [ProfileVisibility.public], and
/// legacy `"connectionsOnly"` / `"hidden"` → [ProfileVisibility.private].
ProfileVisibility _visibilityFromJson(Object? raw) {
  switch (raw) {
    case 'everyone': // legacy
    case 'public':
      return ProfileVisibility.public;
    case 'connectionsOnly': // legacy
    case 'hidden': // legacy
    case 'private':
      return ProfileVisibility.private;
    default:
      return ProfileVisibility.public;
  }
}


/// Future-ready per-photo upload state for a backend. Local assets are [local].
enum PhotoUploadStatus { local, uploading, uploaded, failed }

// ── ProfilePhoto ──────────────────────────────────────────────────────────

/// A single immutable profile photo backed by a local asset.
///
/// [isPrimary] marks the hero/primary image (always the first in the ordered
/// list). [remoteUrl] + [uploadStatus] are placeholders for a future backend.
class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.assetPath,
    this.isPrimary = false,
    this.remoteUrl,
    this.uploadStatus = PhotoUploadStatus.local,
  });

  final String id;
  final String assetPath;
  final bool isPrimary;

  /// Placeholder for a future backend URL (null for local-only assets).
  final String? remoteUrl;

  /// Placeholder for a future upload lifecycle.
  final PhotoUploadStatus uploadStatus;

  ProfilePhoto copyWith({
    String? id,
    String? assetPath,
    bool? isPrimary,
    String? remoteUrl,
    PhotoUploadStatus? uploadStatus,
  }) {
    return ProfilePhoto(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      isPrimary: isPrimary ?? this.isPrimary,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetPath': assetPath,
        'isPrimary': isPrimary,
        'remoteUrl': remoteUrl,
        'uploadStatus': uploadStatus.name,
      };

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      id: json['id'] as String? ?? '',
      assetPath: json['assetPath'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
      remoteUrl: json['remoteUrl'] as String?,
      uploadStatus: PhotoUploadStatus.values.firstWhere(
        (s) => s.name == json['uploadStatus'],
        orElse: () => PhotoUploadStatus.local,
      ),
    );
  }
}

// ── SocialLink ──────────────────────────────────────────────────────────────

/// An immutable social link (e.g. Instagram / Twitter / Website).
class SocialLink {
  const SocialLink({
    required this.platform,
    required this.displayText,
    required this.url,
  });

  final String platform;
  final String displayText;
  final String url;

  SocialLink copyWith({
    String? platform,
    String? displayText,
    String? url,
  }) {
    return SocialLink(
      platform: platform ?? this.platform,
      displayText: displayText ?? this.displayText,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'displayText': displayText,
        'url': url,
      };

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      platform: json['platform'] as String? ?? '',
      displayText: json['displayText'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

// ── ProfileStage ────────────────────────────────────────────────────────────

/// Typed progression through the creation flow, driving progressive reveal.
enum ProfileStage {
  photos,
  bio,
  interests,
  languages,
  gender,
  location,
  socialLinks,
  optionalDetails,
  preview,
  complete,
}

/// Returns the current [ProfileStage] for a [draft] purely from its data.
///
/// Each stage unlocks once the previous required field is satisfied. Once all
/// required fields pass, the flow advances to [ProfileStage.preview] and, when
/// [UserProfileDraft.isComplete], [ProfileStage.complete].
ProfileStage stageFromDraft(UserProfileDraft draft) {
  if (!validatePhotos(draft.photos)) return ProfileStage.photos;
  if (!validateBio(draft.bio)) return ProfileStage.bio;
  if (!validateInterests(draft.interests)) return ProfileStage.interests;
  if (!validateLanguages(draft.languages)) return ProfileStage.languages;
  if (draft.gender.trim().isEmpty) return ProfileStage.gender;
  if (draft.location.trim().isEmpty) return ProfileStage.location;
  if (!validateSocialLinks(draft.socialLinks)) return ProfileStage.socialLinks;
  if (draft.isComplete) return ProfileStage.complete;
  return ProfileStage.preview;
}

// ── ProfilePreviewData ──────────────────────────────────────────────────────

/// A lightweight immutable view model consumed by `ProfilePreviewCard`.
///
/// Both [UserProfileDraft] and [UserProfile] expose `toPreviewData()`, so the
/// preview card never needs to know which model it is rendering. This keeps the
/// card reusable across the whole app with no conditional logic.
class ProfilePreviewData {
  const ProfilePreviewData({
    required this.photoAssets,
    required this.primaryPhotoAsset,
    required this.bio,
    required this.interests,
    required this.languages,
    required this.gender,
    required this.location,
    required this.socialLinks,
    this.occupation = '',
    this.education = '',
    this.company = '',
    this.college = '',
    this.hometown = '',
    this.website = '',
    this.aboutMe = '',
    this.favoriteActivities = const [],
  });

  final List<String> photoAssets;
  final String? primaryPhotoAsset;
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final String gender;
  final String location;
  final List<SocialLink> socialLinks;
  final String occupation;
  final String education;
  final String company;
  final String college;
  final String hometown;
  final String website;
  final String aboutMe;
  final List<String> favoriteActivities;
}

// ── UserProfileDraft ────────────────────────────────────────────────────────

/// The immutable, editable draft used throughout the creation flow.
///
/// Persisted between sessions through `ProfileRepository`. Optional fields
/// never block completion; only the required fields feed [isComplete].
class UserProfileDraft {
  const UserProfileDraft({
    this.photos = const [],
    this.bio = '',
    this.interests = const [],
    this.languages = const [],
    this.gender = '',
    this.location = '',
    this.socialLinks = const [],
    // Optional
    this.occupation = '',
    this.education = '',
    this.company = '',
    this.college = '',
    this.hometown = '',
    this.website = '',
    this.aboutMe = '',
    this.favoriteActivities = const [],
    // Future-ready
    this.verificationStatus = VerificationStatus.notVerified,
    this.profileVisibility = ProfileVisibility.public,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  // Required
  final List<ProfilePhoto> photos;
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final String gender;
  final String location;
  final List<SocialLink> socialLinks;

  // Optional
  final String occupation;
  final String education;
  final String company;
  final String college;
  final String hometown;
  final String website;
  final String aboutMe;
  final List<String> favoriteActivities;

  // Future-ready
  final VerificationStatus verificationStatus;
  final ProfileVisibility profileVisibility;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The primary photo (first `isPrimary`, else the first photo, else null).
  ProfilePhoto? get primaryPhoto {
    if (photos.isEmpty) return null;
    return photos.firstWhere(
      (p) => p.isPrimary,
      orElse: () => photos.first,
    );
  }

  /// Whether every required field passes validation.
  bool get isComplete => validateDraft(this);

  /// A 0..1 progress ratio across the seven required fields, used by the
  /// completion meter. Pure and UI-free.
  double get completionProgress {
    var done = 0;
    const total = 7;
    if (validatePhotos(photos)) done++;
    if (validateBio(bio)) done++;
    if (validateInterests(interests)) done++;
    if (validateLanguages(languages)) done++;
    if (gender.trim().isNotEmpty) done++;
    if (location.trim().isNotEmpty) done++;
    if (validateSocialLinks(socialLinks)) done++;
    return done / total;
  }

  /// Builds the model-independent preview view model.
  ProfilePreviewData toPreviewData() {
    return ProfilePreviewData(
      photoAssets: [for (final p in photos) p.assetPath],
      primaryPhotoAsset: primaryPhoto?.assetPath,
      bio: bio,
      interests: interests,
      languages: languages,
      gender: gender,
      location: location,
      socialLinks: socialLinks,
      occupation: occupation,
      education: education,
      company: company,
      college: college,
      hometown: hometown,
      website: website,
      aboutMe: aboutMe,
      favoriteActivities: favoriteActivities,
    );
  }

  UserProfileDraft copyWith({
    List<ProfilePhoto>? photos,
    String? bio,
    List<String>? interests,
    List<String>? languages,
    String? gender,
    String? location,
    List<SocialLink>? socialLinks,
    String? occupation,
    String? education,
    String? company,
    String? college,
    String? hometown,
    String? website,
    String? aboutMe,
    List<String>? favoriteActivities,
    VerificationStatus? verificationStatus,
    ProfileVisibility? profileVisibility,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileDraft(
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      socialLinks: socialLinks ?? this.socialLinks,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      company: company ?? this.company,
      college: college ?? this.college,
      hometown: hometown ?? this.hometown,
      website: website ?? this.website,
      aboutMe: aboutMe ?? this.aboutMe,
      favoriteActivities: favoriteActivities ?? this.favoriteActivities,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'photos': [for (final p in photos) p.toJson()],
        'bio': bio,
        'interests': interests,
        'languages': languages,
        'gender': gender,
        'location': location,
        'socialLinks': [for (final s in socialLinks) s.toJson()],
        'occupation': occupation,
        'education': education,
        'company': company,
        'college': college,
        'hometown': hometown,
        'website': website,
        'aboutMe': aboutMe,
        'favoriteActivities': favoriteActivities,
        'verificationStatus': verificationStatus.name,
        'profileVisibility': profileVisibility.name,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// Builds an editable draft from an existing finalized [profile].
  ///
  /// Carries `createdAt` (and other data) through unchanged so the finalized
  /// profile's identity + creation time can be preserved on save.
  factory UserProfileDraft.fromProfile(UserProfile profile) {
    return UserProfileDraft(
      photos: profile.photos,
      bio: profile.bio,
      interests: profile.interests,
      languages: profile.languages,
      gender: profile.gender,
      location: profile.location,
      socialLinks: profile.socialLinks,
      occupation: profile.occupation,
      education: profile.education,
      company: profile.company,
      college: profile.college,
      hometown: profile.hometown,
      website: profile.website,
      aboutMe: profile.aboutMe,
      favoriteActivities: profile.favoriteActivities,
      verificationStatus: profile.verificationStatus,
      profileVisibility: profile.profileVisibility,
      latitude: profile.latitude,
      longitude: profile.longitude,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }

  factory UserProfileDraft.fromJson(Map<String, dynamic> json) {
    return UserProfileDraft(
      photos: [
        for (final p in (json['photos'] as List? ?? const []))
          ProfilePhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
      bio: json['bio'] as String? ?? '',
      interests: _stringList(json['interests']),
      languages: _stringList(json['languages']),
      gender: json['gender'] as String? ?? '',
      location: json['location'] as String? ?? '',
      socialLinks: [
        for (final s in (json['socialLinks'] as List? ?? const []))
          SocialLink.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      occupation: json['occupation'] as String? ?? '',
      education: json['education'] as String? ?? '',
      company: json['company'] as String? ?? '',
      college: json['college'] as String? ?? '',
      hometown: json['hometown'] as String? ?? '',
      website: json['website'] as String? ?? '',
      aboutMe: json['aboutMe'] as String? ?? '',
      favoriteActivities: _stringList(json['favoriteActivities']),
      verificationStatus: _verificationFromJson(json['verificationStatus']),
      profileVisibility: _visibilityFromJson(json['profileVisibility']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

// ── UserProfile ─────────────────────────────────────────────────────────────

/// The finalized, immutable profile persisted on completion.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.photos,
    required this.bio,
    required this.interests,
    required this.languages,
    required this.gender,
    required this.location,
    required this.socialLinks,
    this.occupation = '',
    this.education = '',
    this.company = '',
    this.college = '',
    this.hometown = '',
    this.website = '',
    this.aboutMe = '',
    this.favoriteActivities = const [],
    this.verificationStatus = VerificationStatus.notVerified,
    this.profileVisibility = ProfileVisibility.public,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final List<ProfilePhoto> photos;
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final String gender;
  final String location;
  final List<SocialLink> socialLinks;
  final String occupation;
  final String education;
  final String company;
  final String college;
  final String hometown;
  final String website;
  final String aboutMe;
  final List<String> favoriteActivities;
  final VerificationStatus verificationStatus;
  final ProfileVisibility profileVisibility;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfilePhoto? get primaryPhoto {
    if (photos.isEmpty) return null;
    return photos.firstWhere(
      (p) => p.isPrimary,
      orElse: () => photos.first,
    );
  }

  /// Builds the model-independent preview view model.
  ProfilePreviewData toPreviewData() {
    return ProfilePreviewData(
      photoAssets: [for (final p in photos) p.assetPath],
      primaryPhotoAsset: primaryPhoto?.assetPath,
      bio: bio,
      interests: interests,
      languages: languages,
      gender: gender,
      location: location,
      socialLinks: socialLinks,
      occupation: occupation,
      education: education,
      company: company,
      college: college,
      hometown: hometown,
      website: website,
      aboutMe: aboutMe,
      favoriteActivities: favoriteActivities,
    );
  }

  /// Builds a finalized profile from a completed [draft] with a stable [id].
  factory UserProfile.fromDraft(UserProfileDraft draft, {required String id}) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      photos: draft.photos,
      bio: draft.bio,
      interests: draft.interests,
      languages: draft.languages,
      gender: draft.gender,
      location: draft.location,
      socialLinks: draft.socialLinks,
      occupation: draft.occupation,
      education: draft.education,
      company: draft.company,
      college: draft.college,
      hometown: draft.hometown,
      website: draft.website,
      aboutMe: draft.aboutMe,
      favoriteActivities: draft.favoriteActivities,
      verificationStatus: draft.verificationStatus,
      profileVisibility: draft.profileVisibility,
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
    );
  }

  UserProfile copyWith({
    String? id,
    List<ProfilePhoto>? photos,
    String? bio,
    List<String>? interests,
    List<String>? languages,
    String? gender,
    String? location,
    List<SocialLink>? socialLinks,
    String? occupation,
    String? education,
    String? company,
    String? college,
    String? hometown,
    String? website,
    String? aboutMe,
    List<String>? favoriteActivities,
    VerificationStatus? verificationStatus,
    ProfileVisibility? profileVisibility,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      socialLinks: socialLinks ?? this.socialLinks,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      company: company ?? this.company,
      college: college ?? this.college,
      hometown: hometown ?? this.hometown,
      website: website ?? this.website,
      aboutMe: aboutMe ?? this.aboutMe,
      favoriteActivities: favoriteActivities ?? this.favoriteActivities,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'photos': [for (final p in photos) p.toJson()],
        'bio': bio,
        'interests': interests,
        'languages': languages,
        'gender': gender,
        'location': location,
        'socialLinks': [for (final s in socialLinks) s.toJson()],
        'occupation': occupation,
        'education': education,
        'company': company,
        'college': college,
        'hometown': hometown,
        'website': website,
        'aboutMe': aboutMe,
        'favoriteActivities': favoriteActivities,
        'verificationStatus': verificationStatus.name,
        'profileVisibility': profileVisibility.name,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      photos: [
        for (final p in (json['photos'] as List? ?? const []))
          ProfilePhoto.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
      bio: json['bio'] as String? ?? '',
      interests: _stringList(json['interests']),
      languages: _stringList(json['languages']),
      gender: json['gender'] as String? ?? '',
      location: json['location'] as String? ?? '',
      socialLinks: [
        for (final s in (json['socialLinks'] as List? ?? const []))
          SocialLink.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      occupation: json['occupation'] as String? ?? '',
      education: json['education'] as String? ?? '',
      company: json['company'] as String? ?? '',
      college: json['college'] as String? ?? '',
      hometown: json['hometown'] as String? ?? '',
      website: json['website'] as String? ?? '',
      aboutMe: json['aboutMe'] as String? ?? '',
      favoriteActivities: _stringList(json['favoriteActivities']),
      verificationStatus: _verificationFromJson(json['verificationStatus']),
      profileVisibility: _visibilityFromJson(json['profileVisibility']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

// ── Pure equality helpers (used for dirty detection) ────────────────────────

/// Pure, field-by-field equality for two [UserProfileDraft]s.
///
/// Used by Profile Management for unsaved-change detection. This intentionally
/// avoids JSON string comparison (which is order/format fragile) and instead
/// compares every user-editable field. The future-ready timestamp / id-like
/// placeholders are excluded because they are not user-editable and change on
/// save; comparing them would produce false "dirty" positives.
bool profileDraftEquals(UserProfileDraft a, UserProfileDraft b) {
  return a.bio == b.bio &&
      a.gender == b.gender &&
      a.location == b.location &&
      a.occupation == b.occupation &&
      a.education == b.education &&
      a.company == b.company &&
      a.college == b.college &&
      a.hometown == b.hometown &&
      a.website == b.website &&
      a.aboutMe == b.aboutMe &&
      a.verificationStatus == b.verificationStatus &&
      a.profileVisibility == b.profileVisibility &&
      _photosEqual(a.photos, b.photos) &&
      _stringListEqual(a.interests, b.interests) &&
      _stringListEqual(a.languages, b.languages) &&
      _stringListEqual(a.favoriteActivities, b.favoriteActivities) &&
      _socialLinksEqual(a.socialLinks, b.socialLinks);
}

bool _photosEqual(List<ProfilePhoto> a, List<ProfilePhoto> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id ||
        a[i].assetPath != b[i].assetPath ||
        a[i].isPrimary != b[i].isPrimary) {
      return false;
    }
  }
  return true;
}

bool _socialLinksEqual(List<SocialLink> a, List<SocialLink> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].platform != b[i].platform ||
        a[i].displayText != b[i].displayText ||
        a[i].url != b[i].url) {
      return false;
    }
  }
  return true;
}

bool _stringListEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── Private JSON helpers ────────────────────────────────────────────────────

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return [for (final e in raw) '$e'];
  }
  return const [];
}

DateTime? _parseDate(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
