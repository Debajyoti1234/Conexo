import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/supabase/auth_service.dart';
import 'home_discovery_animations.dart';
import 'home_discovery_connect.dart';
import 'home_discovery_profile.dart';
import 'home_discovery_skeleton.dart';
import 'profile/connection_data.dart';
import 'profile/connection_repository.dart';
import 'profile/discovery_data.dart';
import 'profile/discovery_repository.dart';
import 'profile/discovery_helpers.dart';
import 'profile/public_profile_screen.dart';
import 'profile/profile_navigation_mapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _direction = 1;
  String _selectedFilter = 'All';
  DiscoverySortMode _sortMode = DiscoverySortMode.closest;
  bool _loading = false;
  List<DiscoveryProfile> _profiles = const [];
  bool _fetchError = false;
  Timer? _loadTimer;
  final Map<String, Connection?> _connections = {};
  final Map<String, bool> _connecting = {};
  String? _connectionError;
  final ConnectionRepository _connectionRepository = const ConnectionRepository();

  List<DiscoveryProfile> get _visibleProfiles =>
      _applyDiscoveryProfileFilter(_profiles, _selectedFilter);

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _fetchError = false;
      _profiles = const [];
      _index = 0;
      _connections.clear();
      _connecting.clear();
      _connectionError = null;
    });
    try {
      final repository = const DiscoveryRepository();
      final profiles = await repository.fetchNearby(sort: _sortMode);
      if (!mounted) return;
      await _loadConnectionStates(profiles);
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fetchError = true;
        });
      }
    }
  }

  Future<void> _loadConnectionStates(List<DiscoveryProfile> profiles) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final repo = _connectionRepository;
    for (final profile in profiles) {
      final result = await repo.getConnectionBetween(user.id, profile.id);
      if (result.isSuccess && result.value != null) {
        if (mounted) {
          setState(() {
            _connections[profile.id] = result.value;
          });
        }
      }
    }
  }

  void _move(int direction) {
    final profiles = _visibleProfiles;
    if (profiles.isEmpty) return;
    _loadTimer?.cancel();
    setState(() {
      _direction = direction;
      _index = (_index + direction + profiles.length) % profiles.length;
      _connectionError = null;
    });
  }

  void _selectFilter(String filter) {
    if (filter == _selectedFilter) return;
    _loadTimer?.cancel();
    setState(() {
      _selectedFilter = filter;
      _direction = 1;
      _index = 0;
      _connectionError = null;
      _loading = _applyDiscoveryProfileFilter(_profiles, filter).isNotEmpty;
    });
    if (_loading) {
      _loadTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  void _selectSortMode(DiscoverySortMode mode) {
    if (mode == _sortMode) return;
    setState(() {
      _sortMode = mode;
    });
    _loadProfiles();
  }

  Future<void> _sendRequest(String profileId) async {
    if (_connecting[profileId] == true) return;
    final existing = _connections[profileId];
    if (existing != null && existing.isAccepted) return;

    setState(() {
      _connecting[profileId] = true;
      _connectionError = null;
    });

    final result = await _connectionRepository.sendRequest(profileId);
    if (!mounted) return;

    if (result.isSuccess && result.value != null) {
      setState(() {
        _connections[profileId] = result.value;
      });
    } else {
      setState(() {
        _connecting[profileId] = false;
        _connectionError = result.error;
      });
    }
  }

  void _onConnectCompleted(String profileId) {
    if (!mounted) return;
    setState(() {
      _connecting[profileId] = false;
      _profiles.removeWhere((p) => p.id == profileId);
      if (_profiles.isEmpty) {
        _index = 0;
      } else if (_index >= _profiles.length) {
        _index = _profiles.length - 1;
      }
    });
  }

  void _openProfile(DiscoveryProfile profile) {
    final data = mapDiscoveryProfileToProfile(profile);
    Navigator.of(context).push(premiumPublicProfileRoute(data: data));
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _visibleProfiles;
    final hasProfiles = profiles.isNotEmpty;
    final safeIndex = hasProfiles ? _index.clamp(0, profiles.length - 1) : 0;
    final profile = hasProfiles ? profiles[safeIndex] : null;
    final counterLabel = profile == null
        ? 'Nearby'
        : 'Nearby • ${safeIndex + 1} / ${profiles.length}';
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
                        : _fetchError && _profiles.isEmpty
                        ? _DiscoveryErrorState(
                            key: const ValueKey<String>('error'),
                            onRetry: _loadProfiles,
                          )
                        : profile == null
                        ? _DiscoveryEmptyState(
                            key: const ValueKey<String>('empty'),
                            filter: _selectedFilter,
                            onReset: () => _selectFilter('All'),
                          )
                        : ImmersiveProfileView(
                            key: ValueKey<String>('${profile.name}_$safeIndex'),
                            profile: profile,
                            counterLabel: counterLabel,
                            connection: _connections[profile.id],
                            connecting: _connecting[profile.id] ?? false,
                            connectionError: _connectionError,
                            onConnect: () => _sendRequest(profile.id),
                            onProfileTap: () => _openProfile(profile),
                          ),
                  ),
                  if (profile != null && _connecting[profile.id] == true)
                    Center(
                      child: HeartBurst(
                        key: ValueKey<String>('heart-burst-${profile.id}'),
                        onCompleted: () => _onConnectCompleted(profile.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DiscoveryControls(
              connection: _connections[profile?.id],
              connecting: _connecting[profile?.id] ?? false,
              onPrevious: () => _move(-1),
              onNext: () => _move(1),
              onConnect: () => _sendRequest(profile!.id),
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
      builder: (_) => _FilterPreferencesSheet(
        sortMode: _sortMode,
        onSortChanged: _selectSortMode,
      ),
    );
  }
}

class _FilterPreferencesSheet extends StatelessWidget {
  const _FilterPreferencesSheet({
    required this.sortMode,
    required this.onSortChanged,
  });

  final DiscoverySortMode sortMode;
  final ValueChanged<DiscoverySortMode> onSortChanged;

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
        children: [
          const Center(child: SizedBox(width: 38, child: Divider(thickness: 3))),
          const SizedBox(height: 20),
          const Text(
            'Discovery preferences',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          const _PreferenceGroup(
            title: 'Distance',
            values: ['1 km', '3 km', '5 km', '10 km'],
          ),
          const _PreferenceGroup(
            title: 'Availability',
            values: ['Available Now', 'Today', 'This Week'],
          ),
          const _PreferenceGroup(
            title: 'Verification',
            values: ['Verified Only', 'Everyone'],
          ),
          _PreferenceGroup(
            title: 'Sort',
            values: ['Closest', 'Best Match', 'Recently Joined', 'Most Active'],
            selected: sortMode,
            onChanged: onSortChanged,
          ),
        ],
      ),
    ),
  );
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({
    required this.title,
    required this.values,
    this.selected,
    this.onChanged,
  });

  final String title;
  final List<String> values;
  final DiscoverySortMode? selected;
  final ValueChanged<DiscoverySortMode>? onChanged;

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
          children: values.map((value) {
            final mode = _sortModeFromLabel(value);
            final isSelected = mode != null && mode == selected;
            final isMostActiveDisabled = value == 'Most Active';
            return ChoiceChip(
              label: Text(value),
              selected: isSelected,
              onSelected: isMostActiveDisabled
                  ? null
                  : (onChanged != null && mode != null)
                      ? (bool selected) {
                          if (selected && onChanged != null) {
                            onChanged!(mode);
                          }
                        }
                      : null,
            );
          }).toList(),
        ),
      ],
    ),
  );
}

