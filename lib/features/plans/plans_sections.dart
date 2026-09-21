import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import '../home_discovery_animations.dart';
import 'plans_cards.dart';
import 'plans_data.dart';
import 'plans_theme.dart';
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
                color: Colors.black.withValues(alpha: .14),
                blurRadius: 30,
                offset: const Offset(0, 14),
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
                    color: context.cxGlass,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: context.cxLine),
                  ),
                  child: Text(
                    'Tonight\'s highlight',
                    style: plansBody(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.cxInk,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoodBadge(
                      emoji: e.moodEmoji,
                      mood: e.mood,
                      accent: e.accent,
                    ),
                    const SizedBox(width: 8),
                    VisibilityBadge(isPublic: e.isPublic),
                  ],
                ),
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
                      style: plansDisplay(
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PlanMetaLine(
                      fontSize: 13,
                      items: [
                        (Icons.calendar_today_outlined, e.date),
                        (Icons.schedule_outlined, e.time),
                        (Icons.place_outlined, e.distance),
                        (Icons.people_outline, '${e.goingCount} going'),
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
                            style: plansBody(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
PlanCategory allCategory = PlanCategory(
  'All',
  '✨',
  Icons.grid_view_outlined,
  Colors.transparent, // Theme-aware via CategoryCard; not used directly
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
    final items = <PlanCategory>[allCategory, ...planCategories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
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
            style: plansDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
              color: context.cxInk,
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


