import 'profile_data.dart';

/// Presentation-only data layer for Phase 4.5 — Public Profile Viewer.
///
/// This file contains ONLY the immutable view model shown when another user
/// opens someone's profile, plus tiny pure helpers directly related to that
/// presentation. There is NO UI, NO repository, NO persistence, and NO backend
/// here.
///
/// [PublicProfileViewData] intentionally separates presentation identity
/// (displayName / username / age) from the storage-only [UserProfile]. In a
/// future phase these presentation fields can be sourced from a user account or
/// backend response WITHOUT changing [UserProfile] or this screen's API — the
/// same view model is reusable from Discovery, Connections, Chats, Search,
/// Notifications, and Plans.

/// Immutable presentation model for the public profile viewer.
class PublicProfileViewData {
  const PublicProfileViewData({
    required this.profile,
    required this.displayName,
    this.username,
    this.age,
    this.viewerInterests = const [],
  });

  /// The storage-only profile content (photos, bio, interests, etc.).
  final UserProfile profile;

  /// The name shown in the hero. Always required — never derived or faked.
  final String displayName;

  /// Optional handle shown beneath [displayName] (e.g. "@alex"). Shown only
  /// when supplied.
  final String? username;

  /// Optional age. Shown only when supplied (non-null).
  final int? age;

  /// The viewing user's interests, used to compute mutual interests locally.
  final List<String> viewerInterests;

  // ── Tiny pure presentation helpers ─────────────────────────────────────────

  /// Whether a non-empty [username] was supplied.
  bool get hasUsername => (username?.trim().isNotEmpty ?? false);

  /// The username formatted with a leading `@` (idempotent). Empty when none.
  String get formattedUsername {
    if (!hasUsername) return '';
    final u = username!.trim();
    return u.startsWith('@') ? u : '@$u';
  }

  /// Whether an [age] was supplied.
  bool get hasAge => age != null;

  /// The interests shared between the viewer and this profile, preserving the
  /// profile's ordering. Case-insensitive, de-duplicated, pure.
  List<String> get mutualInterests {
    if (viewerInterests.isEmpty || profile.interests.isEmpty) {
      return const [];
    }
    final viewerLower = <String>{
      for (final i in viewerInterests) i.trim().toLowerCase(),
    };
    final seen = <String>{};
    final result = <String>[];
    for (final interest in profile.interests) {
      final key = interest.trim().toLowerCase();
      if (viewerLower.contains(key) && seen.add(key)) {
        result.add(interest);
      }
    }
    return result;
  }

  /// Whether there is at least one mutual interest.
  bool get hasMutualInterests => mutualInterests.isNotEmpty;
}
