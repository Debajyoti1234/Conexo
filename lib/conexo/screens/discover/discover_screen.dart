import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/profile_view.dart';
import '../auth/auth_scaffold.dart' show showCxSnack;
import '../match/match_screen.dart';
import '../settings/settings_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _scroll = ScrollController();
  bool _locating = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _like(Person p, String what, Widget preview) async {
    final comment = await showLikeSheet(context, person: p, preview: preview);
    if (comment == null || !mounted) return;
    try {
      final match = await ConexoScope.read(context).like(p, comment: comment, what: what);
      if (!mounted) return;
      if (match != null) {
        Navigator.of(context).push(cxRoute(MatchScreen(match: match), fullscreen: true));
      } else {
        showCxSnack(context, 'Like sent to ${p.name}. Now we wait, casually.');
      }
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'That like didn\'t go through. Try again.');
    }
  }

  Future<void> _pass(Person p) async {
    HapticFeedback.lightImpact();
    try {
      await ConexoScope.read(context).pass(p);
    } catch (_) {
      // Passing is best-effort; the card is already gone.
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _locating = true);
    try {
      await ConexoScope.read(context).shareLocation();
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'We couldn\'t get your location. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _body(ConexoState s, ConexoColors c) {
    final p = s.current;
    if (p != null) {
      return Stack(
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
      );
    }
    if (s.loadingDiscover) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: c.violet)),
            const SizedBox(height: 16),
            Text('Finding people near you…', style: ConexoType.body(c.inkSoft, size: 14)),
          ],
        ),
      );
    }
    if (s.discoverError != null) {
      return EmptyState(
        key: const ValueKey('error'),
        icon: Icons.wifi_off_rounded,
        title: 'Discover didn\'t load',
        body: s.discoverError!,
        action: 'Try again',
        onAction: s.refreshDiscover,
      );
    }
    if (s.needsLocation) {
      return EmptyState(
        key: const ValueKey('location'),
        icon: Icons.near_me_rounded,
        title: 'Where are you?',
        body: 'Conexo shows people near you. Share your location to see who\'s around.',
        action: _locating ? 'Locating…' : 'Share my location',
        onAction: _locating ? null : _shareLocation,
      );
    }
    return EmptyState(
      key: const ValueKey('empty'),
      icon: Icons.auto_awesome_rounded,
      title: 'That\'s everyone nearby',
      body: 'New people join every day. Widen your distance in preferences, or check back tonight.',
      action: 'Show passed profiles',
      onAction: s.resetDeck,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);

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
              child: _body(s, c),
            ),
          ),
        ],
      ),
    );
  }
}
