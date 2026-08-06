import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';

/// Premium widgets specific to the Phase 4.2 Profile Management flow.
///
/// These reuse the established Conexo dark-glass language and the Phase 4.1
/// reusable primitives. The `ProfilePreviewCard` is intentionally NOT
/// re-implemented here — the management screen imports it from
/// `profile_creation_widgets.dart`.
///
/// Motion is limited to Fade / Scale / Opacity with easeOutCubic /
/// easeInOutCubic — no bounce or elastic.

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);

// ── UnsavedChangesResult ────────────────────────────────────────────────────

/// The user's choice from [UnsavedChangesDialog].
enum UnsavedChangesResult { save, discard, cancel }

// ── UnsavedChangesDialog ────────────────────────────────────────────────────

/// A premium glass confirmation dialog shown when leaving with unsaved changes.
///
/// Offers Save / Discard / Cancel. `saveEnabled` reflects whether the current
/// draft is valid — when false, Save is disabled and only Discard / Cancel
/// remain, so an invalid draft can never be persisted.
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({required this.saveEnabled, super.key});

  final bool saveEnabled;

  /// Shows the dialog with the animated fade + scale transition and returns
  /// the user's [UnsavedChangesResult] (null if dismissed by scrim tap).
  static Future<UnsavedChangesResult?> show(
    BuildContext context, {
    required bool saveEnabled,
  }) {
    return showGeneralDialog<UnsavedChangesResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Unsaved changes',
      barrierColor: Colors.black.withValues(alpha: .55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          UnsavedChangesDialog(saveEnabled: saveEnabled),
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
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kAccent.withValues(alpha: .18),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFB7A5FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Unsaved changes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'You have edits that are not saved yet. What would you '
                  'like to do?',
                  style: TextStyle(fontSize: 14, color: _kSoftText, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop(UnsavedChangesResult.cancel),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop(UnsavedChangesResult.discard),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF08A8A),
                      ),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: saveEnabled
                          ? () => Navigator.of(context)
                              .pop(UnsavedChangesResult.save)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAccent,
                        disabledBackgroundColor:
                            _kAccent.withValues(alpha: .3),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SaveSuccessOverlay ──────────────────────────────────────────────────────

/// A subtle full-screen success animation shown after a successful save.
///
/// Uses AnimatedScale + AnimatedOpacity on a check badge — calm, no bounce.
class SaveSuccessOverlay extends StatefulWidget {
  const SaveSuccessOverlay({super.key});

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
                        colors: [Color(0xFF47D7A5), Color(0xFF22BFE0)],
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
                  const Text(
                    'Changes saved',
                    style: TextStyle(
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

// ── ManagementSectionHeader ─────────────────────────────────────────────────

/// A large section title + optional subtitle for the management screen, with a
/// subtle ✓ that fades in when the section is complete (mirrors the creation
/// SectionShell header without the reveal gating).
class ManagementSectionHeader extends StatelessWidget {
  const ManagementSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.completed = false,
  });

  final String title;
  final String? subtitle;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: completed
                  ? const _HeaderCheck(key: ValueKey('done'))
                  : const SizedBox(key: ValueKey('empty'), width: 22),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: _kSoftText,
            ),
          ),
        ],

      ],
    );
  }
}

class _HeaderCheck extends StatelessWidget {
  const _HeaderCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      width: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF47D7A5), Color(0xFF22BFE0)],
        ),
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
    );
  }
}

// ── SaveChangesButton ───────────────────────────────────────────────────────

/// The primary Save CTA for the management screen. Enabled only when there are
/// valid, unsaved changes. Mirrors the creation button's press feedback.
class SaveChangesButton extends StatefulWidget {
  const SaveChangesButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<SaveChangesButton> createState() => _SaveChangesButtonState();
}

class _SaveChangesButtonState extends State<SaveChangesButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: active ? 1 : 0.5,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kAccent, _kAccent2]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: .5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
