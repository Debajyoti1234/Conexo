/// Data model for the Admin Dashboard Overview metrics.
///
/// Returned by [AdminDataService.fetchOverviewMetrics], which calls the
/// server-side SECURITY DEFINER RPC [get_admin_overview_metrics].
///
/// All counts are non-nullable [int] values returned by the database.
/// [activeUsers] and [suspendedBannedUsers] are intentionally [int?] and
/// remain `null` until a reliable persisted data source exists for them.

class AdminOverviewMetrics {
  const AdminOverviewMetrics({
    required this.totalUsers,
    required this.newUsersToday,
    required this.newUsers7d,
    required this.newUsers30d,
    required this.verifiedUsers,
    required this.pendingVerification,
    required this.publicProfiles,
    required this.privateProfiles,
    required this.activePlans,
    required this.activeConnections,
    required this.totalRooms,
    required this.openReports,
    this.activeUsers,
    this.suspendedBannedUsers,
  });

  /// Total number of registered profiles (one row per user).
  final int totalUsers;

  /// Profiles created since the database's current date (midnight).
  final int newUsersToday;

  /// Profiles created in the last 7 days.
  final int newUsers7d;

  /// Profiles created in the last 30 days.
  final int newUsers30d;

  /// Profiles with `verification_status = 'verified'`.
  final int verifiedUsers;

  /// Profiles with `verification_status = 'pending'`.
  final int pendingVerification;

  /// Profiles with `profile_visibility = 'public'`.
  final int publicProfiles;

  /// Profiles with `profile_visibility = 'private'`.
  final int privateProfiles;

  /// Plans with `status = 'active'`.
  final int activePlans;

  /// Connections with `status = 'accepted'`.
  final int activeConnections;

  /// Total number of conversations (connection + plan rooms).
  final int totalRooms;

  /// Safety reports with `status IN ('pending', 'reviewing')`.
  final int openReports;

  /// NOT YET AVAILABLE — no reliable "last active" timestamp exists in the
  /// persisted schema. Remains `null` until a session/activity field is added.
  final int? activeUsers;

  /// NOT YET AVAILABLE — no platform-level suspension/ban status column
  /// exists on profiles or auth.users. Remains `null` until added.
  final int? suspendedBannedUsers;

  /// Parses a single-row RPC response into [AdminOverviewMetrics].
  ///
  /// The Supabase RPC client returns a `List<dynamic>`; for a single-row
  /// function we take the first element and cast it to `Map<String, dynamic>`.
  factory AdminOverviewMetrics.fromRpcResponse(List<dynamic> response) {
    if (response.isEmpty) {
      throw AdminDataException('Empty metrics response from server');
    }
    final row = response.first;
    if (row is! Map<String, dynamic>) {
      throw AdminDataException('Invalid metrics response format');
    }
    return AdminOverviewMetrics(
      totalUsers: _asInt(row['total_users']),
      newUsersToday: _asInt(row['new_users_today']),
      newUsers7d: _asInt(row['new_users_7d']),
      newUsers30d: _asInt(row['new_users_30d']),
      verifiedUsers: _asInt(row['verified_users']),
      pendingVerification: _asInt(row['pending_verification']),
      publicProfiles: _asInt(row['public_profiles']),
      privateProfiles: _asInt(row['private_profiles']),
      activePlans: _asInt(row['active_plans']),
      activeConnections: _asInt(row['active_connections']),
      totalRooms: _asInt(row['total_rooms']),
      openReports: _asInt(row['open_reports']),
      activeUsers: _asNullableInt(row['active_users']),
      suspendedBannedUsers: _asNullableInt(row['suspended_banned_users']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw AdminDataException('Expected integer metric, got: $value');
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

/// Thrown by [AdminDataService] when the metrics RPC fails or returns
/// malformed data. The UI catches this and shows a generic error state;
/// database/RPC details are never exposed to the end user.
class AdminDataException implements Exception {
  const AdminDataException(this.message);
  final String message;

  @override
  String toString() => message;
}