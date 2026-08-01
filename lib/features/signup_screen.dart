import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _acceptedTerms = false;
  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  void _submit() {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept the terms to continue.')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your Conexo account is ready!')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton()),
    body: SafeArea(top: false, child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AuthHeader(title: 'Create your account', subtitle: 'Start discovering events and people near you.'),
          const SizedBox(height: 34),
          ConexoTextField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded, textInputAction: TextInputAction.next, validator: (value) => (value ?? '').trim().length < 2 ? 'Enter your full name' : null),
          const SizedBox(height: 16),
          ConexoTextField(controller: _email, label: 'Email address', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: emailValidator),
          const SizedBox(height: 16),
          ConexoTextField(controller: _password, label: 'Create password', icon: Icons.lock_outline_rounded, obscureText: true, textInputAction: TextInputAction.done, validator: passwordValidator),
          const SizedBox(height: 8),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: _acceptedTerms, onChanged: (value) => setState(() => _acceptedTerms = value ?? false), controlAffinity: ListTileControlAffinity.leading, title: const Text('I agree to the Terms of Service and Privacy Policy', style: TextStyle(fontSize: 13, color: Color(0xFFAFB8D4)))),
          const SizedBox(height: 12),
          ConexoButton(label: 'Create account', onPressed: _submit),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account?', style: TextStyle(color: Color(0xFFAFB8D4))),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Log in')),
          ]),
        ]),
      )),
    ))),
  );
}
