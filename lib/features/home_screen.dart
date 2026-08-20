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
import 'profile/supabase_profile_repository.dart';
import 'profile/session_aware_profile_repository.dart';

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
  DiscoveryFilterState _filterState = DiscoveryFilterState.defaultValue;
  bool _filterStateInitialized = false;
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

  List<DiscoveryProfile> get _visibleProfiles => _profiles;

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

  Future<void> _ensureFilterStateLoaded() async {
    if (_filterStateInitialized) return;
    final profile = await const SessionAwareProfileRepository().loadProfile();
    if (!mounted) return;
    setState(() {
      _filterState = DiscoveryFilterState(
        distanceKm: profile?.discoveryDistanceKm,
        minAge: profile?.discoveryMinAge,
        maxAge: profile?.discoveryMaxAge,
        sortMode: DiscoverySortMode.closest,
        verification: VerificationFilter.any,
        availability: AvailabilityFilter.any,
        sharedInterests: false,
      );
      _filterStateInitialized = true;
    });
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
      await _ensureFilterStateLoaded();

      final repository = const DiscoveryRepository();
      final profiles = await repository.fetchNearby(
        filterState: _filterStateInitialized ? _filterState : null,
      );
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

  void _applyFilter(DiscoveryFilterState newState) {
    if (newState == _filterState) return;
    _loadTimer?.cancel();
    DiscoveryPhotoCache.clear();
    setState(() {
      _filterState = newState;
      _direction = 1;
      _index = 0;
      _loading = true;
    });
    _loadProfiles();
  }

  void _resetFilters() {
    _applyFilter(const DiscoveryFilterState());
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
                     onReset: _resetFilters,
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
        initialFilterState: _filterState,
        onFilterChanged: _applyFilter,
      ),
    );
  }
}

class _FilterPreferencesSheet extends StatefulWidget {
  const _FilterPreferencesSheet({
    required this.initialFilterState,
    required this.onFilterChanged,
  });

  final DiscoveryFilterState initialFilterState;
  final ValueChanged<DiscoveryFilterState> onFilterChanged;

  @override
  State<_FilterPreferencesSheet> createState() =>
      _FilterPreferencesSheetState();
}

class _FilterPreferencesSheetState extends State<_FilterPreferencesSheet> {
  late DiscoveryFilterState _localState;

  @override
  void initState() {
    super.initState();
    _localState = widget.initialFilterState;
  }

  void _onDistanceDrag(double v) {
    setState(() {
      _localState = _localState.copyWith(distanceKm: v.round());
    });
  }

