import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/cx_image.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';
import 'person_screen.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final me = s.profile;

    // Simple, honest completeness score.
    final checks = <(bool, String)>[
      (me.photos.length >= 4, 'Add ${4 - me.photos.length} more photo${4 - me.photos.length == 1 ? '' : 's'} — four is the sweet spot.'),
      (me.prompts.length >= 3, 'Answer a third prompt. It gives people one more reason to say hi.'),
      (me.vibes.length >= 4, 'Pick a few more vibes so we can find your people.'),
      (me.verified, 'Verify your photos to get the blue check.'),
    ];
    final done = checks.where((x) => x.$1).length;
    final pct = (40 + done * 15).clamp(0, 100);
    final tip = checks.where((x) => !x.$1).map((x) => x.$2).firstOrNull;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 130),
        children: [
          ScreenTitle(
            title: 'You',
            trailing: CxIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: () => Navigator.of(context).push(cxRoute(const SettingsScreen())),
            ),
          ),
          const SizedBox(height: 16),
          Reveal(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(photo: me.firstPhoto, size: 132, ring: true),
                    Positioned(
                      right: 2,
                      bottom: 4,
                      child: Pressable(
                        onTap: () => Navigator.of(context).push(cxRoute(const EditProfileScreen())),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bg, width: 3),
                          ),
                          child: Icon(Icons.edit_rounded, size: 18, color: c.isNight ? c.bg : Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(me.age > 0 ? '${me.name}, ${me.age}' : me.name, style: ConexoType.display(c.ink, size: 32)),
                    if (me.verified) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified_rounded, color: c.cyan, size: 22),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [me.job, me.city].where((x) => x.isNotEmpty).join('  ·  '),
                  style: ConexoType.body(c.inkSoft, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Reveal(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: CxButton(
                          label: 'Edit profile',
                          variant: CxButtonVariant.ink,
                          height: 50,
                          onTap: () => Navigator.of(context).push(cxRoute(const EditProfileScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CxButton(
                          label: 'Preview',
                          variant: CxButtonVariant.soft,
                          height: 50,
                          onTap: () => Navigator.of(context).push(
                            cxRoute(PersonScreen(person: me, title: 'This is what people see')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Reveal(
                  index: 2,
                  child: CxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Profile strength', style: ConexoType.title(c.ink, size: 18)),
                            const Spacer(),
                            GradientText('$pct%', style: ConexoType.display(c.ink, size: 26)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 8,
                            color: c.surfaceAlt,
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: pct / 100),
                              duration: const Duration(milliseconds: 1100),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => FractionallySizedBox(
                                widthFactor: v,
                                heightFactor: 1,
                                child: DecoratedBox(decoration: BoxDecoration(gradient: c.brand)),
                              ),
                            ),
                          ),
                        ),
                        if (tip != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 18, color: c.violet),
                              const SizedBox(width: 8),
                              Expanded(child: Text(tip, style: ConexoType.body(c.inkSoft, size: 13.5))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 3,
                  child: CxCard(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your photos', style: ConexoType.title(c.ink, size: 18)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: me.photos.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CxImage(me.photos[i], width: 96, height: 120),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < me.prompts.length; i++) ...[
                  Reveal(
                    index: 4 + i,
                    child: CxCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.prompts[i].question, style: ConexoType.label(c.inkSoft, size: 13)),
                            const SizedBox(height: 10),
                            Text(me.prompts[i].answer, style: ConexoType.title(c.ink, size: 22)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
