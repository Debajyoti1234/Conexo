import 'package:flutter/material.dart';

import 'admin_auth_service.dart';
import 'admin_shell.dart';
import 'admin_overview_screen.dart';
import '../../app/theme/app_theme.dart';

/// Temporary placeholder shown when the dedicated Admin account is
/// authenticated and authorized. Replaced by AdminShell in Phase 1C.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell();
  }
}