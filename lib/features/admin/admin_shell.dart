import 'package:flutter/material.dart';

import 'admin_auth_service.dart';
import 'admin_overview_screen.dart';
import 'admin_sidebar.dart';
import 'admin_top_header.dart';
import 'admin_users_screen.dart';
import 'admin_verification_screen.dart';
import 'admin_manual_verification_screen.dart';
import '../../app/theme/app_theme.dart';

/// Admin Dashboard Shell — web-only private administration area.
///
/// Isolated from the consumer Conexo app. This shell provides:
///   • Persistent left sidebar navigation
///   • Top header with branding and sign-out
///   • Main content area
///   • Responsive layout (collapses on narrow widths)
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedSection = 0;
  bool _sidebarCollapsed = false;

  static const _sectionTitles = <String>[
    'Dashboard',
    'Users',
    'Verification',
    'Manual Verification',
    'Reports',
    'Connections',
    'Rooms',
    'Analytics',
    'Diagnostics',
    'Settings',
  ];

  static const _sectionIcons = <IconData>[
    Icons.dashboard_outlined,
    Icons.people_outlined,
    Icons.verified_user_outlined,
    Icons.assignment_turned_in,
    Icons.report_outlined,
    Icons.hub_outlined,
    Icons.meeting_room_outlined,
    Icons.bar_chart_outlined,
    Icons.bug_report_outlined,
    Icons.settings_outlined,
  ];

  void _onSectionSelected(int index) {
    setState(() => _selectedSection = index);
    // On mobile/collapsed, close the drawer after selection.
    if (MediaQuery.of(context).size.width < 900) {
      setState(() => _sidebarCollapsed = true);
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _signOut() async {
    await AdminAuthService.signOut();
  }

  Widget _contentFor(int index) {
    switch (index) {
      case 0:
        return const AdminOverviewScreen();
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminVerificationScreen();
      case 3:
        return const AdminManualVerificationScreen();
      default:
        return _PlaceholderSection(title: _sectionTitles[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 900;

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar — persistent on desktop, collapsible/overlay on narrow.
          if (!isNarrow || _sidebarCollapsed == false)
            AdminSidebar(
              sectionTitles: _sectionTitles,
              sectionIcons: _sectionIcons,
              selectedIndex: _selectedSection,
              onSectionSelected: _onSectionSelected,
              collapsed: isNarrow || _sidebarCollapsed,
              onToggle: _toggleSidebar,
              onSignOut: _signOut,
            ),
          // Main content area.
          Expanded(
            child: Column(
              children: [
                AdminTopHeader(
                  title: _sectionTitles[_selectedSection],
                  onMenuTap: _toggleSidebar,
                  onSignOut: _signOut,
                ),
                const Divider(height: 1, color: Color(0xFF1E2438)),
                Expanded(
                  child: _contentFor(_selectedSection),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown for every non-Dashboard section until real screens are built.
class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF9D82FF).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.construction_outlined,
                size: 30,
                color: Color(0xFFB7A5FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This section is a placeholder.\n\n'
              'Real admin management functionality will be built in a '
              'future phase with its own security review. This screen exists '
              'only to demonstrate navigation structure.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9AA3C2),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}