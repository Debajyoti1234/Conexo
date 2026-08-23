import '../../core/supabase/auth_service.dart';
import 'profile_data.dart';
import 'profile_repository.dart';
import 'supabase_profile_repository.dart';

class SessionAwareProfileRepository implements ProfileRepository {
  const SessionAwareProfileRepository();

  ProfileRepository get _delegate {
    final user = AuthService.currentUser;
    if (user != null) {
      return const SupabaseProfileRepository();
    }
    return const LocalProfileRepository();
  }

  @override
  Future<UserProfileDraft?> loadDraft() => _delegate.loadDraft();

  @override
  Future<void> saveDraft(UserProfileDraft draft) => _delegate.saveDraft(draft);

  @override
  Future<void> clearDraft() => _delegate.clearDraft();

  @override
  Future<bool> hasDraft() => _delegate.hasDraft();

  @override
  Future<UserProfile?> loadProfile() => _delegate.loadProfile();

  @override
  Future<UserProfile?> loadProfileByUserId(String userId) =>
      _delegate.loadProfileByUserId(userId);

  @override
  Future<void> saveProfile(UserProfile profile) => _delegate.saveProfile(profile);

  @override
  Future<bool> hasProfile() => _delegate.hasProfile();

  @override
  Future<ProfileStatus> checkProfileStatus() => _delegate.checkProfileStatus();
}
