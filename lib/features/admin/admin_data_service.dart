import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_overview_data.dart';
import 'models/admin_user.dart';
import 'models/admin_user_detail.dart';

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
}
