import 'package:flutter/material.dart';

import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import 'sign_in_screen.dart';

/// Shown after sign-up when the account needs email confirmation.
class CheckInboxScreen extends StatelessWidget {
  const CheckInboxScreen({required this.email, super.key});
  final String email;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CxIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Reveal(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => c.brand.createShader(r),
                        child: const Icon(Icons.mark_email_unread_rounded, size: 34),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(index: 1, child: Text('Check your', style: ConexoType.display(c.ink, size: 40))),
                  Reveal(index: 2, child: GradientText('inbox.', style: ConexoType.display(c.ink, size: 40))),
                  const SizedBox(height: 14),
                  Reveal(
                    index: 3,
                    child: Text.rich(
                      TextSpan(
                        style: ConexoType.body(c.inkSoft, size: 15.5),
                        children: [
                          const TextSpan(text: 'We sent a confirmation link to '),
                          TextSpan(text: email, style: ConexoType.body(c.ink, size: 15.5, w: FontWeight.w700)),
                          const TextSpan(text: '. Tap it, then come back and sign in.'),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  CxButton(
                    label: 'I\'ve confirmed, sign me in',
                    onTap: () => Navigator.of(context).pushReplacement(cxRoute(const SignInScreen())),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Nothing yet? Check spam, or give it a minute.',
                      style: ConexoType.body(c.inkMute, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
