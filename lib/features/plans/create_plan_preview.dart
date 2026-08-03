import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'create_plan_data.dart';
import 'plans_cards.dart';

/// The live Plan Preview — Section 10 of the Create Plan flow.
///
/// Renders the exact Phase 3.1 [ExperienceCard] (immersive variant) built
/// from the current [PlanDraft] via [draftToPlan]. Updates live as the user
/// edits any field. One source of truth — no second preview design.
///
/// The card behaves identically to a real published plan:
///  • identical spacing, shadows, glass, elevation
///  • built-in AnimatedScale press feedback from ExperienceCard
///  • onTap is null → no navigation occurs
class LivePlanPreview extends StatelessWidget {
  const LivePlanPreview({required this.draft, super.key});
  final PlanDraft draft;

  @override
  Widget build(BuildContext context) {
    final experience = draftToPlan(draft);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Plan Preview',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _LiveBadge(),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This is exactly how your plan will appear to nearby people.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFFB9C3DC)),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: ExperienceCard(
              key: ValueKey(experience.coverAsset + experience.title),
              experience: experience,
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle "LIVE" badge shown beside the preview title.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF47D7A5).withValues(alpha: .18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF47D7A5).withValues(alpha: .5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: Color(0xFF47D7A5)),
            SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7BE8C2),
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the preview in an [EntranceFade] for the first reveal.
class PlanPreviewSection extends StatelessWidget {
  const PlanPreviewSection({required this.draft, super.key});
  final PlanDraft draft;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      delay: const Duration(milliseconds: 80),
      child: LivePlanPreview(draft: draft),
    );
  }
}
