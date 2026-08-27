import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/home_connection_dashboard_cards.dart';
import '../../features/notifications/notification_models.dart';
import '../../features/plans/plan_details_screen.dart';
import '../../features/plans/plan_repository.dart';
import '../../features/plans/plans_data.dart';
import '../../features/plans/plans_widgets.dart';
import '../../features/plans/supabase_plan_repository.dart';
import '../../features/profile/profile_navigation_mapper.dart';
import '../../features/profile/public_profile_screen.dart';
import '../../features/profile/supabase_profile_repository.dart';

class HostedPlansPage extends StatefulWidget {
  const HostedPlansPage({super.key, this.repository = const SupabasePlanRepository()});

  final PlanRepository repository;

  @override
  State<HostedPlansPage> createState() => _HostedPlansPageState();
}

class _HostedPlansPageState extends State<HostedPlansPage> {
  List<_HostedPlanUi> _plans = const [];
  bool _loading = true;
  String? _error;
  late final PlanRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final experiences = await _repository.getPublishedExperiences();
      if (!mounted) return;
      final plans = <_HostedPlanUi>[];
      for (final exp in experiences) {
        final members = await _repository.getPlanMembers(exp.id);
        final pending = await _repository.getPendingPlanMembers(exp.id);
        final joinedMembers = members
            .where((m) => m.status == 'joined' && m.role != 'creator' && m.userId != exp.hostId)
            .toList();
        final joinedCount = joinedMembers.length;
        final joinRequests = <_JoinRequestUi>[];
        for (final m in pending) {
          joinRequests.add(_JoinRequestUi(
            id: m.userId,
            name: m.displayName ?? 'User ${m.userId.substring(0, 8)}',
            portrait: m.photoUrl ?? '',
            color: _colorFromId(m.userId),
            requestedAt: m.updatedAt,
          ));
        }
        joinRequests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        final memberBubbles = <_MemberBubble>[];
        for (final m in joinedMembers) {
          if (m.displayName != null && (m.photoUrl ?? '').isNotEmpty) {
            memberBubbles.add(_MemberBubble(
              userId: m.userId,
              name: m.displayName!,
              portrait: m.photoUrl!,
              color: _colorFromId(m.userId),
            ));
          }
        }
        plans.add(_HostedPlanUi(
          id: exp.id,
          experience: exp,
          memberCount: joinedCount,
          joinRequests: joinRequests,
          memberBubbles: memberBubbles,
        ));
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _colorFromId(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0xFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue / 360.0, 0.65, 0.95).toColor();
  }

  Future<void> _approve(_HostedPlanUi plan, _JoinRequestUi request) async {
    try {
      await _repository.approvePlanMember(plan.id, request.id);
    } catch (e) {
      _showError(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _plans.indexWhere((p) => p.id == plan.id);
      if (index == -1) return;
      final updated = _HostedPlanUi(
        id: plan.id,
        experience: plan.experience,
        memberCount: plan.memberCount + 1,
        joinRequests: plan.joinRequests.where((r) => r.id != request.id).toList(),
        memberBubbles: plan.memberBubbles,
      );
      _plans[index] = updated;
    });
  }

