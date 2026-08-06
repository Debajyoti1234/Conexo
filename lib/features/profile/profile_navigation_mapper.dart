import '../home_connection_dashboard_data.dart';
import '../home_discovery_data.dart';
import 'profile_data.dart';
import 'public_profile_data.dart';

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
