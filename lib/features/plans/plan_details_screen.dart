import 'dart:io';

import 'package:flutter/material.dart';

import 'create_plan_screen.dart';
import 'invite_people_screen.dart';
import 'plan_details_data.dart';
import 'plan_details_sections.dart';
import 'plan_join_controller.dart';
import 'plan_repository.dart';
import 'plans_data.dart';
import 'supabase_plan_repository.dart';

import '../../core/supabase/auth_service.dart';
import '../chat/chat_models.dart';
import '../chat/chat_repository.dart';
import '../chat/conversation_screen.dart';
import '../profile/profile_navigation_mapper.dart';
import '../profile/public_profile_screen.dart';
import '../profile/supabase_profile_repository.dart';

/// The premium, cinematic Plan Details experience.
///
/// Deep-link ready: the plan is provided ONLY through the constructor — no
/// global reads — so future deep links / notifications / backend navigation
/// can push this screen directly. The [Experience] is treated as immutable;
/// all interaction state lives in [PlanJoinController].
///
/// Performance: the header, images, and content build once. Only the sticky
/// bottom action bar rebuilds when [JoinStatus] changes, via a scoped
/// [ListenableBuilder] on the controller.
class PlanDetailsScreen extends StatefulWidget {
  const PlanDetailsScreen({
    required this.experience,
    this.repository = const SupabasePlanRepository(),
    super.key,
  });

  final Experience experience;
  final PlanRepository repository;

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  late final PlanJoinController _join;
  late Experience _experience;
  late final bool _isHost;
  List<PlanMembership> _participants = const [];

  @override
  void initState() {
    super.initState();
    _experience = widget.experience;
    _isHost = widget.experience.hostId == AuthService.currentUser?.id;
    _join = PlanJoinController(
      repository: widget.repository,
      initial: _isHost ? JoinStatus.hosting : JoinStatus.notJoined,
    );

    final asset = _experience.coverAsset;
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      // ignore: use_build_context_synchronously
      precacheImage(NetworkImage(asset), context);
    } else if (asset.startsWith('assets/')) {
    } else if (asset.startsWith('plans/')) {
    } else if (asset.isNotEmpty) {
      // ignore: use_build_context_synchronously
      precacheImage(FileImage(File(asset)), context);
    }

