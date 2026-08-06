import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
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

/// A selectable, reorderable grid of local portrait assets.
///
/// Tapping an unselected asset adds it (up to [kMaxProfilePhotos]); tapping a
/// selected asset removes it. The first selected photo is the primary. Long
/// controls let the user reorder to change the primary photo.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.gallery,
    required this.selected,
    required this.onToggle,
    required this.onReorder,
    super.key,
  });

  /// All available local assets.
  final List<String> gallery;

  /// Currently selected photos in display order (first = primary).
  final List<ProfilePhoto> selected;

  final ValueChanged<String> onToggle;

  /// Called with (oldIndex, newIndex) within the selected list.
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected strip with ordering + primary badge.
        if (selected.isNotEmpty) ...[
          const Text(
            'Tap arrows to reorder • first photo is primary',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: _kSoftText,
            ),
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              for (var i = 0; i < selected.length; i++)
                Padding(
                  key: ValueKey('sel_${selected[i].id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SelectedPhotoRow(
                    photo: selected[i],
                    index: i,
                    onUp: i > 0 ? () => onReorder(i, i - 1) : null,
                    onDown: i < selected.length - 1
                        ? () => onReorder(i, i + 1)
                        : null,
                    onRemove: () => onToggle(selected[i].assetPath),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Gallery',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _kSoftText,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gallery.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final asset = gallery[index];
            final isSelected = selected.any((p) => p.assetPath == asset);
            return _GalleryTile(
              asset: asset,
              selected: isSelected,
              onTap: () => onToggle(asset),
            );
          },
        ),
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
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
            color: selected ? _kAccent : Colors.white.withValues(alpha: .08),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            if (selected)
              Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(6),
                color: Colors.black.withValues(alpha: .16),
                child: const _CompletionCheck(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPhotoRow extends StatelessWidget {
  const _SelectedPhotoRow({
    required this.photo,
    required this.index,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final ProfilePhoto photo;
  final int index;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                photo.assetPath,
                height: 54,
                width: 54,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (photo.isPrimary)
                  const Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF47D7A5),
                    ),
                  ),
              ],
            ),
          ),
          _RoundIconButton(
            icon: Icons.arrow_upward_rounded,
            onTap: onUp,
            tooltip: 'Move up',
          ),
          const SizedBox(width: 6),
          _RoundIconButton(
            icon: Icons.arrow_downward_rounded,
            onTap: onDown,
            tooltip: 'Move down',
          ),
          const SizedBox(width: 6),
          _RoundIconButton(
            icon: Icons.close_rounded,
            onTap: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: enabled ? .08 : .03),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: .25),
            ),
          ),
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
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
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
                      Image.asset(hero, fit: BoxFit.cover)
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
