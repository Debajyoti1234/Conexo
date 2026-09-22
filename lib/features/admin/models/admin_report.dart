/// Data models for the Admin Reports / Moderation Queue.
///
/// [AdminReport] mirrors the columns returned by the server-side SECURITY
/// DEFINER RPC `admin_list_reports`. No private storage paths, selfie URLs,
/// or sensitive content are included.
class AdminReport {
  const AdminReport({
    required this.reportId,
    required this.reporterUserId,
    required this.reporterNameSnapshot,
    required this.reportedUserId,
    required this.reportedNameSnapshot,
    required this.reportType,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.total = 0,
  });

  factory AdminReport.fromMap(Map<String, dynamic> row) {
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

    String? nullableString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.isEmpty ? null : value;
      return value.toString();
    }

    return AdminReport(
      reportId: row['report_id'] as String? ?? '',
      reporterUserId: row['reporter_user_id'] as String?,
      reporterNameSnapshot: nullableString(row['reporter_name_snapshot']),
      reportedUserId: row['reported_user_id'] as String?,
      reportedNameSnapshot: nullableString(row['reported_name_snapshot']),
      reportType: row['report_type'] as String? ?? 'Unknown',
      description: nullableString(row['description']),
      status: row['status'] as String? ?? 'pending',
      createdAt: toDate(row['created_at']),
      updatedAt: toDate(row['updated_at']),
      total: toInt(row['total']),
    );
  }

  final String reportId;
  final String? reporterUserId;
  final String? reporterNameSnapshot;
  final String? reportedUserId;
  final String? reportedNameSnapshot;
  final String reportType;
  final String? description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int total;
}

class AdminReportPage {
  const AdminReportPage({
    required this.reports,
    required this.total,
  });

  final List<AdminReport> reports;
  final int total;
}

/// Per-status counts returned by `admin_report_summary`.
class AdminReportSummary {
  const AdminReportSummary({
    required this.pending,
    required this.reviewing,
    required this.resolved,
    required this.dismissed,
    required this.actionTaken,
    required this.total,
    required this.open,
  });

  factory AdminReportSummary.fromMap(Map<String, dynamic> row) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return AdminReportSummary(
      pending: toInt(row['pending_count']),
      reviewing: toInt(row['reviewing_count']),
      resolved: toInt(row['resolved_count']),
      dismissed: toInt(row['dismissed_count']),
      actionTaken: toInt(row['action_taken_count']),
      total: toInt(row['total_count']),
      open: toInt(row['open_count']),
    );
  }

  final int pending;
  final int reviewing;
  final int resolved;
  final int dismissed;
  final int actionTaken;
  final int total;
  final int open;
}
