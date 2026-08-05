import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'profile_repository.dart';

/// A simple, UI-only Safety hub for the Profile module.
///
/// It surfaces the common safety actions users expect from a premium social
/// app — Report a Problem, Blocked Users, Safety Tips, and Contact Support.
/// Every item is presentational (no backend, no persistence); taps show a
/// lightweight placeholder so the flow feels complete without wiring services.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

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
                Text(
                  'Safety',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Your safety comes first. Tools to keep your experience secure '
                'and comfortable.',
                style: TextStyle(color: Color(0xFFB9C3DC)),
              ),
            ),
            const SizedBox(height: 22),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.flag_outlined,
                iconColor: const Color(0xFFE36D9D),
                title: 'Report a Problem',
                subtitle: 'Tell us about inappropriate behavior or content.',
                onTap: () => _showPlaceholder(context, 'Report a Problem'),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.block_rounded,
                iconColor: const Color(0xFFF2B34B),
                title: 'Blocked Users',
                subtitle: 'Review and manage people you have blocked.',
                onTap: () => _showPlaceholder(context, 'Blocked Users'),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF47D7A5),
                title: 'Safety Tips',
                subtitle: 'Advice for meeting new people safely.',
                onTap: () => _showPlaceholder(context, 'Safety Tips'),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFF22BFE0),
                title: 'Contact Support',
                subtitle: 'Get help from the Conexo team.',
                onTap: () => _showPlaceholder(context, 'Contact Support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEAEEF9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB9C3DC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium route into the Safety hub — matches Conexo's fade + slide language.
///
/// Accepts an optional [repository] for signature parity with the other
/// Profile routes (unused here since the screen is UI-only).
Route<void> premiumSafetyRoute({ProfileRepository? repository}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SafetyScreen(),
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