  void _onDistanceChanged(int? km) {
    final next = _localState.copyWith(distanceKm: km);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateMinAge(int value) {
    final clampedMax = _localState.maxAge != null && value > _localState.maxAge!
        ? value
        : _localState.maxAge;
    final next = _localState.copyWith(minAge: value, maxAge: clampedMax);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateMaxAge(int value) {
    final clampedMin =
        _localState.minAge != null && value < _localState.minAge!
            ? value
            : _localState.minAge;
    final next = _localState.copyWith(minAge: clampedMin, maxAge: value);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateSort(DiscoverySortMode mode) {
    final next = _localState.copyWith(sortMode: mode);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateVerification(VerificationFilter v) {
    final next = _localState.copyWith(verification: v);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateAvailability(AvailabilityFilter v) {
    final next = _localState.copyWith(availability: v);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _updateSharedInterests(bool v) {
    final next = _localState.copyWith(sharedInterests: v);
    setState(() => _localState = next);
    widget.onFilterChanged(next);
  }

  void _reset() {
    const reset = DiscoveryFilterState();
    setState(() => _localState = reset);
    widget.onFilterChanged(reset);
  }

  String _formatDistance(int? km) {
    if (km == null) return 'Any';
    return '$km km';
  }

  String _formatAgeRange(int? min, int? max) {
    if (min == null && max == null) return 'Any';
    final minText = min?.toString() ?? '--';
    final maxText = max?.toString() ?? '--';
    return '$minText – $maxText';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
        decoration: BoxDecoration(
          color: const Color(0xFF172039).withValues(alpha: .97),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
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
                'Discovery filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEAEEF9),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Adjust who appears in your discovery feed.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFFB9C3DC),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              _FilterCard(
                icon: Icons.social_distance_rounded,
                title: 'Distance',
                trailing: Text(
                  _formatDistance(_localState.distanceKm),
                  style: _valueStyle,
                ),
                child: _DistanceSlider(
                  distance: _localState.distanceKm,
                  onDistanceDrag: _onDistanceDrag,
                  onDistanceChanged: _onDistanceChanged,
                ),
              ),
              const SizedBox(height: 14),
              _FilterCard(
                icon: Icons.cake_outlined,
                title: 'Age Range',
                trailing: Text(
                  _formatAgeRange(_localState.minAge, _localState.maxAge),
                  style: _valueStyle,
                ),
                child: _AgeRangeControls(
                  minAge: _localState.minAge,
                  maxAge: _localState.maxAge,
                  onMinAgeChanged: _updateMinAge,
                  onMaxAgeChanged: _updateMaxAge,
                ),
              ),
              const SizedBox(height: 14),
              _FilterCard(
                icon: Icons.sort_rounded,
                title: 'Sort by',
                child: _SortChips(
                  selected: _localState.sortMode,
                  onChanged: _updateSort,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Advanced settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFAEB9D6),
                ),
              ),
              const SizedBox(height: 14),
              _FilterCard(
                icon: Icons.verified_user_rounded,
                title: 'Verification',
                child: _VerificationChips(
                  selected: _localState.verification,
                  onChanged: _updateVerification,
                ),
              ),
              const SizedBox(height: 14),
              _FilterCard(
                icon: Icons.schedule_rounded,
                title: 'Availability',
                child: _AvailabilityChips(
                  selected: _localState.availability,
                  onChanged: _updateAvailability,
                ),
              ),
              const SizedBox(height: 14),
              _FilterCard(
                icon: Icons.favorite_rounded,
                title: 'Shared Interests',
                child: _SharedInterestsToggle(
                  value: _localState.sharedInterests,
                  onChanged: _updateSharedInterests,
                ),
              ),
              const SizedBox(height: 24),
              _FilterResetButton(onTap: _reset),
            ],
          ),
        ),
      ),
    );
  }
}

const _valueStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFFB7A5FF),
);

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFB7A5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DistanceSlider extends StatelessWidget {
  const _DistanceSlider({
    required this.distance,
    required this.onDistanceDrag,
    required this.onDistanceChanged,
  });

  final int? distance;
  final ValueChanged<double> onDistanceDrag;
  final ValueChanged<int?> onDistanceChanged;

  static const _presets = <int>[5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    final sliderValue = distance == null ? 5.0 : distance!.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '5 km',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: .5),
              ),
            ),
            const Spacer(),
            Text(
              '100 km',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: .5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: sliderValue,
          min: 5,
          max: 100,
          divisions: 19,
          activeColor: const Color(0xFF8B5CF6),
          inactiveColor: Colors.white.withValues(alpha: .10),
          onChanged: onDistanceDrag,
          onChangeEnd: (v) => onDistanceChanged(v.round()),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              _PresetChip(
                label: '$preset',
                selected: distance == preset,
                onTap: () => onDistanceChanged(preset),
              ),
            _PresetChip(
              label: 'Any',
              selected: distance == null,
              onTap: () => onDistanceChanged(null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Current: ${distance == null ? "Any" : "$distance km"}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB9C3DC),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: .22)
              : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6).withValues(alpha: .55)
                : Colors.white.withValues(alpha: .10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFFEAEEF9)
                : const Color(0xFFB9C3DC),
          ),
        ),
      ),
    );
  }
}

class _AgeRangeControls extends StatelessWidget {
  const _AgeRangeControls({
    required this.minAge,
    required this.maxAge,
    required this.onMinAgeChanged,
    required this.onMaxAgeChanged,
  });

