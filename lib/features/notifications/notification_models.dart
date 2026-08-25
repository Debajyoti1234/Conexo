import 'package:flutter/material.dart';

/// Immutable model + pure grouping helpers for the Activity Center.
///
/// Backend-agnostic shape: the [fromSupabase] factory maps real notification
/// rows from the `notifications` table onto this model. The UI layer never
/// touches the raw map.

/// The semantic kind of a notification, used for routing + accent tint.
enum NotificationKind { join, request, requestAccepted, planInvitation, joinRequest, plan, message, system }

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.kind = NotificationKind.system,
    this.unread = false,
    this.entityId,
    this.entityType,
    this.actorId,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final NotificationKind kind;
  final bool unread;
  final String? entityId;
  final String? entityType;
  final String? actorId;

  factory AppNotification.fromSupabase(Map<String, dynamic> row) {
    final kind = _parseKind(row['kind'] as String? ?? 'system');
    final icon = _iconForKind(kind);
    final title = (row['title'] as String? ?? '').trim();
    final body = (row['body'] as String? ?? '').trim();
    final createdAt = row['created_at'] as String?;
    final timestamp = createdAt != null
        ? DateTime.parse(createdAt).toLocal()
        : DateTime.now();
    final read = row['read'] as bool? ?? false;

    return AppNotification(
      id: row['id'] as String? ?? '',
      icon: icon,
      title: title,
      subtitle: body,
      timestamp: timestamp,
      kind: kind,
      unread: !read,
      entityId: row['entity_id'] as String?,
      entityType: row['entity_type'] as String?,
      actorId: row['actor_id'] as String?,
    );
  }

  AppNotification copyWith({
    bool? unread,
    String? title,
    String? subtitle,
  }) {
    return AppNotification(
      id: id,
      icon: icon,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp,
      kind: kind,
      unread: unread ?? this.unread,
      entityId: entityId,
      entityType: entityType,
      actorId: actorId,
    );
  }

  static NotificationKind _parseKind(String raw) {
    switch (raw) {
      case 'join':
        return NotificationKind.join;
      case 'request':
        return NotificationKind.request;
      case 'request_accepted':
        return NotificationKind.requestAccepted;
      case 'plan_invitation':
        return NotificationKind.planInvitation;
      case 'join_request':
        return NotificationKind.joinRequest;
      case 'plan':
        return NotificationKind.plan;
      case 'message':
        return NotificationKind.message;
      case 'system':
      default:
        return NotificationKind.system;
    }
  }

  static IconData _iconForKind(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.join:
        return Icons.group_add_rounded;
      case NotificationKind.request:
        return Icons.handshake_rounded;
      case NotificationKind.requestAccepted:
        return Icons.check_circle_rounded;
      case NotificationKind.planInvitation:
        return Icons.mail_rounded;
      case NotificationKind.joinRequest:
        return Icons.person_add_rounded;
      case NotificationKind.plan:
        return Icons.event_available_rounded;
      case NotificationKind.message:
        return Icons.forum_rounded;
      case NotificationKind.system:
        return Icons.verified_rounded;
    }
  }
}

/// The date buckets shown in the Activity Center, in display order.
enum NotificationBucket { today, yesterday, earlier }

/// A pure grouping of [notifications] into ordered [NotificationBucket]s.
Map<NotificationBucket, List<AppNotification>> groupNotifications(
  List<AppNotification> notifications, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final sorted = [...notifications]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  final result = <NotificationBucket, List<AppNotification>>{};
  for (final n in sorted) {
    final day = DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
    final NotificationBucket bucket;
    if (!day.isBefore(today)) {
      bucket = NotificationBucket.today;
    } else if (day == yesterday) {
      bucket = NotificationBucket.yesterday;
    } else {
      bucket = NotificationBucket.earlier;
    }
    result.putIfAbsent(bucket, () => <AppNotification>[]).add(n);
  }
  return result;
}

String notificationBucketLabel(NotificationBucket bucket) {
  switch (bucket) {
    case NotificationBucket.today:
      return 'Today';
    case NotificationBucket.yesterday:
      return 'Yesterday';
    case NotificationBucket.earlier:
      return 'Earlier';
  }
}

String notificationTimeLabel(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
