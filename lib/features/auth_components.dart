import 'package:flutter/material.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.child,
    super.key,
    this.showBackButton = false,
  });
  final Widget child;
  final bool showBackButton;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              if (showBackButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: .28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.people_alt_rounded, color: Colors.white),
      ),
      const SizedBox(height: 28),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFFB9C3DC),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    ],
  );
}

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 23),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF182039).withValues(alpha: .72),
        side: BorderSide(color: Colors.white.withValues(alpha: .12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}

class PremiumTextField extends StatefulWidget {
  const PremiumTextField({
    required this.controller,
    required this.label,
    required this.icon,
    super.key,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    validator: widget.validator,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    obscureText: widget.obscureText && _obscured,
    autocorrect: !widget.obscureText,
    enableSuggestions: !widget.obscureText,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: Icon(widget.icon),
      suffixIcon: widget.obscureText
          ? IconButton(
              onPressed: () => setState(() => _obscured = !_obscured),
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            )
          : null,
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: Colors.white.withValues(alpha: .12))),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'OR',
          style: TextStyle(
            color: Color(0xFF8995B5),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(child: Divider(color: Colors.white.withValues(alpha: .12))),
    ],
  );
}

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });
  final String prompt;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(prompt, style: const TextStyle(color: Color(0xFFB9C3DC))),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class AuthInterest {
  const AuthInterest(this.label, this.icon);
  final String label;
  final IconData icon;
}

const authInterests = <AuthInterest>[
  AuthInterest('Coffee', Icons.coffee_rounded),
  AuthInterest('Music', Icons.music_note_rounded),
  AuthInterest('Photography', Icons.camera_alt_rounded),
  AuthInterest('Travel', Icons.flight_takeoff_rounded),
  AuthInterest('Food', Icons.restaurant_rounded),
  AuthInterest('Gaming', Icons.sports_esports_rounded),
  AuthInterest('Fitness', Icons.fitness_center_rounded),
  AuthInterest('Movies', Icons.movie_outlined),
  AuthInterest('Creative', Icons.palette_outlined),
];

class InterestChip extends StatelessWidget {
  const InterestChip({
    required this.interest,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final AuthInterest interest;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(interest.label),
    avatar: Icon(
      interest.icon,
      size: 17,
      color: selected ? Colors.white : const Color(0xFFB7A5FF),
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: const Color(0xFF7659DF),
    backgroundColor: const Color(0xFF171F35),
    side: BorderSide(
      color: selected ? Colors.transparent : const Color(0xFF2C3650),
    ),
    labelStyle: TextStyle(
      color: selected ? Colors.white : const Color(0xFFDDE3F4),
      fontWeight: FontWeight.w600,
    ),
  );
}

class VerificationNote extends StatelessWidget {
  const VerificationNote({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.verified_user_outlined, size: 17, color: Color(0xFF77DFF1)),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Phone verification keeps Conexo safer for everyone.',
          style: TextStyle(color: Color(0xFFB9C3DC), fontSize: 12),
        ),
      ),
    ],
  );
}

abstract final class AuthTextStyles {
  static const sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );
  static const helper = TextStyle(color: Color(0xFFB9C3DC), fontSize: 13);
}
