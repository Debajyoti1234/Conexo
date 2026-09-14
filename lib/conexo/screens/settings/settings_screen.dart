import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../auth/welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Row(
                  children: [
                    CxIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
                  child: Text('Settings', style: ConexoType.display(c.ink, size: 38)),
                ),

                // ── Appearance ─────────────────────────────────────────────
                _Group(
                  title: 'Appearance',
                  children: [
                    _NightModeTile(value: s.night, onChanged: s.setNight),
                  ],
                ),

                // ── Dating preferences ─────────────────────────────────────
                _Group(
                  title: 'Who you\'ll see',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show me', style: ConexoType.body(c.ink, size: 15, w: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final o in ['Women', 'Men', 'Everyone'])
                                VibeChip(
                                  label: o,
                                  selected: s.interestedIn == o,
                                  onTap: () => s.update(() => s.interestedIn = o),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _SliderTile(
                      title: 'Age range',
                      value: '${s.ageRange.start.round()}–${s.ageRange.end.round()}',
                      child: RangeSlider(
                        values: s.ageRange,
                        min: 18,
                        max: 60,
                        divisions: 42,
                        activeColor: c.violet,
                        inactiveColor: c.line,
                        onChanged: (v) => s.update(() => s.ageRange = v),
                      ),
                    ),
                    _SliderTile(
                      title: 'Maximum distance',
                      value: '${s.maxDistance.round()} km',
                      child: Slider(
                        value: s.maxDistance,
                        min: 1,
                        max: 100,
                        activeColor: c.violet,
                        inactiveColor: c.line,
                        onChanged: (v) => s.update(() => s.maxDistance = v),
                      ),
                    ),
                    _SwitchTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'Incognito',
                      body: 'Only people you like can see your profile.',
                      value: s.incognito,
                      onChanged: (v) => s.update(() => s.incognito = v),
                    ),
                  ],
                ),

                // ── Notifications ──────────────────────────────────────────
                _Group(
                  title: 'Notifications',
                  children: [
                    _SwitchTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'New matches',
                      value: s.pushMatches,
                      onChanged: (v) => s.update(() => s.pushMatches = v),
                    ),
                    _SwitchTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Messages',
                      value: s.pushMessages,
                      onChanged: (v) => s.update(() => s.pushMessages = v),
                    ),
                    _SwitchTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Someone likes you',
                      value: s.pushLikes,
                      onChanged: (v) => s.update(() => s.pushLikes = v),
                    ),
                  ],
                ),

                // ── Privacy & safety ───────────────────────────────────────
                _Group(
                  title: 'Privacy & safety',
                  children: [
                    _SwitchTile(
                      icon: Icons.done_all_rounded,
                      title: 'Read receipts',
                      body: 'Let matches see when you\'ve read their message.',
                      value: s.readReceipts,
                      onChanged: (v) => s.update(() => s.readReceipts = v),
                    ),
                    _NavTile(icon: Icons.shield_outlined, title: 'Safety tips for meeting up'),
                    _NavTile(icon: Icons.block_rounded, title: 'Blocked people'),
                    _NavTile(icon: Icons.verified_outlined, title: 'Photo verification', trailing: 'Verified'),
                  ],
                ),

                // ── Account ────────────────────────────────────────────────
                _Group(
                  title: 'Account',
                  children: [
                    _NavTile(icon: Icons.mail_outline_rounded, title: 'Email', trailing: 'sam@conexo.app'),
                    _NavTile(icon: Icons.pause_circle_outline_rounded, title: 'Pause my profile'),
                    _NavTile(icon: Icons.help_outline_rounded, title: 'Help & support'),
                  ],
                ),
                const SizedBox(height: 8),
                CxButton(
                  label: 'Sign out',
                  variant: CxButtonVariant.soft,
                  onTap: () {
                    s.signOut();
                    Navigator.of(context).pushAndRemoveUntil(cxRoute(const WelcomeScreen()), (_) => false);
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account deletion is disabled in demo mode.')),
                    ),
                    child: Text('Delete account', style: ConexoType.label(c.danger, size: 14)),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    const ConexoMark(size: 36),
                    const SizedBox(height: 6),
                    Text('Conexo 1.0  ·  Demo mode, database off', style: ConexoType.body(c.inkMute, size: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
            child: Text(title, style: ConexoType.title(c.inkSoft, size: 16)),
          ),
          CxCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) Divider(height: 1, indent: 18, endIndent: 18, color: c.line),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Night Mode gets a little theatre: a sun/moon that rotates as it swaps.
class _NightModeTile extends StatelessWidget {
  const _NightModeTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Pressable(
      scale: .99,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: value
                    ? const LinearGradient(colors: [Color(0xFF1C2440), Color(0xFF3B2A7A)])
                    : const LinearGradient(colors: [Color(0xFFFFD7A8), Color(0xFFFFA8D5)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, a) => RotationTransition(
                  turns: Tween(begin: .5, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Icon(
                  value ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  key: ValueKey(value),
                  color: value ? const Color(0xFFD9CCFF) : const Color(0xFF8A3B12),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Night Mode', style: ConexoType.body(c.ink, size: 15, w: FontWeight.w700)),
                  Text(
                    value ? 'The classic Conexo after-dark look.' : 'Easy on the eyes after dark.',
                    style: ConexoType.body(c.inkMute, size: 12.5),
                  ),
                ],
              ),
            ),
            Switch(value: value, activeTrackColor: c.violet, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.title, required this.value, required this.onChanged, this.body});
  final IconData icon;
  final String title;
  final String? body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      child: Row(
        children: [
          Icon(icon, size: 21, color: c.violet),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ConexoType.body(c.ink, size: 15, w: FontWeight.w600)),
                if (body != null) Text(body!, style: ConexoType.body(c.inkMute, size: 12.5)),
              ],
            ),
          ),
          Switch(value: value, activeTrackColor: c.violet, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.title, required this.value, required this.child});
  final String title;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: ConexoType.body(c.ink, size: 15, w: FontWeight.w700))),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(value, style: ConexoType.label(c.violet, size: 14)),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Pressable(
      scale: .99,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            Icon(icon, size: 21, color: c.violet),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: ConexoType.body(c.ink, size: 15, w: FontWeight.w600))),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(trailing!, style: ConexoType.body(c.inkMute, size: 13.5)),
              ),
            Icon(Icons.chevron_right_rounded, color: c.inkMute),
          ],
        ),
      ),
    );
  }
}
