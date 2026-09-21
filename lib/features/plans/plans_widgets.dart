import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import 'plans_data.dart';
import 'plans_theme.dart';

/// Reusable premium primitives for the Plans discovery experience.
///
/// Local assets only — no network images. Every widget keeps the luxury
/// dark-glass language consistent with the People and Connections screens.

/// A cover image for the premium Plan UI. Supports both local assets and
/// remote network URLs (for Supabase-backed covers). Falls back to a gentle
/// accent gradient if the image cannot be loaded.
class PlanCover extends StatelessWidget {
  const PlanCover({
    required this.asset,
    required this.accent,
    super.key,
    this.height,
    this.scrim = true,
    this.radius = 0,
  });

  final String asset;
  final Color accent;
  final double? height;
  final bool scrim;
  final double radius;

@override
  Widget build(BuildContext context) {
    Widget image;
    if (asset.isEmpty) {
      image = _buildRemoteFallback(context);
    } else if (asset.startsWith('http://') || asset.startsWith('https://')) {
      image = Image.network(
        asset,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: _buildFallback,
      );
    } else if (asset.startsWith('assets/')) {
      image = Image.asset(
        asset,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: _buildFallback,
      );
    } else if (asset.startsWith('plans/')) {
      image = _buildRemoteFallback(context);
    } else {
      image = Image.file(
        File(asset),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: _buildFallback,
      );
    }

    final layered = Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (scrim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x22000000),
                  Color(0xCC05070F),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        if (scrim)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .28),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
      ],
    );

    if (radius <= 0) return layered;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: layered,
    );
  }

Widget _buildFallback(BuildContext context, Object error, StackTrace? stackTrace) {
    return _buildRemoteFallback(context);
  }

  Widget _buildRemoteFallback(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, context.cxCanvas, .25) ?? accent,
            accent,
            Color.lerp(accent, context.cxCanvas, .55) ?? accent,
          ],
        ),
      ),
    );
  }
}

