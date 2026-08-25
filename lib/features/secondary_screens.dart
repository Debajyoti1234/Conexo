import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'chat/connections_screen.dart';
import 'home_connection_dashboard.dart';
import 'plans/plan_repository.dart';
import 'plans/plans_screen.dart';
import 'plans/supabase_plan_repository.dart';
import 'profile/my_profile_screen.dart';
import 'profile/profile_creation_screen.dart';
import 'profile/profile_repository.dart';
import 'profile/session_aware_profile_repository.dart';
import 'social_components.dart';




class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Discover people',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find small plans with people who share your rhythm.',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
          const SizedBox(height: 24),
          const PlanSearchBar(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              InterestChip(
                label: 'Tonight',
                icon: Icons.nightlight_round,
                selected: true,
              ),
              InterestChip(label: 'Close by', icon: Icons.near_me_outlined),
              InterestChip(
                label: 'This week',
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SectionHeader('Plans made for you'),
          const SizedBox(height: 14),
          for (final plan in nearbyPlans) ...[
            HostCard(plan: plan, onJoin: () {}),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConnectionsDashboard(),
      ),
    );
  }
}


class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key, this.repository = const SupabasePlanRepository()});

  final PlanRepository repository;

  @override
  Widget build(BuildContext context) {
    return _ScreenFrame(child: PlansDiscoveryScreen(repository: repository));
  }
}


class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ScreenFrame(child: ConnectionsInboxScreen());
  }
}

/// The Profile tab entry point.
///
/// A UI/navigation surface only: it asks the injected [ProfileRepository]
/// whether a finalized profile exists and routes accordingly.
///
///  • No profile → a premium welcome screen with a single **Create Profile**
///    CTA into the existing `premiumProfileCreationRoute()`. After a successful
///    creation, it always opens **My Profile**.
///  • Profile exists → **My Profile** is shown directly (the Tinder/Bumble-style
///    [MyProfileScreen]).
///
/// It never rebuilds profile features; it only connects already-built screens.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

  /// Injected repository (defaults to the local implementation). A future
  /// backend repository can be supplied without changing this screen.
  final ProfileRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    setState(() {
      _hasProfile = profile != null;
      _loading = false;
    });
  }

  /// Opens Profile Creation. On successful creation, always opens My Profile.
  Future<void> _openCreation() async {
    await Navigator.of(context).push(premiumProfileCreationRoute(
      repository: widget.repository,
    ));
    if (!mounted) return;
    final created = await widget.repository.hasProfile();
    if (!mounted) return;
    if (created) {
      setState(() => _hasProfile = true);
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _ScreenFrame(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    // Profile exists → My Profile directly (its own full-bleed hero layout, so
    // it is not wrapped in the constrained _ScreenFrame).
    if (_hasProfile) {
      return MyProfileScreen(repository: widget.repository);
    }

    // No profile → premium welcome with a single Create Profile CTA.
    return _ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [_ProfileWelcomeCard(onCreate: _openCreation)],
      ),
    );
  }
}

/// Shown to first-time users with no saved profile — a single Create Profile
/// CTA into the existing Profile Creation flow.
class _ProfileWelcomeCard extends StatelessWidget {
  const _ProfileWelcomeCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 30,
              color: Color(0xFFB7A5FF),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Create your profile',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up a premium presence so people can find and connect with you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
          const SizedBox(height: 22),
          ConexoButton(label: 'Create Profile', onPressed: onCreate),
        ],
      ),
    );
  }
}


class HostPlanScreen extends StatelessWidget {
  const HostPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host a Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Make a little room for new people.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Plan title',
              hintText: 'Coffee and a good conversation',
            ),
          ),
          const SizedBox(height: 18),
          const GlassCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_rounded),
                  title: Text('Time'),
                  subtitle: Text('Today - 7:00 PM'),
                ),
                Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('Location'),
                  subtitle: Text('Choose a public place'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Publish Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: child,
      ),
    ),
  );
}