    if (!_isHost) {
      _join.loadMembership(widget.experience.id);
    }
    _refreshCounts();
    _loadParticipants();
  }

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    try {
      final counts = await widget.repository.getJoinedCounts([widget.experience.id]);
      final joinedCount = counts[widget.experience.id] ?? 1;
      final capacity = _experience.capacity;
      if (!mounted) return;
      setState(() {
        _experience = widget.experience.copyWith(
          goingCount: joinedCount,
          spotsLeft: (capacity - joinedCount).clamp(0, 1000),
        );
      });
    } catch (_) {
      // Keep existing counts on error.
    }
  }

  /// Loads the real joined participants for the "Who's going" rail. The creator
  /// is EXCLUDED (status = 'joined' AND user_id != plans.creator_id) so the host
  /// never appears as a joined participant; the host is surfaced separately in
  /// the header/host card.
  Future<void> _loadParticipants() async {
    try {
      final members = await widget.repository.getPlanMembers(widget.experience.id);
      final joined = members
          .where((m) =>
              m.status == 'joined' &&
              m.role != 'creator' &&
              m.userId != widget.experience.hostId)
          .toList();
      if (!mounted) return;
      setState(() => _participants = joined);
    } catch (_) {
      // Keep existing participants on error.
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  void _openSimilar(Experience e) {
    Navigator.of(context).push(premiumPlanRoute(e));
  }

  /// Opens the canonical Public Profile for a joined participant.
  void _viewParticipant(PlanMembership m) {
    () async {
      final repo = const SupabaseProfileRepository();
      final profile = await repo.loadProfileByUserId(m.userId);
      if (!mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile not available'),
            backgroundColor: Color(0xFFFF4D8D),
          ),
        );
        return;
      }
      final data = mapUserProfileToPublicProfile(profile);
      if (!mounted) return;
      Navigator.of(context).push(premiumPublicProfileRoute(data: data));
    }();
  }

  void _viewHostProfile() {
    final e = widget.experience;
    () async {
      final repo = const SupabaseProfileRepository();
      final profile = await repo.loadProfileByUserId(e.hostId);
      if (!mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile not available'),
            backgroundColor: Color(0xFFFF4D8D),
          ),
        );
        return;
      }
      final data = mapUserProfileToPublicProfile(profile);
      if (!mounted) return;
      Navigator.of(context).push(premiumPublicProfileRoute(data: data));
    }();
  }

  /// Own-plan Edit: reuses CreatePlanScreen(existingPlan:) — never inserts a new
  /// plan, preserves plans.id / creator_id / created_at.
  Future<void> _editPlan() async {
    try {
      final plan = await widget.repository.getPublishedPlan(widget.experience.id);
      if (!mounted) return;
      if (plan == null) {
        _showError('Could not load this plan for editing.');
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => CreatePlanScreen(existingPlan: plan)),
      );
      await _refreshCounts();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  /// P1.2B.9: opens the Plan's single group conversation, creating it lazily.
  /// Only reachable for the creator or a joined participant; the server RPC
  /// rejects anyone else, and we surface a clear error instead of failing
  /// silently. Never shows a "coming soon" placeholder.
  Future<void> _openGroupChat() async {
    const chatRepository = ChatRepository();
    final result =
        await chatRepository.getOrCreatePlanConversation(_experience.id);
    if (!mounted) return;
    if (result.isFailure || result.value == null) {
      _showError(result.error ?? 'Could not open the group chat.');
      return;
    }

    final preview = ConversationPreview(
      id: result.value!,
      name: _experience.title,
      avatarAsset: '',
      lastMessage: '',
      timestamp: '',
      type: ConversationType.group,
      status: ConversationStatus.offline,
      lastMessageType: LastMessageType.plan,
      planId: _experience.id,
    );

    await Navigator.of(context).push(
      conversationRoute(preview, chatRepository: chatRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _experience;
    final isHost = _isHost;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      extendBody: true,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PlanHeader(
                  experience: e,
                  onBack: () => Navigator.of(context).maybePop(),
                  onShare: () => _comingSoon(context, 'Sharing coming soon'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RevealSection(child: PlanInfoSection(experience: e)),
                      const SizedBox(height: 26),
                      // Own plan → management card (Edit/Share/Archive).
                      // Other user's plan → social host glass card.
                      RevealSection(
                        delayMs: 60,
                      child: isHost
                          ? OwnPlanManagementCard(
                              experience: e,
                              onEdit: _editPlan,
                              onShare: () =>
                                  _comingSoon(context, 'Sharing coming soon'),
                              onArchive: () => _comingSoon(
                                  context, 'Manage archive from My Plans'),
                              onInvite: () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => InvitePeopleScreen(
                                      planId: e.id,
                                      planTitle: e.title,
                                      repository: widget.repository,
                                    ),
                                  ),
                                );
                                if (result == true && mounted) {
                                  setState(() {});
                                }
                              },
                            )
                          : HostSection(
                              experience: e,
                              onViewProfile: _viewHostProfile,
                            ),
                      ),
                      const SizedBox(height: 26),
                      RevealSection(
                        delayMs: 90,
                        child: ParticipantsSection(
                          experience: e,
                          participants: _participants,
                          onTapParticipant: _viewParticipant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      RevealSection(
                        delayMs: 120,
                        child: WhyJoinSection(experience: e),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RevealSection(
                  delayMs: 150,
                  child: SimilarNearbySection(
                    experience: e,
                    onOpen: _openSimilar,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RevealSection(
                        delayMs: 180,
                        child: LocationSection(experience: e),
                      ),
                      const SizedBox(height: 26),
                      RevealSection(
                        delayMs: 210,
                        child: SafetySection(experience: e),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: const SizedBox(height: 120),
              ),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _join,
              builder: (context, _) => _JoinActionBar(
                experience: e,
                controller: _join,
                isHost: isHost,
                onError: _showError,
                onOpenGroupChat: _openGroupChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bottom glass action bar. Rebuilds in isolation when the join
/// status changes. Public → "Join Plan"; Private → "Request to Join".
class _JoinActionBar extends StatelessWidget {
  const _JoinActionBar({
    required this.experience,
    required this.controller,
    required this.isHost,
    required this.onOpenGroupChat,
    this.onError,
  });

  final Experience experience;
  final PlanJoinController controller;
  final bool isHost;
  final Future<void> Function() onOpenGroupChat;
  final void Function(String message)? onError;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final status = controller.status;

    if (status == JoinStatus.hosting || isHost) {
      return _HostingBar(experience: e, onOpenGroupChat: onOpenGroupChat);
    }

    // Invited users have an explicit pending invitation. Accepting IS the
    // authorization to join — never a second discovery join request.
    if (status == JoinStatus.invited) {
      return _InvitedBar(
        controller: controller,
        planId: e.id,
        onError: onError,
      );
    }

    String label;
    IconData icon;
    bool enabled;
    if (controller.isLoading) {
      label = e.isPublic ? 'Joining...' : 'Requesting...';
      icon = e.isPublic ? Icons.bolt_rounded : Icons.lock_open_rounded;
      enabled = false;
    } else {
      switch (status) {
        case JoinStatus.joined:
          label = 'Joined';
          icon = Icons.check_circle_rounded;
          enabled = false;
        case JoinStatus.requested:
          label = 'Pending Confirmation';
          icon = Icons.hourglass_top_rounded;
          enabled = true;
          break;
        case JoinStatus.notJoined:
        case JoinStatus.cancelled:
          label = e.isPublic ? 'Join Plan' : 'Request to Join';
          icon = e.isPublic ? Icons.bolt_rounded : Icons.lock_open_rounded;
          enabled = true;
        case JoinStatus.invited:
          // Handled by the early return above.
          label = 'Accept Invitation';
          icon = Icons.mail_rounded;
          enabled = true;
        case JoinStatus.hosting:
          label = "You're Hosting";
          icon = Icons.star_rounded;
          enabled = false;
      }
    }

    Future<void> handleRequestedTap() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF182039),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Cancel join request?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEAEEF9),
            ),
          ),
          content: const Text(
            'Your request to join this Plan is still pending. '
            'Do you want to cancel it?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB9C3DC),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Keep Request',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9DB2E8),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D8D),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Cancel Request',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        await controller.cancelJoinRequest(e.id);
      } on AuthFailure catch (err) {
        onError?.call(err.message);
      }
    }

    Future<void> onPressed() async {
      try {
        if (status == JoinStatus.requested) {
          await handleRequestedTap();
          return;
        }
        await controller.joinOrRequest(e.id);
      } on AuthFailure catch (err) {
        onError?.call(err.message);
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withValues(alpha: .92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${e.spotsLeft} spots left',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '${e.goingCount} going',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF9DB2E8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          if (status == JoinStatus.joined) ...[
            _GroupChatButton(onTap: onOpenGroupChat),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _PrimaryJoinButton(
              label: label,
              icon: icon,
              accent: e.accent,
              enabled: enabled,
              onPressed: enabled ? onPressed : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bottom bar for a user who has a pending Plan Invitation. Accepting
/// the invitation is the authorization to join — it calls the invitation accept
/// path directly and never sends a discovery join request.
class _InvitedBar extends StatelessWidget {
  const _InvitedBar({
    required this.controller,
    required this.planId,
    this.onError,
  });

  final PlanJoinController controller;
  final String planId;
  final void Function(String message)? onError;

  @override
  Widget build(BuildContext context) {
    final loading = controller.isLoading;

    Future<void> onAccept() async {
      try {
        await controller.acceptInvitation(planId);
      } on AuthFailure catch (err) {
        onError?.call(err.message);
      }
    }

    Future<void> onDecline() async {
      try {
        await controller.declineInvitation(planId);
      } on AuthFailure catch (err) {
        onError?.call(err.message);
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withValues(alpha: .92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You are invited',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: loading ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4D8D),
                      side: const BorderSide(color: Color(0xFFFF4D8D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF47D7A5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Accept Invitation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact secondary "Group Chat" action for the sticky bottom bar. It never
/// replaces the primary Join/Request/Hosting action — it sits beside it and is
/// only shown to the creator or a joined participant.
class _GroupChatButton extends StatelessWidget {
  const _GroupChatButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        height: 54,
        width: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: const Icon(
          Icons.forum_rounded,
          size: 22,
          color: Color(0xFFB7A5FF),
        ),
      ),
    );
  }
}

class _HostingBar extends StatelessWidget {
  const _HostingBar({required this.experience, required this.onOpenGroupChat});

  final Experience experience;
  final Future<void> Function() onOpenGroupChat;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020).withValues(alpha: .92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${e.spotsLeft} spots left',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '${e.goingCount} going',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF9DB2E8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _GroupChatButton(onTap: onOpenGroupChat),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.star_rounded,
                    size: 19,
                    color: Color(0xFFFFC24D),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "You're Hosting",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9DB2E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gradient primary button with animated state feedback (no bounce).
class _PrimaryJoinButton extends StatefulWidget {
  const _PrimaryJoinButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  State<_PrimaryJoinButton> createState() => _PrimaryJoinButtonState();
}

class _PrimaryJoinButtonState extends State<_PrimaryJoinButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      widget.accent,
                      Color.lerp(widget.accent, const Color(0xFF587BE2), .6) ??
                          widget.accent,
                    ],
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
            border: enabled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: .5),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Row(
              key: ValueKey(widget.label),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 19,
                  color: enabled ? Colors.white : const Color(0xFF9DB2E8),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: enabled ? Colors.white : const Color(0xFF9DB2E8),
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

void _comingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
}

/// A premium fade + slide route into [PlanDetailsScreen].
///
/// Navigation lives in the Plans layer (this helper is called from the Plans
/// screen and from the Similar Nearby rail), keeping reusable cards free of
/// navigation logic. The shared cover [Hero] handles the cover expansion.
Route<void> premiumPlanRoute(Experience experience) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PlanDetailsScreen(experience: experience),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
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