  final int? minAge;
  final int? maxAge;
  final ValueChanged<int> onMinAgeChanged;
  final ValueChanged<int> onMaxAgeChanged;

  static final _ageOptions = List<int>.generate(63, (i) => 18 + i);

  @override
  Widget build(BuildContext context) {
    final minInvalid = minAge != null && maxAge != null && minAge! > maxAge!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AgeDropdown(
                label: 'Min Age',
                value: minAge ?? 18,
                items: _ageOptions,
                onChanged: (v) {
                  if (v == null) return;
                  onMinAgeChanged(v);
                },
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.arrow_forward_rounded,
                color: Color(0xFFB9C3DC)),
            const SizedBox(width: 16),
            Expanded(
              child: _AgeDropdown(
                label: 'Max Age',
                value: maxAge ?? 80,
                items: _ageOptions,
                onChanged: (v) {
                  if (v == null) return;
                  onMaxAgeChanged(v);
                },
              ),
            ),
          ],
        ),
        if (minInvalid)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Minimum age cannot exceed maximum age.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFE36D9D),
              ),
            ),
          ),
      ],
    );
  }
}

class _AgeDropdown extends StatelessWidget {
  const _AgeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB9C3DC),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF141B2E),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEAEEF9),
              ),
              items: [
                for (final age in items)
                  DropdownMenuItem(
                    value: age,
                    child: Text('$age'),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _SortChips extends StatelessWidget {
  const _SortChips({
    required this.selected,
    required this.onChanged,
  });

  final DiscoverySortMode selected;
  final ValueChanged<DiscoverySortMode> onChanged;

  static const _options = [
    ('Closest', DiscoverySortMode.closest),
    ('Best Match', DiscoverySortMode.bestMatch),
    ('Recently Joined', DiscoverySortMode.recentlyJoined),
    ('Most Active', DiscoverySortMode.mostActive),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, mode) in _options)
          _FilterChip<DiscoverySortMode>(
            label: label,
            value: mode,
            selected: mode == selected,
            onTap: () => onChanged(mode),
          ),
      ],
    );
  }
}

class _VerificationChips extends StatelessWidget {
  const _VerificationChips({
    required this.selected,
    required this.onChanged,
  });

  final VerificationFilter selected;
  final ValueChanged<VerificationFilter> onChanged;

  static const _options = [
    ('Any', VerificationFilter.any),
    ('Verified', VerificationFilter.verified),
    ('Not Verified', VerificationFilter.notVerified),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in _options)
          _FilterChip<VerificationFilter>(
            label: label,
            value: value,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _AvailabilityChips extends StatelessWidget {
  const _AvailabilityChips({
    required this.selected,
    required this.onChanged,
  });

  final AvailabilityFilter selected;
  final ValueChanged<AvailabilityFilter> onChanged;

  static const _options = [
    ('Any', AvailabilityFilter.any),
    ('Available', AvailabilityFilter.available),
    ('Not Available', AvailabilityFilter.notAvailable),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, value) in _options)
          _FilterChip<AvailabilityFilter>(
            label: label,
            value: value,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final T value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: .22)
              : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6).withValues(alpha: .55)
                : Colors.white.withValues(alpha: .10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFFEAEEF9)
                : const Color(0xFFB9C3DC),
          ),
        ),
      ),
    );
  }
}

class _SharedInterestsToggle extends StatelessWidget {
  const _SharedInterestsToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Show only profiles we share interests with',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value
                  ? const Color(0xFFEAEEF9)
                  : const Color(0xFFB9C3DC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF8B5CF6),
          activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: .4),
          inactiveThumbColor: Colors.white.withValues(alpha: .4),
          inactiveTrackColor: Colors.white.withValues(alpha: .10),
        ),
      ],
    );
  }
}

class _FilterResetButton extends StatelessWidget {
  const _FilterResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                'Reset filters',
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
    required this.onReset,
    super.key,
  });

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
                const Text(
                  'No one matches your filters nearby',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Try adjusting your filters to see more people.',
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
