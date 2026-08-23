import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';
import 'create_plan_data.dart';
import 'plans_data.dart';
import 'plans_widgets.dart';

/// Reusable premium primitives for the Create Plan flow.
///
/// Everything reuses the established Conexo dark-glass language (GlassCard,
/// EntranceFade, existing gradients / spacing / shadows). Motion is limited
/// to AnimatedSwitcher / AnimatedSize / AnimatedScale / Fade / Slide / Scale
/// with easeOutCubic / easeInOutCubic — no bounce, elastic, or overshoot.

const _kAccent = Color(0xFF8B5CF6);
const _kSecondary = Color(0xFF587BE2);
const _kSoftText = Color(0xFFB9C3DC);

// ── Section shell with live completion checkmark ────────────────────────

/// Wraps each input section with a large title, an optional subtitle, and a
/// subtle ✓ that fades in the moment the section is complete.
class CreateSection extends StatelessWidget {
  const CreateSection({
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
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
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: _kSoftText),
            ),
          ],
          const SizedBox(height: 12),
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
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF47D7A5).withValues(alpha: .22),
        border: Border.all(color: const Color(0xFF47D7A5).withValues(alpha: .6)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.check_rounded, size: 13, color: Color(0xFF7BE8C2)),
    );
  }
}

// ── Progress stage rail (Cover • Details • Schedule • Preview) ──────────

/// The four guided stages of the flow.
enum CreateStage { cover, details, schedule, preview }

const _stageLabels = <CreateStage, String>{
  CreateStage.cover: 'Cover',
  CreateStage.details: 'Details',
  CreateStage.schedule: 'Schedule',
  CreateStage.preview: 'Preview',
};

/// A subtle premium progress indicator — softly highlights the active stage
/// with a sliding accent underline. No "Step X of Y", no percentages.
class StageRail extends StatelessWidget {
  const StageRail({required this.active, super.key});
  final CreateStage active;