  Future<void> _decline(_HostedPlanUi plan, _JoinRequestUi request) async {
    try {
      await _repository.declinePlanMember(plan.id, request.id);
    } catch (e) {
      _showError(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _plans.indexWhere((p) => p.id == plan.id);
      if (index == -1) return;
      final updated = _HostedPlanUi(
        id: plan.id,
        experience: plan.experience,
        memberCount: plan.memberCount,
        joinRequests: plan.joinRequests.where((r) => r.id != request.id).toList(),
        memberBubbles: plan.memberBubbles,
      );
      _plans[index] = updated;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4D8D),
      ),
    );
  }

  void _openPlan(_HostedPlanUi plan) {
    Navigator.of(context).push<void>(premiumPlanRoute(plan.experience));
  }

  Future<void> _openProfile(_MemberBubble member) async {
    final repository = const SupabaseProfileRepository();
    final profile = await repository.loadProfileByUserId(member.userId);
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not found')),
      );
      return;
    }
    Navigator.of(context).push(
      premiumPublicProfileRoute(data: mapUserProfileToPublicProfile(profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hosted Plans',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEAEEF9),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _plans.isEmpty
                          ? _EmptyState(
                              icon: Icons.event_available_outlined,
                              message:
                                  'No hosted plans yet. Your plans will appear here.',
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              children: [
                                for (final plan in _plans)
                                  _HostedPlanRow(
                                    plan: plan,
                                    onOpen: () => _openPlan(plan),
                                    onApprove: (r) => _approve(plan, r),
                                    onDecline: (r) => _decline(plan, r),
                                    onViewProfile: _openProfile,
                                  ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostedPlanUi {
  const _HostedPlanUi({
    required this.id,
    required this.experience,
    required this.memberCount,
    required this.joinRequests,
    required this.memberBubbles,
  });

  final String id;
  final Experience experience;
  final int memberCount;
  final List<_JoinRequestUi> joinRequests;
  final List<_MemberBubble> memberBubbles;
}

class _MemberBubble {
  const _MemberBubble({
    required this.userId,
    required this.name,
    required this.portrait,
    required this.color,
  });

  final String userId;
  final String name;
  final String portrait;
  final Color color;
}

class _JoinRequestUi {
  const _JoinRequestUi({
    required this.id,
    required this.name,
    required this.portrait,
    required this.color,
    required this.requestedAt,
  });

  final String id;
  final String name;
  final String portrait;
  final Color color;
  final DateTime requestedAt;
}

class _HostedPlanRow extends StatefulWidget {
  const _HostedPlanRow({
    required this.plan,
    required this.onOpen,
    required this.onApprove,
    required this.onDecline,
    required this.onViewProfile,
  });

  final _HostedPlanUi plan;
  final VoidCallback onOpen;
  final ValueChanged<_JoinRequestUi> onApprove;
  final ValueChanged<_JoinRequestUi> onDecline;
  final ValueChanged<_MemberBubble> onViewProfile;

  @override
  State<_HostedPlanRow> createState() => _HostedPlanRowState();
}

class _HostedPlanRowState extends State<_HostedPlanRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final experience = plan.experience;
    final hasRequests = plan.joinRequests.isNotEmpty;
    final hasMembers = plan.memberBubbles.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141C31).withValues(alpha: .55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() => _expanded = !_expanded);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            experience.accent,
                            Color.lerp(
                                  experience.accent,
                                  const Color(0xFF7C3AED),
                                  0.5,
                                ) ??
                                experience.accent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: experience.accent.withValues(alpha: .45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: PlanCover(
                        asset: experience.coverAsset,
                        accent: experience.accent,
                        radius: 23,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experience.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${plan.experience.date} • ${plan.experience.time}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF9DB2E8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasRequests)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC24D).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFC24D).withValues(alpha: .3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_add_rounded,
                                  size: 12, color: Color(0xFFFFC24D)),
                              const SizedBox(width: 4),
                              Text(
                                '${plan.joinRequests.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFC24D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasMembers)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    for (final member in plan.memberBubbles.take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => widget.onViewProfile(member),
                          borderRadius: BorderRadius.circular(20),
                          child: PortraitAvatar(
                            name: member.name,
                            color: member.color,
                            portrait: member.portrait,
                            size: 32,
                          ),
                        ),
                      ),
                    if (plan.memberBubbles.length > 6)
                      Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .08),
                          border: Border.all(color: Colors.white.withValues(alpha: .12)),
                        ),
                        child: Center(
                          child: Text(
                            '+${plan.memberBubbles.length - 6}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB9C3DC),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (_expanded)
              AnimatedSize(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasRequests) ...[
                        Row(
                          children: [
                            const Text(
                              'Join Requests',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB9C3DC),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC24D).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFC24D).withValues(alpha: .25)),
                              ),
                              child: Text(
                                '${plan.joinRequests.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFC24D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...plan.joinRequests.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _JoinRequestRow(
                            request: r,
                            onViewProfile: () {},
                            onApprove: () => widget.onApprove(r),
                            onDecline: () => widget.onDecline(r),
                          ),
                        )),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No pending join requests.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: .5),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ActionPill(
                        label: 'Open Plan',
                        icon: Icons.open_in_new_rounded,
                        primary: true,
                        onTap: widget.onOpen,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JoinRequestRow extends StatelessWidget {
  const _JoinRequestRow({
    required this.request,
    required this.onViewProfile,
    required this.onApprove,
    required this.onDecline,
  });

  final _JoinRequestUi request;
  final VoidCallback onViewProfile;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onViewProfile,
            borderRadius: BorderRadius.circular(28),
            child: PortraitAvatar(
              name: request.name,
              color: request.color,
              portrait: request.portrait,
              size: 42,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onViewProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested ${notificationTimeLabel(request.requestedAt)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9DB2E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ActionPill(
            label: 'Decline',
            icon: Icons.close_rounded,
            danger: true,
            onTap: onDecline,
          ),
          const SizedBox(width: 8),
          ActionPill(
            label: 'Accept',
            icon: Icons.check_rounded,
            primary: true,
            onTap: onApprove,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            child: const Icon(Icons.wifi_off_rounded,
                size: 27, color: Color(0xFFFF4D8D)),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: .14),
              ),
              child: Icon(icon, size: 27, color: const Color(0xFFB7A5FF)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
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
