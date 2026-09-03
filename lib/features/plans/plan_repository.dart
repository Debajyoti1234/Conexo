import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'create_plan_data.dart';
import 'plan_details_data.dart';
import 'plans_data.dart';

/// The single data-access layer for the entire Plans module.
///
/// Every Plans screen (Create Plan, My Plans, Plan Details, and any future
/// Plans feature) must communicate ONLY through a [PlanRepository]. This keeps
/// a single source of truth for local persistence today and a single swap
/// point for a future backend.
///
/// The repository is *injected* through constructors (no global singleton, no
/// service locator) so a future `FirestorePlanRepository` / `ApiPlanRepository`
/// can replace [LocalPlanRepository] WITHOUT touching any UI or business logic.
abstract class PlanRepository {
  /// Loads the in-progress editable draft (or `null` if none).
  Future<PlanDraft?> loadDraft();

  /// Persists the in-progress editable draft.
  Future<void> saveDraft(PlanDraft draft);

  /// Clears the in-progress editable draft.
  Future<void> clearDraft();

  /// Loads every locally published plan (newest last — insertion order).
  Future<List<PublishedPlan>> loadPublished();

  /// Appends a newly published plan.
  Future<void> savePublished(PublishedPlan plan);

  /// Removes a published plan by its stable [PublishedPlan.id].
  Future<void> removePublished(String id);

  /// Returns the current authenticated viewer's eligible discovery plans:
  ///   • active public plans
  ///   • private plans the viewer is allowed to see (creator, accepted
  ///     connection, joined member, or pending invitee)
  ///
  /// Eligibility is enforced server-side by Supabase RLS; this method simply
  /// queries the allowed rows.
  Future<List<PublishedPlan>> getDiscoveryPlans();

  /// Returns the current authenticated viewer's eligible discovery plans as
  /// [Experience] objects ready for the existing Plan UI.
  Future<List<Experience>> getDiscoveryExperiences();

  /// Returns the viewer's saved discovery distance preference in kilometres
  /// (`profiles.discovery_distance_km`), or null for "Any". Reused to bound
  /// the geographic "Near You" rail; never creates a second preference.
  Future<int?> getDiscoveryDistanceKm();

  /// Returns the current viewer's membership for the given plan, or `null` if
  /// none exists.
  Future<PlanMembership?> getMyMembership(String planId);

  /// Requests to join the given plan. For public plans this may immediately
  /// transition to `joined` depending on database policy; for private plans it
  /// creates a `pending` membership.
  Future<void> requestToJoin(String planId);

  /// Returns pending membership requests for a plan. Only the plan creator
  /// should be able to read these; RLS remains authoritative.
  Future<List<PlanMembership>> getPendingPlanMembers(String planId);

  /// Returns pending membership requests for multiple plans, grouped by plan id.
  /// Allows a single batched query instead of one query per plan.
  Future<Map<String, List<PlanMembership>>> getPendingPlanMembersBatch(List<String> planIds);

  /// Approves a pending membership. Only the plan creator may perform this
  /// action; authorization is enforced server-side.
  Future<void> approvePlanMember(String planId, String memberId);

  /// Declines a pending membership. Only the plan creator may perform this
  /// action; authorization is enforced server-side.
  Future<void> declinePlanMember(String planId, String memberId);

  /// Removes an already-joined participant from a plan (joined -> removed).
  /// Only the plan creator may perform this action; authorization is enforced
  /// server-side. Frees a capacity spot under the database-authoritative model.
  Future<void> removePlanMember(String planId, String memberId);

  /// Returns the joined member count for each plan id. Used to compute real
  /// goingCount and spotsLeft without exposing raw plan_members rows.
  Future<Map<String, int>> getJoinedCounts(List<String> planIds);

  /// Returns all membership records for a plan, including pending, joined,
  /// and declined. Used by hosts to manage their plan participants.
  Future<List<PlanMembership>> getPlanMembers(String planId);

  /// Returns all membership records for multiple plans, grouped by plan id.
  /// Allows a single batched query instead of one query per plan.
  Future<Map<String, List<PlanMembership>>> getPlanMembersBatch(List<String> planIds);

