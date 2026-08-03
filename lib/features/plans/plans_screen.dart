import 'dart:async';

import 'package:flutter/material.dart';

import 'create_plan_screen.dart';
import 'plan_details_screen.dart';
import 'plans_data.dart';
import 'plans_filter.dart';
import 'plans_sections.dart';
import 'plans_widgets.dart';


/// The premium Plans discovery experience.
///
/// Browsing only — no join logic, no backend. A single [PlansFilterState] is
/// the source of truth: category + live search feed ONE processing pipeline
/// ([applyPipeline]) whose distance-first sorted output drives the hero and
/// every rail. No rail filters or sorts independently.
class PlansDiscoveryScreen extends StatefulWidget {
  const PlansDiscoveryScreen({super.key});

  @override
  State<PlansDiscoveryScreen> createState() => _PlansDiscoveryScreenState();
}

class _PlansDiscoveryScreenState extends State<PlansDiscoveryScreen> {
  PlansFilterState _filter = const PlansFilterState();
  int _categoryIndex = 0; // 0 = All
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(int index) {
    if (index == _categoryIndex) return;
    setState(() {
      _categoryIndex = index;
      _filter = index == 0
          ? _filter.copyWith(clearCategory: true)
          : _filter.copyWith(selectedCategory: planCategories[index - 1].label);
    });
  }

  void _onSearchChanged(String value) {
    // Lightweight ~250ms debounce so filtering stays smooth while typing.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _filter = _filter.copyWith(query: value));
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _filter = _filter.copyWith(query: ''));
  }

  @override
  Widget build(BuildContext context) {
    // ── Single pipeline: All → Category → Search → Distance-first Sort ──
    final processed = applyPipeline(experiences, _filter);
    final sections = sectionsFor(processed);
    final hasResults = processed.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(top: 8, bottom: 110),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Plans',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Discover experiences worth showing up for.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: PlansSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
              ),
              CategoryStrip(
                selectedIndex: _categoryIndex,
                onSelected: _onCategorySelected,
              ),
              const SizedBox(height: 28),
              // The hero + rails cross-fade whenever the filter changes.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: hasResults
                    ? _ResultsView(
                        key: ValueKey(_filter),
                        hero: processed.first,
                        sections: sections,
                      )
                    : const _EmptyView(key: ValueKey('plans-empty')),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 24,
            child: CreatePlanButton(
              onTap: () => Navigator.of(context).push<void>(
                PageRouteBuilder<void>(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const CreatePlanScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero + curated rails, all derived from the single processed list.
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.hero,
    required this.sections,
    super.key,
  });

  final Experience hero;
  final Map<String, List<Experience>> sections;

  /// Navigation lives here in the Plans screen layer. Reusable cards + hero
  /// only expose callbacks; this pushes the premium fade + slide details route.
  void _open(BuildContext context, Experience e) {
    Navigator.of(context).push(premiumPlanRoute(e));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: FeaturedHero(
            experience: hero,
            onOpen: () => _open(context, hero),
          ),
        ),
        ExperienceRail(
          title: '⭐ Featured',
          items: sections['featured'] ?? const [],
          variant: CardVariant.immersive,
          onOpen: (e) => _open(context, e),
        ),
        const SizedBox(height: 30),
        ExperienceRail(
          title: '✨ Happening Today',
          items: sections['today'] ?? const [],
          variant: CardVariant.stacked,
          height: 400,
          onOpen: (e) => _open(context, e),
        ),

        const SizedBox(height: 30),
        ExperienceRail(
          title: '🔥 Trending',
          items: sections['trending'] ?? const [],
          variant: CardVariant.immersive,
          onOpen: (e) => _open(context, e),
        ),
        const SizedBox(height: 30),
        ExperienceRail(
          title: '📍 Near You',
          items: sections['near'] ?? const [],
          variant: CardVariant.stacked,
          height: 400,
          onOpen: (e) => _open(context, e),
        ),

        const SizedBox(height: 30),
        ExperienceRail(
          title: '👥 Friends Joined',
          items: sections['friends'] ?? const [],
          variant: CardVariant.compact,
          height: 300,
          cardWidth: 260,
          onOpen: (e) => _open(context, e),
        ),
        const SizedBox(height: 30),
        ExperienceRail(
          title: '🆕 New',
          items: sections['new'] ?? const [],
          variant: CardVariant.immersive,
          onOpen: (e) => _open(context, e),
        ),
      ],
    );
  }
}


class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) => const PlansEmptyState();
}
