/// Data model for a single row in the Admin Manual Verification Queue.
///
/// Returned by [AdminDataService.fetchManualVerifications], which calls the
/// server-side SECURITY DEFINER RPC `admin_list_manual_verifications`.
///
/// Only fields required by the Manual Verification screen are included
/// — no secrets, no document paths (those are in the detail model),
/// no face-verification evidence, no private URLs.
class AdminManualVerificationEntry {
  const AdminManualVerificationEntry({
    required this.requestId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.verificationStatus,
    required this.manualStatus,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.rejectionReason,
    this.total = 0,
  });

  factory AdminManualVerificationEntry.fromMap(Map<String, dynamic> row) {
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

    return AdminManualVerificationEntry(
      requestId: row['request_id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      verificationStatus: row['verification_status'] as String?,
      manualStatus: row['manual_status'] as String?,
      createdAt: toDate(row['created_at']),
      reviewedAt: toDate(row['reviewed_at']),
      reviewedBy: row['reviewed_by'] as String?,
      rejectionReason: row['rejection_reason'] as String?,
      total: toInt(row['total']),
    );
  }

  final String requestId;
  final String userId;
  final String? displayName;
  final String? email;
  final String? verificationStatus;
  final String? manualStatus;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final int total;
}

class AdminManualVerificationPage {
  const AdminManualVerificationPage({
    required this.entries,
    required this.total,
  });

  final List<AdminManualVerificationEntry> entries;
  final int total;
}

/// Detail returned by [AdminDataService.getManualVerification], which calls
/// the server-side SECURITY DEFINER RPC `admin_get_manual_verification`.
///
/// Includes document Storage paths (private — signed URLs generated on demand
/// by the caller, never persisted).
class AdminManualVerificationDetail {
  const AdminManualVerificationDetail({
    required this.requestId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.verificationStatus,
    required this.manualStatus,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.rejectionReason,
    this.selfiePath,
    this.idFrontPath,
    this.idBackPath,
  });

  factory AdminManualVerificationDetail.fromMap(Map<String, dynamic> row) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value is String ? value : value.toString());
    }

    return AdminManualVerificationDetail(
      requestId: row['request_id'] as String? ?? '',
      userId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      verificationStatus: row['verification_status'] as String?,
      manualStatus: row['manual_status'] as String?,
      selfiePath: row['selfie_path'] as String?,
      idFrontPath: row['id_front_path'] as String?,
      idBackPath: row['id_back_path'] as String?,
      createdAt: toDate(row['created_at']),
      reviewedAt: toDate(row['reviewed_at']),
      reviewedBy: row['reviewed_by'] as String?,
      rejectionReason: row['rejection_reason'] as String?,
    );
  }

  final String requestId;
  final String userId;
  final String? displayName;
  final String? email;
  final String? verificationStatus;
  final String? manualStatus;
  final String? selfiePath;
  final String? idFrontPath;
  final String? idBackPath;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
}
