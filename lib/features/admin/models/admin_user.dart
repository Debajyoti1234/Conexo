class AdminUser {
  const AdminUser({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.verificationStatus,
    required this.profileVisibility,
    required this.profileCompleted,
    required this.availabilityStatus,
    required this.registrationDate,
    required this.lastSignInAt,
    this.bannedUntil,
    this.connectionCount = 0,
    this.reportCount = 0,
    this.lastActiveAt,
    this.locationUpdatedAt,
    this.locationStatus,
    this.total = 0,
  });

  factory AdminUser.fromMap(Map<String, dynamic> row) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value is String ? value : value.toString());
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return AdminUser(
      userId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      verificationStatus: row['verification_status'] as String?,
      profileVisibility: row['profile_visibility'] as String?,
      profileCompleted: row['profile_completed'] as bool? ?? false,
      availabilityStatus: row['availability_status'] as String?,
      registrationDate: toDate(row['registration_date']),
      lastSignInAt: toDate(row['last_sign_in_at']),
      bannedUntil: toDate(row['banned_until']),
      connectionCount: toInt(row['connection_count']),
      reportCount: toInt(row['report_count']),
      lastActiveAt: toDate(row['last_active_at']),
      locationUpdatedAt: toDate(row['location_updated_at']),
      locationStatus: row['location_status'] as String?,
      total: toInt(row['total']),
    );
  }

  final String userId;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? verificationStatus;
  final String? profileVisibility;
  final bool profileCompleted;
  final String? availabilityStatus;
  final DateTime? registrationDate;
  final DateTime? lastSignInAt;
  final DateTime? bannedUntil;
  final int connectionCount;
  final int reportCount;
  final DateTime? lastActiveAt;
  final DateTime? locationUpdatedAt;
  final String? locationStatus;
  final int total;
}

class AdminUserListPage {
  const AdminUserListPage({
    required this.users,
    required this.total,
  });

  final List<AdminUser> users;
  final int total;
}
