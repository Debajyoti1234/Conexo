import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';
import 'contact_support_screen.dart';
import 'safety_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = <_Faq>[
    _Faq(
      question: 'What is Conexo?',
      answer:
          'Conexo is a social connection platform designed to help people discover meaningful connections, conversations, and experiences in a comfortable and respectful environment.',
    ),
    _Faq(
      question: 'How does People / Discovery work?',
      answer:
          'People helps you discover relevant profiles based on your discovery preferences and available profile information. You can adjust these preferences anytime from Profile → Discovery Preferences.',
    ),
    _Faq(
      question: 'How do I change my Discovery Preferences?',
      answer:
          'Open Profile → Discovery Preferences to update your preferred discovery distance and age range.',
    ),
    _Faq(
      question: 'How do I block someone?',
      answer:
          'Open the user\'s available actions and choose Block. Blocked users can be managed from Profile → Safety → Blocked Users.',
    ),
    _Faq(
      question: 'How do I report someone?',
      answer:
          'Use Profile → Safety → Report a Problem. You can select a reason, add details, and optionally attach a screenshot.',
    ),
    _Faq(
      question: 'How do I edit my profile?',
      answer:
          'Open Profile → Edit Profile and update your information.',
    ),
    _Faq(
      question: 'How do I keep my account safe?',
      answer:
          'Visit Profile → Safety → Safety Tips for guidance on staying safe while connecting with others.',
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
                      'Help & Support',
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
                    'Find answers, learn how Conexo works, or get in touch '
                    'with our support team.',
                    style: TextStyle(color: Color(0xFFB9C3DC)),
                  ),
                ),
                const SizedBox(height: 26),
                ..._faqs.map(
                  (faq) => EntranceFade(
                    child: _FaqCard(faq: faq),
                  ),
                ),
                const SizedBox(height: 28),
                EntranceFade(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22BFE0).withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                color: Color(0xFF22BFE0),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Still need help?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: .92),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Our support team is here for you.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: const Color(0xFFB9C3DC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ConexoButton(
                            label: 'Contact Support',
                            onPressed: () => Navigator.of(context).push(
                              AppRouter.premiumProfileRoute(
                                const ContactSupportScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                EntranceFade(
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE36D9D).withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Color(0xFFE36D9D),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need to report another user?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: .92),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Use Conexo\'s safety tools to report or block '
                                    'users who make you uncomfortable.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: const Color(0xFFB9C3DC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              AppRouter.premiumProfileRoute(
                                const SafetyScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Open Safety'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8B5CF6),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
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

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEAEEF9),
          ),
        ),
        iconColor: const Color(0xFF8B5CF6),
        collapsedIconColor: const Color(0xFFB9C3DC),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          Text(
            faq.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: const Color(0xFFB9C3DC),
            ),
          ),
        ],
      ),
    );
  }
}