  /// Resolves each user's canonical primary profile photo to a displayable
  /// signed URL, using the existing private profile-photos + signed-URL
  /// pipeline. Users without a usable photo are omitted so the UI shows its
  /// graceful fallback. Reused by any screen that needs real profile photos
  /// for a set of user ids (e.g. Invite People).
  Future<Map<String, String>> getProfilePhotoUrls(List<String> userIds);

  /// Returns the current user's published plans as [Experience] objects with
  /// real participant counts.
  Future<List<Experience>> getPublishedExperiences();

  /// Returns the current user's joined plans (excluding hosted plans) as
  /// [Experience] objects with real participant counts.
  Future<List<Experience>> getJoinedExperiences();

  /// Returns the current user's pending join requests (membership status =
  /// `pending`, role = `member`) as [Experience] objects. These are the plans
  /// the viewer has requested but not yet been approved for — surfaced in
  /// My Plans → Requested. While pending, the same plans are hidden from the
  /// viewer's discovery feed but remain discoverable to everyone else.
  Future<List<Experience>> getRequestedExperiences();

  /// Updates an existing published plan. Only the creator may perform this
  /// action; authorization is enforced server-side. Preserves the original
  /// [PublishedPlan.id] and [PublishedPlan.createdAt].
  Future<void> updatePublished(PublishedPlan plan);

  /// Returns a single published plan by id, or null if not found.
  Future<PublishedPlan?> getPublishedPlan(String id);

  /// Returns a single plan as an [Experience] for any authorized viewer
  /// (creator or joined member). RLS remains authoritative; returns null
  /// when the plan cannot be found or the viewer lacks access.
  Future<Experience?> getPlanExperience(String planId);

  /// Removes the current user's membership from the given plan (joined -> left).
  /// Only the member themselves may perform this action; authorization is
  /// enforced server-side.
  Future<void> leavePlan(String planId);

  /// Cancels the current user's pending join request for the given plan
  /// (pending -> cancelled). Only the member themselves may perform this
  /// action; authorization is enforced server-side. Idempotent: if the request
  /// is no longer pending, it is a no-op.
  Future<void> cancelJoinRequest(String planId);

  /// Archives a plan for the current creator. Only the creator may perform
  /// this action; authorization is enforced server-side. The plan remains in
  /// the database with status = 'archived' and can be restored later.
  Future<void> archivePlan(String planId);

  /// Restores an archived plan to active status. Only the creator may perform
  /// this action; authorization is enforced server-side.
  Future<void> restorePlan(String planId);

  /// Permanently deletes an archived plan and all associated data. Only the
  /// creator may perform this action; authorization is enforced server-side.
  /// This operation is irreversible.
  Future<void> deletePlan(String planId);

  /// Sends a plan invitation to an accepted connection. Only the plan creator
  /// may perform this action; authorization is enforced server-side.
  Future<void> inviteToPlan(String planId, String inviteeId);

  /// Accepts a pending plan invitation. Only the invitee may perform this
  /// action; authorization is enforced server-side.
  Future<void> acceptInvitation(String inviteId);

  /// Declines a pending plan invitation. Only the invitee may perform this
  /// action; authorization is enforced server-side.
  Future<void> declineInvitation(String inviteId);

  /// Returns pending invitations received by the current user.
  Future<List<PlanInvitation>> getPendingInvitations();

  /// Returns invitations sent by the current user for a plan.
  Future<List<PlanInvitation>> getSentInvitations(String planId);

  /// Records a plan visit for the current user. Used by the Recently Visited
  /// Discovery section. Persists across app restarts.
  Future<void> recordPlanVisit(String planId);

  /// Returns the current user's recently visited plans as [Experience] objects,
  /// most recently visited first. Only returns plans the user is still
  /// authorized to see (RLS remains authoritative).
  Future<List<Experience>> getRecentlyVisitedExperiences();

  /// Resolves a single cover storage path or local asset to a displayable URL.
  /// For `plans/` storage paths this returns a signed URL; for local assets
  /// it returns the asset path unchanged; for unknown paths it returns null.
  Future<String?> getCoverSignedUrl(String? coverPath);
}

