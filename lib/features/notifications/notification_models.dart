import 'package:flutter/widgets.dart';

/// Immutable model + pure grouping helpers for the Activity Center.
///
/// This file is intentionally UI-agnostic and backend-agnostic: it defines the
/// shape of a demo notification and pure functions to bucket a list into
/// Today / Yesterday / Earlier. No Firebase, realtime, persistence, or UI.

/// The semantic kind of a notification, used only for a subtle accent tint on
/// its leading icon. Presentation-only — never persisted or sent anywhere.
enum NotificationKind { join, request, plan, message, system }

/// An immutable demo notification.
///
/// [icon] is a Material/Cupertino [IconData]; [timestamp] drives the
/// Today/Yesterday/Earlier grouping. [unread] reflects local demo state only.
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
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final NotificationKind kind;
  final bool unread;

  /// Returns a copy with the provided overrides (used for local unread toggles).
  AppNotification copyWith({bool? unread}) {
    return AppNotification(
      id: id,
      icon: icon,
      title: title,
      subtitle: subtitle,
      timestamp: timestamp,
      kind: kind,
      unread: unread ?? this.unread,
    );
  }
}

/// The date buckets shown in the Activity Center, in display order.
enum NotificationBucket { today, yesterday, earlier }

/// A pure grouping of [notifications] into ordered [NotificationBucket]s.
///
/// Groups are computed against [now] (defaults to `DateTime.now()`), sorted
/// newest-first within each bucket, and empty buckets are omitted. This is a
/// pure function — no side effects, no I/O.
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

/// A short human label for a bucket header (e.g. "Today").
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

/// A compact relative timestamp label (e.g. "Just now", "5m", "3h", "2d").
String notificationTimeLabel(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
