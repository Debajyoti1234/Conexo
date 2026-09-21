import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/router/app_router.dart';
import '../plans/plans_theme.dart';
import '../plans/plan_details_widgets.dart';
import '../home_discovery_animations.dart';
import 'profile_repository.dart';
import 'blocked_users_screen.dart';
import 'contact_support_screen.dart';
import 'report_problem_screen.dart';
import 'safety_tips_screen.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

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
                  'Safety',
                  style: plansDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.cxInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Your safety comes first. Tools to keep your experience secure '
                'and comfortable.',
                style: TextStyle(color: context.cxSoft),
              ),
            ),
            const SizedBox(height: 22),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.flag_outlined,
                iconColor: context.cxDanger,
                title: 'Report a Problem',
                subtitle: 'Tell us about inappropriate behavior or content.',
                onTap: () => _openReportProblem(context),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.block_rounded,
                iconColor: context.cxAccentSoft,
                title: 'Blocked Users',
                subtitle: 'Review and manage people you have blocked.',
                onTap: () => _openBlockedUsers(context),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.shield_outlined,
                iconColor: context.cxSuccess,
                title: 'Safety Tips',
                subtitle: 'Advice for meeting new people safely.',
                onTap: () => _openSafetyTips(context),
              ),
            ),
            const SizedBox(height: 12),
            EntranceFade(
              child: _SafetyTile(
                icon: Icons.support_agent_rounded,
                iconColor: context.cxAccent,
                title: 'Contact Support',
                subtitle: 'Get help from the Conexo team.',
                onTap: () => _openContactSupport(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReportProblem(BuildContext context) {
    Navigator.of(context).push(
      AppRouter.premiumProfileRoute(const ReportProblemScreen()),
    );
  }

  void _openBlockedUsers(BuildContext context) {
    Navigator.of(context).push(
      AppRouter.premiumProfileRoute(const BlockedUsersScreen()),
    );
  }

  void _openSafetyTips(BuildContext context) {
    Navigator.of(context).push(
      AppRouter.premiumProfileRoute(const SafetyTipsScreen()),
    );
  }

  void _openContactSupport(BuildContext context) {
    Navigator.of(context).push(
      AppRouter.premiumProfileRoute(const ContactSupportScreen()),
    );
  }
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

@override
  Widget build(BuildContext context) {
    return Material(
      color: context.cxSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.cxLine),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: context.cxInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.cxSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.cxSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium route into the Safety hub — delegates to the shared Profile
/// transition so every Profile sub-screen feels identical.
Route<void> premiumSafetyRoute({ProfileRepository? repository}) {
  return AppRouter.premiumProfileRoute(const SafetyScreen());
}