/// The local, on-device implementation backed by [SharedPreferences].
///
/// This is the ONLY class in the project that touches [SharedPreferences].
/// When a backend arrives, implement [PlanRepository] elsewhere and inject it;
/// nothing else needs to change.
class LocalPlanRepository implements PlanRepository {
  const LocalPlanRepository();

  static const _draftKey = 'conexo_plan_draft_v1';
  static const _publishedKey = 'conexo_published_plans_v1';

  @override
  Future<PlanDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PlanDraft.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(PlanDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  @override
  Future<List<PublishedPlan>> loadPublished() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? const <String>[];
    final result = <PublishedPlan>[];
    for (final raw in list) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result.add(PublishedPlan.fromJson(map));
      } catch (_) {
        // Skip any corrupt entry rather than failing the whole load.
      }
    }
    return result;
  }

  @override
  Future<void> savePublished(PublishedPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? <String>[];
    list.add(jsonEncode(plan.toJson()));
    await prefs.setStringList(_publishedKey, list);
  }

  @override
  Future<void> removePublished(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_publishedKey) ?? <String>[];
    list.removeWhere((raw) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_publishedKey, list);
  }

  @override
  Future<void> leavePlan(String planId) async {}

  @override
  Future<void> cancelJoinRequest(String planId) async {}

  @override
  Future<void> archivePlan(String planId) async {}

  @override
  Future<void> restorePlan(String planId) async {}

  @override
  Future<void> deletePlan(String planId) async {}

  @override
  Future<void> inviteToPlan(String planId, String inviteeId) async {}

  @override
  Future<void> acceptInvitation(String inviteId) async {}

  @override
  Future<void> declineInvitation(String inviteId) async {}

  @override
  Future<List<PlanInvitation>> getPendingInvitations() async => const [];

  @override
  Future<List<PlanInvitation>> getSentInvitations(String planId) async => const [];

  @override
  Future<void> recordPlanVisit(String planId) async {}

  @override
  Future<List<Experience>> getRecentlyVisitedExperiences() async => const [];

  @override
  Future<List<PublishedPlan>> getDiscoveryPlans() async => [];

  @override
  Future<List<Experience>> getDiscoveryExperiences() async => const [];

  @override
  Future<int?> getDiscoveryDistanceKm() async => null;

  @override
  Future<PlanMembership?> getMyMembership(String planId) async => null;

  @override
  Future<void> requestToJoin(String planId) async {}

  @override
  Future<List<PlanMembership>> getPendingPlanMembers(String planId) async => const [];

  @override
  Future<Map<String, List<PlanMembership>>> getPendingPlanMembersBatch(List<String> planIds) async => const {};

  @override
  Future<List<PlanMembership>> getPlanMembers(String planId) async => const [];

  @override
  Future<Map<String, List<PlanMembership>>> getPlanMembersBatch(List<String> planIds) async => const {};

  @override
  Future<Map<String, String>> getProfilePhotoUrls(List<String> userIds) async =>
      const {};

  @override
  Future<void> approvePlanMember(String planId, String memberId) async {}

  @override
  Future<void> declinePlanMember(String planId, String memberId) async {}

  @override
  Future<void> removePlanMember(String planId, String memberId) async {}

  @override
  Future<Map<String, int>> getJoinedCounts(List<String> planIds) async => const {};

  @override
  Future<List<Experience>> getPublishedExperiences() async => const [];

  @override
  Future<List<Experience>> getJoinedExperiences() async => const [];

  @override
  Future<List<Experience>> getRequestedExperiences() async => const [];

  @override
  Future<void> updatePublished(PublishedPlan plan) async {}

  @override
  Future<PublishedPlan?> getPublishedPlan(String id) async => null;

  @override
  Future<Experience?> getPlanExperience(String planId) async => null;

  @override
  Future<String?> getCoverSignedUrl(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return null;
    if (coverPath.startsWith('assets/')) return coverPath;
    if (coverPath.startsWith('http://') || coverPath.startsWith('https://')) {
      return coverPath;
    }
    return null;
  }
}
