import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../widgets/cx_image.dart';
import 'discover/discover_screen.dart';
import 'likes/likes_screen.dart';
import 'matches/matches_screen.dart';
import 'profile/my_profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({this.initialTab = 0, super.key});
  final int initialTab;

  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;

  void go(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: const [
          DiscoverScreen(),
          LikesScreen(),
          MatchesScreen(),
          MyProfileScreen(),
        ],
      ),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onTap: go,
        likes: s.likesYou.length,
        unread: s.unreadTotal,
        avatar: s.profile.firstPhoto,
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onTap,
    required this.likes,
    required this.unread,
    required this.avatar,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int likes;
  final int unread;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final items = [
      (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Discover', 0),
      (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Likes', likes),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Matches', unread),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: c.isNight ? .82 : .9),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: c.line),
                    boxShadow: c.softShadow,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _NavItem(
                          icon: items[i].$1,
                          activeIcon: items[i].$2,
                          label: items[i].$3,
                          badge: items[i].$4,
                          selected: index == i,
                          onTap: () => onTap(i),
                        ),
                      _NavItem(
                        label: 'You',
                        selected: index == 3,
                        onTap: () => onTap(3),
                        avatar: avatar,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.activeIcon,
    this.badge = 0,
    this.avatar,
  });

  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final fg = selected ? (c.isNight ? c.bg : Colors.white) : c.inkSoft;

    Widget glyph;
    if (avatar != null) {
      glyph = Container(
        width: 26,
        height: 26,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? fg : c.line, width: 1.5),
        ),
        child: ClipOval(child: CxImage(avatar!)),
      );
    } else {
      glyph = Icon(selected ? activeIcon : icon, size: 23, color: fg);
    }

    return Expanded(
      flex: selected ? 5 : 3,
      child: Semantics(
        selected: selected,
        button: true,
        label: badge > 0 ? '$label, $badge new' : label,
        child: Pressable(
          onTap: onTap,
          scale: .92,
          haptic: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? c.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    glyph,
                    if (badge > 0)
                      Positioned(
                        top: -5,
                        right: -9,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(badge),
                          tween: Tween(begin: .4, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: c.warm,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: selected ? c.ink : c.surface, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$badge',
                              style: ConexoType.label(Colors.white, size: 9.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: ConexoType.body(fg, size: 13.5, w: FontWeight.w700),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
