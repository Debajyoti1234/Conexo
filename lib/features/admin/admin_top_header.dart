import 'package:flutter/material.dart';

import 'admin_auth_service.dart';

/// Top header for the Admin Dashboard shell.
class AdminTopHeader extends StatelessWidget {
  const AdminTopHeader({
    required this.title,
    required this.onMenuTap,
    required this.onSignOut,
    super.key,
  });

  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2438)),
        ),
      ),
      child: Row(
        children: [
          // Menu toggle (visible on narrow widths).
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: const Color(0xFF9AA3C2),
            tooltip: 'Toggle menu',
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Admin account indicator.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: const Color(0xFF9D82FF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 14,
                  color: Color(0xFFB7A5FF),
                ),
                const SizedBox(width: 6),
                Text(
                  AdminAuthService.currentUser?.email ?? 'Admin',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE9E2FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: const Color(0xFF7E88A8),
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }
}