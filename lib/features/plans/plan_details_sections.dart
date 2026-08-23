import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'plan_details_data.dart';
import 'plan_details_widgets.dart';
import 'plans_data.dart';
import 'plans_sections.dart';
import 'plans_widgets.dart';


/// Composed premium sections for the Plan Details experience.
///
/// Every section is built from an immutable [Experience] passed in — no global
/// reads. Recommendation content flows through the shared distance-first
/// pipeline (see [similarNearby]); no independent sorting happens here.

/// The cinematic header: large cover (Hero), glass gradient overlay, back +
/// share controls, and the host / mood / visibility / distance summary.
class PlanHeader extends StatelessWidget {
  const PlanHeader({
    required this.experience,
    required this.onBack,
    required this.onShare,
    super.key,
  });

  final Experience experience;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 420,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cinematic cover — stable Hero tag from the immutable id.
          Hero(
            tag: 'plan-cover-${e.id}',
            child: PlanCover(asset: e.coverAsset, accent: e.accent),
          ),
          // Extra depth: a soft bottom gradient over the shared scrim.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x000B1020), Color(0xF20B1020)],
                stops: [0.4, 0.7, 1.0],
              ),
            ),
          ),
          // Top controls.
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleGlassButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                  semanticLabel: 'Back',
                ),
                const Spacer(),
                CircleGlassButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                  semanticLabel: 'Share',
                ),
              ],
            ),
          ),
          // Bottom summary.
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MoodBadge(
                      emoji: e.moodEmoji,
                      mood: e.mood,
                      accent: e.accent,
                    ),
                    const SizedBox(width: 8),
                    VisibilityBadge(isPublic: e.isPublic),
                    const Spacer(),
                    if (e.isEditorsPick)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC24D).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFC24D).withValues(alpha: .5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFFFC24D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Editor\'s Pick',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFD98A),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    PlanPortrait(
                      asset: e.hostPortrait,
                      accent: e.accent,
                      size: 40,
                      label: e.host,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hosted by ${e.host}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: Color(0xFF9DB2E8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${e.city} • ${e.distance}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFB9C3DC),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title + description + the premium glass information grid.
class PlanInfoSection extends StatelessWidget {
  const PlanInfoSection({required this.experience, super.key});
  final Experience experience;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final host = PlanHostDetails.of(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        // Subtle authenticity line derived from existing data.
        Text(
          'Hosted by ${e.host} • Created ${host.createdLabel}',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF9DB2E8)),
        ),
        const SizedBox(height: 14),
        if (e.description.isNotEmpty)
          Text(
            e.description,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Color(0xFFC7D0E6),
            ),
          )
        else
          Text(
            _describe(e),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Color(0xFFC7D0E6),
            ),
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DetailChip(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: e.date,
            ),
            DetailChip(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: e.time,
            ),
            DetailChip(
              icon: Icons.place_rounded,
              label: 'Location',
              value: e.city,
            ),
            DetailChip(
              icon: Icons.near_me_rounded,
              label: 'Distance',
              value: e.distance,
            ),
            DetailChip(
              icon: Icons.event_seat_rounded,
              label: 'Spots left',
              value: '${e.spotsLeft}',
            ),
            DetailChip(
              icon: Icons.groups_rounded,
              label: 'Going',
              value: '${e.goingCount}',
            ),
          ],
        ),
      ],
    );
  }

  /// A believable local description generated from the plan's own fields.
  String _describe(Experience e) {
    final parts = <String>[];

    if (e.host.isNotEmpty && e.title.isNotEmpty) {
      parts.add('Join ${e.host} for ${e.title.toLowerCase()}');
    } else if (e.title.isNotEmpty) {
      parts.add('Join for ${e.title.toLowerCase()}');
    }

    if (e.city.trim().isNotEmpty) {
      parts.add('in ${e.city.trim()}');
    }

    final mood = e.mood.trim().toLowerCase();
    if (mood.isNotEmpty) {
      parts.add('A $mood plan');
    }

    if (e.date != 'Date TBD' && e.time != 'TBD') {
      parts.add('happening ${e.date.toLowerCase()} at ${e.time}');
    } else if (e.date != 'Date TBD') {
      parts.add('happening ${e.date.toLowerCase()}');
    }

    final description = parts.join('. ');
    if (description.isEmpty) return 'A new plan worth showing up for.';
    return '$description. ${e.goingCount} people are going with ${e.spotsLeft} spots still open — come meet nearby people who share your vibe.';
  }
}

