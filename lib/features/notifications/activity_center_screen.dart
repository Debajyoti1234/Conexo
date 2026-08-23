import 'dart:async';

import 'package:flutter/material.dart';

import 'notification_controller.dart';
import 'notification_models.dart';
import 'notification_navigation.dart';
import 'notification_widgets.dart';


/// The premium Activity Center page.
///
/// PASSIVE by design: it renders the [NotificationController]'s current
/// notifications grouped into Today / Yesterday / Earlier. It never mutates
/// unread state and never calls `markAllRead()` — the shell owns that.
class ActivityCenterScreen extends StatefulWidget {
  const ActivityCenterScreen({required this.controller, super.key});

  final NotificationController controller;

  @override
  State<ActivityCenterScreen> createState() => _ActivityCenterScreenState();
}

class _ActivityCenterScreenState extends State<ActivityCenterScreen> {
  bool _loading = true;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    // A brief premium shimmer before revealing the grouped list.
    _loadTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            const _ActivityHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _loading
                    ? const NotificationSkeleton(
                        key: ValueKey<String>('activity-skeleton'),
                      )
                    : _ActivityBody(
                        key: const ValueKey<String>('activity-body'),
                        notifications: widget.controller.notifications,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          const Text(
            'Activity',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEAEEF9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the grouped list, or the premium empty state when there is nothing.
class _ActivityBody extends StatelessWidget {
  const _ActivityBody({required this.notifications, super.key});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const NotificationEmptyState();
    }

    // Flatten the ordered buckets into a single list of rows (headers + cards)
    // so a single ListView.builder can render everything efficiently.
    final grouped = groupNotifications(notifications);
    final rows = <_ActivityRow>[];
    for (final bucket in NotificationBucket.values) {
      final items = grouped[bucket];
      if (items == null || items.isEmpty) continue;
      rows.add(_ActivityRow.header(notificationBucketLabel(bucket)));
      for (final n in items) {
        rows.add(_ActivityRow.card(n));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isHeader) {
          return NotificationSectionHeader(
            key: ValueKey<String>('header_${row.label}'),
            label: row.label!,
          );
        }
        final n = row.notification!;
        return Padding(
          key: ValueKey<String>('card_${n.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: NotificationCard(
            notification: n,
            onTap: () => NotificationNavigation.open(context, n),
          ),
        );

      },
    );
  }
}

/// A tiny row descriptor so headers and cards can share one builder.
class _ActivityRow {
  const _ActivityRow.header(this.label) : notification = null;
  const _ActivityRow.card(this.notification) : label = null;

  final String? label;
  final AppNotification? notification;

  bool get isHeader => label != null;
}

/// A premium fade + slide route into the Activity Center, matching the
/// Conexo transition language.
Route<void> premiumActivityCenterRoute({
  required NotificationController controller,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ActivityCenterScreen(controller: controller),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
