import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_discovery_animations.dart';
import 'home_discovery_connect.dart';
import 'home_discovery_data.dart';
import 'home_discovery_profile.dart';
import 'home_discovery_skeleton.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  ConnectPhase _connectPhase = ConnectPhase.none;
  int _direction = 1;
  String _selectedFilter = 'All';
  bool _loading = false;
  Timer? _loadTimer;
  Timer? _pendingTimer;
  Timer? _connectedTimer;

  /// The people currently visible for the selected filter. Filtering is a pure,

  /// local operation over the existing demo data — no backend, no persistence.
  List<DiscoveryPerson> get _visiblePeople =>
      filterDiscoveryPeople(peopleAroundYou, _selectedFilter);

  @override
  void dispose() {
    _loadTimer?.cancel();
    _pendingTimer?.cancel();
    _connectedTimer?.cancel();
    super.dispose();
  }

  void _move(int direction) {
    final people = _visiblePeople;
    if (people.isEmpty) return;
    _loadTimer?.cancel();
    _pendingTimer?.cancel();
    _connectedTimer?.cancel();
    setState(() {
      _direction = direction;
      _index = (_index + direction + people.length) % people.length;
      _connectPhase = ConnectPhase.none;
      _loading = true;
    });
    _loadTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  /// Applies a filter selection, safely resetting the visible index and
  /// replaying the brief loading transition so the switch feels premium.
  void _selectFilter(String filter) {
    if (filter == _selectedFilter) return;
    _loadTimer?.cancel();
    _pendingTimer?.cancel();
    _connectedTimer?.cancel();
    setState(() {
      _selectedFilter = filter;
      _direction = 1;
      _index = 0;
      _connectPhase = ConnectPhase.none;
      _loading = filterDiscoveryPeople(peopleAroundYou, filter).isNotEmpty;
    });
    if (_loading) {
      _loadTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _loading = false);
      });
    }
  }


  /// One-tap connect: heart burst → Request Sent (pending) → automatic demo
  /// approval → Connected. No confirmation dialog.
  void _sendRequest() {
    if (_connectPhase != ConnectPhase.none) return;
    HapticFeedback.lightImpact();
    setState(() => _connectPhase = ConnectPhase.sending);
    _pendingTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _connectPhase = ConnectPhase.pending);
      _connectedTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _connectPhase = ConnectPhase.connected);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = _visiblePeople;
    final hasPeople = people.isNotEmpty;
    final safeIndex = hasPeople ? _index.clamp(0, people.length - 1) : 0;
    final person = hasPeople ? people[safeIndex] : null;
    final counterLabel = 'Nearby • ${safeIndex + 1} / ${people.length}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Align(
                key: ValueKey<int>(DateTime.now().hour),
                alignment: Alignment.centerLeft,
                child: Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: GestureDetector(
                onLongPress: () => _showFilters(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _discoveryFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _discoveryFilters[index];
                    return _DiscoveryFilterChip(
                      key: ValueKey<String>('filter_$filter'),
                      label: filter,
                      selected: _selectedFilter == filter,
                      onTap: () => _selectFilter(filter),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final fade = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(_direction * 0.12, 0),
                            end: Offset.zero,
                          ).animate(fade),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .985, end: 1).animate(
                              fade,
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _loading
                        ? const ProfileSkeleton(
                            key: ValueKey<String>('skeleton'),
                          )
                        : person == null
                        ? _DiscoveryEmptyState(
                            key: const ValueKey<String>('empty'),
                            filter: _selectedFilter,
                            onReset: () => _selectFilter('All'),
                          )
                        : ImmersiveProfileView(
                            key: ValueKey<String>('${person.name}_$safeIndex'),
                            person: person,
                            counterLabel: counterLabel,
                            connectPhase: _connectPhase,
                          ),
                  ),
                  if (_connectPhase == ConnectPhase.sending)
                    const Center(
                      child: HeartBurst(
                        key: ValueKey<String>('heart-burst'),
                        onCompleted: _noop,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DiscoveryControls(
              connectPhase: _connectPhase,
              onPrevious: () => _move(-1),
              onNext: () => _move(1),
              onConnect: _sendRequest,
            ),
          ],
        ),
      ),
    );
  }


  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 22) return 'Still Awake? 🌌';
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤';
    return 'Good Evening 🌙';
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      ),
      builder: (_) => const _FilterPreferencesSheet(),
    );
  }
}

class _FilterPreferencesSheet extends StatelessWidget {
  const _FilterPreferencesSheet();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
    decoration: BoxDecoration(
      color: const Color(0xFF172039).withValues(alpha: .97),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Center(child: SizedBox(width: 38, child: Divider(thickness: 3))),
          SizedBox(height: 20),
          Text(
            'Discovery preferences',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 20),
          _PreferenceGroup(
            title: 'Distance',
            values: ['1 km', '3 km', '5 km', '10 km'],
          ),
          _PreferenceGroup(
            title: 'Availability',
            values: ['Available Now', 'Today', 'This Week'],
          ),
          _PreferenceGroup(
            title: 'Verification',
            values: ['Verified Only', 'Everyone'],
          ),
          _PreferenceGroup(
            title: 'Sort',
            values: ['Closest', 'Best Match', 'Recently Joined', 'Most Active'],
          ),
        ],
      ),
    ),
  );
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({required this.title, required this.values});
  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) => Chip(label: Text(value))).toList(),
        ),
      ],
    ),
  );
}

