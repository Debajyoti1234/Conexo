import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/router/app_router.dart';
import '../../features/main_shell.dart';
import '../../features/notifications/notification_controller.dart';
import '../../features/notifications/notification_models.dart';
import '../../features/notifications/notification_navigation.dart';
import '../../features/profile/profile_photo_resolver.dart';
import '../../features/profile/supabase_profile_repository.dart';
import 'home_discovery_animations.dart';
import 'plans/plan_repository.dart';
import 'plans/supabase_plan_repository.dart';
import 'profile/connections_view_model.dart';
import 'profile/realtime_connections_service.dart';

class ConnectionsDashboard extends StatefulWidget {
  const ConnectionsDashboard({
    super.key,
    this.repository = const SupabasePlanRepository(),
  });

  final PlanRepository repository;

  @override
  State<ConnectionsDashboard> createState() => _ConnectionsDashboardState();
}

class _ConnectionsDashboardState extends State<ConnectionsDashboard> {
  late final ConnectionsViewModel _viewModel = const ConnectionsViewModel();

  List<ConnectionUiModel> _network = const [];
  List<ConnectionUiModel> _requests = const [];
  List<ConnectionUiModel> _pending = const [];
  List<_HostedPlanCount> _plans = const [];

  bool _loading = true;
  String? _error;

  NotificationController? get _notifications => MainShell.notifications;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeConnectionsService.instance.start();
    _realtimeSubscription =
        RealtimeConnectionsService.instance.onConnectionsChanged.listen((_) {
      if (!mounted || _loading) return;
      _load();
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    RealtimeConnectionsService.instance.stop();
    super.dispose();
  }

  StreamSubscription<void>? _realtimeSubscription;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final accepted = await _viewModel.loadAcceptedConnections();
      final incoming = await _viewModel.loadIncomingRequests();
      final outgoing = await _viewModel.loadOutgoingRequests();

      if (!mounted) return;
      setState(() {
        _network = List.from(accepted)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _requests = List.from(incoming)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _pending = List.from(outgoing)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }

    await _loadHostedPlans();
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _loadHostedPlans() async {
    try {
      final experiences = await widget.repository.getPublishedExperiences();
      if (!mounted) return;

      final plans = <_HostedPlanCount>[];
      for (final experience in experiences) {
        final members = await widget.repository.getPlanMembers(experience.id);
        final joinedCount = members
            .where((m) => m.status == 'joined' && m.role != 'creator' && m.userId != experience.hostId)
            .length;
        plans.add(_HostedPlanCount(
          id: experience.id,
          name: experience.title,
          memberCount: joinedCount,
        ));
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
      });
    } catch (e) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    } else if (_error != null) {
      body = _ErrorState(
        message: _error!,
        onRetry: _load,
      );
    } else {
      body = ListView(
        controller: ScrollController(),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 150),
        children: [
          const Text(
            'Connections',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your network, requests & plans',
            style: TextStyle(
              fontSize: 14.5,
              color: Color(0xFFAFB8D4),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildSummaryGrid(),
          const SizedBox(height: 26),
          if (_notifications != null) _ActivitySection(controller: _notifications!),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF8B5CF6),
      child: body,
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _SummaryCard(
          index: 0,
          icon: Icons.people_rounded,
          label: 'Network',
          count: _network.length,
          accent: const Color(0xFF47D7A5),
          onTap: () {
            Navigator.of(context).push(AppRouter.networkPageRoute());
          },
        ),
        _SummaryCard(
          index: 1,
          icon: Icons.person_add_rounded,
          label: 'Requests',
          count: _requests.length,
          accent: const Color(0xFFFF4D8D),
          onTap: () {
            Navigator.of(context).push(AppRouter.requestsPageRoute());
          },
        ),
        _SummaryCard(
          index: 2,
          icon: Icons.schedule_rounded,
          label: 'Pending',
          count: _pending.length,
          accent: const Color(0xFFFFC24D),
          onTap: () {
            Navigator.of(context).push(AppRouter.pendingPageRoute());
          },
        ),
        _SummaryCard(
          index: 3,
          icon: Icons.star_rounded,
          label: 'Hosted Plans',
          count: _plans.length,
          accent: const Color(0xFF7C3AED),
          onTap: () {
            Navigator.of(context).push(AppRouter.hostedPlansPageRoute());
          },
        ),
      ],
    );
  }
}

class _HostedPlanCount {
  const _HostedPlanCount({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  final String id;
  final String name;
  final int memberCount;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4D8D).withValues(alpha: .12),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 27,
              color: Color(0xFFFF4D8D),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFB9C3DC),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.index,
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      delay: Duration(milliseconds: index * 80),
      offset: const Offset(0, 0.1),
      duration: const Duration(milliseconds: 460),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF182039).withValues(alpha: .78),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: .16),
                    ),
                    child: Icon(icon, size: 21, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.82, end: 1)
                                      .animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            '$count',
                            key: ValueKey<int>(count),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB9C3DC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [controller.hasUnread, controller.pulseTrigger]),
      builder: (context, child) {
        return child!;
      },
      child: _ActivityBody(controller: controller),
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    final notifications = controller.notifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(
            children: [
              const Text(
                'Your Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEAEEF9),
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  controller.markAllRead();
                },
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (notifications.isEmpty)
          _ActivityEmpty()
        else
          ..._buildRows(context, notifications),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context, List<AppNotification> notifications) {
    final grouped = groupNotifications(notifications);
    final rows = <Widget>[];
    for (final bucket in NotificationBucket.values) {
      final items = grouped[bucket];
      if (items == null || items.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            notificationBucketLabel(bucket),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9DB2E8),
              letterSpacing: 0.4,
            ),
          ),
        ),
      );
      for (final n in items) {
        rows.add(
          _ActivityRow(
            notification: n,
            onTap: () => NotificationNavigation.open(context, n),
          ),
        );
      }
    }
    return rows;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: notification.unread
              ? Colors.white.withValues(alpha: .05)
              : Colors.white.withValues(alpha: .02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.unread
                ? Colors.white.withValues(alpha: .08)
                : Colors.white.withValues(alpha: .04),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActivityAvatar(notification: notification),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          notification.unread ? FontWeight.w800 : FontWeight.w600,
                      color: notification.unread
                          ? const Color(0xFFEAEEF9)
                          : const Color(0xFFB9C3DC),
                    ),
                  ),
                  if (notification.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9DB2E8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              notificationTimeLabel(notification.timestamp),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8BA8),
              ),
            ),
            if (notification.unread) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityAvatar extends StatefulWidget {
  const _ActivityAvatar({required this.notification});

  final AppNotification notification;

  @override
  State<_ActivityAvatar> createState() => _ActivityAvatarState();
}

