import 'package:supabase_flutter/supabase_flutter.dart';

import './profile_repository.dart';
import './profile_data.dart';
import './profile_validation.dart';
import '../../core/supabase/auth_service.dart';

/// Supabase implementation of [ProfileRepository].
///
/// Profile rows are stored in the `profiles` table with snake_case column names.
/// Draft persistence remains local through [LocalProfileRepository].
class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository();

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
          .select('profile_completed')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return ProfileStatus.missing;
      return (data['profile_completed'] == true)
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;
    } catch (_) {
      return ProfileStatus.error;
    }
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
        case 'created_at':
          result['createdAt'] = value;
          break;
        case 'updated_at':
          result['updatedAt'] = value;
          break;
        default:
          result[key] = value;
      }
    }
    return result;
  }
}
