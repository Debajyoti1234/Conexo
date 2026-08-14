import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_data.dart';
import 'profile_repository.dart';
import 'profile_strength_data.dart';
import 'profile_strength_sections.dart';
import 'session_aware_profile_repository.dart';

/// The complete Profile Strength & Completion screen (Phase 4.4).
///
/// Loads the finalized [UserProfile] through the injected [ProfileRepository]
/// and derives a [ProfileStrengthResult] using ONLY the pure
/// [computeProfileStrength] engine. Everything shown (ring, tier, score,
/// checklist, missing items, suggestions, breakdown) is driven by that single
/// computed result. There are NO editable fields — it is a read-only quality
/// dashboard.
///
/// Local-only: no backend / Firebase / networking / new packages. Per the
/// approved plan, the only [TweenAnimationBuilder] lives inside the ring widget;
/// this screen uses EntranceFade + Fade/Slide route transitions.
class ProfileStrengthScreen extends StatefulWidget {
  const ProfileStrengthScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

  /// Injected repository (defaults to local). A future backend repository can
  /// be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<ProfileStrengthScreen> createState() => _ProfileStrengthScreenState();
}

class _ProfileStrengthScreenState extends State<ProfileStrengthScreen> {
  bool _loading = true;
  bool _notFound = false;
  ProfileStrengthResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _loading = false;
        _notFound = true;
      });
      return;
    }
    // The screen computes strength ONLY through the pure engine.
    final result = computeProfileStrength(profile);
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.black : Colors.transparent,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }
    if (_notFound || _result == null) {
      return _EmptyState(
        key: const ValueKey('empty'),
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    return _buildContent(_result!);
  }

  Widget _buildContent(ProfileStrengthResult result) {
    return ListView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _header(),
        const SizedBox(height: 8),
        EntranceFade(child: OverallStrengthSection(result: result)),
        const SizedBox(height: 28),
        EntranceFade(child: CompletionChecklistSection(result: result)),
        const SizedBox(height: 28),
        EntranceFade(child: SuggestionsSection(result: result)),
        const SizedBox(height: 28),
        EntranceFade(child: MissingInformationSection(result: result)),
        const SizedBox(height: 28),
        EntranceFade(
          child: RepaintBoundary(child: ScoreBreakdownSection(result: result)),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Strength',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'See how complete your profile is.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (no saved profile) ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EntranceFade(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 56,
                color: Color(0xFFB9C3DC),
              ),
              const SizedBox(height: 16),
              const Text(
                'No profile yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your profile first to see your strength and completion.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFB9C3DC)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Route (matches Conexo's premium fade + slide transition) ────────────────

/// Premium route into the Profile Strength & Completion screen.
///
/// Uses the same fade + slide transition language as the other Profile routes
/// for a consistent feel across Conexo.
Route<void> premiumProfileStrengthRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ProfileStrengthScreen(
      repository: repository ?? const SessionAwareProfileRepository(),
    ),
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
