import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import 'profile_data.dart';

/// Reusable premium primitives for the Phase 4.3 Privacy & Verification module.
///
/// Everything reuses the established Conexo dark-glass language (GlassCard,
/// gradients, spacing, typography). These widgets are purely presentational —
/// they hold NO business logic and never touch persistence. Motion is limited
/// to AnimatedContainer / AnimatedSwitcher / AnimatedOpacity / AnimatedScale
/// with easeOutCubic / easeInOutCubic — no bounce or overshoot.

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);
const _kVerified = Color(0xFF47D7A5);
const _kPending = Color(0xFFF0C25A);

// ── SettingSectionHeader ─────────────────────────────────────────────────────

/// A large section title + optional subtitle, matching the profile screens'
/// header rhythm.
class SettingSectionHeader extends StatelessWidget {
  const SettingSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: const Color(0xFFB7A5FF)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 13.5, color: _kSoftText),
          ),
        ],
      ],
    );
  }
}

// ── GlassSettingTile ─────────────────────────────────────────────────────────

/// A tappable (or informational) glass tile with a leading icon, title, and
/// optional subtitle + trailing widget.
class GlassSettingTile extends StatelessWidget {
  const GlassSettingTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = const Color(0xFFB7A5FF),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: .16),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kSoftText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _kSoftText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── GlassToggleTile ──────────────────────────────────────────────────────────

/// A glass tile carrying a [Switch] for a boolean setting.
class GlassToggleTile extends StatelessWidget {
  const GlassToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.iconColor = const Color(0xFFB7A5FF),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GlassSettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: iconColor,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: _kAccent,
      ),
    );
  }
}

// ── PrivacySelectorCard ──────────────────────────────────────────────────────

/// A premium two-option selector for [ProfileVisibility] (Public / Private).
///
/// Purely presentational: emits the chosen value through [onChanged]; it holds
/// no state and performs no persistence.
class PrivacySelectorCard extends StatelessWidget {
  const PrivacySelectorCard({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ProfileVisibility value;
  final ValueChanged<ProfileVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _PrivacyOption(
            key: const ValueKey('public'),
            icon: Icons.public_rounded,
            title: 'Public profile',
            description: 'Your profile can appear in nearby discovery.',
            selected: value == ProfileVisibility.public,
            onTap: () => onChanged(ProfileVisibility.public),
          ),
          const SizedBox(height: 12),
          _PrivacyOption(
            key: const ValueKey('private'),
            icon: Icons.lock_outline_rounded,
            title: 'Private profile',
            description:
                'You are hidden from People Discovery. Plans still work.',
            selected: value == ProfileVisibility.private,
            onTap: () => onChanged(ProfileVisibility.private),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_kAccent, _kAccent2])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: .1),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : const Color(0xFFB7A5FF),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFFEAEEF9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: selected
                          ? Colors.white.withValues(alpha: .9)
                          : _kSoftText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('on'),
                      color: Colors.white,
                    )
                  : const Icon(
                      Icons.radio_button_unchecked_rounded,
                      key: ValueKey('off'),
                      color: _kSoftText,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── VerificationBadge ────────────────────────────────────────────────────────

/// A compact pill reflecting a [VerificationStatus].
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({required this.status, super.key});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      VerificationStatus.verified => (
          _kVerified,
          Icons.verified_rounded,
          'Verified',
        ),
      VerificationStatus.pending => (
          _kPending,
          Icons.hourglass_top_rounded,
          'Pending',
        ),
      VerificationStatus.notVerified => (
          _kSoftText,
          Icons.shield_outlined,
          'Not verified',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── VerificationStatusCard ───────────────────────────────────────────────────

/// A premium card presenting the current [VerificationStatus] with a matching
/// icon, headline, explanation, and the [VerificationBadge].
class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard({required this.status, super.key});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, headline, body) = switch (status) {
      VerificationStatus.verified => (
          _kVerified,
          Icons.verified_rounded,
          'You are verified',
          'Your identity has been confirmed. Your verified badge is visible '
              'to others.',
        ),
      VerificationStatus.pending => (
          _kPending,
          Icons.hourglass_top_rounded,
          'Verification pending',
          'Your verification is being reviewed. This usually takes a little '
              'while.',
        ),
      VerificationStatus.notVerified => (
          _kAccent,
          Icons.shield_outlined,
          'Get verified',
          'Verify your identity to earn a trusted badge and stand out in the '
              'community.',
        ),
    };

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: .9),
                      color.withValues(alpha: .5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .4),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              VerificationBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13.5,
              color: _kSoftText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ComingSoonChip ───────────────────────────────────────────────────────────

/// A small "Coming soon" pill used to mark future-ready features.
class ComingSoonChip extends StatelessWidget {
  const ComingSoonChip({super.key, this.label = 'Coming soon'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _kAccent.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 13, color: Color(0xFFB7A5FF)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB7A5FF),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PrimaryActionButton ──────────────────────────────────────────────────────

/// A gradient primary button with press feedback (mirrors the profile CTAs).
/// Used for "Verify Identity".
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kAccent, _kAccent2]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: .5),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ComingSoonDialog ─────────────────────────────────────────────────────────

/// A premium glass dialog explaining that a feature (selfie verification) will
/// arrive in a future update. No backend / camera / permissions involved.
class ComingSoonDialog extends StatelessWidget {
  const ComingSoonDialog({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  /// Shows the dialog with a fade + scale transition.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: .55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ComingSoonDialog(title: title, message: message),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _kAccent.withValues(alpha: .9),
                            _kAccent2.withValues(alpha: .7),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const ComingSoonChip(),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kSoftText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(backgroundColor: _kAccent),
                    child: const Text('Got it'),
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

// ── SaveSuccessOverlay ───────────────────────────────────────────────────────

/// A subtle full-screen success animation shown after a successful save.
///
/// Uses AnimatedScale + AnimatedOpacity on a check badge — calm, no bounce.
class SaveSuccessOverlay extends StatefulWidget {
  const SaveSuccessOverlay({super.key, this.message = 'Changes saved'});

  final String message;

  @override
  State<SaveSuccessOverlay> createState() => _SaveSuccessOverlayState();
}

class _SaveSuccessOverlayState extends State<SaveSuccessOverlay> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1F).withValues(alpha: .92),
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            opacity: _in ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              scale: _in ? 1 : 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kVerified, Color(0xFF22BFE0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x8847D7A5),
                          blurRadius: 36,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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

// ── InfoNote ─────────────────────────────────────────────────────────────────

/// A soft informational note block (icon + body) used for explanations that
/// are purely informational (e.g. discovery visibility behavior).
class InfoNote extends StatelessWidget {
  const InfoNote({
    required this.icon,
    required this.text,
    super.key,
    this.iconColor = const Color(0xFFB7A5FF),
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: _kSoftText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BenefitRow ───────────────────────────────────────────────────────────────

/// A single benefit line (check icon + label) used inside the benefits list.
class BenefitRow extends StatelessWidget {
  const BenefitRow({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_kVerified, Color(0xFF22BFE0)],
              ),
            ),
            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFEAEEF9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
