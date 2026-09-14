import 'package:flutter/widgets.dart';

import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../setup/profile_setup_screen.dart';
import '../shell.dart';
import 'welcome_screen.dart';

/// Where someone lands for a given session stage.
Widget destinationFor(SessionStage stage, ConexoState s) => switch (stage) {
  SessionStage.ready => const HomeShell(),
  SessionStage.needsProfile => ProfileSetupScreen(firstName: s.suggestedName),
  SessionStage.signedOut => const WelcomeScreen(),
};
