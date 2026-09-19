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

  final int totalUsers;
  final int newUsersToday;
  final int newUsers7d;
  final int newUsers30d;
  final int verifiedUsers;
  final int pendingVerification;
  final int publicProfiles;
  final int privateProfiles;
  final int activePlans;
  final int activeConnections;
  final int totalRooms;
  final int openReports;

  final int? activeUsers;
  final int? suspendedBannedUsers;

  factory AdminOverviewMetrics.fromRpcResponse(List<dynamic> response) {
    final Map<String, dynamic> row = response.isNotEmpty
        ? Map<String, dynamic>.from(response.first as Map)
        : <String, dynamic>{};

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
      activeUsers: _asIntOrNull(row['active_users']),
      suspendedBannedUsers: _asIntOrNull(row['suspended_banned_users']),
    );
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class AdminDataException implements Exception {
  const AdminDataException(this.message);

  final String message;

  @override
  String toString() => 'AdminDataException: $message';
}
