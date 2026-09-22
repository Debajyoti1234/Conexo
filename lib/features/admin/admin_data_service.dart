import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_overview_data.dart';
import 'models/admin_report.dart';
import 'models/admin_user.dart';
import 'models/admin_user_detail.dart';
import 'models/admin_verification_entry.dart';
import 'models/admin_manual_verification_entry.dart';

/// Admin-only data service for the Admin Dashboard.
///
/// This service is intentionally separate from all consumer repositories.
/// It calls only SECURITY DEFINER RPCs (`public.is_admin()` is verified
/// server-side inside each RPC before any data is returned).
///
/// Never catches and silently swallows exceptions — callers decide how to
/// handle failures through loading/error/retry states in the UI.
class AdminDataService {
  const AdminDataService();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches aggregate overview metrics from the server.
  ///
  /// Throws [AdminDataException] on failure.
  Future<AdminOverviewMetrics> fetchOverviewMetrics() async {
    final response = await _client.rpc('get_admin_overview_metrics');

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminOverviewMetrics.fromRpcResponse(response);
  }

  /// Paginated, searchable admin user list from the server-side
  /// `admin_list_users` RPC. All filtering, pagination, and sorting is
  /// enforced inside the RPC; the client only forwards the parameters.
  ///
  /// `total` is the server-computed count of matching users, independent of
  /// pagination.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminUserListPage> fetchUsers({
    int limit = 25,
    int offset = 0,
    String search = '',
    String verificationStatus = '',
    String profileVisibility = '',
    String sort = 'newest',
  }) async {
    final response = await _client.rpc(
      'admin_list_users',
      params: {
        'p_limit': limit,
        'p_offset': offset,
        'p_search': search,
        'p_verification_status': verificationStatus,
        'p_profile_visibility': profileVisibility,
        'p_sort': sort,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    final users = <AdminUser>[
      for (final row in response)
        if (row is Map<String, dynamic>) AdminUser.fromMap(row),
    ];

    return AdminUserListPage(
      users: users,
      total: users.isEmpty ? 0 : users.first.total,
    );
  }

  /// Single-user detail from the server-side `admin_get_user_detail` RPC.
  ///
  /// Throws [AdminDataException] on an unexpected response shape. Returns
  /// null when no user matches [userId].
  Future<AdminUserDetail?> getUserDetail(String userId) async {
    final response = await _client.rpc(
      'admin_get_user_detail',
      params: {'p_user_id': userId},
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) return null;

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminUserDetail.fromMap(row);
  }

  /// Paginated, searchable verification queue from the server-side
  /// `admin_list_verifications` RPC. All filtering, pagination, and sorting
  /// is enforced inside the RPC; the client only forwards the parameters.
  ///
  /// `total` is the server-computed count of matching users, independent of
  /// pagination.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminVerificationPage> fetchVerifications({
    int limit = 25,
    int offset = 0,
    String search = '',
    String verificationStatus = '',
    String sort = 'pending_first',
  }) async {
    final response = await _client.rpc(
      'admin_list_verifications',
      params: {
        'p_limit': limit,
        'p_offset': offset,
        'p_search': search,
        'p_verification_status': verificationStatus,
        'p_sort': sort,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    final entries = <AdminVerificationEntry>[
      for (final row in response)
        if (row is Map<String, dynamic>) AdminVerificationEntry.fromMap(row),
    ];

    return AdminVerificationPage(
      entries: entries,
      total: entries.isEmpty ? 0 : entries.first.total,
    );
  }

  /// Approves a pending verification request via the server-side
  /// `admin_approve_verification` RPC. Only admins can call this; non-admins
  /// are rejected server-side by `public.is_admin()`.
  ///
  /// [expectedStatus] is sent for concurrency protection — the RPC verifies
  /// the current database status still matches before transiting. If another
  /// process changed the status first, the RPC returns `success: false`.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminVerificationActionResult> approveVerification({
    required String targetUserId,
    required String expectedStatus,
  }) async {
    final response = await _client.rpc(
      'admin_approve_verification',
      params: {
        'p_target_user_id': targetUserId,
        'p_expected_status': expectedStatus,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) {
      throw const AdminDataException('Empty response from server');
    }

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminVerificationActionResult.fromMap(row);
  }

  /// Paginated, searchable manual verification queue from the server-side
  /// `admin_list_manual_verifications` RPC. All filtering, pagination, and sorting
  /// is enforced inside the RPC; the client only forwards the parameters.
  ///
  /// `total` is the server-computed count of matching requests, independent of
  /// pagination.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminManualVerificationPage> fetchManualVerifications({
    int limit = 25,
    int offset = 0,
    String search = '',
    String status = '',
    String sort = 'pending_first',
  }) async {
    final response = await _client.rpc(
      'admin_list_manual_verifications',
      params: {
        'p_limit': limit,
        'p_offset': offset,
        'p_search': search,
        'p_status': status,
        'p_sort': sort,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    final entries = <AdminManualVerificationEntry>[
      for (final row in response)
        if (row is Map<String, dynamic>) AdminManualVerificationEntry.fromMap(row),
    ];

    return AdminManualVerificationPage(
      entries: entries,
      total: entries.isEmpty ? 0 : entries.first.total,
    );
  }

  /// Single manual verification request detail from the server-side
  /// `admin_get_manual_verification` RPC.
  ///
  /// Throws [AdminDataException] on an unexpected response shape. Returns
  /// null when no request matches [requestId].
  ///
  /// Document paths (selfiePath, idFrontPath, idBackPath) are Storage
  /// paths — call [SupabaseClient.storage] to generate signed URLs on demand.
  Future<AdminManualVerificationDetail?> getManualVerification(
    String requestId,
  ) async {
    final response = await _client.rpc(
      'admin_get_manual_verification',
      params: {'p_request_id': requestId},
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) return null;

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminManualVerificationDetail.fromMap(row);
  }

  /// Approves a pending manual verification request via the server-side
  /// `admin_approve_manual_verification` RPC. Only admins can call this;
  /// non-admins are rejected server-side by `public.is_admin()`.
  ///
  /// [expectedStatus] is sent for concurrency protection — the RPC verifies
  /// the current database status still matches before transiting. If another
  /// process changed the status first, the RPC returns `success: false`.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminVerificationActionResult> approveManualVerification({
    required String requestId,
    required String expectedStatus,
  }) async {
    final response = await _client.rpc(
      'admin_approve_manual_verification',
      params: {
        'p_request_id': requestId,
        'p_expected_status': expectedStatus,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) {
      throw const AdminDataException('Empty response from server');
    }

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminVerificationActionResult.fromMap(row);
  }

  /// Rejects a pending manual verification request via the server-side
  /// `admin_reject_manual_verification` RPC. Only admins can call this;
  /// non-admins are rejected server-side by `public.is_admin()`.
  ///
  /// [expectedStatus] is sent for concurrency protection.
  /// [rejectionReason] is optional per the RPC contract.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminVerificationActionResult> rejectManualVerification({
    required String requestId,
    required String expectedStatus,
    required String rejectionReason,
  }) async {
    final response = await _client.rpc(
      'admin_reject_manual_verification',
      params: {
        'p_request_id': requestId,
        'p_expected_status': expectedStatus,
        'p_rejection_reason': rejectionReason,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) {
      throw const AdminDataException('Empty response from server');
    }

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminVerificationActionResult.fromMap(row);
  }

  /// Per-status report counts for the Admin Reports summary cards.
  ///
  /// Calls the server-side SECURITY DEFINER RPC `admin_report_summary`.
  /// Returns counts for pending, reviewing, resolved, dismissed,
  /// action_taken, total, and open (pending + reviewing) reports.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminReportSummary> fetchReportSummary() async {
    final response = await _client.rpc('admin_report_summary');

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    if (response.isEmpty) {
      throw const AdminDataException('Empty response from server');
    }

    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    return AdminReportSummary.fromMap(row);
  }

  /// Paginated, searchable moderation report queue from the server-side
  /// `admin_list_reports` RPC. All filtering, pagination, and sorting is
  /// enforced inside the RPC; the client only forwards the parameters.
  ///
  /// `total` is the server-computed count of matching reports, independent of
  /// pagination.
  ///
  /// Throws [AdminDataException] on an unexpected response shape.
  Future<AdminReportPage> fetchReports({
    int limit = 25,
    int offset = 0,
    String search = '',
    String status = '',
    String sort = 'newest',
  }) async {
    final response = await _client.rpc(
      'admin_list_reports',
      params: {
        'p_limit': limit,
        'p_offset': offset,
        'p_search': search,
        'p_status': status,
        'p_sort': sort,
      },
    );

    if (response is! List<dynamic>) {
      throw const AdminDataException('Unexpected response format');
    }

    final reports = <AdminReport>[
      for (final row in response)
        if (row is Map<String, dynamic>) AdminReport.fromMap(row),
    ];

    return AdminReportPage(
      reports: reports,
      total: reports.isEmpty ? 0 : reports.first.total,
    );
  }
}
