import 'dart:io';

import 'package:flutter/material.dart';

import 'create_plan_data.dart';
import 'create_plan_screen.dart';
import 'my_plans_data.dart';
import 'my_plans_sections.dart';
import 'my_plans_widgets.dart';
import 'plan_details_screen.dart';
import 'plan_details_widgets.dart';
import 'plan_repository.dart';
import 'plans_data.dart';
import 'plans_widgets.dart';
import 'supabase_plan_repository.dart';

import '../../core/supabase/auth_service.dart';

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
  const MyPlansScreen({super.key, this.repository = const SupabasePlanRepository()});

  /// Injected so a future backend repository can replace the local one with
  /// zero UI change.
  final PlanRepository repository;

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  MyPlansTab _tab = MyPlansTab.hosting;
  MyPlansFilter? _filter;

  final Set<String> _leftIds = {};

  List<Experience> _publishedExperiences = const [];
  List<Experience> _joinedExperiences = const [];
  List<Experience> _requestedExperiences = const [];
  PlanDraft? _draft;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final publishedExperiences = await widget.repository.getPublishedExperiences();
      final joinedExperiences = await widget.repository.getJoinedExperiences();
      final requestedExperiences = await widget.repository.getRequestedExperiences();
      final draft = await widget.repository.loadDraft();
      if (!mounted) return;

      final allExperiences = [
        ...publishedExperiences,
        ...joinedExperiences,
        ...requestedExperiences,
      ];
      for (final e in allExperiences.take(8)) {
        final asset = e.coverAsset;
        if (asset.startsWith('http://') || asset.startsWith('https://')) {
          try {
            // ignore: use_build_context_synchronously
            await precacheImage(NetworkImage(asset), context);
          } catch (_) {}
        } else if (asset.startsWith('assets/')) {
        } else if (asset.startsWith('plans/')) {
        } else if (asset.isNotEmpty) {
          try {
            // ignore: use_build_context_synchronously
            await precacheImage(FileImage(File(asset)), context);
          } catch (_) {}
        }
      }

      setState(() {
        _publishedExperiences = publishedExperiences;
        _joinedExperiences = joinedExperiences;
        _requestedExperiences = requestedExperiences;
        _draft = draft;
        _loading = false;
        _error = null;
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

  // ── Derived lists (single pipeline is the source of truth) ────────────

  List<Experience> get _hosting {
    final published = _publishedExperiences;
    final all = published
        .where((e) => e.status == 'active')
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> get _joined {
    final all = _joinedExperiences
        .where((e) => !_leftIds.contains(e.id) && e.status == 'active')
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> get _requested {
    final all = _requestedExperiences
        .where((e) => e.status == 'active')
        .toList();
    return _applyTimeFilter(sortMyPlans(all));
  }

  List<Experience> get _archived {
    final published = _publishedExperiences;
    final all = published
        .where((e) => e.status == 'archived')
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
    if (ok != true || !mounted) return;
    try {
      await widget.repository.archivePlan(e.id);
      if (!mounted) return;
      await _load();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to archive plan. Please try again.'),
          backgroundColor: Color(0xFFFF4D8D),
        ),
      );
    }
  }

  Future<void> _restore(Experience e) async {
    try {
      await widget.repository.restorePlan(e.id);
      if (!mounted) return;
      await _load();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to restore plan. Please try again.'),
          backgroundColor: Color(0xFFFF4D8D),
        ),
      );
    }
  }

  Future<void> _delete(Experience e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete plan permanently?',
      message: '"${e.title}" and its Plan Chat history will be permanently removed. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.deletePlan(e.id);
      if (!mounted) return;
      await _load();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete plan. Please try again.'),
          backgroundColor: Color(0xFFFF4D8D),
        ),
      );
    }
  }

  Future<void> _leave(Experience e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Leave plan?',
      message: 'You will be removed from "${e.title}".',
      confirmLabel: 'Leave',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.leavePlan(e.id);
      if (!mounted) return;
      await _load();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave plan. Please try again.'),
          backgroundColor: Color(0xFFFF4D8D),
        ),
      );
    }
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

  Future<void> _edit(Experience e) async {
    try {
      final plan = await widget.repository.getPublishedPlan(e.id);
      if (!mounted || plan == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CreatePlanScreen(existingPlan: plan),
        ),
      );
      await _load();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/plans/myplan.PNG',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: .35),
              ),
            ),
            RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF8B5CF6),
              strokeWidth: 2.2,
              displacement: 8,
              child: CustomScrollView(
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
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: CreatePlanButton(onTap: _createPlan),
            ),
          ],
        ),
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

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9DB2E8)),
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
          ],
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
          onEdit: _edit,
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
      case MyPlansTab.requested:
        return RequestedList(
          items: _requested,
          onOpen: _open,
        );
      case MyPlansTab.archived:
        return ArchivedList(
          items: _archived,
          onOpen: _open,
          onRestore: _restore,
          onDelete: _delete,
        );
      case MyPlansTab.drafts:
        return DraftsList(
          draft: _draft,
          onResume: _resumeDraft,
          onDelete: _deleteDraft,
          resolveCoverUrl: widget.repository.getCoverSignedUrl,
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 22),
      child: Row(
        children: [
          CircleGlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
            semanticLabel: 'Back',
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My Plans',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
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
