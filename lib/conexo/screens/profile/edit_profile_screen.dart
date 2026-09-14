import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../setup/profile_setup_screen.dart';

/// Editing reuses the setup flow, pre-filled, and pops when saved.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = ConexoScope.of(context).profile;
    return ProfileSetupScreen(firstName: me.name, initial: me);
  }
}
