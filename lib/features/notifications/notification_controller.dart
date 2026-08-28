import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/supabase/auth_service.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

/// Production notification controller backed by the real [NotificationRepository].
///
/// Mirrors the [NotificationDemoController] surface so the shell and Activity
/// Center need no UI changes:
///   • [notifications] — current list (newest first)
///   • [hasUnread] — true when any notification is unread
///   • [pulseTrigger] — bumps when a new notification arrives
///   • [markAllRead] — persists read state to the backend
///   • [dispose] — cancels the realtime subscription
class NotificationController {
  NotificationController({NotificationRepository? repository})
      : _repository = repository ?? const NotificationRepository();

  final NotificationRepository _repository;
  final List<AppNotification> _notifications = [];

  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);
  final ValueNotifier<int> pulseTrigger = ValueNotifier<int>(0);
  StreamSubscription<List<AppNotification>>? _subscription;

  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  bool get _hasUnread =>
      _notifications.any((n) => n.unread);

  void _syncUnread() {
    final next = _hasUnread;
    if (hasUnread.value != next) {
      hasUnread.value = next;
    }
  }

  /// Loads notifications from the backend and starts listening for realtime
  /// INSERT/UPDATE events on the `notifications` table.
  Future<void> start() async {
    await _load();

    // P1.2B.10B: lightweight realtime via repository stream.
    _subscription = _repository.watchNotifications().listen(_onRealtime);
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      final items = await _repository.loadNotifications();
      _notifications
        ..clear()
        ..addAll(items);
      _syncUnread();
    } on AuthFailure {
      // keep existing state on auth errors
    } catch (_) {
      // keep existing state on transient errors
    }
  }

  void _onRealtime(List<AppNotification> updated) {
    _notifications
      ..clear()
      ..addAll(updated);
    _syncUnread();
    if (updated.isNotEmpty) {
      pulseTrigger.value = pulseTrigger.value + 1;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      for (var i = 0; i < _notifications.length; i++) {
        if (_notifications[i].unread) {
          _notifications[i] = _notifications[i].copyWith(unread: false);
        }
      }
      _syncUnread();
    } on AuthFailure {
      // keep local state on error
    } catch (_) {
      // keep local state on error
    }
  }

  void dispose() {
    _subscription?.cancel();
    hasUnread.dispose();
    pulseTrigger.dispose();
  }
}
