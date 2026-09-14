import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../setup/profile_setup_screen.dart';
import 'auth_scaffold.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  int get _strength {
    final p = _password.text;
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9!@#\$%^&*]').hasMatch(p)) s++;
    return s;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tick the box to confirm you\'re 18+ and cool with the Terms.')),
      );
      return;
    }
    setState(() => _loading = true);
    await ConexoScope.read(context).signIn();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      cxRoute(ProfileSetupScreen(firstName: _name.text.trim())),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    const labels = ['Too short', 'Getting there', 'Solid', 'Unbreakable'];
    return Form(
      key: _form,
      child: AuthScaffold(
        title: 'Let\'s get',
        accent: 'you in.',
        subtitle: 'Thirty seconds here, then the fun part: building a profile people actually want to reply to.',
        children: [
          CxField(
            controller: _name,
            label: 'First name',
            hint: 'What your friends call you',
            action: TextInputAction.next,
            validator: (v) => (v ?? '').trim().length < 2 ? 'Give us at least two letters.' : null,
          ),
          const SizedBox(height: 18),
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
            hint: '8+ characters',
            obscure: true,
            action: TextInputAction.done,
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < _strength
                          ? [c.danger, c.magenta, c.success][_strength - 1]
                          : c.line,
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(
                  _password.text.isEmpty ? '' : labels[_strength],
                  textAlign: TextAlign.right,
                  style: ConexoType.label(c.inkMute, size: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Pressable(
            onTap: () => setState(() => _agreed = !_agreed),
            scale: .99,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: _agreed ? c.warm : null,
                    border: _agreed ? null : Border.all(color: c.line, width: 1.6),
                  ),
                  child: _agreed
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I\'m 18 or older and I agree to the Terms and Privacy Policy.',
                    style: ConexoType.body(c.inkSoft, size: 13.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          CxButton(label: 'Continue', loading: _loading, onTap: _submit),
          const SizedBox(height: 26),
          const OrDivider(),
          const SizedBox(height: 22),
          SocialRow(
            onTap: (_) async {
              await ConexoScope.read(context).signIn();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                cxRoute(const ProfileSetupScreen(firstName: 'Sam')),
                (_) => false,
              );
            },
          ),
        ],
        footer: FooterLink(
          prompt: 'Already on Conexo?',
          action: 'Sign in',
          onTap: () => Navigator.of(context).pushReplacement(cxRoute(const SignInScreen())),
        ),
      ),
    );
  }
}