  @override
  Widget build(BuildContext context) {
    final stages = CreateStage.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Row(
        children: [
          for (final stage in stages) ...[
            _StageItem(
              label: _stageLabels[stage]!,
              active: stage == active,
              done: stage.index < active.index,
            ),
            if (stage != stages.last)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '•',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF3C486A), fontSize: 12),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StageItem extends StatelessWidget {
  const _StageItem({
    required this.label,
    required this.active,
    required this.done,
  });
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || done;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: highlighted ? Colors.white : const Color(0xFF6B7799),
          ),
          child: Text(label),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic,
          height: 3,
          width: active ? 22 : (done ? 14 : 8),
          decoration: BoxDecoration(
            color: highlighted
                ? _kAccent.withValues(alpha: active ? .95 : .5)
                : const Color(0xFF2C3650),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

// ── Cover picker hero + premium Conexo gallery grid ─────────────────────

/// The cover selection area.
///
/// When no cover is chosen, shows two equal premium glass cards side by side:
///   • "From Device" — opens the device image picker
///   • "Conexo Gallery" — opens the built-in cover gallery
///
/// When a cover is already selected, shows the cover image with a subtle
/// glass overlay and a "Change cover" affordance, plus the two action cards
/// below for switching.
class CoverPickerHero extends StatelessWidget {
  const CoverPickerHero({
    required this.coverAsset,
    required this.onPickGallery,
    required this.onPickDevice,
    super.key,
  });

  final String? coverAsset;
  final VoidCallback onPickGallery;
  final VoidCallback onPickDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _hero(coverAsset),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CoverActionCard(
                onTap: onPickDevice,
                icon: Icons.add_photo_alternate_rounded,
                label: 'From Device',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CoverActionCard(
                onTap: onPickGallery,
                icon: Icons.photo_library_rounded,
                label: 'Conexo Gallery',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hero(String? asset) {
    if (asset == null || asset.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('empty-cover'));
    }
    return SizedBox(
      key: ValueKey(asset),
      height: 200,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlanCover(asset: asset, accent: _kAccent, radius: 24),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .0),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: onPickGallery,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: .2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Change cover',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverActionCard extends StatelessWidget {
  const _CoverActionCard({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFFB7A5FF)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The premium Conexo Gallery — a responsive rounded grid of local covers.
/// Each tile shows the image, a subtle glass overlay, and its title.
class CoverGalleryGrid extends StatelessWidget {
  const CoverGalleryGrid({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: planCoverGallery.length,
      itemBuilder: (context, i) {
        final option = planCoverGallery[i];
        final isSelected = option.asset == selected;
        return _GalleryTile(
          option: option,
          selected: isSelected,
          onTap: () => onSelect(option.asset),
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final PlanCoverOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _kAccent : Colors.white.withValues(alpha: .1),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
               PlanCover(asset: option.asset, accent: _kAccent),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kAccent,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Luxury chips ────────────────────────────────────────────────────────

/// A premium selectable chip with animated press + selected glow.
class LuxuryChip extends StatefulWidget {
  const LuxuryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.emoji,
    this.accent = _kAccent,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<LuxuryChip> createState() => _LuxuryChipState();
}

class _LuxuryChipState extends State<LuxuryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? .16 : .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? widget.accent.withValues(alpha: .85)
                  : Colors.white.withValues(alpha: .1),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: .4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.emoji != null) ...[
                Text(widget.emoji!, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFFCBD4EC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Segmented visibility cards ──────────────────────────────────────────

class SegmentedVisibilityCards extends StatelessWidget {
  const SegmentedVisibilityCards({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final PlanVisibility? value;
  final ValueChanged<PlanVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VisibilityCard(
          emoji: '🌍',
          title: 'Public Plan',
          subtitle: 'Anyone nearby can discover and request to join.',
          selected: value == PlanVisibility.public,
          onTap: () => onChanged(PlanVisibility.public),
        ),
        const SizedBox(height: 10),
        _VisibilityCard(
          emoji: '🔒',
          title: 'Private Plan',
          subtitle: 'Invite only.',
          selected: value == PlanVisibility.private,
          onTap: () => onChanged(PlanVisibility.private),
        ),
      ],
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? .12 : .05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _kAccent.withValues(alpha: .85)
                : Colors.white.withValues(alpha: .1),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _kSoftText),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: selected
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('sel'), color: _kAccent, size: 22)
                  : const Icon(Icons.circle_outlined,
                      key: ValueKey('unsel'),
                      color: Color(0xFF3C486A),
                      size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass selector tiles (location / date / time) ───────────────────────

/// A premium glass tile used by Location / Date / Time selectors.
class SelectorTile extends StatelessWidget {
  const SelectorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
    this.placeholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: const Color(0xFFB7A5FF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: _kSoftText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: placeholder ? const Color(0xFF6B7799) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7799)),
          ],
        ),
      ),
    );
  }
}

/// A premium glass text field (title / location / description).
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    required this.controller,
    required this.hint,
    super.key,
    this.maxLines = 1,
    this.onChanged,
    this.leadingIcon,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final IconData? leadingIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: leadingIcon != null ? 14 : 16,
        vertical: maxLines > 1 ? 14 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: leadingIcon != null
              ? Icon(leadingIcon, size: 18, color: const Color(0xFF9DB2E8))
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B7799)),
        ),
      ),
    );
  }
}

// ── Floating publish button with morphing loading state ─────────────────

enum PublishState { idle, loading }

/// The large floating gradient action button. Disabled (dimmed +
/// non-interactive) until [enabled]; morphs into a loading spinner on tap.
/// [label] lets the caller show "Publish Plan" (create) or "Save Changes"
/// (editing an existing plan).
class PublishButton extends StatelessWidget {
  const PublishButton({
    required this.enabled,
    required this.state,
    required this.onTap,
    super.key,
    this.label = 'Publish Plan',
  });

  final bool enabled;
  final PublishState state;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final loading = state == PublishState.loading;
    final active = enabled && !loading;
    return AnimatedOpacity(
      opacity: active ? 1 : (loading ? 1 : 0.5),
      duration: const Duration(milliseconds: 260),
      child: IgnorePointer(
        ignoring: !active,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            height: 56,
            width: loading ? 56 : double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccent, _kSecondary],
              ),
              borderRadius: BorderRadius.circular(loading ? 28 : 18),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: .45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      key: const ValueKey('label'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium success overlay ─────────────────────────────────────────────

/// A calm full-screen success state shown after publishing or saving edits.
class PublishSuccessOverlay extends StatelessWidget {
  const PublishSuccessOverlay({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final title = isEditing ? '✨ Changes Saved' : '✨ Plan Published';
    final message = isEditing
        ? 'Your plan has been updated.'
        : 'Your plan is now visible to nearby people.';
    return Container(
      color: const Color(0xFF060912).withValues(alpha: .92),
      alignment: Alignment.center,
      child: EntranceFade(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_kAccent, _kSecondary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: .5),
                    blurRadius: 34,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 44, color: Colors.white),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: _kSoftText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
