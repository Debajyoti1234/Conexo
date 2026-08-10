import 'package:flutter/material.dart';
import '../app/router/app_router.dart';
import 'auth_components.dart';
import '../../core/supabase/auth_gate.dart';
import '../../core/supabase/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.phoneNumber});
  final String? phoneNumber;
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.phoneNumber);
  }

  @override
  void dispose() {
    _phone.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    print('[PHONE_OTP] _send() invoked, validating form...');
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await AuthService.signInWithPhone(_phone.text.trim());
        if (!mounted) return;
        setState(() => _codeSent = true);
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

  Future<void> _verify() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.verifyPhoneOtp(
        phone: _phone.text.trim(),
        token: token,
      );
      if (!mounted) return;

      final target = await AuthGate.navigateToTarget();
      if (!mounted) return;

      if (target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load profile. Please check your connection and try again.')),
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        AppRouter.slideRoute(target),
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

  @override
  Widget build(BuildContext context) => AuthPageFrame(
    backgroundImage: 'assets/images/auth/Login_background.png',
    showBackButton: true,
    child: Form(
      key: _formKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: _codeSent
            ? _OtpStep(onVerify: _verify, controller: _otpController, isLoading: _isLoading)
            : _PhoneStep(controller: _phone, onSend: _send, isLoading: _isLoading),
      ),
    ),
  );
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.controller, required this.onSend, required this.isLoading});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('phone'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthHeader(
        label: 'One last step',
        title: 'Stay connected.',
        subtitle: 'A quick verification keeps your account secure.',
      ),
      const SizedBox(height: 28),
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
      PrimaryButton(
        label: 'Send OTP',
        onPressed: () {
          if (!isLoading) onSend();
        },
      ),
    ],
  );
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({required this.onVerify, required this.controller, required this.isLoading});
  final VoidCallback onVerify;
  final TextEditingController controller;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('otp'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthHeader(
        label: 'One last step',
        title: 'Enter your code',
        subtitle: 'We sent a 6-digit code to your phone number.',
      ),
      const SizedBox(height: 28),
      _OtpInput(controller: controller),
      const SizedBox(height: 22),
      PrimaryButton(label: 'Verify OTP', onPressed: () {
        if (!isLoading) onVerify();
      }),
      const SizedBox(height: 16),
      const VerificationNote(),
    ],
  );
}

class _OtpInput extends StatelessWidget {
  const _OtpInput({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
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
