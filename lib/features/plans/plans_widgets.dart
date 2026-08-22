import 'package:flutter/material.dart';

import 'plans_data.dart';

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
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      image = Image.network(
        asset,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            color: accent.withValues(alpha: .25),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: .7),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: _buildFallback,
      );
    } else {
      image = Image.asset(
        asset,
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
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, .25) ?? accent,
            accent,
            Color.lerp(accent, const Color(0xFF0A0F1F), .55) ?? accent,
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
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9DB2E8)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14.5,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFFB7A5FF),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'What do you feel like doing today?',
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF9DB2E8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      hasText ? Icons.close_rounded : Icons.tune_rounded,
                      size: 18,
                      color: const Color(0xFFB7A5FF),
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
  const InfoChip({required this.emoji, required this.label, super.key});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11.5)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE7ECF9),
            ),
          ),
        ],
      ),
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
  });
  final String emoji;
  final String mood;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            mood,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
              color: Colors.white,
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
        color: Colors.black.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public_rounded : Icons.lock_rounded,
            size: 12,
            color: const Color(0xFFDDE3F4),
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDDE3F4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small, elegant glass "View →" call-to-action. UI only.
class ViewPill extends StatelessWidget {
  const ViewPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 5),
          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
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
  });
  final String text;
  final bool isEditorsPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isEditorsPick
              ? Icons.star_rounded
              : Icons.auto_awesome_rounded,
          size: 13,
          color: const Color(0xFFFFC24D),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD4EC),
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: accent.withValues(alpha: .25),
            child: Center(
              child: SizedBox(
                width: size * .4,
                height: size * .4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: .7),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
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
        border: Border.all(color: Colors.white.withValues(alpha: .35), width: 1.4),
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
                  color: const Color(0xFF232C47),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .35),
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: size * .34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 92,
          padding: EdgeInsets.all(selected ? 1.6 : 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Gradient border when selected (via padding + inner fill).
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.color.withValues(alpha: .95),
                      c.color.withValues(alpha: .35),
                    ],
                  )
                : null,
            border: selected
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .1)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.color.withValues(alpha: .5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF161E36).withValues(alpha: .92)
                  : Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.color.withValues(alpha: selected ? .32 : .16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(c.icon, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFFCBD4EC),
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
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: .5),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '✨ Create Plan',
                style: TextStyle(
                  fontSize: 14.5,
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
              color: Colors.white.withValues(alpha: .06),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              size: 36,
              color: Color(0xFF9DB2E8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nothing here yet',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try another category or create the first nearby plan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFFB9C3DC)),
          ),

        ],
      ),
    );
  }
}
