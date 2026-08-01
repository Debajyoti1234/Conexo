import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import 'auth_components.dart';
import 'login_screen.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _interests.isNotEmpty) {
      Navigator.of(context).push(
        AppRouter.slideRoute(
          PhoneAuthScreen(phoneNumber: _phoneController.text),
        ),
      );
      return;
    }
    if (_interests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one interest to continue.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthPageFrame(
        showBackButton: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                title: 'Create your circle',
                subtitle:
                    'A few details help us make every introduction feel safer.',
              ),
              const SizedBox(height: 30),
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
              const SizedBox(height: 28),
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
              const SizedBox(height: 28),
              PrimaryButton(label: 'Create Account', onPressed: _submit),
              const SizedBox(height: 16),
              const VerificationNote(),
              const SizedBox(height: 18),
              AuthFooter(
                prompt: 'Already have an account?',
                action: 'Log in',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
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

String? optionalEmailValidator(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return null;
  }
  return emailValidator(value);
}
