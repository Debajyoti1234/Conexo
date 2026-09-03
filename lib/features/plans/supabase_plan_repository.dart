import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../chat/chat_repository.dart';
import '../profile/discovery_helpers.dart';
import '../profile/profile_photo_resolver.dart';
import 'create_plan_data.dart';
import 'plan_details_data.dart';
import 'plan_repository.dart';
import 'plans_data.dart';

class SupabasePlanRepository implements PlanRepository {
  const SupabasePlanRepository({LocalPlanRepository? local})
      : _local = local ?? const LocalPlanRepository();

  final LocalPlanRepository _local;

  static const _bucket = 'plan-covers';
  static const _discoveryLimit = 50;

  @override
  Future<PlanDraft?> loadDraft() => _local.loadDraft();

  @override
  Future<void> saveDraft(PlanDraft draft) => _local.saveDraft(draft);

  @override
  Future<void> clearDraft() => _local.clearDraft();

  @override
  Future<List<PublishedPlan>> loadPublished() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select('''
            id,
            creator_id,
            title,
            description,
            category,
            mood,
            cover_url,
            visibility,
            latitude,
            longitude,
            location_name,
            location_address,
            is_featured,
            starts_at,
            capacity,
            status,
            created_at,
            updated_at
          ''')
          .eq('creator_id', user.id)
          .order('created_at', ascending: false);

      final plans = <PublishedPlan>[];
      for (final row in data) {
        try {
          plans.add(PublishedPlan.fromSupabase(row));
        } catch (_) {
          // Skip malformed rows rather than failing the whole list.
        }
      }
      return plans;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> removePublished(String id) async {}

  @override
  Future<void> archivePlan(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) throw const AuthFailure('Not authenticated');

    try {
      await Supabase.instance.client
          .from('plans')
          .update({'status': 'archived'})
          .eq('id', planId)
          .eq('creator_id', user.id);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> restorePlan(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) throw const AuthFailure('Not authenticated');

    try {
      await Supabase.instance.client
          .from('plans')
          .update({'status': 'active'})
          .eq('id', planId)
          .eq('creator_id', user.id);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> deletePlan(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) throw const AuthFailure('Not authenticated');

    String? coverPath;
    try {
      final plan = await Supabase.instance.client
          .from('plans')
          .select('cover_url')
          .eq('id', planId)
          .eq('creator_id', user.id)
          .maybeSingle();
      if (plan != null) {
        coverPath = plan['cover_url'] as String?;
      }
    } catch (_) {
      coverPath = null;
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'delete_plan',
        params: {'p_plan_id': planId},
      );
      if (result == null) {
        throw const AuthFailure('Failed to delete plan.');
      }
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }

    if (coverPath != null && coverPath.startsWith('plans/')) {
      try {
        await Supabase.instance.client.storage
            .from('plan-covers')
            .remove([coverPath]);
      } catch (_) {
        // Best-effort cleanup: do not fail the delete if storage removal fails.
      }
    }
  }

  @override
  Future<List<PublishedPlan>> getDiscoveryPlans() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      // Viewer-specific visibility: a plan the current viewer has already
      // requested (pending) or joined must NOT appear in THEIR discovery feed.
      // This filters ONLY on the current viewer's own memberships, so the plan
      // remains discoverable to every other user. A `declined` membership is
      // intentionally NOT excluded, so a declined plan becomes discoverable
      // again for that viewer. Creator exclusion is handled by the query below.
      final myMemberships = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, status')
          .eq('user_id', user.id)
          .inFilter('status', const ['pending', 'joined']);

      final hiddenPlanIds = <String>{
        for (final row in myMemberships)
          if (row['plan_id'] is String) row['plan_id'] as String,
      };

      // Canonical block exclusion: a plan created by someone the viewer has
      // blocked — or who has blocked the viewer — must NOT appear in the
      // viewer's Plan Discovery. Uses the same canonical `blocks` relationship
      // via the SECURITY DEFINER blocked_profile_ids() helper (bidirectional),
      // never a plan-specific block list.
      final blockedCreatorIds = await _loadBlockedProfileIds();

      final data = await Supabase.instance.client
          .from('plans')
          .select('''
            id,
            creator_id,
            title,
            description,
            category,
            mood,
            cover_url,
            visibility,
            latitude,
            longitude,
            location_name,
            location_address,
            is_featured,
            starts_at,
            capacity,
            status,
            created_at,
            updated_at
          ''')
          .eq('status', 'active')
          .neq('creator_id', user.id)
          .order('starts_at', ascending: true)
          .limit(_discoveryLimit);

      final plans = <PublishedPlan>[];
      for (final row in data) {
        try {
          final id = row['id'] as String?;
          // Hide plans the current viewer has already requested or joined.
          if (id != null && hiddenPlanIds.contains(id)) continue;
          // Hide plans created by a blocked (either direction) user.
          final creatorId = row['creator_id'] as String?;
          if (creatorId != null && blockedCreatorIds.contains(creatorId)) {
            continue;
          }
          plans.add(PublishedPlan.fromSupabase(row));
        } catch (_) {
          // Skip malformed rows rather than failing the whole feed.
        }
      }

      return plans;
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  /// Returns the set of user ids the current viewer is blocked-with in EITHER
  /// direction (viewer blocked them, or they blocked viewer), using the
  /// canonical SECURITY DEFINER `blocked_profile_ids()` helper over
  /// `public.blocks`. Falls back to the viewer-as-blocker direction that RLS
  /// exposes directly, and to an empty set on any failure so discovery never
  /// hard-fails.
  Future<Set<String>> _loadBlockedProfileIds() async {
    final user = AuthService.currentUser;
    if (user == null) return const <String>{};

    try {
      final rows = await Supabase.instance.client.rpc('blocked_profile_ids');
      if (rows is List) {
        final blocked = <String>{};
        for (final row in rows) {
          if (row is Map) {
            final id = row['user_id'] as String?;
            if (id != null) blocked.add(id);
          } else if (row is String) {
            blocked.add(row);
          }
        }
        return blocked;
      }
    } catch (_) {
      // Fall back to the direct one-direction query below.
    }

    try {
      final data = await Supabase.instance.client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', user.id);
      return <String>{
        for (final row in data)
          if (row['blocked_id'] is String) row['blocked_id'] as String,
      };
    } catch (_) {
      return const <String>{};
    }
  }

