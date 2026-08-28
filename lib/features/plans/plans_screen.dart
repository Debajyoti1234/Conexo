import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'create_plan_screen.dart';
import 'my_plans_screen.dart';
import 'plan_details_screen.dart';
import 'plan_repository.dart';
import 'plans_data.dart';

import 'plans_filter.dart';
import 'plans_sections.dart';
import 'plans_widgets.dart';
import 'supabase_plan_repository.dart';

import '../../core/supabase/auth_service.dart';


/// The premium Plans discovery experience.
///
/// Browsing only — no join logic, no backend. A single [PlansFilterState] is
/// the source of truth: category + live search feed ONE processing pipeline
/// ([applyPipeline]) whose distance-first sorted output drives the hero and
/// every rail. No rail filters or sorts independently.
class PlansDiscoveryScreen extends StatefulWidget {
  const PlansDiscoveryScreen({super.key, this.repository = const SupabasePlanRepository()});

  final PlanRepository repository;

  @override
  State<PlansDiscoveryScreen> createState() => _PlansDiscoveryScreenState();
}

class _PlansDiscoveryScreenState extends State<PlansDiscoveryScreen> with WidgetsBindingObserver {
  PlansFilterState _filter = const PlansFilterState();
  int _categoryIndex = 0; // 0 = All
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Experience> _allPlans = const [];
  List<Experience> _createdPlans = const [];
  List<Experience> _recentlyVisited = const [];
  int? _maxDistanceKm;
  bool _loading = true;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;
    try {
      final experiences = await widget.repository.getDiscoveryExperiences();
      if (generation != _requestGeneration) return;
      final maxKm = await widget.repository.getDiscoveryDistanceKm();
      if (generation != _requestGeneration) return;
      if (!mounted) return;

      for (final e in experiences.take(5)) {
        final asset = e.coverAsset;
        if (asset.startsWith('http://') || asset.startsWith('https://')) {
          try {
            await precacheImage(NetworkImage(asset), context);
          } catch (_) {}
        } else if (asset.startsWith('assets/')) {
        } else if (asset.startsWith('plans/')) {
        } else if (asset.isNotEmpty) {
          try {
            await precacheImage(FileImage(File(asset)), context);
          } catch (_) {}
        }
      }

      if (generation != _requestGeneration) return;
      setState(() {
        _allPlans = experiences;
        _maxDistanceKm = maxKm;
        _loading = false;
        _error = null;
      });

      if (generation != _requestGeneration) return;
      List<Experience> created = const [];
      List<Experience> visited = const [];
      try {
        created = await widget.repository.getPublishedExperiences();
        if (generation != _requestGeneration) return;
        visited = await widget.repository.getRecentlyVisitedExperiences();
        if (generation != _requestGeneration) return;
      } catch (_) {
        // Auxiliary discovery sections are best-effort; do not fail the main
        // discovery feed if Created / Recently Visited cannot load.
      }
      if (!mounted) return;
      if (generation != _requestGeneration) return;
      setState(() {
        _createdPlans = created;
        _recentlyVisited = visited;
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  /// Opens a plan's details, then reloads discovery on return. This keeps the
  /// feed viewer-specific: if the viewer requested to join (pending) or joined
  /// while on the details screen, the plan is filtered out of THEIR feed on
  /// return. It remains visible to every other user, and reappears for this
  /// viewer if the request is later declined.
  Future<void> _openPlan(Experience e) async {
    await widget.repository.recordPlanVisit(e.id);
    await Navigator.of(context).push<void>(premiumPlanRoute(e));
    if (!mounted) return;
    await _load();
  }

  void _onCategorySelected(int index) {
    if (index == _categoryIndex) return;
    setState(() {
      _categoryIndex = index;
      if (index == 0) {
        _filter = _filter.copyWith(clearCategory: true);
      } else {
        _filter = _filter.copyWith(
          selectedCategory: planCategories[index - 1].label,
        );
      }
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

  List<Widget> _buildContent() {
    if (_loading) {
      return [
        const SizedBox(height: 200),
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      ];
    }

    if (_error != null) {
      return [
        const SizedBox(height: 200),
        Icon(Icons.wifi_off_rounded, size: 48, color: const Color(0xFF9DB2E8)),
        const SizedBox(height: 20),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFFB9C3DC)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ];
    }

    final processed = applyPipeline(_allPlans, _filter);
    final sections = sectionsFor(processed, maxDistanceKm: _maxDistanceKm);
    final hasResults = processed.isNotEmpty;

    return [
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
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Discover experiences worth showing up for.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB9C3DC),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _MyPlansPill(
              onTap: () async {
                await Navigator.of(context).push<void>(myPlansRoute());
                if (!mounted) return;
                await _refresh();
              },
            ),
          ],
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
                created: _createdPlans,
                recentlyVisited: _recentlyVisited,
                onOpen: _openPlan,
              )
            : const _EmptyView(key: ValueKey('plans-empty')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/plans/plan.PNG',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: .35),
            ),
          ),
          RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF8B5CF6),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 110),
              children: _buildContent(),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 100,
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
    required this.created,
    required this.recentlyVisited,
    required this.onOpen,
    super.key,
  });

  final Experience hero;
  final Map<String, List<Experience>> sections;
  final List<Experience> created;
  final List<Experience> recentlyVisited;

  /// Opens a plan's details. Provided by the screen so it can await the route
  /// and refresh the viewer-specific feed on return. Reusable cards + hero
  /// only expose callbacks; navigation + refresh live in the screen layer.
  final void Function(Experience) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: FeaturedHero(
            experience: hero,
            onOpen: () => onOpen(hero),
          ),
        ),
        if (sections['featured'] != null && sections['featured']!.isNotEmpty)
          ExperienceRail(
            title: '⭐ Featured',
            items: sections['featured']!,
            variant: CardVariant.immersive,
            onOpen: onOpen,
          ),
        if (sections['featured'] != null && sections['featured']!.isNotEmpty)
          const SizedBox(height: 30),
        if (sections['tonight'] != null && sections['tonight']!.isNotEmpty)
          ExperienceRail(
            title: '🌙 Tonight',
            items: sections['tonight']!,
            variant: CardVariant.stacked,
            height: 400,
            onOpen: onOpen,
          ),
        if (sections['tonight'] != null && sections['tonight']!.isNotEmpty)
          const SizedBox(height: 30),
        if (sections['private'] != null && sections['private']!.isNotEmpty)
          ExperienceRail(
            title: '🔒 Private',
            items: sections['private']!,
            variant: CardVariant.immersive,
            onOpen: onOpen,
          ),
        if (sections['private'] != null && sections['private']!.isNotEmpty)
          const SizedBox(height: 30),
        ExperienceRail(
          title: '🔥 Trending',
          items: sections['trending'] ?? const [],
          variant: CardVariant.immersive,
          onOpen: onOpen,
        ),
        const SizedBox(height: 30),
        ExperienceRail(
          title: '📍 Near You',
          items: sections['near'] ?? const [],
          variant: CardVariant.stacked,
          height: 400,
          onOpen: onOpen,
        ),

        const SizedBox(height: 30),
        ExperienceRail(
          title: '👥 Friends Joined',
          items: sections['friends'] ?? const [],
          variant: CardVariant.compact,
          height: 300,
          cardWidth: 260,
          onOpen: onOpen,
        ),
        const SizedBox(height: 30),
        if (created.isNotEmpty)
          ExperienceRail(
            title: '✨ Created',
            items: created,
            variant: CardVariant.immersive,
            onOpen: onOpen,
          ),
        if (created.isNotEmpty) const SizedBox(height: 30),
        if (recentlyVisited.isNotEmpty)
          ExperienceRail(
            title: '🕒 Recently Visited',
            items: recentlyVisited,
            variant: CardVariant.stacked,
            height: 360,
            onOpen: onOpen,
          ),
        if (recentlyVisited.isNotEmpty) const SizedBox(height: 30),
        ExperienceRail(
          title: '🆕 New',
          items: sections['new'] ?? const [],
          variant: CardVariant.immersive,
          onOpen: onOpen,
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

/// A compact glass "My Plans" pill in the header. Navigation lives in the
/// Plans screen layer, so this only exposes the tap intent.
class _MyPlansPill extends StatefulWidget {
  const _MyPlansPill({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_MyPlansPill> createState() => _MyPlansPillState();
}

class _MyPlansPillState extends State<_MyPlansPill> {
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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 16,
                color: Color(0xFFB7A5FF),
              ),
              SizedBox(width: 7),
              Text(
                'My Plans',
                style: TextStyle(
                  fontSize: 12.5,
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


