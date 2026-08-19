import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'privacy_verification_widgets.dart' show SaveSuccessOverlay;
import 'profile_data.dart';
import 'profile_repository.dart';
import 'session_aware_profile_repository.dart';

/// Discovery Preferences for the People/Discover experience.
///
/// Phase 9.1A wires **Distance** and **Age Range** to real Supabase
/// persistence through the existing [ProfileRepository]. **Theme** stays an
/// inert preview. This screen does not touch the Plans (create-plan) feature.
class DiscoveryPreferencesScreen extends StatefulWidget {
  const DiscoveryPreferencesScreen({
    super.key,
    this.repository = const SessionAwareProfileRepository(),
  });

  final ProfileRepository repository;

  @override
  State<DiscoveryPreferencesScreen> createState() =>
      _DiscoveryPreferencesScreenState();
}

class _DiscoveryPreferencesScreenState extends State<DiscoveryPreferencesScreen> {
  UserProfile? _profile;

  int? _selectedDistance;
  int? _originalDistance;

  int? _selectedMinAge;
  int? _originalMinAge;

  int? _selectedMaxAge;
  int? _originalMaxAge;

  bool _loading = true;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.repository.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _originalDistance = profile?.discoveryDistanceKm;
      _selectedDistance = profile?.discoveryDistanceKm;
      _originalMinAge = profile?.discoveryMinAge;
      _selectedMinAge = profile?.discoveryMinAge;
      _originalMaxAge = profile?.discoveryMaxAge;
      _selectedMaxAge = profile?.discoveryMaxAge;
      _loading = false;
    });
  }

  bool get _isDirty =>
      _selectedDistance != _originalDistance ||
      _selectedMinAge != _originalMinAge ||
      _selectedMaxAge != _originalMaxAge;

  bool get _canSave => _profile != null && _isDirty && !_saving;

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || !_isDirty || _saving) return;

    setState(() => _saving = true);

    try {
      final updated = profile.copyWith(
        discoveryDistanceKm: _selectedDistance,
        discoveryMinAge: _selectedMinAge,
        discoveryMaxAge: _selectedMaxAge,
        updatedAt: DateTime.now(),
      );
      await widget.repository.saveProfile(updated);
      if (!mounted) return;

      setState(() {
        _profile = updated;
        _originalDistance = _selectedDistance;
        _originalMinAge = _selectedMinAge;
        _originalMaxAge = _selectedMaxAge;
        _saving = false;
        _saved = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save preferences: $e'),
          backgroundColor: const Color(0xFFE36D9D),
        ),
      );
    }
  }

  String _formatDistance(int? km) {
    if (km == null) return 'Any';
    return '$km km';
  }

  String _formatAgeRange(int? min, int? max) {
    if (min == null && max == null) return '--';
    final minText = min?.toString() ?? '--';
    final maxText = max?.toString() ?? '--';
    return '$minText – $maxText';
  }

  bool _shouldClampMax(int? newMin, int? currentMax) {
    return currentMax != null && newMin != null && newMin > currentMax;
  }

  bool _shouldClampMin(int? newMax, int? currentMin) {
    return currentMin != null && newMax != null && newMax < currentMin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? Colors.black : Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            if (!_loading)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: _SaveButton(
                  enabled: _canSave,
                  loading: _saving,
                  onTap: _save,
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: _saved
                  ? const SaveSuccessOverlay(message: 'Preferences updated')
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Discovery Preferences',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Fine-tune who you discover. More preferences are coming soon.',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
        ),
        const SizedBox(height: 22),
        EntranceFade(
          child: _PrefCard(
            icon: Icons.social_distance_rounded,
            title: 'Distance',
            trailing: Text(_formatDistance(_selectedDistance), style: _valueStyle),
            child: _DistanceControls(
              distance: _selectedDistance,
              onDistanceChanged: (v) {
                setState(() => _selectedDistance = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        EntranceFade(
          child: _PrefCard(
            icon: Icons.cake_outlined,
            title: 'Age Range',
            trailing: Text(
              _formatAgeRange(_selectedMinAge, _selectedMaxAge),
              style: _valueStyle,
            ),
            child: _AgeRangeControls(
              minAge: _selectedMinAge,
              maxAge: _selectedMaxAge,
              onMinAgeChanged: (v) {
                setState(() {
                  if (_shouldClampMax(v, _selectedMaxAge)) {
                    _selectedMaxAge = v;
                  }
                  _selectedMinAge = v;
                });
              },
              onMaxAgeChanged: (v) {
                setState(() {
                  if (_shouldClampMin(v, _selectedMinAge)) {
                    _selectedMinAge = v;
                  }
                  _selectedMaxAge = v;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        EntranceFade(
          child: _PrefCard(
            icon: Icons.palette_outlined,
            title: 'Theme',
            child: _InertChips(
              options: const ['System', 'Dark', 'Light'],
              selectedIndex: 1,
            ),
          ),
        ),
      ],
    );
  }
}

const _valueStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFFB7A5FF),
);

class _PrefCard extends StatelessWidget {
  const _PrefCard({
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

class _DistanceControls extends StatelessWidget {
  const _DistanceControls({
    required this.distance,
    required this.onDistanceChanged,
  });

  final int? distance;
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
          onChanged: (v) {
            onDistanceChanged(v.round());
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              _DistancePresetChip(
                label: '$preset',
                selected: distance == preset,
                onTap: () => onDistanceChanged(preset),
              ),
            _DistancePresetChip(
              label: 'Any',
              selected: distance == null,
              onTap: () => onDistanceChanged(null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Current value: ${distance == null ? "Any" : "$distance km"}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB9C3DC),
          ),
        ),
      ],
    );
  }
}

class _DistancePresetChip extends StatelessWidget {
  const _DistancePresetChip({
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
  final ValueChanged<int?> onMinAgeChanged;
  final ValueChanged<int?> onMaxAgeChanged;

  static final _ageOptions = List<int>.generate(63, (i) => 18 + i);

  static bool _minExceedsMax(int? min, int? max) {
    return min != null && max != null && min > max;
  }

  @override
  Widget build(BuildContext context) {
    final minInvalid = _minExceedsMax(minAge, maxAge);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AgeDropdown(
                label: 'Min Age',
                value: minAge ?? 18,
                items: _ageOptions,
                enabled: maxAge == null || (minAge ?? 18) <= (maxAge ?? 80),
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
                enabled: minAge == null || (maxAge ?? 80) >= minAge!,
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
    this.enabled = true,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final bool enabled;
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
              color: enabled
                  ? Colors.white.withValues(alpha: .08)
                  : const Color(0xFFE36D9D).withValues(alpha: .5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF141B2E),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? const Color(0xFFEAEEF9)
                    : const Color(0xFFE36D9D),
              ),
              items: [
                for (final age in items)
                  DropdownMenuItem(
                    value: age,
                    enabled: enabled,
                    child: Text('$age'),
                  ),
              ],
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A static chip selector preview (non-interactive), used by the inert Theme card.
class _InertChips extends StatelessWidget {
  const _InertChips({required this.options, required this.selectedIndex});

  final List<String> options;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < options.length; i++)
          Container(
            key: ValueKey('chip_${options[i]}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: i == selectedIndex
                  ? const Color(0xFF8B5CF6).withValues(alpha: .22)
                  : Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: i == selectedIndex
                    ? const Color(0xFF8B5CF6).withValues(alpha: .55)
                    : Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Text(
              options[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: i == selectedIndex
                    ? const Color(0xFFEAEEF9)
                    : const Color(0xFFB9C3DC),
              ),
            ),
          ),
      ],
    );
  }
}

/// Save CTA mirroring the Privacy & Verification screen's gradient button.
class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: active ? 1 : 0.5,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: .5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Premium route into Discovery Preferences — Conexo fade + slide language.
Route<void> premiumDiscoveryPreferencesRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        DiscoveryPreferencesScreen(
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
