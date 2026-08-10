import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../../core/services/location_service.dart';
import '../../core/services/permission_manager.dart';
import '../home_discovery_animations.dart';
import 'profile_data.dart';

/// Reusable premium primitives for the Profile Creation flow.
///
/// Everything reuses the established Conexo dark-glass language (GlassCard,
/// EntranceFade, existing gradients / spacing / typography). Motion is limited
/// to AnimatedContainer / AnimatedSwitcher / AnimatedSize / AnimatedScale /
/// Fade / Slide with easeOutCubic / easeInOutCubic — no bounce or overshoot.

const _kAccent = Color(0xFF8B5CF6);
const _kAccent2 = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);
const _kFieldFill = Color(0x14FFFFFF);

// ── ProfilePhotoViewer ───────────────────────────────────────────────────────

/// Renders a profile photo from either a bundled asset or a local file path.
///
/// Asset paths are displayed with [Image.asset]; all other paths are treated
/// as local file paths and displayed with [Image.file].
class ProfilePhotoViewer extends StatelessWidget {
  const ProfilePhotoViewer({
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
    );
  }
}

// ── SectionShell ────────────────────────────────────────────────────────────

/// Wraps each input section with a large title, optional subtitle, and a
/// subtle ✓ that fades in the moment the section is complete.
class SectionShell extends StatelessWidget {
  const SectionShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.completed = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      child: Column(
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
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: completed
                    ? const _CompletionCheck(key: ValueKey('done'))
                    : const SizedBox(key: ValueKey('empty'), width: 22),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CompletionCheck extends StatelessWidget {
  const _CompletionCheck({super.key});

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

// ── PhotoGrid ───────────────────────────────────────────────────────────────

/// A slot-based photo picker with exactly [kMaxProfilePhotos] premium glass
/// cards. Empty slots show a "+" icon; filled slots show the selected photo.
///
/// Tapping an empty slot triggers [onAddPhoto]. Tapping the remove button on a
/// filled slot triggers [onRemove] with that photo's index. When [onReorder]
/// is provided, up/down arrows are shown for reordering.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.selected,
    required this.onAddPhoto,
    required this.onRemove,
    this.onReorder,
    super.key,
  });

  final List<ProfilePhoto> selected;

  final VoidCallback onAddPhoto;

  final ValueChanged<int> onRemove;

  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    for (var i = 0; i < kMaxProfilePhotos; i++) {
      if (i < selected.length) {
        slots.add(_FilledPhotoSlot(
          photo: selected[i],
          index: i,
          onRemove: () => onRemove(i),
          onUp: onReorder != null && i > 0
              ? () => onReorder!(i, i - 1)
              : null,
          onDown: onReorder != null && i < selected.length - 1
              ? () => onReorder!(i, i + 1)
              : null,
        ));
      } else {
        slots.add(_EmptyPhotoSlot(onTap: onAddPhoto));
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => slots[index],
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: .08),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_rounded,
            size: 28,
            color: Colors.white.withValues(alpha: .35),
          ),
        ),
      ),
    );
  }
}

class _FilledPhotoSlot extends StatelessWidget {
  const _FilledPhotoSlot({
    required this.photo,
    required this.index,
    required this.onRemove,
    this.onUp,
    this.onDown,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kAccent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: .4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfilePhotoViewer(
              path: photo.assetPath,
              fit: BoxFit.cover,
            ),
            if (onUp != null || onDown != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: .55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SlotIconButton(
                        icon: Icons.arrow_upward_rounded,
                        onTap: onUp,
                      ),
                      const SizedBox(width: 8),
                      _SlotIconButton(
                        icon: Icons.arrow_downward_rounded,
                        onTap: onDown,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  height: 24,
                  width: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotIconButton extends StatelessWidget {
  const _SlotIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? Colors.white.withValues(alpha: .2)
              : Colors.white.withValues(alpha: .06),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: .3),
        ),
      ),
    );
  }
}

// ── SelectableChip ──────────────────────────────────────────────────────────

/// A premium selectable chip (fills with the accent gradient when selected).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_kAccent, _kAccent2])
              : null,
          color: selected ? null : _kFieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: .1),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFFB7A5FF),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
                color: selected ? Colors.white : const Color(0xFFDDE3F4),
              ),
            ),
          ],
        ),
      ),

    );
  }
}

// ── MultiChipField ──────────────────────────────────────────────────────────

/// A wrap of [SelectableChip]s for multi-select fields (interests, languages).
class MultiChipField extends StatelessWidget {
  const MultiChipField({
    required this.options,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          SelectableChip(
            label: option,
            selected: selected.contains(option),
            onTap: () => onToggle(option),
          ),
      ],
    );
  }
}

// ── GlassTextField ──────────────────────────────────────────────────────────

