import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/services/image_normalizer.dart';

class SafetyResult<T> {
  const SafetyResult._(this._value, this._error);

  const SafetyResult.success(T value) : this._(value, null);
  const SafetyResult.failure(String error) : this._(null, error);

  final T? _value;
  final String? _error;

  T? get value => _value;
  String? get error => _error;
  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

/// Directional block relationship between the current user and one other user.
///
/// Resolved through the canonical `block_state` SECURITY DEFINER RPC over
/// `public.blocks`, so it can report [theyBlocked] even though RLS hides that
/// row from a direct client query.
class BlockState {
  const BlockState({required this.iBlocked, required this.theyBlocked});

  /// The current user has blocked the other user.
  final bool iBlocked;

  /// The other user has blocked the current user.
  final bool theyBlocked;

  /// A block exists in either direction.
  bool get isBlocked => iBlocked || theyBlocked;

  static const none = BlockState(iBlocked: false, theyBlocked: false);
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.blockedUserId,
    required this.blockedUserName,
    this.blockedUserAvatar,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as String,
      blockedUserId: json['blocked_user_id'] as String,
      blockedUserName: json['blocked_user_name'] as String? ?? 'Unknown',
      blockedUserAvatar: json['blocked_user_avatar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String blockedUserId;
  final String blockedUserName;
  final String? blockedUserAvatar;
  final DateTime createdAt;
}

class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.reporterUserId,
    required this.reportedUserId,
    this.reporterNameSnapshot,
    this.reportedNameSnapshot,
    required this.reportType,
    this.description,
    this.screenshotPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SafetyReport.fromJson(Map<String, dynamic> json) {
    return SafetyReport(
      id: json['id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      reporterNameSnapshot: json['reporter_name_snapshot'] as String?,
      reportedNameSnapshot: json['reported_name_snapshot'] as String?,
      reportType: json['report_type'] as String,
      description: json['description'] as String?,
      screenshotPath: json['screenshot_path'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String reporterUserId;
  final String reportedUserId;
  final String? reporterNameSnapshot;
  final String? reportedNameSnapshot;
  final String reportType;
  final String? description;
  final String? screenshotPath;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SafetyRepository {
  const SafetyRepository();

  static const _reportBucket = 'report-screenshots';

  Future<SafetyResult<SafetyReport>> submitReport({
    required String reportedUserId,
    required String reportType,
    String? description,
    XFile? screenshot,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const SafetyResult.failure('You must be signed in');
      }

      if (user.id == reportedUserId) {
        return const SafetyResult.failure('Cannot report yourself');
      }

      final reporterName = user.userMetadata?['name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          'Unknown';

      final reportedProfile = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', reportedUserId)
          .maybeSingle();

      if (reportedProfile == null) {
        return const SafetyResult.failure('User not found');
      }

      final reportedName =
          (reportedProfile['display_name'] as String?)?.trim().isNotEmpty == true
              ? reportedProfile['display_name'] as String
              : 'Unknown';

      final reportPayload = <String, dynamic>{
        'reporter_user_id': user.id,
        'reported_user_id': reportedUserId,
        'reporter_name_snapshot': reporterName,
        'reported_name_snapshot': reportedName,
        'report_type': reportType,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'screenshot_path': null,
        'status': 'pending',
      };

      final reportResponse = await Supabase.instance.client
          .from('safety_reports')
          .insert(reportPayload)
          .select()
          .single();

      final report = SafetyReport.fromJson(reportResponse);
      String? screenshotPath;

      if (screenshot != null) {
        try {
          final bytes = await screenshot.readAsBytes();
          final normalized = await ConexoImageNormalizer.normalize(bytes);
          final storagePath =
              'reports/${user.id}/${report.id}.jpg';

          await Supabase.instance.client.storage
              .from(_reportBucket)
              .uploadBinary(
                storagePath,
                normalized.bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                ),
              );

          screenshotPath = storagePath;

          await Supabase.instance.client
              .from('safety_reports')
              .update({'screenshot_path': storagePath})
              .eq('id', report.id);
        } catch (_) {
          screenshotPath = null;
        }
      }

      // Email notification is secondary — the stored report is the source of
      // truth. A failure here (including a 503 when RESEND_API_KEY is not
      // configured, or a 502 when Resend rejects the message) must NOT surface
      // to the user as a failed report.
      try {
        await Supabase.instance.client.functions.invoke(
          'notify-safety-report',
          body: {
            'report_id': report.id,
          },
        );
      } catch (e) {
        debugPrint(
          'notify-safety-report invocation failed for report ${report.id}: $e',
        );
      }

      final updatedReport = SafetyReport(
        id: report.id,
        reporterUserId: report.reporterUserId,
        reportedUserId: report.reportedUserId,
        reporterNameSnapshot: report.reporterNameSnapshot,
        reportedNameSnapshot: report.reportedNameSnapshot,
        reportType: report.reportType,
        description: report.description,
        screenshotPath: screenshotPath ?? report.screenshotPath,
        status: report.status,
        createdAt: report.createdAt,
        updatedAt: report.updatedAt,
      );

      return SafetyResult.success(updatedReport);
    } on PostgrestException catch (e) {
      return SafetyResult.failure(e.message);
    } catch (_) {
      return const SafetyResult.failure('Network error. Please try again.');
    }
  }

  Future<SafetyResult<List<BlockedUser>>> getBlockedUsers() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const SafetyResult.failure('You must be signed in');
      }

      // Canonical block relationship lives in public.blocks
      // (blocker_id, blocked_id). RLS returns only rows where the current user
      // is the blocker.
      final blocksData = await Supabase.instance.client
          .from('blocks')
          .select('id, blocked_id, created_at')
          .eq('blocker_id', user.id)
          .order('created_at', ascending: false);

      if (blocksData.isEmpty) {
        return const SafetyResult.success(<BlockedUser>[]);
      }

      final blockedIds = <String>[
        for (final row in blocksData) row['blocked_id'] as String,
      ];

      // Resolve display info from the canonical profiles table in one batch.
      final profilesData = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, photos')
          .inFilter('id', blockedIds);

      final profilesById = <String, Map<String, dynamic>>{
        for (final row in profilesData) row['id'] as String: row,
      };

      final blocked = <BlockedUser>[];
      for (final row in blocksData) {
        final blockedId = row['blocked_id'] as String;
        final profile = profilesById[blockedId];
        final photos = profile?['photos'] as List?;
        String? avatar;
        if (photos != null && photos.isNotEmpty) {
          final first = photos.first;
          if (first is Map) {
            avatar = first['remoteUrl'] as String?;
            if (avatar == null || avatar.isEmpty) {
              avatar = first['assetPath'] as String?;
            }
          }
        }

        blocked.add(BlockedUser(
          id: row['id'] as String,
          blockedUserId: blockedId,
          blockedUserName:
              (profile?['display_name'] as String?)?.trim().isNotEmpty == true
                  ? (profile?['display_name'] as String)
                  : 'Unknown',
          blockedUserAvatar: avatar,
          createdAt: DateTime.parse(row['created_at'] as String),
        ));
      }

      return SafetyResult.success(blocked);
    } on PostgrestException catch (e) {
      return SafetyResult.failure(e.message);
    } catch (_) {
      return const SafetyResult.failure('Network error. Please try again.');
    }
  }

  Future<SafetyResult<void>> blockUser(String userId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const SafetyResult.failure('You must be signed in');
      }

      if (user.id == userId) {
        return const SafetyResult.failure('Cannot block yourself');
      }

      await Supabase.instance.client
          .from('blocks')
          .insert({
            'blocker_id': user.id,
            'blocked_id': userId,
          });

      return const SafetyResult.success(null);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const SafetyResult.failure('User is already blocked');
      }
      return SafetyResult.failure(e.message);
    } catch (_) {
      return const SafetyResult.failure('Network error. Please try again.');
    }
  }

  Future<SafetyResult<void>> unblockUser(String userId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const SafetyResult.failure('You must be signed in');
      }

      await Supabase.instance.client
          .from('blocks')
          .delete()
          .eq('blocker_id', user.id)
          .eq('blocked_id', userId);

      return const SafetyResult.success(null);
    } on PostgrestException catch (e) {
      return SafetyResult.failure(e.message);
    } catch (_) {
      return const SafetyResult.failure('Network error. Please try again.');
    }
  }

  Future<SafetyResult<bool>> isBlocked(String otherUserId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return const SafetyResult.success(false);

      final result = await Supabase.instance.client
          .from('blocks')
          .select('id')
          .or('and(blocker_id.eq.${user.id},blocked_id.eq.$otherUserId),and(blocker_id.eq.$otherUserId,blocked_id.eq.${user.id})')
          .maybeSingle();

      return SafetyResult.success(result != null);
    } catch (_) {
      return const SafetyResult.success(false);
    }
  }

  /// Resolves the directional block relationship (who blocked whom) between the
  /// current user and [otherUserId] via the canonical `block_state` RPC.
  ///
  /// Never throws: on any failure it reports [BlockState.none] so callers can
  /// decide their own safe default. Callers that must fail closed (e.g. a chat
  /// composer) should keep the input disabled until this resolves.
  Future<BlockState> blockStateWith(String otherUserId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return BlockState.none;

      final rows = await Supabase.instance.client.rpc(
        'block_state',
        params: {'p_other': otherUserId},
      );

      if (rows is List && rows.isNotEmpty) {
        final row = rows.first;
        if (row is Map) {
          return BlockState(
            iBlocked: row['i_blocked'] == true,
            theyBlocked: row['they_blocked'] == true,
          );
        }
      }
      return BlockState.none;
    } catch (_) {
      return BlockState.none;
    }
  }
}
