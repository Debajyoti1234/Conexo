import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
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
      body = Center(
        child: CircularProgressIndicator(color: context.cxInk),
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
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 150),
        children: [
          const _HeroBanner(),
          const SizedBox(height: 16),
          _buildSummaryGrid(),
          const SizedBox(height: 30),
          if (_notifications != null) _ActivitySection(controller: _notifications!),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.cxInk,
      child: body,
    );
  }

  Widget _buildSummaryGrid() {
    return _StatStrip(
      children: [
        _SummaryCard(
          index: 0,
          icon: Icons.people_outline,
          label: 'Network',
          count: _network.length,
          accent: context.cxSuccess,
          onTap: () {
            Navigator.of(context).push(AppRouter.networkPageRoute());
          },
        ),
        _SummaryCard(
          index: 1,
          icon: Icons.person_add_alt_1_outlined,
          label: 'Requests',
          count: _requests.length,
          accent: context.cxDanger,
          onTap: () {
            Navigator.of(context).push(AppRouter.requestsPageRoute());
          },
        ),
        _SummaryCard(
          index: 2,
          icon: Icons.schedule_outlined,
          label: 'Pending',
          count: _pending.length,
          accent: context.cxAccentSoft,
          onTap: () {
            Navigator.of(context).push(AppRouter.pendingPageRoute());
          },
        ),
        _SummaryCard(
          index: 3,
          icon: Icons.star_outline_rounded,
          label: 'Hosted',
          count: _plans.length,
          accent: context.cxInk,
          onTap: () {
            Navigator.of(context).push(AppRouter.hostedPlansPageRoute());
          },
        ),
      ],
    );
  }
}

/// Editorial hero: the generated illustration with the page title set into
/// its negative space. Purely decorative — no interaction.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return EntranceFade(
      duration: const Duration(milliseconds: 460),
      offset: Offset(0, 0.06),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/connections/hero.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              // Dark mode: subtle dark scrim so the hero reads as a dark glass card
              if (isDark)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.cxCanvas.withValues(alpha: .3),
                        context.cxCanvas.withValues(alpha: .6),
                        context.cxCanvas,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              // Hairline border so the card reads on both themes.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: context.cxLine),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connections',
                      style: TextStyle(
                        fontSize: 36,
                        fontFamily: 'Fraunces',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.9,
                        height: 1.0,
                        color: context.cxInk,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your network, requests & plans',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: context.cxSoft,
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

/// A single white strip holding the four summary cells, separated by
/// hairlines. Replaces the 2x2 grid; each cell keeps its own tap target.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.children});

  final List<Widget> children;

@override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cxCanvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cxLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.cxLine,
                ),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
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
              color: context.cxDanger.withValues(alpha: .12),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 27,
              color: context.cxDanger,
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
            style: TextStyle(
              fontSize: 13.5,
              color: context.cxSoft,
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
          onTap: onTap,
          child: Ink(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Monochrome glyph on a quiet neutral disc — one tone across
                  // all four cells reads calmer and more professional than
                  // four tinted colours.
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.cxSurface,
                    ),
                    child: Icon(icon, size: 15, color: context.cxInk),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
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
                      // Tabular sans figures: metrics read like a real
                      // dashboard and stay aligned when counts change.
                      style: TextStyle(
                        fontSize: 22,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        height: 1.0,
                        color: context.cxInk,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: context.cxMuted,
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
              Text(
                'Your activity',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w500,
                  color: context.cxInk,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  controller.markAllRead();
                },
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.cxSoft,
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
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(
            notificationBucketLabel(bucket).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.cxMuted,
              letterSpacing: 1.1,
            ),
          ),
        ),
      );
rows.add(
        Container(
          decoration: BoxDecoration(
            color: context.cxCanvas,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cxLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    color: context.cxLine,
                  ),
                _ActivityRow(
                  notification: items[i],
                  onTap: () => NotificationNavigation.open(context, items[i]),
                ),
              ],
            ],
          ),
        ),
      );
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: notification.unread
            ? context.cxSurface.withValues(alpha: .6)
            : Colors.transparent,
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
                      fontSize: 14,
                      fontWeight:
                          notification.unread ? FontWeight.w600 : FontWeight.w500,
                      color: notification.unread
                          ? context.cxInk
                          : context.cxSoft,
                    ),
                  ),
                  if (notification.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.cxMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              notificationTimeLabel(notification.timestamp),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: context.cxMuted,
              ),
            ),
if (notification.unread) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: context.cxDanger,
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
          color: context.cxInk.withValues(alpha: .08),
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.cxInk),
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
                  color: context.cxInk.withValues(alpha: .08),
                ),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: context.cxInk),
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
    final accent = _kindColor(context, widget.notification.kind);
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
                color: context.cxSurface,
                border: Border.all(color: context.cxLine),
              ),
              child: Icon(Icons.notifications_none_outlined,
                  size: 26, color: context.cxMuted),
            ),
            const SizedBox(height: 14),
            Text(
              'You\'re all caught up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: context.cxSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _kindColor(BuildContext context, NotificationKind kind) {
  switch (kind) {
    case NotificationKind.join:
      return context.cxSuccess;
    case NotificationKind.request:
      return context.cxInk;
    case NotificationKind.requestAccepted:
      return context.cxSuccess;
    case NotificationKind.planInvitation:
      return context.cxDanger;
    case NotificationKind.joinRequest:
      return context.cxAccentSoft;
    case NotificationKind.plan:
      return context.cxAccentSoft;
    case NotificationKind.message:
      return context.cxAccent;
    case NotificationKind.system:
      return context.cxInk;
  }
}
