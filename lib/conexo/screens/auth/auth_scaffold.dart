import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/widgets.dart';

/// Shared frame for sign in / sign up: back button, big title, scrolling form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.accent,
    required this.subtitle,
    required this.children,
    this.footer,
    super.key,
  });

  /// Title is split so the last phrase can carry the brand gradient.
  final String title;
  final String accent;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Row(
                  children: [
                    CxIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    const ConexoMark(size: 34),
                  ],
                ),
                const SizedBox(height: 36),
                Reveal(child: Text(title, style: ConexoType.display(c.ink, size: 40))),
                Reveal(
                  index: 1,
                  child: GradientText(accent, style: ConexoType.display(c.ink, size: 40)),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 2,
                  child: Text(subtitle, style: ConexoType.body(c.inkSoft, size: 15.5)),
                ),
                const SizedBox(height: 32),
                for (var i = 0; i < children.length; i++)
                  Reveal(index: 3 + i, child: children[i]),
                if (footer != null) ...[const SizedBox(height: 28), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      children: [
        Expanded(child: Divider(color: c.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: ConexoType.label(c.inkMute)),
        ),
        Expanded(child: Divider(color: c.line)),
      ],
    );
  }
}

class SocialRow extends StatelessWidget {
  const SocialRow({required this.onTap, super.key});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    Widget tile(String id, Widget glyph, String label) => Expanded(
      child: Pressable(
        onTap: () => onTap(id),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line, width: 1.2),
          ),
          child: Semantics(
            label: 'Continue with $label',
            child: Center(child: glyph),
          ),
        ),
      ),
    );

    return Row(
      children: [
        tile('google', Text('G', style: ConexoType.title(c.ink, size: 22)), 'Google'),
        const SizedBox(width: 10),
        tile('apple', Icon(Icons.apple_rounded, color: c.ink, size: 26), 'Apple'),
        const SizedBox(width: 10),
        tile('phone', Icon(Icons.phone_iphone_rounded, color: c.ink, size: 22), 'phone'),
      ],
    );
  }
}

class FooterLink extends StatelessWidget {
  const FooterLink({required this.prompt, required this.action, required this.onTap, super.key});
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Center(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text.rich(
            TextSpan(
              text: '$prompt  ',
              style: ConexoType.body(c.inkSoft, size: 14),
              children: [
                TextSpan(
                  text: action,
                  style: ConexoType.body(c.violet, size: 14, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? validateEmail(String? v) {
  final e = v?.trim() ?? '';
  if (e.isEmpty) return 'We\'ll need your email for this one.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
    return 'That email looks a little off.';
  }
  return null;
}

String? validatePassword(String? v) =>
    (v ?? '').length < 8 ? 'Use at least 8 characters.' : null;
