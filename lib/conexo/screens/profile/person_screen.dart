import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/profile_view.dart';

/// Read-only full profile (from a chat, or previewing your own).
class PersonScreen extends StatelessWidget {
  const PersonScreen({required this.person, this.title, super.key});
  final Person person;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  CxIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  if (title != null)
                    Expanded(child: Text(title!, style: ConexoType.title(c.ink, size: 18))),
                ],
              ),
            ),
            Expanded(child: ProfileView(person: person, bottomPadding: 40)),
          ],
        ),
      ),
    );
  }
}
