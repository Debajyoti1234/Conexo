import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import 'auth_components.dart';
import 'main_shell.dart';
import 'phone_auth_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continueToConexo() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pushAndRemoveUntil(
        AppRouter.slideRoute(const MainShell()),
        (route) => false,
      );
    }
  }

  void _openPhoneAuth() {
    Navigator.of(context).push(AppRouter.slideRoute(const PhoneAuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthPageFrame(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                title: 'Welcome back 👋',
                subtitle: 'Ready to meet someone new?',
              ),
              const SizedBox(height: 34),
              SocialLoginButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                label: 'Continue with Apple',
                icon: Icons.apple_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                label: 'Continue with Phone Number',
                icon: Icons.phone_iphone_rounded,
                onPressed: _openPhoneAuth,
              ),
              const SizedBox(height: 28),
              const AuthDivider(),
              const SizedBox(height: 28),
              PremiumTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: emailValidator,
              ),
              const SizedBox(height: 16),
              PremiumTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: passwordValidator,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Continue', onPressed: _continueToConexo),
              const SizedBox(height: 22),
              AuthFooter(
                prompt: 'New to Conexo?',
                action: 'Create account',
                onTap: () => Navigator.of(
                  context,
                ).push(AppRouter.slideRoute(const SignupScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? passwordValidator(String? value) {
  if ((value ?? '').length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}
