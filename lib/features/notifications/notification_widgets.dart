import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';
import 'notification_models.dart';

/// Shared premium widgets for the Activity Center + the global bell/toast.
///
/// Reuses the existing Conexo design language: [GlassCard], the [Shimmer] /
/// [SkeletonLine] skeleton primitives, violet accents, and easeOutCubic motion.

const Color _kAccent = Color(0xFF8B5CF6);
const Color _kAccentSoft = Color(0xFFB7A5FF);

/// The accent tint used for a notification's leading icon by [NotificationKind].
Color _kindColor(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.join:
      return const Color(0xFF47D7A5);
    case NotificationKind.request:
      return _kAccentSoft;
    case NotificationKind.plan:
      return const Color(0xFFFFB86B);
    case NotificationKind.message:
      return const Color(0xFF6EA8FE);
    case NotificationKind.system:
      return _kAccentSoft;
  }
}

/// A global, premium notification bell.
///
/// • [CupertinoIcons.bell_fill]-style glyph at 30–32dp, premium white.
/// • Subtle glow + a tiny 7px accent dot only when [hasUnread].
/// • Plays a single 1.0 → 1.08 → 1.0 pulse (220ms, easeOutCubic) whenever
///   [pulseTrigger] changes — driven by [TweenAnimationBuilder], no
///   [AnimationController].
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    required this.hasUnread,
    required this.pulseTrigger,
    required this.onTap,
    super.key,
  });

  final bool hasUnread;
  final int pulseTrigger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: hasUnread ? 'Notifications, unread' : 'Notifications',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              // A single pulse: value hops to 1 with each trigger change and the
              // 0→1 curve is mapped to 1.0 → 1.08 → 1.0 for a soft "ding".
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(pulseTrigger),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  final scale = 1.0 + 0.08 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Transform.scale(scale: scale, child: child);
                },
                child: _BellGlyph(hasUnread: hasUnread),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BellGlyph extends StatelessWidget {
  const _BellGlyph({required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: hasUnread
                ? [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: .45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: const Icon(
            Icons.notifications_rounded,
            size: 31,
            color: Colors.white,
          ),
        ),
        if (hasUnread)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B8A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B8A).withValues(alpha: .7),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Owns the top live toast overlay. Exposed as a class (not a free function)
/// so the shell calls `NotificationOverlay.show(context, notification)`.
///
/// The toast slides down from the top, holds ~2s, then fades away and removes
/// itself. It never blocks scrolling and stops receiving touches immediately
/// once it begins exiting.
class NotificationOverlay {
  const NotificationOverlay._();

  static void show(BuildContext context, AppNotification notification) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _LiveToastHost(
        notification: notification,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

/// The animated host that drives one toast's slide-in, hold, and fade-out and
/// reports completion via [onDismissed].
class _LiveToastHost extends StatefulWidget {
  const _LiveToastHost({
    required this.notification,
    required this.onDismissed,
  });

  final AppNotification notification;
  final VoidCallback onDismissed;

  @override
  State<_LiveToastHost> createState() => _LiveToastHostState();
}

class _LiveToastHostState extends State<_LiveToastHost> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Enter on the next frame so the AnimatedSlide/Opacity animate from off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    // Hold ~2s, then begin the exit.
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _onExitEnd() {
    // Only fire when we have finished the exit (not the entrance).
    if (!_visible) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + 12,
      left: 16,
      right: 16,
      // Non-interactive: never absorbs touches, so scrolling underneath is
      // always possible and taps pass straight through even during animation.
      child: IgnorePointer(
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          onEnd: _onExitEnd,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(
              child: LiveNotificationToast(notification: widget.notification),
            ),
          ),
        ),
      ),
    );
  }
}

/// The visual glass toast card used by [NotificationOverlay].
class LiveNotificationToast extends StatelessWidget {
  const LiveNotificationToast({required this.notification, super.key});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final tint = _kindColor(notification.kind);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconChip(icon: notification.icon, tint: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAEB9D6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, tinted leading icon chip shared by the toast and cards.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: .28)),
      ),
      child: Icon(icon, size: 21, color: tint),
    );
  }
}

/// A premium glass card for a single notification in the Activity Center.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
    final tint = _kindColor(notification.kind);
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(

          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconChip(icon: notification.icon, tint: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEAEEF9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notificationTimeLabel(notification.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A96B4),
                        ),
                      ),
                      if (notification.unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _kAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFFAEB9D6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// A small uppercase section header (Today / Yesterday / Earlier).

class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Color(0xFF8A96B4),
        ),
      ),
    );
  }
}

/// The loading skeleton for the Activity Center, reusing the existing
/// [Shimmer] + [SkeletonLine] language.
class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            SkeletonLine(width: 80, height: 12),
            SizedBox(height: 14),
            _SkeletonCard(),
            SizedBox(height: 12),
            _SkeletonCard(),
            SizedBox(height: 24),
            SkeletonLine(width: 96, height: 12),
            SizedBox(height: 14),
            _SkeletonCard(),
            SizedBox(height: 12),
            _SkeletonCard(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF182039).withValues(alpha: .78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBlock(width: 42, height: 42, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 180, height: 14),
                SizedBox(height: 10),
                SkeletonLine(width: 240, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium, asset-free empty state for the Activity Center.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: EntranceFade(
        offset: const Offset(0, 0.06),
        scaleFrom: 0.98,
        duration: const Duration(milliseconds: 460),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: .12),
                        Colors.white.withValues(alpha: .04),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 42,
                    color: _kAccentSoft,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'You’re all caught up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'New activity from your plans and connections will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFAEB9D6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
