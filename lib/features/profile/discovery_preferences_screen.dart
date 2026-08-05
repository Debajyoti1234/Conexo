import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_repository.dart';

/// A UI-only placeholder for future Discovery Preferences.
///
/// It previews the controls that will eventually shape a user's discovery
/// experience — Distance, Age Range, Theme, and Language. Nothing here is
/// persisted or wired to a backend; the controls are inert previews so the
/// destination feels complete while the real logic lands later.
class DiscoveryPreferencesScreen extends StatelessWidget {
  const DiscoveryPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                'Fine-tune who you discover. These preferences are a preview — '
                'coming soon.',
                style: TextStyle(color: Color(0xFFB9C3DC)),
              ),
            ),
            const SizedBox(height: 22),
            EntranceFade(
              child: _PrefCard(
                icon: Icons.social_distance_rounded,
                title: 'Distance',
                trailing: const Text(
                  '25 km',
                  style: _valueStyle,
                ),
                child: _InertSlider(value: 0.35),
              ),
            ),
            const SizedBox(height: 14),
            EntranceFade(
              child: _PrefCard(
                icon: Icons.cake_outlined,
                title: 'Age Range',
                trailing: const Text(
                  '24 – 34',
                  style: _valueStyle,
                ),
                child: _InertRangeBar(),
              ),
            ),
            const SizedBox(height: 14),
            EntranceFade(
              child: _PrefCard(
                icon: Icons.palette_outlined,
                title: 'Theme',
                child: _InertChips(
                  options: ['System', 'Dark', 'Light'],
                  selectedIndex: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            EntranceFade(
              child: _PrefCard(
                icon: Icons.translate_rounded,
                title: 'Language',
                trailing: const Text(
                  'English',
                  style: _valueStyle,
                ),
                child: _InertChips(
                  options: ['English', 'Español', 'हिन्दी'],
                  selectedIndex: 0,
                ),
              ),
            ),
          ],
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
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A static, non-interactive slider preview.
class _InertSlider extends StatelessWidget {
  const _InertSlider({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                height: 5,
                width: width * value,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Positioned(
                left: (width * value) - 9,
                child: Container(
                  height: 18,
                  width: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: .5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A static two-handle range preview.
class _InertRangeBar extends StatelessWidget {
  const _InertRangeBar();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const start = 0.25;
        const end = 0.7;
        return SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Positioned(
                left: width * start,
                child: Container(
                  height: 5,
                  width: width * (end - start),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              for (final pos in const [start, end])
                Positioned(
                  left: (width * pos) - 9,
                  child: Container(
                    height: 18,
                    width: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A static chip selector preview (non-interactive).
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

/// Premium route into Discovery Preferences — Conexo fade + slide language.
///
/// Accepts an optional [repository] for signature parity with the other
/// Profile routes (unused here since the screen is UI-only).
Route<void> premiumDiscoveryPreferencesRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const DiscoveryPreferencesScreen(),
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
