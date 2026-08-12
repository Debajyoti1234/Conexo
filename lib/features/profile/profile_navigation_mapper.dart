import '../home_connection_dashboard_data.dart';
import '../home_discovery_data.dart';
import 'connections_view_model.dart';
import 'profile_data.dart';
import 'public_profile_data.dart';
import 'discovery_data.dart';

/// The single, reusable mapper from existing demo models to the shared
/// [PublicProfileViewData] consumed by `premiumPublicProfileRoute()`.
///
/// Navigation wiring only: these functions map ONLY fields that already exist
/// on the demo models. They never invent profile data and never touch a
/// backend, repository, or persistence. Every screen that opens a public
/// profile must reuse these so mapping logic is never duplicated.

/// Builds an ordered, de-duplicated photo gallery from a person's own portrait
/// followed by the remaining local portrait assets that already ship with the
/// app ([profilePhotoGallery]). This activates the existing premium swipeable
/// gallery (which needs more than one photo) without any new assets or fake
/// demo data. Returns an empty list only when no portrait is available.
List<ProfilePhoto> _galleryFor(String idPrefix, String primaryPortrait) {
  final ordered = <String>[
    if (primaryPortrait.isNotEmpty) primaryPortrait,
    for (final asset in profilePhotoGallery)
      if (asset != primaryPortrait) asset,
  ];
  if (ordered.isEmpty) return const [];
  return [
    for (var i = 0; i < ordered.length; i++)
      ProfilePhoto(
        id: '${idPrefix}_photo_$i',
        assetPath: ordered[i],
        isPrimary: i == 0,
      ),
  ];
}

/// Maps an established [NetworkConnection] to a public profile view model.
PublicProfileViewData mapNetworkConnectionToProfile(NetworkConnection c) {
  return PublicProfileViewData(
    displayName: c.name,
    age: c.age,
    viewerInterests: c.mutualInterests,
    profile: UserProfile(
      id: c.id,
      photos: _galleryFor(c.id, c.portrait),
      bio: '',
      interests: c.mutualInterests,
      languages: const [],
      gender: '',
      location: c.city,
      socialLinks: const [],
      occupation: c.occupation,
    ),
  );
}

/// Maps a [DiscoveryPerson] to a public profile view model.
PublicProfileViewData mapDiscoveryPersonToProfile(DiscoveryPerson p) {
  return PublicProfileViewData(
    displayName: p.name,
    age: p.age,
    viewerInterests: p.mutualInterests,
    profile: UserProfile(
      id: p.name,
      photos: _galleryFor(p.name, p.portrait),
      bio: p.bio,

      interests: p.tags,
      languages: p.languages,
      gender: '',
      location: p.city,
      socialLinks: p.instagram.isEmpty
          ? const []
          : [
              SocialLink(
                platform: 'Instagram',
                displayText: p.instagram,
                url: p.instagram,
              ),
            ],
      occupation: p.occupation,
      aboutMe: p.lookingFor,
    ),
  );
}

/// Maps a [DiscoveryProfile] to a public profile view model.
PublicProfileViewData mapDiscoveryProfileToProfile(DiscoveryProfile p) {
  return PublicProfileViewData(
    displayName: p.displayName.isNotEmpty ? p.displayName : p.name,
    age: p.age,
    viewerInterests: const [],
    profile: UserProfile(
      id: p.id,
      photos: _galleryFor(p.id, p.portrait),
      bio: p.bio,
      interests: p.interests,
      languages: p.languages,
      gender: p.gender,
      location: p.location,
      socialLinks: const [],
      occupation: p.occupation ?? '',
      verificationStatus: p.verificationStatus,
      profileVisibility: p.profileVisibility,
      dateOfBirth: p.dateOfBirth,
      aboutMe: p.bio,
      displayName: p.displayName,
      availabilityStatus: p.availabilityStatus,
    ),
  );
}

/// Maps an [IncomingRequest] to a public profile view model.
PublicProfileViewData mapIncomingRequestToProfile(IncomingRequest request) {
  return PublicProfileViewData(
    displayName: request.name,
    age: request.age,
    viewerInterests: request.mutualInterests,
    profile: UserProfile(
      id: request.id,
      photos: _galleryFor(request.id, request.portrait),
      bio: request.bio,
      interests: request.mutualInterests,
      languages: const [],
      gender: '',
      location: request.city,
      socialLinks: const [],
      occupation: request.occupation,
      verificationStatus: VerificationStatus.notVerified,
      profileVisibility: ProfileVisibility.public,
      displayName: request.name,
      availabilityStatus: 'offline',
    ),
  );
}

/// Maps a [PendingRequest] to a public profile view model.
PublicProfileViewData mapPendingRequestToProfile(PendingRequest request) {
  return PublicProfileViewData(
    displayName: request.name,
    age: 0,
    viewerInterests: const [],
    profile: UserProfile(
      id: request.id,
      photos: _galleryFor(request.id, request.portrait),
      bio: '',
      interests: const [],
      languages: const [],
      gender: '',
      location: '',
      socialLinks: const [],
      occupation: '',
      verificationStatus: VerificationStatus.notVerified,
      profileVisibility: ProfileVisibility.public,
      displayName: request.name,
      availabilityStatus: 'offline',
    ),
  );
}

/// Maps a [ConnectionUiModel] to a public profile view model.
PublicProfileViewData mapConnectionUiModelToProfile(ConnectionUiModel model) {
  return PublicProfileViewData(
    displayName: model.otherUserName,
    age: model.otherUserAge,
    viewerInterests: model.mutualInterests,
    profile: UserProfile(
      id: model.otherUserId,
      photos: _galleryFor(model.otherUserId, model.otherUserPortrait ?? ''),
      bio: model.otherUserBio ?? '',
      interests: model.mutualInterests,
      languages: model.otherUserLanguages,
      gender: '',
      location: model.otherUserCity ?? '',
      socialLinks: const [],
      occupation: model.otherUserOccupation ?? '',
      verificationStatus: model.isVerified
          ? VerificationStatus.verified
          : VerificationStatus.notVerified,
      profileVisibility: ProfileVisibility.public,
      displayName: model.otherUserName,
      availabilityStatus: model.otherUserAvailabilityStatus ?? 'offline',
    ),
  );
}
