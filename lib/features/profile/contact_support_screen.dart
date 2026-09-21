import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_widgets.dart';
import '../plans/plans_theme.dart';
import '../plans/plan_details_widgets.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const _supportEmail = 'support.contact@gmail.com';

  Future<void> _contactSupport() async {
    final uri = Uri.parse('mailto:$_supportEmail');
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open email client for $_supportEmail'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open email client for $_supportEmail'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cxCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                CircleGlassButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Back',
                ),
                const SizedBox(width: 4),
                Text(
                  'Contact Support',
                  style: plansDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.cxInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            GlassCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E8FA8).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Color(0xFF0E8FA8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Need help?',
                        style: plansDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.cxInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our support team is here to help with account issues, '
                    'safety concerns, reports, or other Conexo questions.',
                    style: plansBody(
                      fontSize: 14,
                      height: 1.5,
                      color: context.cxSoft,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.cxGlass,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.cxLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: context.cxSoft,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _supportEmail,
                          style: plansBody(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.cxInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ConexoButton(
                      label: 'Contact Support',
                      onPressed: _contactSupport,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'For safety concerns involving another user, use '
                    'Report a Problem so we can associate your request '
                    'with the relevant account.',
                    style: plansBody(
                      fontSize: 12.5,
                      height: 1.45,
                      color: context.cxSoft.withValues(alpha: .8),
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
