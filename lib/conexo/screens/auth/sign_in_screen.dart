import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import 'auth_routing.dart';
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
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go(SessionStage stage) {
    Navigator.of(context).pushAndRemoveUntil(
      cxRoute(destinationFor(stage, ConexoScope.read(context))),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final stage = await ConexoScope.read(context).signIn(_email.text.trim(), _password.text);
      if (mounted) _go(stage);
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'Couldn\'t reach Conexo. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      final stage = await ConexoScope.read(context).signInWithGoogle();
      if (!mounted || stage == null || stage == SessionStage.signedOut) return;
      _go(stage);
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgot() async {
    if (validateEmail(_email.text) != null) {
      showCxSnack(context, 'Type your email above first, then tap Forgot password.');
      return;
    }
    try {
      await ConexoScope.read(context).resetPassword(_email.text.trim());
      if (mounted) showCxSnack(context, 'Reset link sent to ${_email.text.trim()}. Check your inbox.');
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    }
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
        footer: FooterLink(
          prompt: 'New to Conexo?',
          action: 'Create an account',
          onTap: () => Navigator.of(context).pushReplacement(cxRoute(const SignUpScreen())),
        ),
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
              onPressed: _forgot,
              style: TextButton.styleFrom(foregroundColor: c.violet),
              child: Text('Forgot password?', style: ConexoType.label(c.violet, size: 13)),
            ),
          ),
          const SizedBox(height: 10),
          CxButton(label: 'Sign in', loading: _loading, onTap: _submit),
          const SizedBox(height: 26),
          const OrDivider(),
          const SizedBox(height: 22),
          GoogleButton(onTap: _google, loading: _googleLoading),
        ],
      ),
    );
  }
}
