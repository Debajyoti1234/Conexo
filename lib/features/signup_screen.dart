import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../core/supabase/auth_service.dart';
import 'auth/confirm_email_screen.dart';
import 'auth_components.dart';
import 'phone_auth_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Set<String> _interests = <String>{};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_interests.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose at least one interest to continue.'),
          ),
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        final email = _emailController.text.trim();
        final shouldNavigateToPhone =
            email.isEmpty || !_isValidEmail(email);
        if (shouldNavigateToPhone) {
          if (!mounted) return;
          Navigator.of(context).push(
            AppRouter.slideRoute(
              PhoneAuthScreen(phoneNumber: _phoneController.text),
            ),
          );
          return;
        }
        await AuthService.signUp(
          email: email,
          password: _passwordController.text,
          name: _nameController.text,
        );
        if (!mounted) return;
        Navigator.of(context).push(
          AppRouter.slideRoute(
            ConfirmEmailScreen(email: email),
          ),
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

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      backgroundImage: 'assets/images/auth/Login_background.png',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              label: "Let's begin",
              title: 'Together begins today.',
              subtitle: 'Meet, plan, and grow together.',
            ),
            const SizedBox(height: 28),
            AuthGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumTextField(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _phoneController,
                    label: 'Phone number',
                    icon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: phoneValidator,
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _emailController,
                    label: 'Email address (optional)',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: optionalEmailValidator,
                  ),
                  const SizedBox(height: 14),
                  PremiumTextField(
                    controller: _passwordController,
                    label: 'Create password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: passwordValidator,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'What feels like you?',
                    style: AuthTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a few interests for better introductions.',
                    style: AuthTextStyles.helper,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: authInterests.map((interest) {
                      return InterestChip(
                        interest: interest,
                        selected: _interests.contains(interest.label),
                        onTap: () => setState(() {
                          _interests.contains(interest.label)
                              ? _interests.remove(interest.label)
                              : _interests.add(interest.label);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Create my account',
                    onPressed: () {
                      if (!_isLoading) _submit();
                    },
                  ),
                  const SizedBox(height: 16),
                  const VerificationNote(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            AuthFooter(
              prompt: 'Already part of Conexo?',
              action: 'Welcome back',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

String? phoneValidator(String? value) {
  if ((value ?? '').replaceAll(RegExp(r'\D'), '').length < 8) {
    return 'Enter a valid phone number';
  }
  return null;
}

String? passwordValidator(String? value) {
  if ((value ?? '').length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? optionalEmailValidator(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return null;
  }
  return emailValidator(value);
}

String? emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}