DiscoverySortMode? _sortModeFromLabel(String label) {
  switch (label) {
    case 'Closest':
      return DiscoverySortMode.closest;
    case 'Best Match':
      return DiscoverySortMode.bestMatch;
    case 'Recently Joined':
      return DiscoverySortMode.recentlyJoined;
    case 'Most Active':
      return DiscoverySortMode.mostActive;
    default:
      return null;
  }
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

const _kDiscoveryFilterKeywords = <String, List<String>>{
  'Coffee': ['coffee', 'cafe', 'espresso', 'chai', 'tea'],
  'Walk': ['walk', 'walking', 'hiking', 'trek', 'running', 'run', 'jog'],
  'Music': ['music', 'singing', 'jazz', 'vinyl', 'songwriter', 'podcast', 'guitar', 'piano'],
  'Study': ['book', 'reading', 'writing', 'poetry', 'chess', 'journaling', 'study', 'learn'],
};

List<DiscoveryProfile> _applyDiscoveryProfileFilter(
  List<DiscoveryProfile> profiles,
  String filter,
) {
  switch (filter) {
    case 'All':
      return profiles;
    case 'Nearby':
      return [
        for (final p in profiles)
          if (p.distanceMeters != null && p.distanceMeters! <= 1500) p,
      ];
    case 'Verified':
      return [
        for (final p in profiles)
          if (p.verified) p,
      ];
    case 'Available Now':
      return [
        for (final p in profiles)
          if (p.availabilityStatus == 'available_now') p,
      ];
    case 'New':
      return [
        for (final p in profiles)
          if (isNewProfile(p.createdAt)) p,
      ];
    case 'Shared Interests':
      return [
        for (final p in profiles)
          if (p.sharedInterestsCount > 0) p,
      ];
    default:
      final keywords = _kDiscoveryFilterKeywords[filter];
      if (keywords == null) return profiles;
      return [
        for (final p in profiles)
          if (_profileMatchesKeywords(p, keywords)) p,
      ];
  }
}

bool _profileMatchesKeywords(DiscoveryProfile profile, List<String> keywords) {
  final haystack = <String>[
    ...profile.interests,
    profile.bio,
    profile.location,
    if (profile.occupation != null) profile.occupation!,
  ].join(' ').toLowerCase();
  for (final k in keywords) {
    if (haystack.contains(k)) return true;
  }
  return false;
}

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

class _DiscoveryErrorState extends StatelessWidget {
  const _DiscoveryErrorState({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

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
                    Icons.wifi_off_rounded,
                    size: 42,
                    color: Color(0xFFB7A5FF),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Unable to load nearby people',
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
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFAEB9D6),
                  ),
                ),
                const SizedBox(height: 22),
                _ErrorStateRetryButton(onTap: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorStateRetryButton extends StatelessWidget {
  const _ErrorStateRetryButton({required this.onTap});

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
                'Try again',
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


