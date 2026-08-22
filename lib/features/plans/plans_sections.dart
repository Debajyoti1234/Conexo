import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'plans_cards.dart';
import 'plans_data.dart';
import 'plans_widgets.dart';

/// Cinematic hero for the single featured "Tonight's Highlight" experience.
class FeaturedHero extends StatelessWidget {
  const FeaturedHero({required this.experience, this.onOpen, super.key});
  final Experience experience;

  /// Optional open callback. Navigation is owned by the Plans screen layer,
  /// so this reusable hero only exposes the intent.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return EntranceFade(
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: e.accent.withValues(alpha: .3),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'plan-cover-${e.id}',
                  child: PlanCover(asset: e.coverAsset, accent: e.accent),
                ),

              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: const Text(
                    '✨ Tonight\'s Highlight',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: VisibilityBadge(isPublic: e.isPublic),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MoodBadge(
                          emoji: e.moodEmoji,
                          mood: e.mood,
                          accent: e.accent,
                        ),
                        InfoChip(emoji: '📅', label: e.date),
                        InfoChip(emoji: '⏰', label: e.time),
                        InfoChip(emoji: '📍', label: e.distance),
                        InfoChip(emoji: '👥', label: '${e.goingCount} Going'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        PlanPortrait(
                          asset: e.hostPortrait,
                          accent: e.accent,
                          size: 34,
                          label: e.host,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hosted by ${e.host}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const ViewPill(),
                      ],
                    ),

                  ],
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


/// The "All" pseudo-category prepended to the strip. A `null` selection in
/// [PlansFilterState] represents All; this entry drives its visual card.
const PlanCategory allCategory = PlanCategory(
  'All',
  '✨',
  Icons.auto_awesome_mosaic_rounded,
  Color(0xFF8B5CF6),
);

const PlanCategory privateCategory = PlanCategory(
  'Private',
  '🔒',
  Icons.lock_rounded,
  Color(0xFF8B5CF6),
);

/// Horizontal strip of premium glass category cards. Fully controlled: "All"
/// is index 0, and selection is owned by the parent (single source of truth).
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// 0 = All; 1..n map to [planCategories].
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <PlanCategory>[allCategory, ...planCategories, privateCategory];
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) => CategoryCard(
          category: items[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

/// A titled horizontal rail of experience cards. Hidden entirely when the
/// [items] list is empty so the layout always feels curated. An optional
/// [variant] override keeps every card in a rail visually consistent.
class ExperienceRail extends StatelessWidget {
  const ExperienceRail({
    required this.title,
    required this.items,
    super.key,
    this.height = 360,
    this.cardWidth = 300,
    this.variant,
    this.onOpen,
  });

  final String title;
  final List<Experience> items;
  final double height;
  final double cardWidth;
  final CardVariant? variant;

  /// Optional open callback per card. Navigation is owned by the Plans screen
  /// layer, so the reusable card only forwards the tapped experience.
  final ValueChanged<Experience>? onOpen;


  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: height,
          child: RepaintBoundary(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, i) => EntranceFade(
                delay: Duration(milliseconds: 60 * i),
                child: ExperienceCard(
                  key: ValueKey(items[i].id),
                  experience: items[i],
                  width: cardWidth,
                  variant: variant,
                  onTap: onOpen == null ? null : () => onOpen!(items[i]),
                ),
              ),

            ),
          ),
        ),
      ],
    );
  }
}


