import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../features/profile/profile_repository.dart';
import '../../features/profile/profile_creation_screen.dart';
import '../../features/main_shell.dart';
import '../../features/profile/supabase_profile_repository.dart';

/// Centralized gate that determines post-auth navigation target based on profile status.
///
/// Only called when a session already exists. Callers are responsible for
/// no-session routing.
class AuthGate {
  const AuthGate._();

  static Future<Widget?> navigateToTarget({ProfileRepository? repository}) async {
    final repo = repository ?? const SupabaseProfileRepository();
    final status = await repo.checkProfileStatus();

    switch (status) {
      case ProfileStatus.missing:
      case ProfileStatus.incomplete:
        return ProfileCreationScreen(
          repository: repo,
          onComplete: (context) {
            Navigator.of(context).pushAndRemoveUntil(
              AppRouter.slideRoute(MainShell(key: mainShellKey)),
              (route) => false,
            );
          },
        );
      case ProfileStatus.complete:
        return MainShell(key: mainShellKey);
      case ProfileStatus.error:
        return null;
    }
  }
}
