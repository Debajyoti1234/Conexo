import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile_data.dart';

enum ProfileStatus { missing, incomplete, complete, error }

abstract class ProfileRepository {
  Future<UserProfileDraft?> loadDraft();

  Future<void> saveDraft(UserProfileDraft draft);

  Future<void> clearDraft();

  Future<bool> hasDraft();

  Future<UserProfile?> loadProfile();

  Future<void> saveProfile(UserProfile profile);

  Future<bool> hasProfile();

  Future<ProfileStatus> checkProfileStatus() async {
    final profile = await loadProfile();
    if (profile == null) return ProfileStatus.missing;
    final draft = await loadDraft();
    if (draft != null && !draft.isComplete) {
      return ProfileStatus.incomplete;
    }
    return ProfileStatus.complete;
  }
}

/// The local, on-device implementation backed by [SharedPreferences].
///
/// This is the ONLY class in the Profile feature that touches
/// [SharedPreferences]. When a backend arrives, implement [ProfileRepository]
/// elsewhere and inject it; nothing else needs to change.
class LocalProfileRepository implements ProfileRepository {
  const LocalProfileRepository([this.userId]);

  final String? userId;

  String get _draftKey =>
      userId == null ? 'conexo_profile_draft_v1' : 'conexo_profile_draft_v1_$userId';

  String get _profileKey =>
      userId == null ? 'conexo_profile_v1' : 'conexo_profile_v1_$userId';

  @override
  Future<UserProfileDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfileDraft.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(UserProfileDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  @override
  Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    return raw != null && raw.isNotEmpty;
  }

  @override
  Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    return raw != null && raw.isNotEmpty;
  }

  @override
  Future<ProfileStatus> checkProfileStatus() async {
    final profile = await loadProfile();
    if (profile == null) return ProfileStatus.missing;
    final draft = await loadDraft();
    if (draft!= null &&!draft.isComplete) {
      return ProfileStatus.incomplete;
    }
    return ProfileStatus.complete;
  }
}
