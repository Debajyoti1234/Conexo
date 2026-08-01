import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import '../app/theme/app_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome back to Conexo!')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AuthHeader(title: 'Welcome back', subtitle: 'Your next connection could be just around the corner.'),
          const SizedBox(height: 42),
          ConexoTextField(controller: _email, label: 'Email address', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: emailValidator),
          const SizedBox(height: 16),
          ConexoTextField(controller: _password, label: 'Password', icon: Icons.lock_outline_rounded, obscureText: true, textInputAction: TextInputAction.done, validator: passwordValidator),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot password?'))),
          const SizedBox(height: 18),
          ConexoButton(label: 'Log in', onPressed: _submit),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to Conexo?', style: TextStyle(color: Color(0xFFAFB8D4))),
            TextButton(onPressed: () => Navigator.of(context).push(AppRouter.slideRoute(const SignupScreen())), child: const Text('Create an account')),
          ]),
        ]),
      )),
    ))),
  );
}

String? emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
  return null;
}

String? passwordValidator(String? value) => (value ?? '').length < 8 ? 'Password must be at least 8 characters' : null;