/// Floating premium glass search bar — a real controlled text field that
/// filters the local dataset live. Keeps the identical premium glass look.
class PlansSearchBar extends StatelessWidget {
  const PlansSearchBar({
    required this.controller,
    super.key,
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.cxGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cxLine),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search, color: context.cxSoft, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: plansBody(
                fontSize: 15,
                color: context.cxInk,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: context.cxInk,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'What do you feel like doing today?',
                hintStyle: plansBody(
                  fontSize: 15,
                  color: context.cxMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          // Clear button appears while typing; otherwise the tune glyph.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return GestureDetector(
                onTap: hasText ? onClear : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  child: Container(
                    key: ValueKey(hasText),
                    margin: const EdgeInsets.only(right: 8),
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: hasText ? context.cxAccent.withValues(alpha: .12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: hasText ? Border.all(color: context.cxAccent.withValues(alpha: .3)) : null,
                    ),
                    child: Icon(
                      hasText ? Icons.close : Icons.tune,
                      size: 18,
                      color: hasText ? context.cxAccent : context.cxSoft,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


/// A small elegant glass chip used for compact card info (date, time, etc).
class InfoChip extends StatelessWidget {
  const InfoChip({
    required this.label,
    super.key,
    this.icon,
    this.emoji,
    this.onLight = false,
  });

  /// Preferred leading glyph. When null, [emoji] is shown instead.
  final IconData? icon;

  /// Legacy leading glyph; ignored when [icon] is provided.
  final String? emoji;
  final String label;

  /// True when rendered on a white card surface rather than over a photo.
  final bool onLight;

@override
  Widget build(BuildContext context) {
    final fg = onLight ? context.cxInk : Colors.white;
    final bg = onLight ? context.cxSurface : context.cxGlass;
    final borderColor = onLight ? context.cxLine : context.cxLine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: fg)
          else
            Text(emoji ?? '', style: const TextStyle(fontSize: 11.5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: plansBody(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves the outlined glyph for a plan mood via its Discovery category.
/// Unknown moods fall back to a neutral sparkle so nothing renders blank.
IconData iconForMood(String mood) {
  final label = categoryForMood(mood);
  for (final c in planCategories) {
    if (c.label == label) return c.icon;
  }
  return Icons.auto_awesome_outlined;
}

/// A compact inline meta line (date · time · distance …) rendered as small
/// outlined icons + text with no boxes, so cards read like editorial captions
/// instead of a wall of chips. Wraps gracefully when space is tight.
class PlanMetaLine extends StatelessWidget {
  const PlanMetaLine({
    required this.items,
    super.key,
    this.onLight = false,
    this.fontSize = 12.5,
  });

  /// Ordered (icon, label) pairs.
  final List<(IconData, String)> items;

  /// True when rendered on a white card surface rather than over a photo.
  final bool onLight;
  final double fontSize;

@override
  Widget build(BuildContext context) {
    final fg = onLight
        ? context.cxSoft
        : context.cxInk;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (icon, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: fontSize + 2, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: plansBody(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A small mood badge — emotional context, distinct from category.
class MoodBadge extends StatelessWidget {
  const MoodBadge({
    required this.emoji,
    required this.mood,
    required this.accent,
    super.key,
    this.onLight = false,
  });
  final String emoji;
  final String mood;
  final Color accent;

  /// True when rendered on a white card surface rather than over a photo.
  final bool onLight;

@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onLight
            ? context.cxAccent.withValues(alpha: .08)
            : context.cxGlass,
        borderRadius: BorderRadius.circular(20),
        border: onLight
            ? Border.all(color: context.cxAccent.withValues(alpha: .25))
            : Border.all(color: context.cxLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForMood(mood),
            size: 12,
            color: onLight ? context.cxAccent : context.cxAccent,
          ),
          const SizedBox(width: 5),
          Text(
            mood,
            style: plansBody(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
              color: onLight ? context.cxAccent : context.cxInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elegant Public / Private badge. Not the primary focus.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({required this.isPublic, super.key});
  final bool isPublic;

@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.cxGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cxLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public_outlined : Icons.lock_outline_rounded,
            size: 12,
            color: context.cxInk,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: plansBody(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small, elegant glass "View →" call-to-action. UI only.
class ViewPill extends StatelessWidget {
  const ViewPill({super.key, this.onLight = false});

  /// True when rendered on a white card surface rather than over a photo.
  final bool onLight;

@override
  Widget build(BuildContext context) {
    final fg = onLight ? context.cxCanvas : context.cxInk;
    final bg = onLight ? context.cxInk : context.cxGlass;
    final borderColor = onLight ? Colors.transparent : context.cxLine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View',
            style: plansBody(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.arrow_forward, size: 14, color: fg),
        ],
      ),
    );
  }
}

/// The micro-detail line (e.g. "Editor's Pick", "3 friends interested").
class HighlightLine extends StatelessWidget {
  const HighlightLine({
    required this.text,
    required this.isEditorsPick,
    super.key,
    this.onLight = false,
  });
  final String text;
  final bool isEditorsPick;

  /// True when rendered on a white card surface rather than over a photo.
  final bool onLight;

@override
  Widget build(BuildContext context) {
    final color = onLight ? context.cxSoft : context.cxMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isEditorsPick
              ? Icons.star_outline_rounded
              : Icons.auto_awesome_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: plansBody(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A local portrait avatar with a graceful letter fallback.
class PlanPortrait extends StatelessWidget {
  const PlanPortrait({
    required this.asset,
    required this.accent,
    super.key,
    this.size = 40,
    this.label = '',
  });

  final String asset;
  final Color accent;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      image = Image.network(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: _buildFallback,
      );
    } else {
      image = Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: _buildFallback,
      );
    }

return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.cxLine, width: 1.4),
      ),
      child: ClipOval(child: image),
    );
  }

  Widget _buildFallback(BuildContext context, Object error, StackTrace? stackTrace) {
    final isYou = label == 'You';
    return Container(
      color: accent,
      alignment: Alignment.center,
      child: isYou
          ? const Icon(Icons.person_outline_rounded, size: 18, color: Colors.white)
          : Text(
              label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: size * .4,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}

/// An overlapping cluster of participant avatars with a "+N" overflow.
class ParticipantStack extends StatelessWidget {
  const ParticipantStack({
    required this.portraits,
    required this.accent,
    super.key,
    this.size = 26,
    this.max = 3,
  });

  final List<String> portraits;
  final Color accent;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = portraits.take(max).toList();
    final extra = portraits.length - shown.length;
    final overlap = size * 0.62;
    final width = shown.isEmpty
        ? 0.0
        : size + (shown.length - 1) * overlap + (extra > 0 ? overlap : 0);

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: PlanPortrait(asset: shown[i], accent: accent, size: size),
            ),
if (extra > 0)
            Positioned(
              left: shown.length * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.cxSurface,
                  border: Border.all(
                    color: context.cxLine,
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: plansBody(
                    fontSize: size * .34,
                    fontWeight: FontWeight.w600,
                    color: context.cxInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A premium glass category card with animated press + a stronger selected
/// state: gradient border, premium glow, brighter glass, larger icon.
class CategoryCard extends StatefulWidget {
  const CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PlanCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
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
            borderRadius: BorderRadius.circular(22),
            color: selected ? context.cxAccent : context.cxCanvas,
            border: Border.all(
              color: selected ? context.cxAccent : context.cxLine,
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.cxAccent.withValues(alpha: .35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                c.icon,
                size: 16,
                color: selected ? context.cxCanvas : context.cxInk,
              ),
              const SizedBox(width: 7),
              Text(
                c.label,
                maxLines: 1,
                style: plansBody(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? context.cxCanvas : context.cxInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Floating premium gradient "✨ Create Plan" pill. Opens the Create Plan
/// flow — the single entry point into hosting a plan.
class CreatePlanButton extends StatefulWidget {
  const CreatePlanButton({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  State<CreatePlanButton> createState() => _CreatePlanButtonState();
}

class _CreatePlanButtonState extends State<CreatePlanButton> {

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [context.cxAccent, context.cxAccent]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: context.cxAccent.withValues(alpha: .45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Create plan',
                style: plansBody(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
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

/// Premium empty state for a future search with no results.
class PlansEmptyState extends StatelessWidget {
  const PlansEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cxSurface,
              border: Border.all(color: context.cxLine),
            ),
            child: Icon(
              Icons.travel_explore_outlined,
              size: 36,
              color: context.cxMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nothing here yet',
            style: plansDisplay(fontSize: 24, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try another category or create the first nearby plan.',
            textAlign: TextAlign.center,
            style: plansBody(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: context.cxSoft,
            ),
          ),

        ],
      ),
    );
  }
}