class _ActivityAvatarState extends State<_ActivityAvatar> {
  String? _imageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  Future<void> _resolvePhoto() async {
    final kind = widget.notification.kind;
    final actorId = widget.notification.actorId;
    final entityId = widget.notification.entityId;

    try {
      if (_isUserPhotoKind(kind) && actorId != null && actorId.isNotEmpty) {
        final profile =
            await const SupabaseProfileRepository().loadProfileByUserId(actorId);
        if (!mounted) return;
        if (profile != null && profile.photos.isNotEmpty) {
          final primary = profile.photos.firstWhere(
            (p) => p.isPrimary,
            orElse: () => profile.photos.first,
          );
          final remoteUrl = primary.remoteUrl;
          if (remoteUrl != null && remoteUrl.isNotEmpty) {
            if (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://')) {
              _setImage(remoteUrl);
            } else if (remoteUrl.startsWith('profiles/')) {
              final resolved =
                  await ProfilePhotoResolver.instance.resolvePhoto(remoteUrl);
              if (!mounted) return;
              _setImage(resolved.signedUrl);
            }
            return;
          }
        }
      } else if (_isPlanPhotoKind(kind) && entityId != null && entityId.isNotEmpty) {
        final data = await Supabase.instance.client
            .from('plans')
            .select('cover_url')
            .eq('id', entityId)
            .maybeSingle();
        if (!mounted) return;
        final coverUrl = data?['cover_url'] as String?;
        if (coverUrl != null && coverUrl.isNotEmpty) {
          final signed =
              await const SupabasePlanRepository().getCoverSignedUrl(coverUrl);
          if (!mounted) return;
          if (signed != null && signed.isNotEmpty) {
            _setImage(signed);
            return;
          }
        }
      }
    } catch (_) {
      // fall through to fallback icon
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _setImage(String url) {
    if (!mounted) return;
    setState(() {
      _imageUrl = url;
      _loading = false;
    });
  }

  bool _isUserPhotoKind(NotificationKind kind) {
    return kind == NotificationKind.request ||
        kind == NotificationKind.requestAccepted ||
        kind == NotificationKind.joinRequest ||
        kind == NotificationKind.join;
  }

  bool _isPlanPhotoKind(NotificationKind kind) {
    return kind == NotificationKind.planInvitation || kind == NotificationKind.plan;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .08),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
        ),
      );
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Container(
        height: 36,
        width: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            _imageUrl!,
            height: 36,
            width: 36,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .08),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
          ),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    final accent = _kindColor(widget.notification.kind);
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: .14),
      ),
      child: Icon(
        widget.notification.icon,
        size: 18,
        color: accent,
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: .14),
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  size: 27, color: Color(0xFFB7A5FF)),
            ),
            const SizedBox(height: 14),
            Text(
              'You\'re all caught up.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB9C3DC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _kindColor(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.join:
      return const Color(0xFF47D7A5);
    case NotificationKind.request:
      return const Color(0xFFB7A5FF);
    case NotificationKind.requestAccepted:
      return const Color(0xFF47D7A5);
    case NotificationKind.planInvitation:
      return const Color(0xFFFF6B8A);
    case NotificationKind.joinRequest:
      return const Color(0xFFFFB86B);
    case NotificationKind.plan:
      return const Color(0xFFFFB86B);
    case NotificationKind.message:
      return const Color(0xFF6EA8FE);
    case NotificationKind.system:
      return const Color(0xFFB7A5FF);
  }
}