/// Premium glass host card with demo credibility signals.
class HostSection extends StatelessWidget {
  const HostSection({
    required this.experience,
    this.onViewProfile,
    super.key,
  });
  final Experience experience;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final host = PlanHostDetails.of(e);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlanPortrait(
                asset: e.hostPortrait,
                accent: e.accent,
                size: 56,
                label: e.host,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (host.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF6C8EF5),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFC24D),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${host.rating}  •  ${host.plansHosted} plans hosted',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB9C3DC),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PanelDivider(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              HostStat(value: '${host.plansHosted}', label: 'Hosted'),
              HostStat(value: '${host.friendsJoined}', label: 'Friends'),
              HostStat(value: '${host.mutualInterests}', label: 'Mutual'),
            ],
          ),
          const SizedBox(height: 16),
          _ViewProfileButton(onPressed: onViewProfile),
        ],
      ),
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: .18)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.person_outline_rounded, size: 18),
        label: const Text(
          'View Profile',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Premium horizontal participant rail — real joined participants only.
///
/// The creator/host is intentionally EXCLUDED here (they are surfaced in the
/// header + host/management card). Participants are the real joined members
/// (status = 'joined', user_id != creator_id) passed in from the screen, with
/// real display names + signed profile photos. Tapping an avatar opens that
/// participant's public profile.
class ParticipantsSection extends StatelessWidget {
  const ParticipantsSection({
    required this.experience,
    this.participants = const [],
    this.onTapParticipant,
    super.key,
  });

  final Experience experience;
  final List<PlanMembership> participants;
  final void Function(PlanMembership)? onTapParticipant;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    const visible = 8;
    final shown = participants.take(visible).toList();
    final extra = participants.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: 'Who\'s going',
          subtitle: '${e.goingCount} going • ${e.spotsLeft} spots left',
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          Text(
            'No one has joined yet.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: .6),
            ),
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: shown.length + (extra > 0 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                if (i < shown.length) {
                  final m = shown[i];
                  final label = m.displayName?.trim().isNotEmpty ?? false
                      ? m.displayName!.trim()
                      : 'User ${m.userId.substring(0, 8)}';
                  return ParticipantAvatar(
                    asset: (m.photoUrl?.trim().isEmpty ?? true) ? '' : m.photoUrl!.trim(),
                    accent: e.accent,
                    label: label,
                    onTap: onTapParticipant == null ? null : () => onTapParticipant!(m),
                  );
                }
                return ParticipantOverflow(count: extra);
              },
            ),
          ),
      ],
    );
  }
}

/// Own-plan management card shown in Plan Details when the viewer is the
/// creator. Deliberately replaces the social discovery-style host card so the
/// owner never sees "Hosted by / View Profile / Friends / Mutual / stats" for
/// their own plan.
class OwnPlanManagementCard extends StatelessWidget {
  const OwnPlanManagementCard({
    required this.experience,
    required this.onEdit,
    required this.onShare,
    required this.onArchive,
    required this.onInvite,
    super.key,
  });

  final Experience experience;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onArchive;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlanPortrait(
                asset: experience.hostPortrait,
                accent: experience.accent,
                size: 44,
                label: 'You',
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You\'re hosting this plan',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage your plan',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF9DB2E8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PanelDivider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ManageAction(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ManageAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ManageAction(
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  onTap: onArchive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _ManageAction(
              icon: Icons.person_add_rounded,
              label: 'Invite People',
              onTap: onInvite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageAction extends StatelessWidget {
  const _ManageAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFFC7D0E6)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC7D0E6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A premium "why join" section built from local, derived reasons.
class WhyJoinSection extends StatelessWidget {
  const WhyJoinSection({required this.experience, super.key});
  final Experience experience;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final reasons = whyJoinReasons(e);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Why join'),
          const SizedBox(height: 8),
          for (final r in reasons) WhyJoinRow(text: r, accent: e.accent),
        ],
      ),
    );
  }
}

/// Similar nearby plans — reuses the SAME discovery rail + cards, fed by the
/// distance-first [similarNearby] output (current plan excluded, capped).
class SimilarNearbySection extends StatelessWidget {
  const SimilarNearbySection({
    required this.experience,
    required this.onOpen,
    super.key,
  });

  final Experience experience;
  final ValueChanged<Experience> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = similarNearby(experience);
    if (items.isEmpty) return const SizedBox.shrink();
    return ExperienceRail(
      title: '📍 Similar Nearby',
      items: items,
      variant: CardVariant.compact,
      height: 300,
      cardWidth: 260,
      onOpen: onOpen,
    );
  }
}

/// Premium glass location placeholder (no Maps dependency).
class LocationSection extends StatelessWidget {
  const LocationSection({required this.experience, super.key});
  final Experience experience;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final hasAddress = e.locationAddress.trim().isNotEmpty;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Location'),
          const SizedBox(height: 14),
          StaticMapPreview(
            city: e.city,
            distance: e.distance,
            accent: e.accent,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_rounded,
                size: 16,
                color: Color(0xFF9DB2E8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.city,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC7D0E6),
                      ),
                    ),
                    if (hasAddress) ...[
                      const SizedBox(height: 2),
                      Text(
                        e.locationAddress.trim(),
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
            ],
          ),
        ],
      ),
    );
  }
}

/// Premium glass safety card. Some actions surface "Coming Soon".
class SafetySection extends StatelessWidget {
  const SafetySection({required this.experience, super.key});
  final Experience experience;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Safety'),
          const SizedBox(height: 6),
          SafetyRow(
            icon: e.isPublic ? Icons.public_rounded : Icons.lock_rounded,
            label: 'Visibility',
            trailingText: e.isPublic ? 'Public' : 'Private',
          ),
          const PanelDivider(),
          const SafetyRow(
            icon: Icons.verified_user_rounded,
            label: 'Community Guidelines',
          ),
          const PanelDivider(),
          const SafetyRow(
            icon: Icons.flag_rounded,
            label: 'Report Plan',
            comingSoon: true,
          ),
          const PanelDivider(),
          const SafetyRow(
            icon: Icons.emergency_share_rounded,
            label: 'Emergency features',
            comingSoon: true,
          ),
        ],
      ),
    );
  }
}

/// Small helper so screen sections can share the entrance reveal.
class RevealSection extends StatelessWidget {
  const RevealSection({required this.child, this.delayMs = 0, super.key});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      delay: Duration(milliseconds: delayMs),
      child: child,
    );
  }
}
