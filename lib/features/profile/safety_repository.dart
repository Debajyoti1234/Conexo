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

      final data = await Supabase.instance.client
          .from('blocked_users')
          .select(
              'id, blocker_user_id, blocked_user_id, created_at, blocked_profiles!inner(display_name, photos)')
          .eq('blocker_user_id', user.id)
          .order('created_at', ascending: false);

      final blocked = <BlockedUser>[];
      for (final row in data) {
        final profile = row['blocked_profiles'] as Map<String, dynamic>?;
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
          blockedUserId: row['blocked_user_id'] as String,
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

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client
          .from('blocked_users')
          .insert({
            'blocker_user_id': user.id,
            'blocked_user_id': userId,
            'created_at': now,
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
          .from('blocked_users')
          .delete()
          .eq('blocker_user_id', user.id)
          .eq('blocked_user_id', userId);

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
          .from('blocked_users')
          .select('id')
          .or('and(blocker_user_id.eq.${user.id},blocked_user_id.eq.$otherUserId),and(blocker_user_id.eq.$otherUserId,blocked_user_id.eq.${user.id})')
          .maybeSingle();

      return SafetyResult.success(result != null);
    } catch (_) {
      return const SafetyResult.success(false);
    }
  }
}
