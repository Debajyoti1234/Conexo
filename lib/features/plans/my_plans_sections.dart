import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'create_plan_data.dart';
import 'my_plans_data.dart';
import 'my_plans_widgets.dart';
import 'plans_cards.dart';
import 'plans_data.dart';

/// Composed sections for the My Plans management experience.
///
/// Each section consumes already-processed lists (filtered + sorted upstream
/// by the screen using the shared [applyPipeline]) and renders them with the
/// reusable [ExperienceCard] plus the light-weight My Plans primitives. No
/// section filters or sorts independently — the screen is the single source
/// of truth, mirroring the Plans discovery architecture.

/// The horizontal insights row shown above the tabs.
class InsightsRow extends StatelessWidget {
  const InsightsRow({required this.insights, super.key});

  final MyPlansInsights insights;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // The insight cards' internal Column (icon + value + label + padding)
      // measures ~139px; 132 clipped it by 7px. This is the real parent
      // constraint — typography, spacing, and glass styling are unchanged.
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          InsightCard(

            value: '${insights.plansHosted}',
            label: 'Plans hosted',
            icon: Icons.campaign_rounded,
            accent: const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 12),
          InsightCard(
            value: '${insights.plansJoined}',
            label: 'Plans joined',
            icon: Icons.event_available_rounded,
            accent: const Color(0xFF22BFE0),
          ),
          const SizedBox(width: 12),
          InsightCard(
            value: '${insights.totalParticipants}',
            label: 'Participants',
            icon: Icons.groups_rounded,
            accent: const Color(0xFF47D7A5),
          ),
          const SizedBox(width: 12),
          InsightCard(
            value: '${insights.newConnections}',
            label: 'New connections',
            icon: Icons.favorite_rounded,
            accent: const Color(0xFFE36D9D),
          ),
        ],
      ),
    );
  }
}

/// A hosted plan: the reusable [ExperienceCard] plus an owner action bar
/// (Edit / Share / Archive). Navigation + actions are provided by the screen.
class HostingList extends StatelessWidget {
  const HostingList({
    required this.items,
    required this.onOpen,
    required this.onEdit,
    required this.onShare,
    required this.onArchive,
    super.key,
  });