const _discoveryFilters = <String>[
  'All',
  'Nearby',
  'Coffee',
  'Walk',
  'Music',
  'Study',
  'Verified',
  'Available Now',
  'New',
  'Shared Interests',
];

/// Keyword sets used to map a category chip to the existing [DiscoveryPerson]
/// interest/lifestyle vocabulary in the demo data. Matching is case-insensitive
/// and substring-based so related terms (e.g. "Cafes" → "Coffee") still hit.
const _kFilterKeywords = <String, List<String>>{
  'Coffee': ['coffee', 'cafe', 'espresso', 'chai', 'tea'],
  'Walk': ['walk', 'walking', 'hiking', 'trek', 'running', 'run'],
  'Music': ['music', 'singing', 'jazz', 'vinyl', 'songwriter', 'podcast'],
  'Study': ['book', 'reading', 'writing', 'poetry', 'chess', 'journaling'],
};

/// Pure, local filter over the demo [people] for a given [filter] chip.
///
/// This never touches a backend, repository, or persistence — it simply narrows
/// the visible list using fields already present on [DiscoveryPerson].
List<DiscoveryPerson> filterDiscoveryPeople(
  List<DiscoveryPerson> people,
  String filter,
) {
  switch (filter) {
    case 'All':
      return people;
    case 'Nearby':
      return [
        for (final p in people)
          if (_distanceMeters(p.distance) <= 1500) p,
      ];
    case 'Verified':
      return [
        for (final p in people)
          if (p.verified) p,
      ];
    case 'Available Now':
      return [
        for (final p in people)
          if (p.availability.toLowerCase().contains('available now')) p,
      ];
    case 'New':
      return [
        for (final p in people)
          if (p.introduction.toLowerCase().contains('new here') ||
              p.introduction.toLowerCase().contains('new to'))
            p,
      ];
    case 'Shared Interests':
      return [
        for (final p in people)
          if (p.mutualInterests.isNotEmpty) p,
      ];
    default:
      final keywords = _kFilterKeywords[filter];
      if (keywords == null) return people;
      return [
        for (final p in people)
          if (_matchesKeywords(p, keywords)) p,
      ];
  }
}

/// Whether any of the person's textual interest fields contain one of the
/// [keywords] (case-insensitive substring match).
bool _matchesKeywords(DiscoveryPerson person, List<String> keywords) {
  final haystack = <String>[
    ...person.tags,
    ...person.mutualInterests,
    ...person.lifestyle,
    person.introduction,
    person.lookingFor,
  ].join(' ').toLowerCase();
  for (final k in keywords) {
    if (haystack.contains(k)) return true;
  }
  return false;
}

/// Parses a demo distance label (e.g. "800m away", "1.4 km away") into meters.
/// Returns a large value when it cannot be parsed so it is excluded from
/// "Nearby".
double _distanceMeters(String distance) {
  final lower = distance.toLowerCase();
  final match = RegExp(r'([\d.]+)').firstMatch(lower);
  if (match == null) return double.infinity;
  final value = double.tryParse(match.group(1) ?? '');
  if (value == null) return double.infinity;
  return lower.contains('km') ? value * 1000 : value;
}

/// A premium empty state shown when the active filter matches nobody. Reuses
/// the existing dark-glass language and the [EntranceFade] entrance motion.
class _DiscoveryEmptyState extends StatelessWidget {
  const _DiscoveryEmptyState({
    required this.filter,
    required this.onReset,
    super.key,
  });

  final String filter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: EntranceFade(
        offset: const Offset(0, 0.06),
        scaleFrom: 0.98,
        duration: const Duration(milliseconds: 460),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: .12),
                        Colors.white.withValues(alpha: .04),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    size: 42,
                    color: Color(0xFFB7A5FF),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'No one matches "$filter" nearby',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Try a different filter to see more people around you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFAEB9D6),
                  ),
                ),
                const SizedBox(height: 22),
                _EmptyStateResetButton(onTap: onReset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateResetButton extends StatelessWidget {
  const _EmptyStateResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: .4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Show everyone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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


class _DiscoveryFilterChip extends StatelessWidget {
  const _DiscoveryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 240),
    decoration: BoxDecoration(
      color: selected
          ? const Color(0xFF7C3AED)
          : Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white.withValues(alpha: selected ? .0 : .12),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Heart-burst completion hook. The burst fades out by itself; no rebuild is
/// required once it completes because the phase transition is timer-driven.
void _noop() {}
