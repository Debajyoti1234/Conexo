import 'package:flutter/material.dart';

import 'privacy_verification_widgets.dart';
import 'profile_data.dart';

/// Section widgets for the Phase 4.3 Privacy & Verification module.
///
/// Every section is a thin, presentational widget. Only [PrivacySection] emits
/// a change (the editable [ProfileVisibility]); everything else is purely
/// informational. NO business logic, persistence, or navigation lives here —
/// those belong to the screen / repository layers.

// ── Shared informational copy ────────────────────────────────────────────────

/// Explanation shown for Private mode (exact product copy).
const kPrivateModeExplanation =
    'When Private Mode is enabled, your profile will not appear in People '
    'Discovery.\nYou can still host and join Plans.\nYour hosted public plans '
    'remain discoverable.';

/// Explanation shown for Public mode (exact product copy).
const kPublicModeExplanation = 'Your profile can appear in nearby discovery.';

// ── PrivacySection ────────────────────────────────────────────────────────────

/// The only editable section: choose [ProfileVisibility] and read the
/// contextual explanation for the current choice.
class PrivacySection extends StatelessWidget {
  const PrivacySection({
    required this.visibility,
    required this.onVisibilityChanged,
    super.key,
  });

  final ProfileVisibility visibility;
  final ValueChanged<ProfileVisibility> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final isPrivate = visibility == ProfileVisibility.private;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingSectionHeader(
          title: 'Privacy',
          subtitle: 'Control whether you appear in People Discovery.',
          icon: Icons.privacy_tip_outlined,
        ),
        const SizedBox(height: 14),
        PrivacySelectorCard(
          value: visibility,
          onChanged: onVisibilityChanged,
        ),
        const SizedBox(height: 12),
        // Contextual explanation swaps smoothly with the current selection.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              child: child,
            ),

          ),
          child: InfoNote(
            key: ValueKey(isPrivate),
            icon: isPrivate
                ? Icons.lock_outline_rounded
                : Icons.travel_explore_rounded,
            text: isPrivate ? kPrivateModeExplanation : kPublicModeExplanation,
          ),
        ),
      ],
    );
  }
}

// ── VerificationSection ───────────────────────────────────────────────────────

/// Informational verification section: current status, benefits, information,
/// and the "Verify Identity" action (which only opens a coming-soon dialog).
class VerificationSection extends StatelessWidget {
  const VerificationSection({
    required this.status,
    required this.onVerifyIdentity,
    this.verifying = false,
    super.key,
  });

  final VerificationStatus status;
  final VoidCallback onVerifyIdentity;
  final bool verifying;

  @override
  Widget build(BuildContext context) {
    final showVerifyAction = status == VerificationStatus.notVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingSectionHeader(
          title: 'Verification',
          subtitle: 'Build trust with a verified identity.',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 14),

        // Current status.
        VerificationStatusCard(status: status),
        const SizedBox(height: 14),

        // Benefits.
        const _BenefitsCard(),

        if (showVerifyAction) ...[
          const SizedBox(height: 14),
          AbsorbPointer(
            absorbing: verifying,
            child: PrimaryActionButton(
              label: verifying ? 'Verifying...' : 'Verify Identity',
              icon: verifying ? Icons.hourglass_top_rounded : Icons.verified_rounded,
              onTap: onVerifyIdentity,
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Verification information.
        const InfoNote(
          icon: Icons.info_outline_rounded,
          text: 'Selfie verification is a future feature. When available, '
              'you will take a quick selfie that is matched against your '
              'photos. No verification data is collected in this version.',
        ),
      ],
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCardBenefits(
      benefits: [
        'A trusted verified badge on your profile',
        'Higher trust with people you meet',
        'Priority placement in nearby discovery',
        'Access to verified-only communities in the future',
      ],
    );
  }
}

/// A titled glass card listing verification benefits via [BenefitRow]s.
class GlassCardBenefits extends StatelessWidget {
  const GlassCardBenefits({required this.benefits, super.key});

  final List<String> benefits;

  @override
  Widget build(BuildContext context) {
    return _SectionGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  size: 20, color: Color(0xFFB7A5FF)),
              SizedBox(width: 8),
              Text(
                'Benefits of verification',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < benefits.length; i++)
            BenefitRow(key: ValueKey('benefit_$i'), text: benefits[i]),
        ],
      ),
    );
  }
}

// ── DiscoverySection ──────────────────────────────────────────────────────────

/// Explains how visibility affects discovery. Purely informational; it does NOT
/// alter Discovery filtering anywhere in the app.
class DiscoverySection extends StatelessWidget {
  const DiscoverySection({required this.visibility, super.key});

  final ProfileVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility == ProfileVisibility.public;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingSectionHeader(
          title: 'Discovery',
          subtitle: 'How your visibility affects People Discovery.',
          icon: Icons.explore_outlined,
        ),
        const SizedBox(height: 14),
        GlassSettingTile(
          icon: isPublic ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          iconColor:
              isPublic ? const Color(0xFF47D7A5) : const Color(0xFFB9C3DC),
          title: isPublic
              ? 'You are discoverable'
              : 'You are hidden from discovery',
          subtitle: isPublic
              ? 'People nearby can find and view your profile.'
              : 'People cannot find you in People Discovery.',
        ),
        const SizedBox(height: 12),
        const InfoNote(
          icon: Icons.groups_2_outlined,
          text: 'Plans are separate from profile discovery. You can always '
              'host and join Plans, and your hosted public plans remain '
              'discoverable regardless of this setting.',
        ),
      ],
    );
  }
}

// ── SafetySection ─────────────────────────────────────────────────────────────

/// Informational safety section: report, block, and safety tips. These are
/// presentational entries only; wiring to real flows is out of scope here.
class SafetySection extends StatelessWidget {
  const SafetySection({
    super.key,
    this.onReport,
    this.onBlock,
    this.onSafetyTips,
  });

  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onSafetyTips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingSectionHeader(
          title: 'Safety',
          subtitle: 'Tools to help you stay safe.',
          icon: Icons.health_and_safety_outlined,
        ),
        const SizedBox(height: 14),
        GlassSettingTile(
          key: const ValueKey('safety_report'),
          icon: Icons.flag_outlined,
          iconColor: const Color(0xFFF0A85A),
          title: 'Report a problem',
          subtitle: 'Tell us about inappropriate behavior or content.',
          trailing: const ComingSoonChip(),
          onTap: onReport,
        ),
        const SizedBox(height: 12),
        GlassSettingTile(
          key: const ValueKey('safety_block'),
          icon: Icons.block_rounded,
          iconColor: const Color(0xFFF08A8A),
          title: 'Block someone',
          subtitle: 'Blocked people can no longer reach you.',
          trailing: const ComingSoonChip(),
          onTap: onBlock,
        ),
        const SizedBox(height: 12),
        GlassSettingTile(
          key: const ValueKey('safety_tips'),
          icon: Icons.lightbulb_outline_rounded,
          iconColor: const Color(0xFF47D7A5),
          title: 'Safety tips',
          subtitle: 'Best practices for meeting new people safely.',
          onTap: onSafetyTips,
        ),
      ],
    );
  }
}

// ── Local glass wrapper ───────────────────────────────────────────────────────

/// A minimal glass container matching the Conexo card language, used where a
/// custom padded card is needed inside a section.
class _SectionGlass extends StatelessWidget {
  const _SectionGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF182039).withValues(alpha: .78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: child,
    );
  }
}