  @override
  Future<PlanMembership?> getMyMembership(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    try {
      final data = await Supabase.instance.client
          .from('plan_members')
          .select()
          .eq('plan_id', planId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return PlanMembership.fromSupabase(data);
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> requestToJoin(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to join');
    }

    try {
      await Supabase.instance.client.rpc(
        'request_to_join',
        params: {'p_plan_id': planId},
      );
    } on PostgrestException catch (error) {
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();

      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache')) {
        throw const AuthFailure(
          'Server action "request_to_join" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      if (message.contains('already a member') ||
          message.contains('already pending')) {
        return;
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<List<PlanMembership>> getPendingPlanMembers(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, user_id, role, status, joined_at, updated_at')
          .eq('plan_id', planId)
          .eq('status', 'pending');

      if (data.isEmpty) return const [];

      final userIds = data.map((row) => row['user_id'] as String).toSet().toList();
      final displayNames = await _fetchDisplayNames(userIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(userIds);

      return data.map((row) {
        final membership = PlanMembership.fromSupabase(row);
        return PlanMembership(
          planId: membership.planId,
          userId: membership.userId,
          role: membership.role,
          status: membership.status,
          joinedAt: membership.joinedAt,
          updatedAt: membership.updatedAt,
          displayName: displayNames[membership.userId],
          photoUrl: profilePhotoUrls[membership.userId],
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<List<PlanMembership>> getPlanMembers(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, user_id, role, status, joined_at, updated_at')
          .eq('plan_id', planId);

      if (data.isEmpty) return const [];

      final userIds = data.map((row) => row['user_id'] as String).toSet().toList();
      final displayNames = await _fetchDisplayNames(userIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(userIds);

      return data.map((row) {
        final membership = PlanMembership.fromSupabase(row);
        return PlanMembership(
          planId: membership.planId,
          userId: membership.userId,
          role: membership.role,
          status: membership.status,
          joinedAt: membership.joinedAt,
          updatedAt: membership.updatedAt,
          displayName: displayNames[membership.userId],
          photoUrl: profilePhotoUrls[membership.userId],
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<Map<String, String>> getProfilePhotoUrls(List<String> userIds) async {
    return _fetchProfilePhotoUrls(userIds);
  }

  @override
  Future<Map<String, List<PlanMembership>>> getPlanMembersBatch(List<String> planIds) async {
    if (planIds.isEmpty) return const {};
    final user = AuthService.currentUser;
    if (user == null) return const {};

    try {
      final data = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, user_id, role, status, joined_at, updated_at')
          .inFilter('plan_id', planIds);

      if (data.isEmpty) return const {};

      final allUserIds = data.map((row) => row['user_id'] as String).toSet().toList();
      final displayNames = await _fetchDisplayNames(allUserIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(allUserIds);

      final result = <String, List<PlanMembership>>{};
      for (final row in data) {
        final membership = PlanMembership.fromSupabase(row);
        final planId = membership.planId;
        result.putIfAbsent(planId, () => []);
        result[planId]!.add(PlanMembership(
          planId: membership.planId,
          userId: membership.userId,
          role: membership.role,
          status: membership.status,
          joinedAt: membership.joinedAt,
          updatedAt: membership.updatedAt,
          displayName: displayNames[membership.userId],
          photoUrl: profilePhotoUrls[membership.userId],
        ));
      }
      return result;
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<Map<String, List<PlanMembership>>> getPendingPlanMembersBatch(List<String> planIds) async {
    if (planIds.isEmpty) return const {};
    final user = AuthService.currentUser;
    if (user == null) return const {};

    try {
      final data = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, user_id, role, status, joined_at, updated_at')
          .inFilter('plan_id', planIds)
          .eq('status', 'pending');

      if (data.isEmpty) return const {};

      final allUserIds = data.map((row) => row['user_id'] as String).toSet().toList();
      final displayNames = await _fetchDisplayNames(allUserIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(allUserIds);

      final result = <String, List<PlanMembership>>{};
      for (final row in data) {
        final membership = PlanMembership.fromSupabase(row);
        final planId = membership.planId;
        result.putIfAbsent(planId, () => []);
        result[planId]!.add(PlanMembership(
          planId: membership.planId,
          userId: membership.userId,
          role: membership.role,
          status: membership.status,
          joinedAt: membership.joinedAt,
          updatedAt: membership.updatedAt,
          displayName: displayNames[membership.userId],
          photoUrl: profilePhotoUrls[membership.userId],
        ));
      }
      return result;
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> approvePlanMember(String planId, String memberId) async {
    try {
      await Supabase.instance.client.rpc(
        'approve_plan_member',
        params: {'p_plan_id': planId, 'p_user_id': memberId},
      );
    } on PostgrestException catch (error) {
      debugPrint(
        '[SupabasePlanRepository] approvePlanMember RPC error: '
        'code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );
      throw AuthFailure(_mapMembershipRpcError(error, 'approve'));
    } on AuthException catch (error) {
      debugPrint('[SupabasePlanRepository] approvePlanMember auth error: ${error.message}');
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      debugPrint('[SupabasePlanRepository] approvePlanMember unexpected error: $error');
      throw AuthFailure('Approve failed: $error');
    }
  }

  @override
  Future<void> declinePlanMember(String planId, String memberId) async {
    try {
      await Supabase.instance.client.rpc(
        'decline_plan_member',
        params: {'p_plan_id': planId, 'p_user_id': memberId},
      );
    } on PostgrestException catch (error) {
      debugPrint(
        '[SupabasePlanRepository] declinePlanMember RPC error: '
        'code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );
      throw AuthFailure(_mapMembershipRpcError(error, 'decline'));
    } on AuthException catch (error) {
      debugPrint('[SupabasePlanRepository] declinePlanMember auth error: ${error.message}');
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      debugPrint('[SupabasePlanRepository] declinePlanMember unexpected error: $error');
      throw AuthFailure('Decline failed: $error');
    }
  }

  /// Maps a membership-action RPC failure to a precise, non-masking message.
  ///
  /// Root causes are surfaced explicitly rather than collapsed into a generic
  /// "Something went wrong" so end-to-end validation reveals the real cause:
  ///   * PGRST202 / "could not find the function" → RPC not deployed
  ///   * capacity → plan full
  ///   * creator authorization → permission
  ///   * otherwise the raw database message is passed through.
  String _mapMembershipRpcError(PostgrestException error, String action) {
    final code = error.code?.toUpperCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('schema cache') ||
        (message.contains('function') && message.contains('does not exist'))) {
      return 'Server action "${action}_plan_member" is unavailable. '
          'Apply the latest database migrations, then retry.';
    }
    if (message.contains('plan is full') || message.contains('capacity')) {
      return 'This Plan is full';
    }
    if (message.contains('only the plan creator') ||
        code == '42501' ||
        message.contains('permission') ||
        message.contains('policy') ||
        message.contains('rls')) {
      return 'You don\'t have permission to manage this request.';
    }
    // Surface the real database message instead of masking it.
    return error.message;
  }

  @override
  Future<void> removePlanMember(String planId, String memberId) async {
    try {
      await Supabase.instance.client.rpc(
        'remove_plan_member',
        params: {'p_plan_id': planId, 'p_user_id': memberId},
      );
    } on PostgrestException catch (error) {
      debugPrint(
        '[SupabasePlanRepository] removePlanMember RPC error: '
        'code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache') ||
          (message.contains('function') && message.contains('does not exist'))) {
        throw const AuthFailure(
          'Server action "remove_plan_member" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      if (message.contains('only the plan creator') ||
          message.contains('cannot be removed') ||
          code == '42501' ||
          message.contains('permission')) {
        throw const AuthFailure('You don\'t have permission to remove this participant.');
      }
      throw AuthFailure(error.message);
    } on AuthException catch (error) {
      debugPrint('[SupabasePlanRepository] removePlanMember auth error: ${error.message}');
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      debugPrint('[SupabasePlanRepository] removePlanMember unexpected error: $error');
      throw AuthFailure('Remove failed: $error');
    }
  }

  @override
  Future<void> leavePlan(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to leave this plan');
    }

    try {
      await Supabase.instance.client
          .from('plan_members')
          .update({'status': 'left'})
          .eq('plan_id', planId)
          .eq('user_id', user.id)
          .eq('status', 'joined');
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('permission') || message.contains('policy') || message.contains('rls')) {
        throw const AuthFailure('You don\'t have permission to leave this plan.');
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Failed to leave plan. Please try again.');
    }
  }

  @override
  Future<void> cancelJoinRequest(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to manage this request');
    }

    try {
      await Supabase.instance.client.rpc(
        'cancel_plan_join_request',
        params: {'p_plan_id': planId},
      );
    } on PostgrestException catch (error) {
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();

      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache') ||
          (message.contains('function') && message.contains('does not exist'))) {
        throw const AuthFailure(
          'Server action "cancel_plan_join_request" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      if (message.contains('permission') || message.contains('policy') || message.contains('rls')) {
        throw const AuthFailure('You don\'t have permission to cancel this request.');
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Failed to cancel request. Please try again.');
    }
  }

  @override
  Future<Map<String, int>> getJoinedCounts(List<String> planIds) async {
    if (planIds.isEmpty) return const {};

    final result = <String, int>{};
    final futures = planIds.map((id) async {
      try {
        final data = await Supabase.instance.client.rpc(
          'get_plan_joined_count',
          params: {'p_plan_id': id},
        );
        final count = data is int ? data : int.tryParse(data.toString());
        if (count != null) result[id] = count;
      } catch (_) {
        // Ignore individual failures; fall back to 1.
        result[id] = 1;
      }
    }).toList();
    await Future.wait(futures);
    return result;
  }

  @override
  Future<List<Experience>> getPublishedExperiences() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final plans = await loadPublished();
    if (plans.isEmpty) return const [];

    final planIds = plans.map((p) => p.id).toList();
    final counts = await getJoinedCounts(planIds);
    final photoUrls = await _fetchProfilePhotoUrls([user.id]);
    final coverPaths = plans.map((p) => p.coverAsset).toList();
    final signedUrls = await getCoverSignedUrls(coverPaths);

    return List.generate(plans.length, (i) {
      final plan = plans[i];
      final joinedCount = counts[plan.id] ?? 1;
      return _planToExperience(plan, 'You', signedUrls[i], joinedCount,
          hostPhotoUrl: photoUrls[user.id]);
    });
  }

  @override
  Future<List<Experience>> getJoinedExperiences() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final memberships = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, role')
          .eq('user_id', user.id)
          .eq('status', 'joined')
          .eq('role', 'member');

      if (memberships.isEmpty) return const [];

      final planIds = memberships.map((m) => m['plan_id'] as String).toList();

      final plansData = await Supabase.instance.client
          .from('plans')
          .select('''
            id, creator_id, title, description, category, mood, cover_url,
            visibility, latitude, longitude, location_name, location_address, is_featured,
            starts_at, capacity, status,
            created_at, updated_at
          ''')
          .inFilter('id', planIds)
          .eq('status', 'active');

      final plans = <PublishedPlan>[];
      for (final row in plansData) {
        try {
          plans.add(PublishedPlan.fromSupabase(row));
        } catch (_) {
          // skip malformed
        }
      }

      final creatorIds = plans.map((p) => p.hostId).toSet().toList();
      final displayNames = await _fetchDisplayNames(creatorIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(creatorIds);
      final coverPaths = plans.map((p) => p.coverAsset).toList();
      final signedUrls = await getCoverSignedUrls(coverPaths);
      final counts = await getJoinedCounts(planIds);

      return List.generate(plans.length, (i) {
        final plan = plans[i];
        final joinedCount = counts[plan.id] ?? 1;
        return _planToExperience(plan, displayNames[plan.hostId], signedUrls[i], joinedCount,
            hostPhotoUrl: profilePhotoUrls[plan.hostId]);
      });
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<List<Experience>> getRequestedExperiences() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      // The viewer's own pending requests. RLS ("Users can read own
      // membership") authorizes reading these rows. Only `member` pending rows
      // are requests — a creator is never pending on their own plan.
      final memberships = await Supabase.instance.client
          .from('plan_members')
          .select('plan_id, role')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .eq('role', 'member');

      if (memberships.isEmpty) return const [];

      final planIds = memberships.map((m) => m['plan_id'] as String).toList();

      final plansData = await Supabase.instance.client
          .from('plans')
          .select('''
            id, creator_id, title, description, category, mood, cover_url,
            visibility, latitude, longitude, location_name, location_address, is_featured,
            starts_at, capacity, status,
            created_at, updated_at
          ''')
          .inFilter('id', planIds)
          .eq('status', 'active');

      final plans = <PublishedPlan>[];
      for (final row in plansData) {
        try {
          plans.add(PublishedPlan.fromSupabase(row));
        } catch (_) {
          // skip malformed
        }
      }

      if (plans.isEmpty) return const [];

      final creatorIds = plans.map((p) => p.hostId).toSet().toList();
      final displayNames = await _fetchDisplayNames(creatorIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(creatorIds);
      final coverPaths = plans.map((p) => p.coverAsset).toList();
      final signedUrls = await getCoverSignedUrls(coverPaths);
      final counts = await getJoinedCounts(planIds);

      return List.generate(plans.length, (i) {
        final plan = plans[i];
        final joinedCount = counts[plan.id] ?? 1;
        return _planToExperience(plan, displayNames[plan.hostId], signedUrls[i], joinedCount,
            hostPhotoUrl: profilePhotoUrls[plan.hostId]);
      });
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<List<Experience>> getDiscoveryExperiences() async {
    final plans = await getDiscoveryPlans();
    if (plans.isEmpty) return const [];

    final creatorIds = plans
        .map((p) => p.hostId)
        .where((id) => id.isNotEmpty)
        .toList();

    final displayNames = await _fetchDisplayNames(creatorIds);
    final profilePhotoUrls = await _fetchProfilePhotoUrls(creatorIds);
    final coverPaths = plans.map((p) => p.coverAsset).toList();
    final signedUrls = await getCoverSignedUrls(coverPaths);
    final planIds = plans.map((p) => p.id).toList();
    final counts = await getJoinedCounts(planIds);

    // Resolve the viewer's coordinates ONCE (not per plan) so Near You can be
    // ranked by real distance. Null when the viewer's location is unknown —
    // Discovery still loads and Near You simply has no distance-ranked plans.
    final user = AuthService.currentUser;
    final viewerCoords =
        user == null ? null : await _resolveViewerCoords(user.id);

    // Resolve Friends Joined ONCE for the whole authorized set (no per-plan
    // connection queries): which of these plans an accepted connection joined.
    final friendsJoined = await _fetchFriendsJoinedPlanIds(planIds);

    return List.generate(plans.length, (i) {
      final plan = plans[i];
      final signedUrl = signedUrls[i];
      final joinedCount = counts[plan.id] ?? 1;
      return _planToExperience(plan, displayNames[plan.hostId], signedUrl, joinedCount,
          hostPhotoUrl: profilePhotoUrls[plan.hostId],
          viewerLat: viewerCoords?.lat,
          viewerLng: viewerCoords?.lng,
          friendsJoinedPlanIds: friendsJoined);
    });
  }

  @override
  Future<int?> getDiscoveryDistanceKm() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('discovery_distance_km')
          .eq('id', user.id)
          .maybeSingle();
      return (row?['discovery_distance_km'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _fetchDisplayNames(List<String> userIds) async {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) return const {};

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', uniqueIds);

      final result = <String, String>{};
      for (final row in data) {
        final id = row['id'] as String?;
        final name = row['display_name'] as String?;
        if (id != null && name != null && name.trim().isNotEmpty) {
          result[id] = name.trim();
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Resolves the canonical primary profile photo for each user id to a
  /// displayable URL, mirroring the proven Profile/People pipeline:
  ///
  ///   profiles.photos[].remoteUrl (storage path 'profiles/...')
  ///     → SupabaseProfileRepository.getSignedPhotoUrl() on 'profile-photos'
  ///     → https signed URL
  ///
  /// A stored value that is already a full http(s) URL is passed through
  /// unchanged. Anything else (local asset / empty) is skipped so the UI shows
  /// its graceful fallback only when there is genuinely no usable photo.
  Future<Map<String, String>> _fetchProfilePhotoUrls(List<String> userIds) async {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) return const {};

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, photos')
          .inFilter('id', uniqueIds);

      // Collect each user's primary photo storage path (or pass-through URL).
      final rawByUser = <String, String>{};
      for (final row in data) {
        final id = row['id'] as String?;
        final photos = row['photos'] as List?;
        if (id == null || photos == null || photos.isEmpty) continue;
        final primary = photos.firstWhere(
          (p) => p is Map && p['isPrimary'] == true,
          orElse: () => photos.first,
        );
        if (primary is Map) {
          final remoteUrl = (primary['remoteUrl'] as String?)?.trim();
          if (remoteUrl != null && remoteUrl.isNotEmpty) {
            rawByUser[id] = remoteUrl;
          }
        }
      }

      if (rawByUser.isEmpty) return const {};

      final resolver = ProfilePhotoResolver.instance;
      final result = <String, String>{};
      final toSignUsers = <String>[];
      final toSignPaths = <String>[];

      rawByUser.forEach((userId, value) {
        if (value.startsWith('http://') || value.startsWith('https://')) {
          result[userId] = value;
        } else if (value.startsWith('profiles/')) {
          toSignUsers.add(userId);
          toSignPaths.add(value);
        }
        // else: local asset / unknown → skip (UI fallback).
      });

      if (toSignPaths.isNotEmpty) {
        final futures = toSignPaths.map((p) => resolver.resolvePhoto(p));
        final signedResults = await Future.wait(futures);
        for (var i = 0; i < toSignUsers.length; i++) {
          result[toSignUsers[i]] = signedResults[i].signedUrl;
        }
      }

      return result;
    } catch (_) {
      return const {};
    }
  }

  Experience _planToExperience(
      PublishedPlan plan, String? displayName, String? signedCoverUrl, int joinedCount,
      {String? hostPhotoUrl,
      double? viewerLat,
      double? viewerLng,
      Set<String> friendsJoinedPlanIds = const <String>{}}) {
    final now = DateTime.now();
    final mood = moodByLabel(plan.mood);
    final accent = mood?.accent ?? const Color(0xFF8B5CF6);
    final effectiveMood = plan.mood.isEmpty ? 'Plan' : plan.mood;
    final moodEmoji = mood?.emoji ?? '✨';

    String dateLabel = 'Date TBD';
    String timeLabel = 'TBD';
    if (plan.startsAt != null) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      dateLabel = '${months[plan.startsAt!.month - 1]} ${plan.startsAt!.day}';
      final hour = plan.startsAt!.hour % 12 == 0 ? 12 : plan.startsAt!.hour % 12;
      final minute = plan.startsAt!.minute.toString().padLeft(2, '0');
      final period = plan.startsAt!.hour < 12 ? 'AM' : 'PM';
      timeLabel = '$hour:$minute $period';
    }

    final currentUserId = AuthService.currentUser?.id;
    final host = plan.hostId == currentUserId
        ? 'You'
        : (displayName?.trim().isEmpty ?? true
            ? 'User ${plan.hostId.substring(0, 8)}'
            : displayName!.trim());

    final startsAt = plan.startsAt;
    final isToday = startsAt != null &&
        startsAt.year == now.year &&
        startsAt.month == now.month &&
        startsAt.day == now.day;

    final sections = <String>[];
    if (isToday) sections.add('today');
    if (now.difference(plan.createdAt).inDays <= 7) {
      sections.add('new');
    }

    final coverAsset = signedCoverUrl ?? plan.coverAsset;

    final capacity = plan.participants ?? 2;
    final safeCount = joinedCount.clamp(0, capacity);
    final spotsLeft = capacity - safeCount;

    // Featured: real curated flag only (never fabricated / randomised).
    if (plan.isFeatured) sections.add('featured');

    // Private: tag private plans so the Private section rail can slice them.
    if (plan.visibility == PlanVisibility.private) sections.add('private');

    // Friends Joined: at least one accepted connection is a joined member.
    // The set is computed once by the caller via a SECURITY DEFINER helper so
    // no per-plan connection query happens here.
    if (friendsJoinedPlanIds.contains(plan.id)) sections.add('friends');

    // Trending: real traction beyond the creator (>= 2 joined) blended with
    // recency. Deterministic + transparent: engagement dominates, newer plans
    // get a small recency bonus, older/inactive plans rank lower.
    final ageInDays = now.difference(plan.createdAt).inDays;
    final recencyBonus = (14 - ageInDays).clamp(0, 14);
    final trendingScore = (safeCount * 5 + recencyBonus).toDouble();
    if (safeCount >= 2) sections.add('trending');

    final resolvedHostPhoto = plan.hostId == currentUserId
        ? (hostPhotoUrl?.trim().isEmpty ?? true ? '' : hostPhotoUrl!.trim())
        : (hostPhotoUrl?.trim().isEmpty ?? true ? '' : hostPhotoUrl!.trim());

    // Real geographic distance from the viewer, when both the viewer's and the
    // plan's coordinates are known. Never fabricated: unknown → empty label +
    // null distanceKm (excluded from Near You, shown as unavailable).
    double? distanceKm;
    String distanceLabel = '';
    if (viewerLat != null &&
        viewerLng != null &&
        isValidCoordinate(plan.latitude, plan.longitude)) {
      final meters =
          haversine(viewerLat, viewerLng, plan.latitude!, plan.longitude!);
      distanceKm = meters / 1000;
      distanceLabel = _formatPlanDistance(meters);
    }

    return Experience(
      id: plan.id,
      title: plan.title,
      host: host,
      hostId: plan.hostId,
      hostPortrait: resolvedHostPhoto,
      coverAsset: coverAsset,
      category: plan.category ?? effectiveMood,
      mood: effectiveMood,
      moodEmoji: moodEmoji,
      city: plan.location.isNotEmpty ? plan.location : 'Nearby',
      date: dateLabel,
      time: timeLabel,
      distance: distanceLabel,
      goingCount: safeCount,
      spotsLeft: spotsLeft,
      accent: accent,
      highlight: plan.description.isNotEmpty
          ? plan.description
          : 'Just created — be the first to join',
      participants: const <String>[],
      visibility: plan.visibility,
      cardVariant: CardVariant.immersive,
      isEditorsPick: false,
      sections: sections,
      description: plan.description,
      capacity: plan.participants ?? 2,
      locationAddress: plan.locationAddress,
      distanceKm: distanceKm,
      trendingScore: trendingScore,
      status: plan.status,
    );
  }

  /// Formats a raw metre distance into a compact label ("850 m", "1.2 km",
  /// "12 km"). No decimals at or above 10 km. Never shows raw coordinates.
  String _formatPlanDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Resolves the viewer's coordinates ONCE for distance ranking, reusing the
  /// same source as People discovery: a fresh `live_locations` row if present,
  /// otherwise the persisted `profiles.latitude/longitude`. Returns null when
  /// no usable location exists (Near You then falls back safely). Never prompts
  /// for GPS here so discovery never blocks on a permission dialog.
  Future<({double lat, double lng})?> _resolveViewerCoords(String userId) async {
    try {
      final live = await Supabase.instance.client
          .from('live_locations')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (live != null) {
        final lat = (live['latitude'] as num?)?.toDouble();
        final lng = (live['longitude'] as num?)?.toDouble();
        final updatedAt = DateTime.tryParse(live['updated_at'] as String? ?? '');
        if (isValidCoordinate(lat, lng) && isLocationFresh(updatedAt)) {
          return (lat: lat!, lng: lng!);
        }
      }
    } catch (_) {
      // fall through to profile coordinates
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();
      final lat = (profile?['latitude'] as num?)?.toDouble();
      final lng = (profile?['longitude'] as num?)?.toDouble();
      if (isValidCoordinate(lat, lng)) {
        return (lat: lat!, lng: lng!);
      }
    } catch (_) {
      // no usable viewer location
    }
    return null;
  }

  /// Returns the subset of [planIds] where at least one of the viewer's
  /// ACCEPTED connections is a joined member. Uses a SECURITY DEFINER RPC
  /// because the viewer is not a member of discovery plans and cannot read
  /// their plan_members rows under RLS. Input is the already-authorized
  /// discovery plan ids, so no unauthorized plan is ever revealed. Returns an
  /// empty set on any failure (Friends Joined then shows its empty state).
  Future<Set<String>> _fetchFriendsJoinedPlanIds(List<String> planIds) async {
    if (planIds.isEmpty) return const <String>{};
    try {
      final data = await Supabase.instance.client.rpc(
        'get_friends_joined_plan_ids',
        params: {'p_plan_ids': planIds},
      );
      final result = <String>{};
      if (data is List) {
        for (final row in data) {
          final id = row is Map ? row['plan_id'] as String? : null;
          if (id != null) result.add(id);
        }
      }
      return result;
    } catch (_) {
      return const <String>{};
    }
  }

  @override
  Future<void> savePublished(PublishedPlan plan) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to publish your plan');
    }

    final client = Supabase.instance.client;

    final category = plan.mood.isEmpty
        ? (plan.title.trim().isEmpty ? 'Custom' : plan.title.trim())
        : plan.mood;

    final payload = <String, dynamic>{
      'creator_id': user.id,
      'title': plan.title.trim(),
      'description': plan.description.trim().isEmpty ? null : plan.description.trim(),
      'category': category,
      'mood': plan.mood.isEmpty ? null : plan.mood,
      'cover_url': _resolveCoverUrl(plan.coverAsset),
      'visibility': plan.visibility.name,
      'latitude': plan.latitude,
      'longitude': plan.longitude,
      'location_name': plan.location.trim().isEmpty ? null : plan.location.trim(),
      'location_address':
          plan.locationAddress.trim().isEmpty ? null : plan.locationAddress.trim(),
      'starts_at': plan.startsAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'capacity': plan.participants ?? 2,
      'status': plan.status,
    };

    String planId;
    try {
      final response = await client
          .from('plans')
          .insert(payload)
          .select('id')
          .single();

      planId = response['id'] as String;
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Failed to publish plan. Please try again.');
    }

    if (plan.coverAsset.isNotEmpty) {
      try {
        final uploaded = await _uploadCoverIfNeeded(user.id, planId, plan.coverAsset);
        if (uploaded != null && uploaded != _resolveCoverUrl(plan.coverAsset)) {
          await client
              .from('plans')
              .update({'cover_url': uploaded})
              .eq('id', planId);
        }
      } on AuthException catch (error) {
        throw AuthFailure(_mapAuthException(error.message));
      } catch (_) {
        throw const AuthFailure('Failed to upload cover. Please try again.');
      }
    }

    try {
      await const ChatRepository().getOrCreatePlanConversation(planId);
    } catch (_) {
      // Best-effort: do not fail the publish if chat creation transiently fails.
      debugPrint('[SupabasePlanRepository] plan chat creation failed for $planId');
    }
  }

  @override
  Future<void> updatePublished(PublishedPlan plan) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to update your plan');
    }

    if (plan.hostId != user.id) {
      throw const AuthFailure('You don\'t have permission to edit this plan');
    }

    String? uploadedCover;
    if (plan.coverAsset.isNotEmpty) {
      try {
        uploadedCover = await _uploadCoverIfNeeded(user.id, plan.id, plan.coverAsset);
      } on AuthException catch (error) {
        throw AuthFailure(_mapAuthException(error.message));
      } catch (_) {
        throw const AuthFailure('Failed to upload cover. Please try again.');
      }
    }

    final category = plan.mood.isEmpty
        ? (plan.title.trim().isEmpty ? 'Custom' : plan.title.trim())
        : plan.mood;

    final payload = <String, dynamic>{
      'title': plan.title.trim(),
      'description': plan.description.trim().isEmpty ? null : plan.description.trim(),
      'category': category,
      'mood': plan.mood.isEmpty ? null : plan.mood,
      'cover_url': uploadedCover ?? _resolveCoverUrl(plan.coverAsset),
      'visibility': plan.visibility.name,
      'latitude': plan.latitude,
      'longitude': plan.longitude,
      'location_name': plan.location.trim().isEmpty ? null : plan.location.trim(),
      'location_address':
          plan.locationAddress.trim().isEmpty ? null : plan.locationAddress.trim(),
      'starts_at': plan.startsAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'capacity': plan.participants ?? 2,
      'status': plan.status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await Supabase.instance.client
          .from('plans')
          .update(payload)
          .eq('id', plan.id)
          .eq('creator_id', user.id);
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Failed to update plan. Please try again.');
    }
  }

  @override
  Future<String?> getCoverSignedUrl(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return null;
    if (_isLocalAsset(coverPath)) return coverPath;
    if (!coverPath.startsWith('plans/')) return coverPath;

    try {
      return await Supabase.instance.client.storage
          .from(_bucket)
          .createSignedUrl(coverPath, 3600);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      return null;
    }
  }

  Future<List<String?>> getCoverSignedUrls(List<String?> coverPaths) async {
    final result = <String?>[];
    for (final path in coverPaths) {
      try {
        result.add(await getCoverSignedUrl(path));
      } catch (_) {
        result.add(null);
      }
    }
    return result;
  }

  bool _isLocalAsset(String asset) {
    return asset.startsWith('assets/');
  }

  String? _resolveCoverUrl(String? coverAsset) {
    if (coverAsset == null || coverAsset.isEmpty) return null;
    if (_isLocalAsset(coverAsset)) return coverAsset;
    if (coverAsset.startsWith('plans/')) return null;
    return null;
  }

  Future<String?> _uploadCoverIfNeeded(
      String userId, String planId, String? coverAsset) async {
    if (coverAsset == null || coverAsset.isEmpty) return null;
    if (_isLocalAsset(coverAsset)) return coverAsset;

    if (coverAsset.startsWith('plans/')) {
      final segments = coverAsset.split('/');
      if (segments.length >= 4 && segments[1] == userId) {
        final pathId = segments[2];
        if (pathId != planId) {
          final ext = _fileExtension(coverAsset);
          if (ext.isEmpty) return null;
          final finalPath = 'plans/$userId/$planId/cover.$ext';
          try {
            final bytes = await Supabase.instance.client.storage
                .from(_bucket)
                .download(coverAsset);
            await Supabase.instance.client.storage
                .from(_bucket)
                .uploadBinary(
                  finalPath,
                  bytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg'),
                );
          } on AuthException {
            rethrow;
          } catch (_) {
            return null;
          }
          return finalPath;
        }
      }
      return coverAsset;
    }

    final ext = _fileExtension(coverAsset);
    if (ext.isEmpty) return null;

    final storagePath = 'plans/$userId/$planId/cover.$ext';
    final bytes = await File(coverAsset).readAsBytes();

    await Supabase.instance.client.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );

    return storagePath;
  }

  @override
  Future<PublishedPlan?> getPublishedPlan(String id) async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select('''
            id, creator_id, title, description, category, mood, cover_url,
            visibility, latitude, longitude, location_name, location_address, is_featured,
            starts_at, capacity, status,
            created_at, updated_at
          ''')
          .eq('id', id)
          .eq('creator_id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return PublishedPlan.fromSupabase(data);
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<Experience?> getPlanExperience(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select('''
            id, creator_id, title, description, category, mood, cover_url,
            visibility, latitude, longitude, location_name, location_address, is_featured,
            starts_at, capacity, status,
            created_at, updated_at
          ''')
          .eq('id', planId)
          .maybeSingle();

      if (data == null) return null;

      final plan = PublishedPlan.fromSupabase(data);

      final counts = await getJoinedCounts([planId]);
      final displayNames = await _fetchDisplayNames([plan.hostId]);
      final profilePhotoUrls = await _fetchProfilePhotoUrls([plan.hostId]);
      final coverPaths = [plan.coverAsset];
      final signedUrls = await getCoverSignedUrls(coverPaths);

      final joinedCount = counts[plan.id] ?? 1;
      final viewerCoords = await _resolveViewerCoords(user.id);
      return _planToExperience(
        plan,
        displayNames[plan.hostId],
        signedUrls[0],
        joinedCount,
        hostPhotoUrl: profilePhotoUrls[plan.hostId],
        viewerLat: viewerCoords?.lat,
        viewerLng: viewerCoords?.lng,
      );
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> inviteToPlan(String planId, String inviteeId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to send invitations');
    }

    try {
      await Supabase.instance.client.rpc(
        'invite_to_plan',
        params: {'p_plan_id': planId, 'p_invitee_id': inviteeId},
      );
    } on PostgrestException catch (error) {
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache')) {
        throw const AuthFailure(
          'Server action "invite_to_plan" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      if (message.contains('only the plan creator') ||
          message.contains('not authorized') ||
          code == '42501') {
        throw const AuthFailure('Only the plan creator can send invitations.');
      }
      if (message.contains('already a member')) {
        throw const AuthFailure('This user is already a member of the plan.');
      }
      if (message.contains('only invite accepted connections')) {
        throw const AuthFailure('You can only invite accepted connections.');
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      throw AuthFailure('Invite failed: $error');
    }
  }

  @override
  Future<void> acceptInvitation(String inviteId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to accept invitations');
    }

    try {
      await Supabase.instance.client.rpc(
        'accept_plan_invitation',
        params: {'p_invite_id': inviteId},
      );
    } on PostgrestException catch (error) {
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache')) {
        throw const AuthFailure(
          'Server action "accept_plan_invitation" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      throw AuthFailure('Accept failed: $error');
    }
  }

  @override
  Future<void> declineInvitation(String inviteId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in to decline invitations');
    }

    try {
      await Supabase.instance.client.rpc(
        'decline_plan_invitation',
        params: {'p_invite_id': inviteId},
      );
    } on PostgrestException catch (error) {
      final code = error.code?.toUpperCase() ?? '';
      final message = error.message.toLowerCase();
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache')) {
        throw const AuthFailure(
          'Server action "decline_plan_invitation" is unavailable. '
          'Apply the latest database migrations, then retry.',
        );
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (error) {
      throw AuthFailure('Decline failed: $error');
    }
  }

  @override
  Future<List<PlanInvitation>> getPendingInvitations() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from('plan_invites')
          .select('''
            id, plan_id, inviter_id, invitee_id, status, created_at, updated_at
          ''')
          .eq('invitee_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (data.isEmpty) return const [];

      final planIds = data
          .map((row) => row['plan_id'] as String)
          .toSet()
          .toList();

      final inviterIds = data
          .map((row) => row['inviter_id'] as String)
          .toSet()
          .toList();

      final plans = await Supabase.instance.client
          .from('plans')
          .select('id, title')
          .inFilter('id', planIds);

      final displayNames = await _fetchDisplayNames(inviterIds);

      final planTitles = <String, String>{};
      for (final row in plans) {
        final id = row['id'] as String?;
        final title = row['title'] as String?;
        if (id != null && title != null) {
          planTitles[id] = title;
        }
      }

      return data.map((row) {
        final planId = row['plan_id'] as String;
        final inviterId = row['inviter_id'] as String;
        return PlanInvitation(
          id: row['id'] as String,
          planId: planId,
          inviterId: inviterId,
          inviteeId: row['invitee_id'] as String,
          status: row['status'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String),
          planTitle: planTitles[planId],
          inviterName: displayNames[inviterId],
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<List<PlanInvitation>> getSentInvitations(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from('plan_invites')
          .select('''
            id, plan_id, inviter_id, invitee_id, status, created_at, updated_at
          ''')
          .eq('plan_id', planId)
          .eq('inviter_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (data.isEmpty) return const [];

      final inviteeIds = data
          .map((row) => row['invitee_id'] as String)
          .toSet()
          .toList();

      final displayNames = await _fetchDisplayNames(inviteeIds);

      return data.map((row) {
        final inviteeId = row['invitee_id'] as String;
        return PlanInvitation(
          id: row['id'] as String,
          planId: row['plan_id'] as String,
          inviterId: row['inviter_id'] as String,
          inviteeId: inviteeId,
          status: row['status'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String),
          inviteeName: displayNames[inviteeId],
        );
      }).toList();
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  @override
  Future<void> recordPlanVisit(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.rpc(
        'record_plan_visit',
        params: {'p_plan_id': planId},
      );
    } on PostgrestException catch (error) {
      debugPrint(
        '[SupabasePlanRepository] recordPlanVisit RPC error: '
        'code=${error.code} message=${error.message}',
      );
    } on AuthException catch (_) {
      // Silently ignore auth failures for visit recording.
    } catch (_) {
      // Silently ignore all other failures for visit recording.
    }
  }

  @override
  Future<List<Experience>> getRecentlyVisitedExperiences() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final rows = await Supabase.instance.client.rpc(
        'get_recently_visited_plan_ids',
        params: {'p_limit': 20},
      );

      final planIds = <String>[];
      final visitedAts = <String>[];
      if (rows is List) {
        for (final row in rows) {
          if (row is Map) {
            final id = row['plan_id'] as String?;
            final visitedAt = row['visited_at'] as String?;
            if (id != null) {
              planIds.add(id);
              if (visitedAt != null) visitedAts.add(visitedAt);
            }
          }
        }
      }

      if (planIds.isEmpty) return const [];

      final plansData = await Supabase.instance.client
          .from('plans')
          .select('''
            id, creator_id, title, description, category, mood, cover_url,
            visibility, latitude, longitude, location_name, location_address, is_featured,
            starts_at, capacity, status,
            created_at, updated_at
          ''')
          .inFilter('id', planIds)
          .eq('status', 'active');

      final plans = <PublishedPlan>[];
      for (final row in plansData) {
        try {
          plans.add(PublishedPlan.fromSupabase(row));
        } catch (_) {
          // skip malformed
        }
      }

      final planMap = <String, PublishedPlan>{};
      for (final p in plans) {
        planMap[p.id] = p;
      }

      final creatorIds = plans.map((p) => p.hostId).toSet().toList();
      final displayNames = await _fetchDisplayNames(creatorIds);
      final profilePhotoUrls = await _fetchProfilePhotoUrls(creatorIds);
      final coverPaths = plans.map((p) => p.coverAsset).toList();
      final signedUrls = await getCoverSignedUrls(coverPaths);
      final planIdsForCounts = plans.map((p) => p.id).toList();
      final counts = await getJoinedCounts(planIdsForCounts);

      // Preserve visit order (most recent first), skip plans removed from
      // the authorized set by RLS.
      final result = <Experience>[];
      for (var i = 0; i < planIds.length; i++) {
        final plan = planMap[planIds[i]];
        if (plan == null) continue;
        final idx = plans.indexOf(plan);
        final signedUrl = signedUrls[idx];
        final joinedCount = counts[plan.id] ?? 1;
        result.add(
          _planToExperience(
            plan,
            displayNames[plan.hostId],
            signedUrl,
            joinedCount,
            hostPhotoUrl: profilePhotoUrls[plan.hostId],
          ),
        );
      }
      return result;
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      return const [];
    }
  }

  String _fileExtension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx == -1 || idx == path.length - 1) return '';
    return path.substring(idx + 1);
  }

  String _mapAuthException(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Network error. Please try again.';
    }
    if (lower.contains('storage') || lower.contains('bucket')) {
      return 'Failed to upload cover. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _mapPostgrestException(PostgrestException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == '42501' || message.contains('permission') || message.contains('policy') || message.contains('rls')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (message.contains('not found') || message.contains('does not exist')) {
      return 'The requested resource was not found.';
    }
    if (message.contains('network') || message.contains('connection') || message.contains('timeout')) {
      return 'Network error. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
