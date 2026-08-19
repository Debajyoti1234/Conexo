import 'dart:ui';

import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'notifications/activity_center_screen.dart';
import 'notifications/demo_notification_data.dart';
import 'notifications/notification_widgets.dart';
import 'secondary_screens.dart';

/// The shared application shell.
///
/// Hosts the five primary destinations behind a single [IndexedStack] (so
/// each screen keeps its state) and renders a premium floating glass
/// navigation dock — inspired by modern floating docks while keeping the
/// Conexo violet identity. UI-only: no routing, backend, or feature logic
/// lives here.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Plans (index 0) is the default landing tab.
  int _selectedIndex = 0;

  static const _screens = [
    PlansScreen(),
    HomeScreen(),
    ConnectionsScreen(),
    ChatsScreen(),
    ProfileScreen(),
  ];

  /// The single, shell-owned notification state. Pure state only — the shell is
  /// the only place that turns its changes into UI (bell pulse + live toast)
  /// and navigation. Swappable for a future backend controller without
  /// changing this widget.
  final NotificationDemoController _notifications = NotificationDemoController();

  /// Tracks the last handled pulse so a rebuild does not re-show the toast.
  int _lastHandledPulse = 0;

  @override
  void initState() {
    super.initState();
    _notifications.pulseTrigger.addListener(_onPulse);
    // Demo work is started here, never inside the controller constructor.
    _notifications.startDemo();
  }

  @override
  void dispose() {
    _notifications.pulseTrigger.removeListener(_onPulse);
    _notifications.dispose();
    super.dispose();
  }

  /// When a new notification arrives, show the live glass toast once. The bell
  /// reacts to the same trigger on its own via [ValueListenableBuilder].
  void _onPulse() {
    final pulse = _notifications.pulseTrigger.value;
    if (pulse == _lastHandledPulse) return;
    _lastHandledPulse = pulse;
    final list = _notifications.notifications;
    if (list.isEmpty) return;
    NotificationOverlay.show(context, list.first);
  }

  void _onSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  /// Opens the Activity Center, then clears unread — only after the push has
  /// succeeded (never before navigation).
  Future<void> _openActivityCenter() async {
    await Navigator.of(context).push(
      premiumActivityCenterRoute(controller: _notifications),
    );
    _notifications.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The dock floats over the content instead of pushing it up.
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: _screens),
          // Shell-owned bell: shown ONLY on the Connections tab (index 2) so it
          // never overlaps other screens (e.g. the Profile overflow menu).
          if (_selectedIndex == 2)
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 14,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _notifications.hasUnread,
                      builder: (context, hasUnread, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _notifications.pulseTrigger,
                          builder: (context, pulse, _) {
                            return NotificationBell(
                              hasUnread: hasUnread,
                              pulseTrigger: pulse,
                              onTap: _openActivityCenter,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

        ],
      ),
      bottomNavigationBar: FloatingNavDock(
        selectedIndex: _selectedIndex,
        onSelected: _onSelected,
      ),
    );
  }
}

/// Per-destination configuration for the dock.
///
/// Every glyph renders at a 24dp base, but Material Symbols differ in
/// *perceived* weight, so each item may carry tiny optical tweaks:
///
/// • [opticalScale] — multiplies the 24dp base (default `1.0` = no change).
/// • [opticalOffset] — a small dx/dy nudge for baseline / centering
///   (default `Offset.zero` = no change).
///
/// Only icons that genuinely need balancing get non-default values, which
/// keeps the dock maintainable and future icon swaps trivial.
class _NavItem {
  const _NavItem(
    this.icon,
    this.label, {
    this.opticalScale = 1.0,
    this.opticalOffset = Offset.zero,
  });

  final IconData icon;
  final String label;
  final double opticalScale;
  final Offset opticalOffset;
}

/// A premium floating, frosted-glass navigation dock (icons only).
///
/// • Floats above the screen bottom with comfortable margins + SafeArea.
/// • Frosted blur, semi-transparent fill, thin translucent border, layered
///   shadow, and a large pill radius.
/// • The selected item lifts into a glowing glass capsule with a smooth,
///   non-bouncy transition.
/// • Every item keeps an identical 48×48 capsule / touch target; optical
///   tweaks move only the rendered glyph, never the hit area.
class FloatingNavDock extends StatelessWidget {
  const FloatingNavDock({
    required this.selectedIndex,
    required this.onSelected,
    this.profileImage,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Future-ready swap point: when a user avatar exists, pass it here and the
  /// Profile tab shows a circular avatar; otherwise it falls back gracefully
  /// to [Icons.person_rounded]. No refactoring needed when this is wired up.
  final ImageProvider? profileImage;

  static const _accent = Color(0xFF8B5CF6);

  // Optical values are intentionally small (±4% scale, ≤0.5px nudge) so all
  // five glyphs read at the same visual weight without changing the layout.
  static const _items = <_NavItem>[
    _NavItem(Icons.explore_rounded, 'Plans'),
    _NavItem(
      Icons.diversity_3_rounded,
      'People',
      opticalScale: 0.96,
      opticalOffset: Offset(0, 0.5),
    ),
    _NavItem(
      Icons.handshake_rounded,
      'Connections',
      opticalScale: 1.04,
      opticalOffset: Offset(0, 0.5),
    ),
    _NavItem(
      Icons.forum_rounded,
      'Rooms',
      opticalScale: 0.98,
      opticalOffset: Offset(0, -0.5),
    ),
    _NavItem(Icons.person_rounded, 'Profile', opticalScale: 1.02),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2E).withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .48),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: _accent.withValues(alpha: .14),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      _NavButton(
                        key: ValueKey(_items[i].label),
                        item: _items[i],
                        selected: i == selectedIndex,
                        accent: _accent,
                        avatar: i == _items.length - 1 ? profileImage : null,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single icon-only dock button with a lifting glass capsule + glow when
/// selected. Motion is limited to AnimatedContainer / AnimatedScale with
/// easeOutCubic — no bounce, elastic, or overshoot.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.avatar,
    super.key,
  });

  final _NavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  /// When non-null (Profile tab only), a circular avatar replaces the glyph.
  final ImageProvider? avatar;

  static const double _baseIconSize = 24;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? Colors.white : Colors.white.withValues(alpha: .5);

    // Icon ↔ avatar swap fades gracefully (allowed FadeTransition) so the
    // Profile fallback is seamless.
    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: avatar != null
          ? _AvatarBadge(
              key: const ValueKey('avatar'),
              image: avatar!,
              accent: accent,
              selected: selected,
            )
          : Transform.translate(
              key: ValueKey(item.icon.codePoint),
              offset: item.opticalOffset,
              child: Icon(
                item.icon,
                size: _baseIconSize * item.opticalScale,
                color: iconColor,
              ),
            ),
    );

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Guarantees a 48×48 minimum touch target regardless of glyph tweaks.
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.94,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: 48,
              height: 48,
              alignment: Alignment.center,
              // A gentle lift for the selected icon.
              transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: .32),
                          accent.withValues(alpha: .16),
                        ],
                      )
                    : null,
                border: selected
                    ? Border.all(color: accent.withValues(alpha: .55))
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A modestly sized circular avatar for the Profile tab, sharing the same
/// optical center as the glyphs and carrying a subtle border that matches the
/// dock styling. Never oversized.
class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.image,
    required this.accent,
    required this.selected,
    super.key,
  });

  final ImageProvider image;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: image, fit: BoxFit.cover),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: .75)
              : Colors.white.withValues(alpha: .22),
          width: 1.4,
        ),
      ),
    );
  }
}
