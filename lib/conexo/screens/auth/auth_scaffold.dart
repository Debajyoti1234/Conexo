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
  final Widget? footer;
  final List<Widget> children;

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

class GoogleButton extends StatelessWidget {
  const GoogleButton({required this.onTap, this.loading = false, super.key});
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Pressable(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: c.line, width: 1.2),
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: c.ink),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('G', style: ConexoType.title(c.ink, size: 20)),
                  const SizedBox(width: 10),
                  Text('Continue with Google', style: ConexoType.body(c.ink, size: 15, w: FontWeight.w700)),
                ],
              ),
      ),
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

void showCxSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
