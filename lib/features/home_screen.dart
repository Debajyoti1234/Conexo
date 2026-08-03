import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void dispose() {
    _loadTimer?.cancel();
    _pendingTimer?.cancel();
    _connectedTimer?.cancel();
    super.dispose();
  }

  void _move(int direction) {
    _loadTimer?.cancel();
    _pendingTimer?.cancel();
    _connectedTimer?.cancel();
    setState(() {
      _direction = direction;
      _index =
          (_index + direction + peopleAroundYou.length) %
          peopleAroundYou.length;
      _connectPhase = ConnectPhase.none;
      _loading = true;
    });
    _loadTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _loading = false);
    });
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
    final person = peopleAroundYou[_index];
    final counterLabel = 'Nearby • ${_index + 1} / ${peopleAroundYou.length}';
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
            const SizedBox(height: 10),
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
                      label: filter,
                      selected: _selectedFilter == filter,
                      onTap: () => setState(() => _selectedFilter = filter),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                        : ImmersiveProfileView(
                            key: ValueKey<String>(person.name),
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

class _DiscoveryFilterChip extends StatelessWidget {
  const _DiscoveryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
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
