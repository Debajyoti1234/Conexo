import 'package:flutter/material.dart';

import 'plan_details_data.dart';
import 'plan_details_sections.dart';
import 'plan_join_controller.dart';
import 'plans_data.dart';

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
  const PlanDetailsScreen({required this.experience, super.key});

  final Experience experience;

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  late final PlanJoinController _join;

  @override
  void initState() {
    super.initState();
    _join = PlanJoinController();
  }

  @override
  void dispose() {
    _join.dispose();
    super.dispose();
  }

  void _openSimilar(Experience e) {
    // Navigation stays in the Plans screen layer; push a sibling details page
    // with the same premium fade + slide transition.
    Navigator.of(context).push(premiumPlanRoute(e));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.experience;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      // The sticky action bar floats over the scrolling content.
      extendBody: true,
      body: Stack(
        children: [
          // ── Static, build-once content ──────────────────────────────
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
                      RevealSection(
                        delayMs: 60,
                        child: HostSection(experience: e),
                      ),
                      const SizedBox(height: 26),
                      RevealSection(
                        delayMs: 90,
                        child: ParticipantsSection(experience: e),
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
              // Similar rail spans full width (its own internal padding).
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
              // Bottom spacer so content clears the sticky action bar.
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ── Sticky action bar — the ONLY part that rebuilds on status ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: _join,
              builder: (context, _) => _JoinActionBar(
                experience: e,
                controller: _join,
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
  const _JoinActionBar({required this.experience, required this.controller});

  final Experience experience;
  final PlanJoinController controller;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final status = controller.status;

    // Resolve label / colours from the local status + visibility.
    late final String label;
    late final IconData icon;
    late final bool enabled;
    switch (status) {
      case JoinStatus.joined:
        label = 'Joined';
        icon = Icons.check_circle_rounded;
        enabled = false;
      case JoinStatus.requested:
        label = 'Requested';
        icon = Icons.hourglass_top_rounded;
        enabled = false;
      case JoinStatus.notJoined:
      case JoinStatus.cancelled:
        label = e.isPublic ? 'Join Plan' : 'Request to Join';
        icon = e.isPublic ? Icons.bolt_rounded : Icons.lock_open_rounded;
        enabled = true;
    }

    void onPressed() {
      if (e.isPublic) {
        controller.join();
      } else {
        controller.request();
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
          // Going / spots summary on the left.
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
          // Primary action — animates smoothly between states.
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