/// A dark-glass text field matching the Conexo input language.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.suffixIcon,
    this.onSuffixTap,
    this.suffixBusy = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// Optional trailing action icon (e.g. "use current location"). Kept visually
  /// minimal so the field's premium glass language is preserved.
  final IconData? suffixIcon;

  /// Tap handler for [suffixIcon]. When null, no suffix affordance is shown.
  final VoidCallback? onSuffixTap;

  /// When true, the suffix shows a small spinner instead of the icon.
  final bool suffixBusy;

  @override
  Widget build(BuildContext context) {
    final hasSuffix = suffixIcon != null || suffixBusy;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14.5,
          color: _kSoftText,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: const Color(0xFFB7A5FF))
            : null,
        suffixIcon: hasSuffix
            ? _GlassFieldSuffix(
                icon: suffixIcon,
                busy: suffixBusy,
                onTap: onSuffixTap,
              )
            : null,
        filled: true,
        fillColor: _kFieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kAccent, width: 1.6),
        ),
      ),
    );

  }
}

/// A subtle, tappable suffix used inside [GlassTextField] (e.g. the GPS
/// "detect" affordance). Shows a small spinner while [busy].
class _GlassFieldSuffix extends StatelessWidget {
  const _GlassFieldSuffix({
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  final IconData? icon;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: busy ? null : onTap,
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
      icon: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFB7A5FF),
              ),
            )
          : Icon(icon, size: 20, color: const Color(0xFFB7A5FF)),
    );
  }
}

// ── LocationDetectField ─────────────────────────────────────────────────────

/// A [GlassTextField] specialised for location entry with a subtle GPS suffix.
///
/// The whole field triggers detection when empty (via [readOnlyTapWhenEmpty]),
/// and the suffix icon triggers detection at any time; either way the text stays
/// editable so the resolved area name can be corrected by hand. All GPS /
/// geocoding lives in [LocationService]; this widget only orchestrates UI state
/// and surfaces failures.
class LocationDetectField extends StatefulWidget {
  const LocationDetectField({
    required this.controller,
    required this.onLocationNameChanged,
    required this.onLocationDetected,
    super.key,
    this.hint = 'e.g. Bengaluru, India',
  });

  final TextEditingController controller;

  /// Called when the user manually edits the location name.
  final ValueChanged<String> onLocationNameChanged;

  /// Called once per successful GPS detection with the resolved area name
  /// (may be null) AND the real coordinates. The parent should update the
  /// draft atomically in a single [copyWith].
  final void Function(String? areaName, double latitude, double longitude)
      onLocationDetected;

  final String hint;

  @override
  State<LocationDetectField> createState() => _LocationDetectFieldState();
}

class _LocationDetectFieldState extends State<LocationDetectField> {
  bool _busy = false;

  /// After the first detection attempt, tapping the field no longer auto-detects
  /// (so manual typing is never interrupted). Re-detection stays on the GPS icon.
  bool _autoDetectSuppressed = false;

  Future<void> _detect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _autoDetectSuppressed = true;
    });

    final result = await LocationService.detectCurrentLocation();
    if (!mounted) return;

    setState(() => _busy = false);

    switch (result.outcome) {
      case LocationOutcome.success:
        final name = result.areaName;
        if (name != null && name.isNotEmpty) {
          widget.controller.text = name;
          widget.controller.selection = TextSelection.collapsed(
            offset: name.length,
          );
        }
        widget.onLocationDetected(name, result.latitude!, result.longitude!);
        _showSnack(
          name != null && name.isNotEmpty
              ? 'Location detected'
              : 'Coordinates captured. Add a location name.',
        );
      case LocationOutcome.permissionDenied:
        _showSnack('Location permission denied. You can type it manually.');
      case LocationOutcome.permissionPermanentlyDenied:
        _showSettingsSnack();
      case LocationOutcome.serviceDisabled:
        _showSnack('Turn on location services, or type your location.');
      case LocationOutcome.failed:
        _showSnack("Couldn't get your location. You can type it manually.");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSettingsSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Location permission is off in Settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: PermissionManager.openAppSettings,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final canAutoDetect =
        !_autoDetectSuppressed && widget.controller.text.trim().isEmpty && !_busy;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Tapping an empty field is the primary "use current location" gesture
      // (once only); afterwards we defer to normal editing + the suffix icon.
      onTap: canAutoDetect ? _detect : null,
      child: GlassTextField(
        controller: widget.controller,
        hint: widget.hint,
        icon: Icons.location_on_outlined,
        suffixIcon: Icons.my_location_rounded,
        suffixBusy: _busy,
        onSuffixTap: _detect,
        onChanged: widget.onLocationNameChanged,
      ),
    );
  }
}

// ── GenderSelector ──────────────────────────────────────────────────────────

