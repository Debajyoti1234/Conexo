import 'plans_data.dart';
import 'plans_filter.dart';

/// Data helpers for the premium Plan Details experience.
///
/// Everything here is local + demo only and *pure*: values are derived
/// deterministically from an immutable [Experience] (usually keyed off its
/// [Experience.id]) so the same plan always renders the same authentic-looking
/// details. Nothing mutates an [Experience]; it remains the single source of
/// truth for plan data. A future backend can replace these helpers without any
/// UI refactoring.

/// The local join lifecycle for a plan.
///
/// The UI surfaces `notJoined → requested → joined` for discovery, plus
/// [invited] for users with a pending Plan Invitation (accept = direct join).
/// [cancelled] exists now so adding leave/cancel later needs no model change.
enum JoinStatus { notJoined, requested, joined, cancelled, hosting, invited }

class PlanMembership {
  const PlanMembership({
    required this.planId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
    this.displayName,
    this.photoUrl,
  });

  final String planId;
  final String userId;
  final String role;
  final String status;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final String? displayName;
  final String? photoUrl;

  factory PlanMembership.fromSupabase(Map<String, dynamic> row) {
    DateTime? parseNullable(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    return PlanMembership(
      planId: (row['plan_id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      role: (row['role'] as String?) ?? 'member',
      status: (row['status'] as String?) ?? 'pending',
      joinedAt: parseNullable(row['joined_at']) ?? DateTime.now(),
      updatedAt: parseNullable(row['updated_at']) ?? DateTime.now(),
      displayName: row['display_name'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }
}

class PlanInvitation {
  const PlanInvitation({
    required this.id,
    required this.planId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.planTitle,
    this.inviterName,
    this.inviteeName,
  });

  final String id;
  final String planId;
  final String inviterId;
  final String inviteeId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? planTitle;
  final String? inviterName;
  final String? inviteeName;

  factory PlanInvitation.fromSupabase(Map<String, dynamic> row) {
    DateTime? parseNullable(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    return PlanInvitation(
      id: (row['id'] as String?) ?? '',
      planId: (row['plan_id'] as String?) ?? '',
      inviterId: (row['inviter_id'] as String?) ?? '',
      inviteeId: (row['invitee_id'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'pending',
      createdAt: parseNullable(row['created_at']) ?? DateTime.now(),
      updatedAt: parseNullable(row['updated_at']) ?? DateTime.now(),
      planTitle: row['plan_title'] as String?,
      inviterName: row['inviter_name'] as String?,
      inviteeName: row['invitee_name'] as String?,
    );
  }
}

/// A stable pseudo-random 0..(mod-1) value derived from a plan id + salt.
/// Deterministic so demo stats never flicker between rebuilds.
int _seed(String id, int salt, int mod) {
  var hash = salt & 0x7fffffff;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % mod;
}

/// Demo-only host + plan metadata derived from an immutable [Experience].
///
/// No new plan model — this simply projects extra, believable presentation
/// values from data the [Experience] already carries.
class PlanHostDetails {
  const PlanHostDetails({
    required this.rating,
    required this.isVerified,
    required this.plansHosted,
    required this.friendsJoined,
    required this.mutualInterests,
    required this.createdLabel,
  });

  final double rating; // e.g. 4.7
  final bool isVerified;
  final int plansHosted;
  final int friendsJoined;
  final int mutualInterests;
  final String createdLabel; // e.g. "2 days ago"

  factory PlanHostDetails.of(Experience e) {
    final created = _seed(e.id, 13, 6); // 0..5 → label below
    const createdLabels = [
      'just now',
      'today',
      'yesterday',
      '2 days ago',
      '3 days ago',
      'last week',
    ];
    return PlanHostDetails(
      rating: 0.0,
      isVerified: false,
      plansHosted: 0,
      friendsJoined: 0,
      mutualInterests: 0,
      createdLabel: createdLabels[created],
    );
  }
}

/// Generates 3–4 local "why join" reasons from the plan's own data. Ordering
/// is stable and purely derived — no backend, no randomness at build time.
List<String> whyJoinReasons(Experience e) {
  final reasons = <String>[];

  if (parseDistanceKm(e.distance) <= 2.0) {
    reasons.add('Perfect for meeting nearby people');
  }
  if (e.goingCount >= 15) {
    reasons.add('Trending this weekend');
  }
  if (e.spotsLeft <= 3) {
    reasons.add('Only a few spots left');
  }

  return reasons.take(4).toList();
}

/// Similar nearby plans for the details page.
///
/// Consumes the SAME distance-first [applyPipeline] as discovery (category
/// scoped, then a broad fallback), excludes the current plan by id, and caps
/// the result at [limit] (6–8) so the rail stays light + curated. The Details
/// page never sorts or filters independently.
List<Experience> similarNearby(Experience current, {int limit = 8}) {
  return const <Experience>[];
}
