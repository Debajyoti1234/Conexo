import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile_data.dart';

/// The single data-access layer for the entire Profile feature.
///
/// Every Profile screen must communicate ONLY through a [ProfileRepository].
/// This keeps a single source of truth for local persistence today and a
/// single swap point for a future backend.
///
/// The repository is *injected* through constructors (no global singleton, no
/// service locator) so a future `FirestoreProfileRepository` /
/// `ApiProfileRepository` can replace [LocalProfileRepository] WITHOUT touching
/// any UI or business logic.
abstract class ProfileRepository {
  /// Loads the in-progress editable draft (or `null` if none).
  Future<UserProfileDraft?> loadDraft();

  /// Persists the in-progress editable draft.
  Future<void> saveDraft(UserProfileDraft draft);

  /// Clears the in-progress editable draft.
  Future<void> clearDraft();

  /// Whether a draft currently exists.
  Future<bool> hasDraft();

  /// Loads the finalized profile (or `null` if none saved yet).
  Future<UserProfile?> loadProfile();

  /// Persists the finalized profile.
  Future<void> saveProfile(UserProfile profile);

  /// Whether a finalized profile currently exists.
  Future<bool> hasProfile();
}

/// The local, on-device implementation backed by [SharedPreferences].
///
/// This is the ONLY class in the Profile feature that touches
/// [SharedPreferences]. When a backend arrives, implement [ProfileRepository]
/// elsewhere and inject it; nothing else needs to change.
class LocalProfileRepository implements ProfileRepository {
  const LocalProfileRepository();

  static const _draftKey = 'conexo_profile_draft_v1';
  static const _profileKey = 'conexo_profile_v1';

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
}
