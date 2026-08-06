import 'dart:async';

import 'package:flutter/material.dart';

import 'notification_models.dart';

/// A tiny, pure-state controller for the demo Activity Center.
///
/// It owns ONLY local state and the demo mutations — no [BuildContext],
/// [Overlay], [Navigator], widgets, animation, or shell logic. This keeps it
/// trivially swappable for a future Firebase/WebSocket source without changing
/// [MainShell].
///
/// A future backend controller can implement the same surface ([hasUnread],
/// [pulseTrigger], [notifications], [showDemoNotification], [markAllRead],
/// [startDemo]) and drop in unchanged.
class NotificationDemoController {
  NotificationDemoController() : _notifications = List.of(_seedNotifications);

  /// Whether there is at least one unread notification (drives bell glow/dot).
  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  /// Increments whenever a new notification arrives; the bell listens to this
  /// to play a single pulse. (State only — the animation lives in the widget.)
  final ValueNotifier<int> pulseTrigger = ValueNotifier<int>(0);

  final List<AppNotification> _notifications;
  int _incomingIndex = 0;
  Timer? _demoTimer;
  bool _seededUnread = false;

  /// An immutable snapshot of the current notifications (newest arrivals first
  /// once grouped by the Activity Center).
  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  /// Schedules the first demo notification to arrive shortly after mount.
  ///
  /// Called by [MainShell] from `initState()` — never from the constructor.
  /// Safe to call once; subsequent calls are ignored while a demo is pending.
  void startDemo() {
    _demoTimer?.cancel();
    _demoTimer = Timer(const Duration(milliseconds: 2200), showDemoNotification);
  }

  /// Injects a new demo notification: prepends it, marks unread, and bumps the
  /// [pulseTrigger]. This is the single entry point the shell reacts to.
  void showDemoNotification() {
    final incoming = _incomingNotifications[
        _incomingIndex % _incomingNotifications.length];
    _incomingIndex++;
    _notifications.insert(0, incoming);
    hasUnread.value = true;
    pulseTrigger.value = pulseTrigger.value + 1;
  }

  /// Clears the unread state and marks every notification as read. Called by
  /// the shell only after the Activity Center has successfully opened.
  void markAllRead() {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].unread) {
        _notifications[i] = _notifications[i].copyWith(unread: false);
      }
    }
    hasUnread.value = false;
    _seededUnread = true;
  }

  /// Whether any seed notifications began unread (used only internally).
  bool get seededUnread => _seededUnread;

  void dispose() {
    _demoTimer?.cancel();
    hasUnread.dispose();
    pulseTrigger.dispose();
  }
}

// ── Demo data (local, ephemeral) ────────────────────────────────────────────

final DateTime _now = DateTime.now();

/// The initial list shown in the Activity Center across all three buckets.
final List<AppNotification> _seedNotifications = <AppNotification>[
  AppNotification(
    id: 'seed_1',
    icon: Icons.group_add_rounded,
    title: 'Ravi joined your Sunset Trek',
    subtitle: 'Your plan now has 5 people going.',
    timestamp: _now.subtract(const Duration(minutes: 18)),
    kind: NotificationKind.join,
  ),
  AppNotification(
    id: 'seed_2',
    icon: Icons.handshake_rounded,
    title: 'Aisha wants to connect',
    subtitle: 'You share 3 mutual interests.',
    timestamp: _now.subtract(const Duration(hours: 3)),
    kind: NotificationKind.request,
  ),
  AppNotification(
    id: 'seed_3',
    icon: Icons.forum_rounded,
    title: 'New message from Maya',
    subtitle: '“See you at the cafe at 6?”',
    timestamp: _now.subtract(const Duration(days: 1, hours: 2)),
    kind: NotificationKind.message,
  ),
  AppNotification(
    id: 'seed_4',
    icon: Icons.event_available_rounded,
    title: 'Your Coffee & Chess plan is tomorrow',
    subtitle: 'A gentle reminder for 10:00 AM.',
    timestamp: _now.subtract(const Duration(days: 1, hours: 6)),
    kind: NotificationKind.plan,
  ),
  AppNotification(
    id: 'seed_5',
    icon: Icons.verified_rounded,
    title: 'You’re now verified',
    subtitle: 'Your profile earned the verified badge.',
    timestamp: _now.subtract(const Duration(days: 4)),
    kind: NotificationKind.system,
  ),
];

/// Notifications that "arrive" live via [NotificationDemoController].
final List<AppNotification> _incomingNotifications = <AppNotification>[
  AppNotification(
    id: 'live_1',
    icon: Icons.group_add_rounded,
    title: 'Emma joined your Goa Trip',
    subtitle: 'Say hi and share the meetup point.',
    timestamp: _now,
    kind: NotificationKind.join,
    unread: true,
  ),
];
