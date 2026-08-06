import 'dart:ui';

import 'package:flutter/material.dart';

/// Returns the responsive logo edge size for the auth hero.
double _authLogoSize(double width) {
  if (width < 350) return 88;
  if (width > 600) return 104;
  return 96;
}

class AuthPageFrame extends StatefulWidget {
  const AuthPageFrame({
    required this.child,
    required this.backgroundImage,
    super.key,
    this.showBackButton = false,
  });
  final Widget child;
  final String backgroundImage;
  final bool showBackButton;

  @override
  State<AuthPageFrame> createState() => _AuthPageFrameState();
}

class _AuthPageFrameState extends State<AuthPageFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        // Background hero — animated, isolated in its own RepaintBoundary so
        // typing in the form never repaints the artwork.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + (_controller.value * 0.015),
              child: Opacity(
                opacity: 1.0 - (_controller.value * 0.04),
                child: child,
              ),
            ),
            child: Image.asset(
              widget.backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        // Premium dark overlay for readability while keeping artwork visible.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x730B1020), Color(0xD90B1020)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.showBackButton)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _AuthBackButton(
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 8),
                          widget.child,
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF151B2E).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: Color(0xFFDDE3F4),
        ),
      ),
    ),
  );
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.label,
    required this.title,
    required this.subtitle,
    super.key,
  });
  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final logoSize = _authLogoSize(MediaQuery.sizeOf(context).width);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo is the sole branding element — no wordmark beneath it.
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/logo/conexo_logo.png.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 1,
                color: const Color(0xFF9D82FF).withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB7A5FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 1,
                color: const Color(0xFF9D82FF).withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC7CFE4),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Transform.translate(
      offset: Offset(0, 16 * (1 - value)),
      child: Opacity(opacity: value, child: child),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151B2E).withValues(alpha: 0.57),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.11),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    ),
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
    height: 54,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDDE3F4),
        backgroundColor: const Color(0xFF151B2E).withValues(alpha: 0.45),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: const Color(0xFFDDE3F4)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFFC7CFE4),
            ),
          ),
        ],
      ),
    ),
  );
}

class SocialButtonsRow extends StatelessWidget {
  const SocialButtonsRow({required this.buttons, super.key});
  final List<SocialLoginButton> buttons;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < buttons.length; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        Expanded(child: buttons[i]),
      ],
    ],
  );
}

class RememberForgotRow extends StatelessWidget {
  const RememberForgotRow({
    required this.remember,
    required this.onRememberChanged,
    required this.onForgot,
    super.key,
  });
  final bool remember;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      InkWell(
        onTap: () => onRememberChanged(!remember),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: remember,
                onChanged: (value) => onRememberChanged(value ?? false),
                activeColor: const Color(0xFF7659DF),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Remember me',
              style: TextStyle(color: Color(0xFFC7CFE4), fontSize: 14),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: onForgot,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFB7A5FF),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: const Text(
          'Forgot password?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ],
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (value) => setState(() => _focused = value),
    // Only opacity of the glow animates; geometry stays fixed so typing is
    // perfectly stable (no size/padding/scale/position changes).
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF7C3AED,
            ).withValues(alpha: _focused ? 0.15 : 0.0),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText && _obscured,
        autocorrect: !widget.obscureText,
        enableSuggestions: !widget.obscureText,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: const Color(0xFF8995B5),
            size: 21,
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF8995B5),
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF151B2E).withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: const Color(0xFF9D82FF).withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
      ),
    ),
  );
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? 0.985 : 1.0,
    duration: const Duration(milliseconds: 100),
    curve: Curves.easeOut,
    child: SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF22D3EE)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
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
      Expanded(
        child: Divider(
          color: Colors.white.withValues(alpha: 0.06),
          thickness: 0.5,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'or continue with',
          style: TextStyle(
            color: const Color(0xFF8995B5).withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      Expanded(
        child: Divider(
          color: Colors.white.withValues(alpha: 0.06),
          thickness: 0.5,
        ),
      ),
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
      Text(
        prompt,
        style: TextStyle(
          color: const Color(0xFFB9C3DC).withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      const SizedBox(width: 6),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFDDE3F4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
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
