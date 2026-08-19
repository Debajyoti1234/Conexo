import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const _tips = <_SafetyTip>[
    _SafetyTip(
      icon: Icons.public_rounded,
      title: 'Meet on your terms',
      body: 'Take your time getting to know someone before meeting in person.',
    ),
    _SafetyTip(
      icon: Icons.lock_outline_rounded,
      title: 'Protect personal information',
      body: 'Do not share passwords, OTPs, financial details, or sensitive documents.',
    ),
    _SafetyTip(
      icon: Icons.psychology_rounded,
      title: 'Trust your instincts',
      body: 'If something feels wrong, step away and use Block or Report.',
    ),
    _SafetyTip(
      icon: Icons.location_on_rounded,
      title: 'Meet in public',
      body: 'For first meetings, choose a familiar public place and tell someone you trust.',
    ),
    _SafetyTip(
      icon: Icons.money_off_rounded,
      title: 'Never send money',
      body: 'Never send money, gift cards, or transfers to someone you met through Conexo.',
    ),
    _SafetyTip(
      icon: Icons.volunteer_activism_rounded,
      title: 'Respect boundaries',
      body: 'Healthy connections require mutual respect and consent.',
    ),
    _SafetyTip(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Keep conversations comfortable',
      body: 'You never have to continue a conversation that makes you uncomfortable.',
    ),
    _SafetyTip(
      icon: Icons.shield_rounded,
      title: 'Use Conexo safety tools',
      body: 'Block or report users whenever necessary. Your safety comes first.',
    ),
  ];

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
                      'Safety on Conexo',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Simple guidelines to help you connect safely and confidently.',
                  style: TextStyle(color: Color(0xFFB9C3DC)),
                ),
                const SizedBox(height: 24),
                ..._tips.map(
                  (tip) => EntranceFade(
                    child: _SafetyTipCard(tip: tip),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Safety'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
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

class _SafetyTip {
  const _SafetyTip({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _SafetyTipCard extends StatelessWidget {
  const _SafetyTipCard({required this.tip});

  final _SafetyTip tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tip.icon, color: const Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEAEEF9),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tip.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: const Color(0xFFB9C3DC),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
