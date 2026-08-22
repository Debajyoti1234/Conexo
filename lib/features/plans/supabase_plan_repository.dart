import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../chat/chat_repository.dart';
import '../profile/supabase_profile_repository.dart';
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
      await Supabase.instance.client
          .from('plan_members')
          .insert({
            'plan_id': planId,
            'user_id': user.id,
            'role': 'member',
            'status': 'pending',
          });
    } on PostgrestException catch (error) {
      final code = error.code?.toLowerCase() ?? '';
      final message = error.message.toLowerCase();

      if (code == '23505' ||
          message.contains('unique') ||
          message.contains('duplicate') ||
          message.contains('plan_members_plan_id_user_id_key')) {
        return;
      }
      if (code == '23456' ||
          message.contains('check violation') ||
          message.contains('capacity') ||
          message.contains('full')) {
        throw const AuthFailure('This Plan is full');
      }
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
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
            visibility, latitude, longitude, starts_at, capacity, status,
            created_at, updated_at
          ''')
          .inFilter('id', planIds);

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
            visibility, latitude, longitude, starts_at, capacity, status,
            created_at, updated_at
          ''')
          .inFilter('id', planIds);

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

    return List.generate(plans.length, (i) {
      final plan = plans[i];
      final signedUrl = signedUrls[i];
      final joinedCount = counts[plan.id] ?? 1;
      return _planToExperience(plan, displayNames[plan.hostId], signedUrl, joinedCount,
          hostPhotoUrl: profilePhotoUrls[plan.hostId]);
    });
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

      // Sign the storage paths in one batch using the canonical profile-photos
      // signer. Already-signed http(s) values are kept as-is.
      const profileRepo = SupabaseProfileRepository();
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
        final signed = await profileRepo.getSignedPhotoUrls(toSignPaths);
        for (var i = 0; i < toSignUsers.length; i++) {
          final url = signed[i];
          if (url != null && url.isNotEmpty) {
            result[toSignUsers[i]] = url;
          }
        }
      }

      return result;
    } catch (_) {
      return const {};
    }
  }

  Experience _planToExperience(
      PublishedPlan plan, String? displayName, String? signedCoverUrl, int joinedCount,
      {String? hostPhotoUrl}) {
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

    final coverAsset = signedCoverUrl ??
        (_isLocalAsset(plan.coverAsset) ? plan.coverAsset : '');

    final capacity = plan.participants ?? 2;
    final safeCount = joinedCount.clamp(0, capacity);
    final spotsLeft = capacity - safeCount;

    final resolvedHostPhoto = plan.hostId == currentUserId
        ? (hostPhotoUrl?.trim().isEmpty ?? true ? '' : hostPhotoUrl!.trim())
        : (hostPhotoUrl?.trim().isEmpty ?? true ? '' : hostPhotoUrl!.trim());

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
      city: plan.location,
      date: dateLabel,
      time: timeLabel,
      distance: plan.location,
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
    );
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
      'cover_url': _isLocalAsset(plan.coverAsset) ? plan.coverAsset : null,
      'visibility': plan.visibility.name,
      'latitude': plan.latitude,
      'longitude': plan.longitude,
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

    if (plan.coverAsset.isNotEmpty && !_isLocalAsset(plan.coverAsset)) {
      try {
        final ext = _fileExtension(plan.coverAsset);
        if (ext.isEmpty) return;

        final storagePath = 'plans/${user.id}/$planId/cover.$ext';
        final bytes = await File(plan.coverAsset).readAsBytes();

        await client.storage
            .from(_bucket)
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
              ),
            );

        await client
            .from('plans')
            .update({'cover_url': storagePath})
            .eq('id', planId);
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

    final client = Supabase.instance.client;

    final category = plan.mood.isEmpty
        ? (plan.title.trim().isEmpty ? 'Custom' : plan.title.trim())
        : plan.mood;

    final payload = <String, dynamic>{
      'title': plan.title.trim(),
      'description': plan.description.trim().isEmpty ? null : plan.description.trim(),
      'category': category,
      'mood': plan.mood.isEmpty ? null : plan.mood,
      'cover_url': _isLocalAsset(plan.coverAsset) ? plan.coverAsset : null,
      'visibility': plan.visibility.name,
      'latitude': plan.latitude,
      'longitude': plan.longitude,
      'starts_at': plan.startsAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'capacity': plan.participants ?? 2,
      'status': plan.status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await client
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

  Future<String?> getCoverSignedUrl(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return null;
    if (_isLocalAsset(coverPath)) return coverPath;

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
    final futures = coverPaths.map(getCoverSignedUrl).toList();
    return Future.wait(futures);
  }

  bool _isLocalAsset(String asset) {
    return asset.startsWith('assets/');
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
            visibility, latitude, longitude, starts_at, capacity, status,
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
            visibility, latitude, longitude, starts_at, capacity, status,
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
      return _planToExperience(
        plan,
        displayNames[plan.hostId],
        signedUrls[0],
        joinedCount,
        hostPhotoUrl: profilePhotoUrls[plan.hostId],
      );
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
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
