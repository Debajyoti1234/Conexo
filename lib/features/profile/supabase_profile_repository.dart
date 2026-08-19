import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './profile_repository.dart';
import './profile_data.dart';
import './profile_validation.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/services/image_normalizer.dart';

/// Supabase implementation of [ProfileRepository].
///
/// Profile rows are stored in the `profiles` table with snake_case column names.
/// Draft persistence remains local through [LocalProfileRepository].
class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository();

  static const _bucket = 'profile-photos';

  @override
  Future<UserProfileDraft?> loadDraft() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    return LocalProfileRepository(user.id).loadDraft();
  }

  @override
  Future<void> saveDraft(UserProfileDraft draft) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    await LocalProfileRepository(user.id).saveDraft(draft);
  }

  @override
  Future<void> clearDraft() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    await LocalProfileRepository(user.id).clearDraft();
  }

  @override
  Future<bool> hasDraft() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    return LocalProfileRepository(user.id).hasDraft();
  }

  @override
  Future<UserProfile?> loadProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile.fromJson(_snakeToCamel(data));
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    if (profile.id != user.id) {
      throw ArgumentError('Profile ID mismatch');
    }

    final draft = UserProfileDraft.fromProfile(profile);
    final profileCompleted = validateDraft(draft);

    final payload = <String, dynamic>{
      'id': user.id,
      'photos': [for (final p in profile.photos) p.toJson()],
      'bio': profile.bio,
      'interests': profile.interests,
      'languages': profile.languages,
      'gender': profile.gender,
      'location': profile.location,
      'social_links': [for (final s in profile.socialLinks) s.toJson()],
      'date_of_birth':
          profile.dateOfBirth == null ? null : formatDateOnly(profile.dateOfBirth!),
      'occupation': profile.occupation,
      'education': profile.education,
      'company': profile.company,
      'college': profile.college,
      'hometown': profile.hometown,
      'website': profile.website,
      'about_me': profile.aboutMe,
      'favorite_activities': profile.favoriteActivities,
      'verification_status': profile.verificationStatus.name,
      'profile_visibility': profile.profileVisibility.name,
      'latitude': profile.latitude,
      'longitude': profile.longitude,
      'created_at': profile.createdAt?.toIso8601String(),
      'updated_at': profile.updatedAt?.toIso8601String(),
      'profile_completed': profileCompleted,
      'display_name': profile.displayName,
      'availability_status': profile.availabilityStatus,
      'discovery_distance_km': profile.discoveryDistanceKm,
      'discovery_min_age': profile.discoveryMinAge,
      'discovery_max_age': profile.discoveryMaxAge,
    };

    await Supabase.instance.client
        .from('profiles')
        .upsert(payload);
  }

  @override
  Future<bool> hasProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return true;
    } on PostgrestException {
      return false;
    }
  }

  @override
  Future<ProfileStatus> checkProfileStatus() async {
    final user = AuthService.currentUser;
    if (user == null) return ProfileStatus.error;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('profile_completed, date_of_birth')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return ProfileStatus.missing;
      final completed = data['profile_completed'] == true;
      final hasDob = data['date_of_birth'] != null;
      return (completed && hasDob)
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;
    } catch (_) {
      return ProfileStatus.error;
    }
  }

  Future<String> uploadProfilePhoto(String photoId, XFile xfile) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final bytes = await xfile.readAsBytes();
    final normalized = await ConexoImageNormalizer.normalize(bytes);
    final storagePath = 'profiles/${user.id}/photos/$photoId.jpg';

    await Supabase.instance.client.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          normalized.bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
          ),
        );

    return storagePath;
  }

  Future<void> deleteProfilePhoto(String storagePath) async {
    await Supabase.instance.client.storage
        .from(_bucket)
        .remove([storagePath]);
  }

  Future<String?> getSignedPhotoUrl(String storagePath) async {
    try {
      final result = await Supabase.instance.client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 3600);
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<String?>> getSignedPhotoUrls(List<String> storagePaths) async {
    final results = <String?>[];
    for (final path in storagePaths) {
      try {
        final result = await Supabase.instance.client.storage
            .from(_bucket)
            .createSignedUrl(path, 3600);
        results.add(result);
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }

  Map<String, dynamic> _snakeToCamel(Map<String, dynamic> snake) {
    final result = <String, dynamic>{};
    for (final entry in snake.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'profile_completed') continue;
      switch (key) {
        case 'social_links':
          result['socialLinks'] = value;
          break;
        case 'about_me':
          result['aboutMe'] = value;
          break;
        case 'favorite_activities':
          result['favoriteActivities'] = value;
          break;
        case 'verification_status':
          result['verificationStatus'] = value;
          break;
        case 'profile_visibility':
          result['profileVisibility'] = value;
          break;
        case 'date_of_birth':
          result['dateOfBirth'] = value;
          break;
        case 'created_at':
          result['createdAt'] = value;
          break;
        case 'updated_at':
          result['updatedAt'] = value;
          break;
        case 'display_name':
          result['displayName'] = value;
          break;
        case 'availability_status':
          result['availabilityStatus'] = value;
          break;
        case 'discovery_distance_km':
          result['discoveryDistanceKm'] = value;
          break;
        case 'discovery_min_age':
          result['discoveryMinAge'] = value;
          break;
        case 'discovery_max_age':
          result['discoveryMaxAge'] = value;
          break;
        default:
          result[key] = value;
      }
    }
    return result;
  }
}