/// A single-select set of gender chips.
class GenderSelector extends StatelessWidget {
  const GenderSelector({
    required this.options,
    required this.value,
    required this.onSelected,
    super.key,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          SelectableChip(
            label: option,
            selected: value == option,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

// ── SocialLinkField ─────────────────────────────────────────────────────────

/// A row that captures one social link: a platform chip + a URL/handle field.
class SocialLinkField extends StatelessWidget {
  const SocialLinkField({
    required this.platforms,
    required this.platform,
    required this.controller,
    required this.onPlatformChanged,
    required this.onUrlChanged,
    super.key,
  });

  final List<String> platforms;
  final String platform;
  final TextEditingController controller;
  final ValueChanged<String> onPlatformChanged;
  final ValueChanged<String> onUrlChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in platforms)
              SelectableChip(
                label: p,
                selected: platform == p,
                onTap: () => onPlatformChanged(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: controller,
          hint: 'Your $platform handle or URL',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          onChanged: onUrlChanged,
        ),
      ],
    );
  }
}

// ── RestoreBanner ───────────────────────────────────────────────────────────

/// A premium banner prompting the user to restore a saved draft.
class RestoreBanner extends StatelessWidget {
  const RestoreBanner({
    required this.onRestore,
    required this.onDiscard,
    super.key,
  });

  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: EntranceFade(
        child: GlassCard(
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFB7A5FF)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Continue where you left off?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onRestore,
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CompletionMeter ─────────────────────────────────────────────────────────

/// A slim animated progress meter reflecting [progress] (0..1).
class CompletionMeter extends StatelessWidget {
  const CompletionMeter({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Profile completeness',
              style: TextStyle(fontSize: 13, color: _kSoftText),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB7A5FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(height: 8, color: Colors.white.withValues(alpha: .08)),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kAccent, _kAccent2],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── CompleteProfileButton ───────────────────────────────────────────────────

/// The primary CTA. Enabled only when the draft is complete; shows a loading
/// spinner while saving with animated press feedback.
class CompleteProfileButton extends StatefulWidget {
  const CompleteProfileButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<CompleteProfileButton> createState() => _CompleteProfileButtonState();
}

class _CompleteProfileButtonState extends State<CompleteProfileButton> {
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
                    'Complete profile',
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

// ── ProfilePreviewCard ──────────────────────────────────────────────────────

/// A premium, continuously-updating preview of the profile.
///
/// Consumes only [ProfilePreviewData], so it never depends on mutable screen
/// state or a specific model (draft vs. finalized). This keeps it reusable
/// unchanged across future profile screens.
class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({required this.data, super.key});

  final ProfilePreviewData data;

  @override
  Widget build(BuildContext context) {
    final hero = data.primaryPhotoAsset;
    return RepaintBoundary(
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hero != null)
                      ProfilePhotoViewer(
                        path: hero,
                        fit: BoxFit.cover,
                      )
                    else
                      const ColoredBox(color: Color(0xFF1A2138)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0xCC0A0F1F),
                          ],
                          stops: [0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.location.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 15,
                                  color: Color(0xFFEAEEF9),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  data.location,
                                  style: const TextStyle(
                                    color: Color(0xFFEAEEF9),
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x99000000),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (data.gender.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              data.gender,
                              style: const TextStyle(
                                color: Color(0xFFC7D0E6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.bio.isNotEmpty)
                      Text(
                        data.bio,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Color(0xFFEAEEF9),
                        ),
                      ),
                    if (data.interests.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Interests'),
                      const SizedBox(height: 8),
                      _PreviewChips(values: data.interests),
                    ],
                    if (data.languages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Languages'),
                      const SizedBox(height: 8),
                      _PreviewChips(values: data.languages),
                    ],
                    if (data.occupation.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.work_outline_rounded,
                        value: data.occupation,
                      ),
                    if (data.college.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.school_outlined,
                        value: data.college,
                      ),
                    if (data.hometown.isNotEmpty)
                      _PreviewDetail(
                        icon: Icons.home_outlined,
                        value: data.hometown,
                      ),
                    if (data.socialLinks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PreviewLabel('Socials'),
                      const SizedBox(height: 8),
                      _PreviewChips(
                        values: [
                          for (final s in data.socialLinks)
                            if (s.url.trim().isNotEmpty) s.platform,
                        ],
                      ),
                    ],
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

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: .2,
        color: Color(0xFFB7A5FF),
      ),
    );
  }
}

class _PreviewChips extends StatelessWidget {
  const _PreviewChips({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(

              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: Color(0xFFDDE3F4),
              ),
            ),
          ),

      ],
    );
  }
}

class _PreviewDetail extends StatelessWidget {
  const _PreviewDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB7A5FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFFC7D0E6)),
            ),
          ),
        ],
      ),
    );
  }
}
