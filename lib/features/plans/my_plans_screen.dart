import 'package:flutter/material.dart';

import 'create_plan_data.dart';
import 'create_plan_screen.dart';
import 'my_plans_data.dart';
import 'my_plans_sections.dart';
import 'my_plans_widgets.dart';
import 'plan_details_screen.dart';
import 'plan_repository.dart';
import 'plans_data.dart';
import 'plans_widgets.dart';

/// The premium My Plans management experience (Phase 3.4).
///
/// Manages everything the local user has hosted, joined, archived, or saved as
/// a draft. The screen is the single source of truth: it owns the selected tab
/// + time filter and derives every list from the shared [applyPipeline] via
/// [sortMyPlans], mirroring the Plans discovery architecture. All persistence
/// flows through the injected [PlanRepository]; no direct SharedPreferences.
///
/// Local + demo only. No backend, no navigation-graph changes, no request
/// logic — actions confirm intent through premium glass dialogs.
class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key, this.repository = const LocalPlanRepository()});

  /// Injected so a future backend repository can replace the local one with
  /// zero UI change.
  final PlanRepository repository;

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  MyPlansTab _tab = MyPlansTab.hosting;
  MyPlansFilter? _filter;

  // Local, in-memory management state layered over the demo dataset. These
  // sets track which plans the user archived / left so the UI reacts without a
  // backend. Ids reference [Experience.id].
  final Set<String> _archivedIds = {};
  final Set<String> _leftIds = {};

  // Locally published plans + the saved draft, loaded through the repository.
  List<PublishedPlan> _published = const [];
  PlanDraft? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final published = await widget.repository.loadPublished();
    final draft = await widget.repository.loadDraft();
    if (!mounted) return;
    setState(() {
      _published = published;
      _draft = draft;
      _loading = false;
    });
  }

  // ── Derived lists (single pipeline is the source of truth) ────────────

  List<Experience> get _hosting {
    final published = _published.map(publishedToExperience);
    final demo = demoHostedPlans();
    final all = [...published, ...demo]
        .where((e) => !_archivedIds.contains(e.id))
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> get _joined {
    final all = demoJoinedPlans()
        .where((e) => !_leftIds.contains(e.id) && !_archivedIds.contains(e.id))
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> get _archived {
    final published = _published.map(publishedToExperience);
    final all = [...published, ...demoHostedPlans(), ...demoJoinedPlans()]
        .where((e) => _archivedIds.contains(e.id))
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> _applyTimeFilter(List<Experience> list) {
    final f = _filter;
    if (f == null) return list;
    return list.where((e) => matchesFilter(e, f)).toList();
  }

  MyPlansInsights get _insights => MyPlansInsights.compute(
        hosted: _hosting,
        joined: _joined,
      );

  // ── Actions (local + demo, confirmed through glass dialogs) ───────────

  void _open(Experience e) {
    Navigator.of(context).push(premiumPlanRoute(e));
  }

  Future<void> _archive(Experience e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Archive plan?',
      message: '"${e.title}" will move to your Archived tab. '
          'You can restore it anytime.',
      confirmLabel: 'Archive',
    );
    if (ok) setState(() => _archivedIds.add(e.id));
  }

  void _restore(Experience e) {
    setState(() => _archivedIds.remove(e.id));
  }

  Future<void> _leave(Experience e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Leave plan?',
      message: 'You will be removed from "${e.title}".',
      confirmLabel: 'Leave',
      danger: true,
    );
    if (ok) setState(() => _leftIds.add(e.id));
  }

  Future<void> _deleteDraft() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete draft?',
      message: 'Your saved draft will be permanently removed.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await widget.repository.clearDraft();
    if (!mounted) return;
    setState(() => _draft = null);
  }

  Future<void> _resumeDraft() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
    );
    // Reload after returning so any edits are reflected.
    await _load();
  }

  Future<void> _createPlan() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(child: InsightsRow(insights: _insights)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: MyPlansTabBar(
                  selected: _tab,
                  onSelected: (t) => setState(() => _tab = t),
                ),
              ),
              // The time filter is only relevant for plan lists, not drafts.
              if (_tab != MyPlansTab.drafts) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: MyPlansFilterBar(
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 24,
            child: CreatePlanButton(onTap: _createPlan),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    // Gentle fade between tabs — premium, never abrupt.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey('${_tab}_$_filter'),
        child: _sectionForTab(),
      ),
    );
  }

  Widget _sectionForTab() {
    switch (_tab) {
      case MyPlansTab.hosting:
        return HostingList(
          items: _hosting,
          onOpen: _open,
          onEdit: (e) => showEditPlanDialog(context, e.title),
          onShare: (e) => showSharePlanDialog(context, e.title),
          onArchive: _archive,
        );
      case MyPlansTab.joined:
        return JoinedList(
          items: _joined,
          onOpen: _open,
          onShare: (e) => showSharePlanDialog(context, e.title),
          onLeave: _leave,
        );
      case MyPlansTab.archived:
        return ArchivedList(
          items: _archived,
          onOpen: _open,
          onRestore: _restore,
        );
      case MyPlansTab.drafts:
        return DraftsList(
          draft: _draft,
          onResume: _resumeDraft,
          onDelete: _deleteDraft,
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Plans',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Everything you host, join, and save — all in one place.',
            style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
          ),
        ],
      ),
    );
  }
}

/// A premium fade + slide route into [MyPlansScreen].
///
/// Navigation lives in the Plans layer; this helper is called from the Plans
/// discovery header so reusable widgets stay free of navigation logic.
Route<void> myPlansRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const MyPlansScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
