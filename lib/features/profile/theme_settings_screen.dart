import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/theme_preferences.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                children: [
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how Conexo looks on this device.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemePreferences.mode,
                    builder: (_, selectedMode, _) {
                      return RadioGroup<ThemeMode>(
                        groupValue: selectedMode,
                        onChanged: (value) {
                          if (value != null) {
                            ThemePreferences.setMode(value);
                          }
                        },
                        child: Column(
                          children: [
                            _ThemeOption(
                              mode: ThemeMode.light,
                              icon: Icons.light_mode_rounded,
                              title: 'Light',
                              subtitle: 'Friend light visual design',
                              selected: selectedMode == ThemeMode.light,
                            ),
                            const SizedBox(height: 12),
                            _ThemeOption(
                              mode: ThemeMode.dark,
                              icon: Icons.dark_mode_rounded,
                              title: 'Dark',
                              subtitle: 'Current Conexo purple/black design',
                              selected: selectedMode == ThemeMode.dark,
                            ),
                            const SizedBox(height: 12),
                            _ThemeOption(
                              mode: ThemeMode.system,
                              icon: Icons.brightness_auto_rounded,
                              title: 'System',
                              subtitle: 'Follow device appearance',
                              selected: selectedMode == ThemeMode.system,
                            ),
                          ],
                        ),
                      );
                    },
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ThemePreferences.setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.secondaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? colorScheme.secondary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Radio<ThemeMode>(value: mode),
          ],
        ),
      ),
    );
  }
}

Route<void> premiumThemeSettingsRoute() {
  return AppRouter.premiumProfileRoute(const ThemeSettingsScreen());
}
