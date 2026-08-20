import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/supabase/auth_service.dart';
import 'home_discovery_animations.dart';
import 'home_discovery_cache.dart';
import 'home_discovery_connect.dart';
import 'home_discovery_profile.dart';
import 'home_discovery_skeleton.dart';
import 'profile/connection_data.dart';
import 'profile/connection_repository.dart';
import 'profile/discovery_data.dart';
import 'profile/discovery_repository.dart';
import 'profile/discovery_helpers.dart';
import 'profile/supabase_profile_repository.dart';

class _DiscoveryPreparationState extends StatefulWidget {
  const _DiscoveryPreparationState({super.key});

  @override
  State<_DiscoveryPreparationState> createState() =>
      _DiscoveryPreparationStateState();
}

class _DiscoveryPreparationStateState extends State<_DiscoveryPreparationState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _animations = List.generate(4, (i) {
      final start = 0.08 + i * 0.22;
      final end = (start + 0.18).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: EntranceFade(
        offset: const Offset(0, 0.04),
        scaleFrom: 0.99,
        duration: const Duration(milliseconds: 600),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conexo',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: Colors.white.withValues(alpha: .92),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: .55),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 52),
                _PrepLine(text: 'Gathering people', animation: _animations[0]),
                const SizedBox(height: 10),
                _PrepLine(text: 'near you...', animation: _animations[1]),
                const SizedBox(height: 52),
                _PrepLine(text: 'Preparing your', animation: _animations[2]),
                const SizedBox(height: 10),
                _PrepLine(text: 'discovery feed', animation: _animations[3]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrepLine extends StatelessWidget {
  const _PrepLine({required this.text, required this.animation});

  final String text;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: Colors.white.withValues(alpha: .68),
          height: 1.45,
        ),
      ),
    );
  }
}

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
  bool _preparing = false;
  List<DiscoveryProfile> _profiles = const [];
  bool _fetchError = false;
  Timer? _loadTimer;
  Timer? _prefetchTimer;
  final Map<String, Connection?> _connections = {};
  final Map<String, bool> _connecting = {};
  final ConnectionRepository _connectionRepository =
      const ConnectionRepository();

  static const int _prefetchWindow = 10;

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
    _prefetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    DiscoveryPhotoCache.clear();
    setState(() {
      _loading = true;
      _preparing = true;
      _fetchError = false;
      _profiles = const [];
      _index = 0;
      _connections.clear();
      _connecting.clear();
    });

    try {
      final repository = const DiscoveryRepository();
      final profiles = await repository.fetchNearby(sort: _sortMode);
      if (!mounted) return;

      if (profiles.isEmpty) {
        setState(() {
          _profiles = const [];
          _loading = false;
          _preparing = false;
        });
        return;
      }

      await _prefetchBatch(profiles, 0, _prefetchWindow);
      await _waitForFirstBatchReady(profiles, 0, _prefetchWindow);

      await _loadConnectionStates(profiles);

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
          _preparing = false;
        });
      }

      if (profiles.length > _prefetchWindow && mounted) {
        _prefetchBatch(
          profiles,
          _prefetchWindow,
          profiles.length - _prefetchWindow,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _preparing = false;
          _fetchError = true;
        });
      }
    }
  }

  Future<void> _prefetchBatch(
    List<DiscoveryProfile> profiles,
    int start,
    int count,
  ) async {
    final end = (start + count).clamp(0, profiles.length);
    if (start >= end) return;

    final batch = profiles.sublist(start, end);
    final repo = const SupabaseProfileRepository();

    for (final profile in batch) {
      if (DiscoveryPhotoCache.isPrefetched(profile.id)) continue;
      DiscoveryPhotoCache.markPrefetched(profile.id);

      final photo = profile.photos.firstOrNull;
      if (photo == null || photo.remoteUrl == null) {
        DiscoveryPhotoCache.markReady(profile.id);
        continue;
      }

      try {
        final signedUrl = await repo.getSignedPhotoUrl(photo.remoteUrl!);
        if (signedUrl == null || signedUrl.isEmpty) {
          DiscoveryPhotoCache.markReady(profile.id);
          continue;
        }
        DiscoveryPhotoCache.setSignedUrl(photo.remoteUrl!, signedUrl);

        if (mounted) {
          try {
            final provider = NetworkImage(signedUrl);
            DiscoveryPhotoCache.setProvider(photo.remoteUrl!, provider);
            await precacheImage(provider, context);
            DiscoveryPhotoCache.markReady(profile.id);
          } catch (_) {
            DiscoveryPhotoCache.markReady(profile.id);
          }
        } else {
          DiscoveryPhotoCache.markReady(profile.id);
        }
      } catch (_) {
        DiscoveryPhotoCache.markReady(profile.id);
      }
    }
  }

  Future<void> _waitForFirstBatchReady(
    List<DiscoveryProfile> profiles,
    int start,
    int count, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = (start + count).clamp(0, profiles.length);
    if (start >= end) return;

    final batch = profiles.sublist(start, end);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final allReady = batch.every((p) => DiscoveryPhotoCache.isReady(p.id));
      if (allReady) return;
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  void _scheduleRollingPrefetch(List<DiscoveryProfile> profiles) {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _prefetchBatch(profiles, _index + 1, _prefetchWindow);
    });
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
    });
    _scheduleRollingPrefetch(profiles);
  }

  void _selectFilter(String filter) {
    if (filter == _selectedFilter) return;
    _loadTimer?.cancel();
    DiscoveryPhotoCache.clear();
    setState(() {
      _selectedFilter = filter;
      _direction = 1;
      _index = 0;
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
      });
      final message =
          result.error ?? 'Could not send request. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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

  @override
  Widget build(BuildContext context) {
    final profiles = _visibleProfiles;
    final hasProfiles = profiles.isNotEmpty;
    final safeIndex = hasProfiles ? _index.clamp(0, profiles.length - 1) : 0;
    final profile = hasProfiles ? profiles[safeIndex] : null;
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final controlsTop = screenHeight * 0.76;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
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
                    scale: Tween<double>(begin: .985, end: 1).animate(fade),
                    child: child,
                  ),
                ),
              );
            },
            child: _preparing
                ? const _DiscoveryPreparationState(
                    key: ValueKey<String>('preparation'),
                  )
                : _loading
                ? const ProfileSkeleton(key: ValueKey<String>('skeleton'))
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
                    connection: _connections[profile.id],
                    connecting: _connecting[profile.id] ?? false,
                    onConnect: () => _sendRequest(profile.id),
                    onPrevious: () => _move(-1),
                    onNext: () => _move(1),
                    onRefresh: _loadProfiles,
                  ),
          ),
        ),
        if (profile != null)
          Positioned(
            left: 0,
            right: 0,
            top: controlsTop,
            child: DiscoveryControls(
              connection: _connections[profile.id],
              connecting: _connecting[profile.id] ?? false,
              onConnect: () => _sendRequest(profile.id),
            ),
          ),
        Positioned(
          top: media.padding.top + 10,
          left: 16,
          right: 16,
          child: _DiscoveryHeaderPill(
            greeting: _greeting(),
            onFilterTap: () => _showFilters(context),
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
          const Center(
            child: SizedBox(width: 38, child: Divider(thickness: 3)),
          ),
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

const _kDiscoveryFilterKeywords = <String, List<String>>{
  'Coffee': ['coffee', 'cafe', 'espresso', 'chai', 'tea'],
  'Walk': ['walk', 'walking', 'hiking', 'trek', 'running', 'run', 'jog'],
  'Music': [
    'music',
    'singing',
    'jazz',
    'vinyl',
    'songwriter',
    'podcast',
    'guitar',
    'piano',
  ],
  'Study': [
    'book',
    'reading',
    'writing',
    'poetry',
    'chess',
    'journaling',
    'study',
    'learn',
  ],
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

/// A floating, frosted-glass header pill that sits over the hero. It carries
/// the time-based greeting on the left and the Discovery filter on the right.
/// The hero photo remains subtly visible (blurred) behind it, so the pill
/// reads as floating over the profile rather than a solid header bar.
class _DiscoveryHeaderPill extends StatelessWidget {
  const _DiscoveryHeaderPill({
    required this.greeting,
    required this.onFilterTap,
  });

  final String greeting;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    greeting,
                    key: ValueKey<String>(greeting),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _FloatingFilterButton(onTap: onFilterTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingFilterButton extends StatelessWidget {
  const _FloatingFilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.tune_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: .92),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  const _DiscoveryErrorState({required this.onRetry, super.key});

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
