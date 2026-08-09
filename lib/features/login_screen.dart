import 'package:flutter/material.dart';

import '../core/supabase/auth_service.dart';
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
  bool _remember = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueToConexo() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await AuthService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          AppRouter.slideRoute(const MainShell()),
          (route) => false,
        );
      } on AuthFailure catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _openPhoneAuth() {
    Navigator.of(context).push(AppRouter.slideRoute(const PhoneAuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      backgroundImage: 'assets/images/auth/Login_background.png',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              label: 'Welcome back',
              title: 'Where connections feel real. ✨',
              subtitle: 'Your next meaningful moment starts here.',
            ),
            const SizedBox(height: 28),
            AuthGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumTextField(
                    controller: _emailController,
                    label: 'Email',
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
                  const SizedBox(height: 12),
                  RememberForgotRow(
                    remember: _remember,
                    onRememberChanged: (value) =>
                        setState(() => _remember = value),
                    onForgot: () {},
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Continue to Conexo',
                    onPressed: () {
                      if (!_isLoading) _continueToConexo();
                    },
                  ),
                  const SizedBox(height: 24),
                  const AuthDivider(),
                  const SizedBox(height: 20),
                  SocialButtonsRow(
                    buttons: [
                      SocialLoginButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata_rounded,
                        onPressed: () {},
                      ),
                      SocialLoginButton(
                        label: 'Apple',
                        icon: Icons.apple_rounded,
                        onPressed: () {},
                      ),
                      SocialLoginButton(
                        label: 'Phone',
                        icon: Icons.phone_iphone_rounded,
                        onPressed: _openPhoneAuth,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AuthFooter(
              prompt: 'New here?',
              action: 'Create your space',
              onTap: () => Navigator.of(
                context,
              ).push(AppRouter.slideRoute(const SignupScreen())),
            ),
          ],
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
