/// Data model for a single row in the Admin Verification Queue.
///
/// Returned by [AdminDataService.fetchVerifications], which calls the
/// server-side SECURITY DEFINER RPC `admin_list_verifications`.
///
/// Only fields required by the Verification screen are included — no secrets,
/// no face-verification evidence, no private URLs.
class AdminVerificationEntry {
  const AdminVerificationEntry({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.verificationStatus,
    required this.registrationDate,
    required this.lastUpdated,
    this.total = 0,
  });

  factory AdminVerificationEntry.fromMap(Map<String, dynamic> row) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value is String ? value : value.toString());
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return AdminVerificationEntry(
      userId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      verificationStatus: row['verification_status'] as String?,
      registrationDate: toDate(row['registration_date']),
      lastUpdated: toDate(row['last_updated']),
      total: toInt(row['total']),
    );
  }

  final String userId;
  final String? displayName;
  final String? email;
  final String? verificationStatus;
  final DateTime? registrationDate;
  final DateTime? lastUpdated;
  final int total;
}

class AdminVerificationPage {
  const AdminVerificationPage({
    required this.entries,
    required this.total,
  });

  final List<AdminVerificationEntry> entries;
  final int total;
}

/// Result returned by [AdminDataService.approveVerification], which calls the
/// server-side SECURITY DEFINER RPC `admin_approve_verification`.
///
/// `success` is `true` only when the server performed the pending → verified
/// transition. On failure, [message] contains a safe, user-facing reason.
class AdminVerificationActionResult {
  const AdminVerificationActionResult({
    required this.success,
    required this.previousStatus,
    required this.newStatus,
    required this.updatedAt,
    required this.message,
  });

  factory AdminVerificationActionResult.fromMap(Map<String, dynamic> row) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value is String ? value : value.toString());
    }

    return AdminVerificationActionResult(
      success: row['success'] as bool? ?? false,
      previousStatus: row['previous_status'] as String?,
      newStatus: row['new_status'] as String?,
      updatedAt: toDate(row['updated_at']),
      message: row['message'] as String? ?? '',
    );
  }

  final bool success;
  final String? previousStatus;
  final String? newStatus;
  final DateTime? updatedAt;
  final String message;
}
