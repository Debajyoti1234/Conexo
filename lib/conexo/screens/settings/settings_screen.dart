import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../auth/auth_scaffold.dart' show showCxSnack;
import '../auth/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _minAge = 18.0;
  static const _maxAge = 60.0;
  static const _maxDistance = 100.0;

  RangeValues? _age;
  double? _distance;
  bool _signingOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_age != null) return;
    final prefs = ConexoScope.read(context).prefs;
    final lo = (prefs.minAge?.toDouble() ?? _minAge).clamp(_minAge, _maxAge);
    final hi = (prefs.maxAge?.toDouble() ?? _maxAge).clamp(lo, _maxAge);
    _age = RangeValues(lo, hi);
    _distance = (prefs.distanceKm?.toDouble() ?? _maxDistance).clamp(1.0, _maxDistance);
  }

  Future<void> _savePrefs() async {
    final age = _age!;
    final distance = _distance!.round();
    try {
      await ConexoScope.read(context).savePrefs(
        Preferences(
          minAge: age.start.round(),
          maxAge: age.end >= _maxAge ? null : age.end.round(),
          distanceKm: distance >= _maxDistance ? null : distance,
        ),
      );
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'Your preferences didn\'t save. Try again.');
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ConexoScope.read(context).signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(cxRoute(const WelcomeScreen()), (_) => false);
    } catch (_) {
      if (mounted) {
        showCxSnack(context, 'Couldn\'t sign out. Check your connection and try again.');
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final age = _age!;
    final distance = _distance!;

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
                _Group(
                  title: 'Appearance',
                  children: [_NightModeTile(value: s.night, onChanged: s.setNight)],
                ),
                _Group(
                  title: 'Who you\'ll see',
                  footer: 'Discover pairs people by the gender on their profile, then applies these limits.',
                  children: [
                    _SliderTile(
                      title: 'Age range',
                      value: '${age.start.round()}–${age.end >= _maxAge ? '60+' : age.end.round()}',
                      child: RangeSlider(
                        values: age,
                        min: _minAge,
                        max: _maxAge,
                        divisions: (_maxAge - _minAge).round(),
                        activeColor: c.violet,
                        inactiveColor: c.line,
                        onChanged: (v) => setState(() => _age = v),
                        onChangeEnd: (_) => _savePrefs(),
                      ),
                    ),
                    _SliderTile(
                      title: 'Maximum distance',
                      value: distance >= _maxDistance ? 'Any distance' : '${distance.round()} km',
                      child: Slider(
                        value: distance,
                        min: 1,
                        max: _maxDistance,
                        activeColor: c.violet,
                        inactiveColor: c.line,
                        onChanged: (v) => setState(() => _distance = v),
                        onChangeEnd: (_) => _savePrefs(),
                      ),
                    ),
                  ],
                ),
                _Group(
                  title: 'Account',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Row(
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 21, color: c.violet),
                          const SizedBox(width: 14),
                          Text('Email', style: ConexoType.body(c.ink, size: 15, w: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.source.myEmail ?? '—',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: ConexoType.body(c.inkMute, size: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CxButton(
                  label: 'Sign out',
                  variant: CxButtonVariant.soft,
                  loading: _signingOut,
                  onTap: _signOut,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => showCxSnack(context, 'Account deletion isn\'t available in the app yet.'),
                    child: Text('Delete account', style: ConexoType.label(c.danger, size: 14)),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    const ConexoMark(size: 36),
                    const SizedBox(height: 6),
                    Text(
                      s.source.isLive ? 'Conexo 1.0' : 'Conexo 1.0  ·  Demo mode, database off',
                      style: ConexoType.body(c.inkMute, size: 12),
                    ),
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
  const _Group({required this.title, required this.children, this.footer});
  final String title;
  final String? footer;
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
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Text(footer!, style: ConexoType.body(c.inkMute, size: 12.5)),
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
