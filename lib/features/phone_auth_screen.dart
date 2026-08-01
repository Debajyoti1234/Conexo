import 'package:flutter/material.dart';
import '../app/router/app_router.dart';
import 'auth_components.dart';
import 'main_shell.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.phoneNumber});
  final String? phoneNumber;
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  bool _codeSent = false;
  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.phoneNumber);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _send() {
    if (_formKey.currentState!.validate()) setState(() => _codeSent = true);
  }

  void _verify() {
    Navigator.of(context).pushAndRemoveUntil(
      AppRouter.slideRoute(const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthPageFrame(
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _codeSent
              ? _OtpStep(onVerify: _verify)
              : _PhoneStep(controller: _phone, onSend: _send),
        ),
      ),
    ),
  );
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('phone'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthHeader(
        title: 'Verify your number',
        subtitle:
            'A verified community helps every connection begin with trust.',
      ),
      const SizedBox(height: 34),
      PremiumTextField(
        controller: controller,
        label: 'Phone number',
        icon: Icons.phone_iphone_rounded,
        keyboardType: TextInputType.phone,
        validator: (value) =>
            (value ?? '').replaceAll(RegExp(r'\D'), '').length < 8
            ? 'Enter a valid phone number'
            : null,
      ),
      const SizedBox(height: 22),
      PrimaryButton(label: 'Send OTP', onPressed: onSend),
    ],
  );
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({required this.onVerify});
  final VoidCallback onVerify;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('otp'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthHeader(
        title: 'Enter your code',
        subtitle: 'We sent a 6-digit code to your phone number.',
      ),
      const SizedBox(height: 34),
      const _OtpInput(),
      const SizedBox(height: 22),
      PrimaryButton(label: 'Verify OTP', onPressed: onVerify),
      const SizedBox(height: 16),
      const VerificationNote(),
    ],
  );
}

class _OtpInput extends StatelessWidget {
  const _OtpInput();
  @override
  Widget build(BuildContext context) => TextFormField(
    keyboardType: TextInputType.number,
    maxLength: 6,
    textAlign: TextAlign.center,
    decoration: const InputDecoration(
      labelText: '6-digit verification code',
      counterText: '',
      prefixIcon: Icon(Icons.lock_outline_rounded),
    ),
    validator: (value) =>
        (value ?? '').length == 6 ? null : 'Enter the 6-digit code',
  );
}