  final List<Experience> items;
  final ValueChanged<Experience> onOpen;
  final ValueChanged<Experience> onEdit;
  final ValueChanged<Experience> onShare;
  final ValueChanged<Experience> onArchive;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const MyPlansEmptyState(
        icon: Icons.campaign_rounded,
        title: 'No plans hosted yet',
        message: 'Create your first plan and it will appear here to manage.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        StatusBadge(
                          label: statusLabelFor(items[i]),
                          color: statusColorFor(items[i]),
                        ),
                      ],
                    ),
                  ),
                  ExperienceCard(
                    experience: items[i],
                    variant: CardVariant.immersive,
                    onTap: () => onOpen(items[i]),
                  ),
                  const SizedBox(height: 12),
                  PlanActionBar(
                    onEdit: () => onEdit(items[i]),
                    onShare: () => onShare(items[i]),
                    trailingLabel: 'Archive',
                    trailingIcon: Icons.inventory_2_rounded,
                    onTrailing: () => onArchive(items[i]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A joined plan: the reusable [ExperienceCard] plus a light Share + Leave
/// action bar. Navigation + actions are provided by the screen.
class JoinedList extends StatelessWidget {
  const JoinedList({
    required this.items,
    required this.onOpen,
    required this.onShare,
    required this.onLeave,
    super.key,
  });

  final List<Experience> items;
  final ValueChanged<Experience> onOpen;
  final ValueChanged<Experience> onShare;
  final ValueChanged<Experience> onLeave;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const MyPlansEmptyState(
        icon: Icons.event_available_rounded,
        title: 'No joined plans yet',
        message: 'Plans you join from discovery will show up here.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExperienceCard(
                    experience: items[i],
                    variant: CardVariant.stacked,
                    onTap: () => onOpen(items[i]),
                  ),
                  const SizedBox(height: 12),
                  PlanActionBar(
                    onEdit: () => onOpen(items[i]),
                    onShare: () => onShare(items[i]),
                    trailingLabel: 'Leave',
                    trailingIcon: Icons.logout_rounded,
                    onTrailing: () => onLeave(items[i]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A requested (pending) plan: the reusable [ExperienceCard] with a "Request
/// Pending" status badge. The viewer has requested to join but is awaiting the
/// creator's decision. Tapping opens the plan (which shows "Request Pending").
/// No Edit/Leave actions — the request is not yet an accepted membership.
class RequestedList extends StatelessWidget {
  const RequestedList({
    required this.items,
    required this.onOpen,
    super.key,
  });

  final List<Experience> items;
  final ValueChanged<Experience> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const MyPlansEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: 'No pending requests',
        message: 'Plans you request to join from discovery will wait here '
            'until the host approves.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        StatusBadge(
                          label: 'Request Pending',
                          color: Color(0xFFF0B65A),
                        ),
                      ],
                    ),
                  ),
                  ExperienceCard(
                    experience: items[i],
                    variant: CardVariant.stacked,
                    onTap: () => onOpen(items[i]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Archived plans: dimmed compact cards with Restore and Delete actions.
class ArchivedList extends StatelessWidget {
  const ArchivedList({
    required this.items,
    required this.onOpen,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final List<Experience> items;
  final ValueChanged<Experience> onOpen;
  final ValueChanged<Experience> onRestore;
  final ValueChanged<Experience> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const MyPlansEmptyState(
        icon: Icons.inventory_2_rounded,
        title: 'Nothing archived',
        message: 'Archived plans are tucked away here so your list stays tidy.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 60 * i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: .72,
                    child: ExperienceCard(
                      experience: items[i],
                      variant: CardVariant.compact,
                      onTap: () => onOpen(items[i]),
                    ),
                  ),
                   const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PlanActionBar(
                            onEdit: null,
                            onShare: null,
                            trailingLabel: 'Restore',
                            trailingIcon: Icons.unarchive_rounded,
                            onTrailing: () => onRestore(items[i]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PlanActionBar(
                            onEdit: null,
                            onShare: null,
                            trailingLabel: 'Delete',
                            trailingIcon: Icons.delete_outline_rounded,
                            onTrailing: () => onDelete(items[i]),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The saved-draft section. A single locally-persisted [PlanDraft] is shown
/// with resume / delete. Empty state when there is nothing in progress.
class DraftsList extends StatefulWidget {
  const DraftsList({
    required this.draft,
    required this.onResume,
    required this.onDelete,
    this.resolveCoverUrl,
    super.key,
  });

  final PlanDraft? draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final Future<String?> Function(String? coverAsset)? resolveCoverUrl;

  @override
  State<DraftsList> createState() => _DraftsListState();
}

class _DraftsListState extends State<DraftsList> {
  String? _coverPreviewUrl;

  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(covariant DraftsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft?.coverAsset != widget.draft?.coverAsset) {
      _resolveCover();
    }
  }

  void _resolveCover() {
    final asset = widget.draft?.coverAsset;
    if (asset == null || asset.isEmpty) {
      setState(() => _coverPreviewUrl = null);
      return;
    }
    if (asset.startsWith('assets/') ||
        asset.startsWith('http://') ||
        asset.startsWith('https://')) {
      setState(() => _coverPreviewUrl = null);
      return;
    }
    final resolver = widget.resolveCoverUrl;
    if (resolver == null) {
      setState(() => _coverPreviewUrl = null);
      return;
    }
    resolver(asset).then((url) {
      if (mounted) setState(() => _coverPreviewUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    if (d == null || (!d.hasCover && !d.hasTitle)) {
      return const MyPlansEmptyState(
        icon: Icons.drafts_rounded,
        title: 'No drafts saved',
        message: 'Start a plan and leave it — your progress waits for you here.',
      );
    }

    final subtitleParts = <String>[
      if (d.hasMood) d.effectiveMood,
      if (d.hasLocation) d.location.trim(),
    ];
    final subtitle =
        subtitleParts.isEmpty ? 'In progress' : subtitleParts.join(' • ');

    return EntranceFade(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: DraftCard(
          title: d.hasTitle ? d.title.trim() : 'Untitled plan',
          coverAsset: d.coverAsset,
          coverPreviewUrl: _coverPreviewUrl,
          subtitle: subtitle,
          onResume: widget.onResume,
          onDelete: widget.onDelete,
        ),
      ),
    );
  }
}

// ── Status helpers (pure, derived from the Experience) ──────────────────

/// A pure status label derived from an [Experience]'s date heuristics.
String statusLabelFor(Experience e) {
  final d = e.date.toLowerCase();
  if (d.contains('today') || d.contains('tonight')) return 'Active';
  if (d.contains('yesterday') || d.contains('last')) return 'Past';
  return 'Upcoming';
}

/// The accent colour paired with [statusLabelFor].
Color statusColorFor(Experience e) {
  switch (statusLabelFor(e)) {
    case 'Active':
      return const Color(0xFF47D7A5);
    case 'Past':
      return const Color(0xFF9DB2E8);
    default:
      return const Color(0xFF8B5CF6);
  }
}
