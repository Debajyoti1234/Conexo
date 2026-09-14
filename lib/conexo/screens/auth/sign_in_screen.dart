import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../shell.dart';
import 'auth_scaffold.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _enter();
  }

  Future<void> _enter() async {
    setState(() => _loading = true);
    await ConexoScope.read(context).signIn();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(cxRoute(const HomeShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Form(
      key: _form,
      child: AuthScaffold(
        title: 'Hey, you\'re',
        accent: 'back.',
        subtitle: 'Pick up where you left off. Someone might be waiting on your reply.',
        children: [
          CxField(
            controller: _email,
            label: 'Email',
            hint: 'you@email.com',
            keyboardType: TextInputType.emailAddress,
            action: TextInputAction.next,
            validator: validateEmail,
          ),
          const SizedBox(height: 18),
          CxField(
            controller: _password,
            label: 'Password',
            hint: 'Your password',
            obscure: true,
            action: TextInputAction.done,
            validator: validatePassword,
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset link sent. Check your inbox.')),
              ),
              style: TextButton.styleFrom(foregroundColor: c.violet),
              child: Text('Forgot password?', style: ConexoType.label(c.violet, size: 13)),
            ),
          ),
          const SizedBox(height: 10),
          CxButton(label: 'Sign in', loading: _loading, onTap: _submit),
          const SizedBox(height: 26),
          const OrDivider(),
          const SizedBox(height: 22),
          SocialRow(onTap: (_) => _enter()),
        ],
        footer: FooterLink(
          prompt: 'New to Conexo?',
          action: 'Create an account',
          onTap: () => Navigator.of(context).pushReplacement(cxRoute(const SignUpScreen())),
        ),
      ),
    );
  }
}
