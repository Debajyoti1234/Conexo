import 'package:flutter/material.dart';

import 'admin_auth_service.dart';
import '../../app/theme/app_widgets.dart';
import '../auth_components.dart';
import '../../core/supabase/auth_service.dart';
import 'admin_placeholder_screen.dart';

/// Premium standalone Admin Login screen.
///
/// Visually independent from the consumer Conexo login experience while
/// reusing the same shared UI primitives ([AuthPageFrame],
/// [AuthGlassCard], [ConexoTextField], [ConexoButton]).
///
/// Business logic lives entirely in [AdminAuthService]. This widget only
/// handles form state, validation, and a success callback hook.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    this.onAdminAuthenticated,
  });

  /// Called when authentication + server-side admin authorization succeed.
  /// Navigation is NOT implemented here — the parent wires this hook.
  final Future<void> Function()? onAdminAuthenticated;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AdminAuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      await widget.onAdminAuthenticated?.call();
    } on AdminUnauthorizedFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      backgroundImage: 'assets/images/auth/Login_background.png',
      showBackButton: true,
      child: AuthGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdminBrand(),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  ConexoTextField(
                    controller: _emailController,
                    label: 'Admin email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  ConexoTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 26),
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 18),
                  ],
                  ConexoButton(
                    label: 'Sign In',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin-specific branding block — clearly distinct from consumer auth.
class _AdminBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9D82FF).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            size: 30,
            color: Color(0xFFB7A5FF),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'CONEXO ADMIN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: Color(0xFFE9E2FF),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: const Color(0xFF9D82FF).withValues(alpha: 0.35),
            ),
          ),
          child: const Text(
            'PRIVATE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFFB7A5FF),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Owner administration dashboard',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9AA3C2),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Inline error banner for auth failures.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF5E2A3A).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B85).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFFF8FA3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFFFC4D4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}