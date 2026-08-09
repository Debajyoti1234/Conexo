import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../features/auth_components.dart';
import '../../features/login_screen.dart';

class ConfirmEmailScreen extends StatelessWidget {
  const ConfirmEmailScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      backgroundImage: 'assets/images/auth/Login_background.png',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            label: 'Almost there',
            title: 'Confirm your email',
            subtitle:
                'We sent a confirmation link to your inbox. Tap it to finish setting up your account.',
          ),
          const SizedBox(height: 28),
          AuthGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB7A5FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Back to login',
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    AppRouter.slideRoute(const LoginScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
