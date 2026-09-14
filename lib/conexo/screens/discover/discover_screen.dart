import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/profile_view.dart';
import '../match/match_screen.dart';
import '../settings/settings_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _like(Person p, String what, Widget preview) async {
    final comment = await showLikeSheet(context, person: p, preview: preview);
    if (comment == null || !mounted) return;
    final s = ConexoScope.read(context);
    final match = s.like(p, comment: comment, what: what);
    if (match != null) {
      Navigator.of(context).push(cxRoute(MatchScreen(match: match), fullscreen: true));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like sent to ${p.name}. Now we wait, casually.')),
      );
    }
  }

  void _pass(Person p) {
    HapticFeedback.lightImpact();
    ConexoScope.read(context).pass(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final p = s.current;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 16, 4),
            child: Row(
              children: [
                const ConexoWordmark(size: 28),
                const Spacer(),
                CxIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Dating preferences',
                  onTap: () => Navigator.of(context).push(cxRoute(const SettingsScreen())),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: p == null
                  ? EmptyState(
                      key: const ValueKey('empty'),
                      icon: Icons.auto_awesome_rounded,
                      title: 'That\'s everyone nearby',
                      body: 'New people join every day. Widen your distance or check back tonight.',
                      action: 'Show them again',
                      onAction: s.resetDeck,
                    )
                  : Stack(
                      key: ValueKey(p.id),
                      children: [
                        ProfileView(
                          person: p,
                          controller: _scroll,
                          onLike: (what, preview) => _like(p, what, preview),
                        ),
                        Positioned(
                          left: 20,
                          bottom: MediaQuery.paddingOf(context).bottom + 100,
                          child: Tooltip(
                            message: 'Not for me',
                            child: Pressable(
                              onTap: () => _pass(p),
                              scale: .88,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.line),
                                  boxShadow: c.softShadow,
                                ),
                                child: Icon(Icons.close_rounded, size: 28, color: c.ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
