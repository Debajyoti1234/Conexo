import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';

class AboutConexoScreen extends StatefulWidget {
  const AboutConexoScreen({super.key});

  @override
  State<AboutConexoScreen> createState() => _AboutConexoScreenState();
}

class _AboutConexoScreenState extends State<AboutConexoScreen> {
  String _version = '1.0.0';
  bool _loadingVersion = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
        _loadingVersion = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVersion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
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
                      'About Conexo',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: EntranceFade(
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFFB7A5FF),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Conexo',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: .95),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connect with people. Discover possibilities. '
                          'Create meaningful moments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: const Color(0xFFB9C3DC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What is Conexo?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: .92),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Conexo is a premium social connection platform built to '
                        'help people discover meaningful connections, explore new '
                        'possibilities, and create experiences together.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: const Color(0xFFB9C3DC),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Built for meaningful connections',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: .92),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Conexo brings people discovery, conversations, '
                        'connections, and plans together in one experience — '
                        'designed around genuine interaction rather than endless '
                        'scrolling.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: const Color(0xFFB9C3DC),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'What we believe',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
                const SizedBox(height: 12),
                ..._principles.map(
                  (p) => EntranceFade(
                    child: _PrincipleCard(principle: p),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Conexo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: .7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _loadingVersion ? 'Loading...' : 'Version $_version',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: const Color(0xFFB9C3DC).withValues(alpha: .7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Principle {
  const _Principle({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _principles = <_Principle>[
  _Principle(
    icon: Icons.favorite_rounded,
    title: 'Meaningful',
    body: 'Quality connections matter more than quantity.',
  ),
  _Principle(
    icon: Icons.volunteer_activism_rounded,
    title: 'Respectful',
    body: 'Every interaction should feel comfortable and respectful.',
  ),
  _Principle(
    icon: Icons.person_rounded,
    title: 'Personal',
    body: 'Your profile and preferences should help shape your experience.',
  ),
  _Principle(
    icon: Icons.shield_rounded,
    title: 'Safe',
    body: 'Reporting and blocking tools are built in to help you stay in control.',
  ),
];

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({required this.principle});

  final _Principle principle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(principle.icon, color: const Color(0xFF8B5CF6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  principle.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  principle.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: const Color(0xFFB9C3DC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
