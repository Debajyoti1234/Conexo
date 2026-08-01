import 'package:flutter/material.dart';

class ConexoButton extends StatelessWidget {
  const ConexoButton({required this.label, required this.onPressed, super.key, this.isLoading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: isLoading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}

class ConexoTextField extends StatefulWidget {
  const ConexoTextField({required this.controller, required this.label, required this.icon, super.key, this.validator, this.keyboardType, this.obscureText = false, this.textInputAction});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;

  @override
  State<ConexoTextField> createState() => _ConexoTextFieldState();
}

class _ConexoTextFieldState extends State<ConexoTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: isPassword && _obscured,
      autocorrect: !isPassword,
      enableSuggestions: !isPassword,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: isPassword ? IconButton(tooltip: _obscured ? 'Show password' : 'Hide password', icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscured = !_obscured)) : null,
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 52, width: 52, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(.18), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.people_alt_rounded, color: Color(0xFFB7A5FF))),
          const SizedBox(height: 28),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFFAFB8D4))),
        ],
      );
}
