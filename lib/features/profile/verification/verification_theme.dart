import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_theme.dart';

/// Shared design kit for the premium 3-angle identity-verification flow.
///
/// Centralizes the Conexo luxury-dark tokens and the reusable premium
/// primitives (glass panels, glow badges, SVG glyphs, guide frame, capture
/// cards, gradient CTA) so the individual screens stay small and coherent.
///
/// Purely presentational — no business logic, no networking, no persistence.
/// Motion is restrained (150–500ms, easeOutCubic in / easeInOutCubic out).

// ── Tokens ──────────────────────────────────────────────────────────────────

/// Premium fade + short vertical slide route, matching Conexo's other premium
/// screens (420ms in / 320ms out, easeOutCubic).
Route<T> verifyFadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Local SVG asset paths (bundled under assets/verification/).
class VerifyAsset {
  const VerifyAsset._();

  static const _base = 'assets/verification';
  static const faceFront = '$_base/face_front.svg';
  static const faceLeft = '$_base/face_left.svg';
  static const faceRight = '$_base/face_right.svg';
  static const distance = '$_base/distance.svg';
  static const lighting = '$_base/lighting.svg';
  static const eyes = '$_base/eyes.svg';
  static const glasses = '$_base/glasses.svg';
  static const background = '$_base/background.svg';
  static const expression = '$_base/expression.svg';
  static const privacy = '$_base/privacy.svg';
  static const shieldFace = '$_base/shield_face.svg';
  static const shieldCheck = '$_base/shield_check.svg';
  static const check = '$_base/check.svg';
  static const alert = '$_base/alert.svg';
}

// ── SVG glyph ─────────────────────────────────────────────────────────────
/// A tinted vector glyph from the local verification asset set.
class VerifyGlyph extends StatelessWidget {
  const VerifyGlyph(
    this.asset, {
    super.key,
    this.size = 24,
    Color? color,
  }) : color = color;

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.cxAccentSoft;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}

// ── Background ────────────────────────────────────────────────────────────

/// Full-bleed luxury-dark background with a restrained top glow.
class VerifyBackground extends StatelessWidget {
  const VerifyBackground({
    required this.child,
    super.key,
    this.glow,
  });

  final Widget child;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glow ?? context.cxAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.cxCanvas, context.cxCanvas],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            left: -40,
            right: -40,
            child: IgnorePointer(
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      effectiveGlow.withValues(alpha: .20),
                      effectiveGlow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Glass panel (real frosted blur) ─────────────────────────────────────────

class VerifyGlass extends StatelessWidget {
  const VerifyGlass({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.glow,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow!.withValues(alpha: .22),
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: context.cxGlass.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor ?? context.cxLine),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Glow badge (circular gradient icon holder) ───────────────────────────────

class VerifyGlowBadge extends StatelessWidget {
  const VerifyGlowBadge({
    required this.child,
    super.key,
    this.size = 56,
    this.colors,
    this.glowColor,
    this.glowStrength = .45,
  });

  final Widget child;
  final double size;
  final List<Color>? colors;
  final Color? glowColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final effectiveColors = colors ?? [context.cxAccent, context.cxAccent];
    final effectiveGlowColor = glowColor ?? context.cxAccent;
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: effectiveColors,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveGlowColor.withValues(alpha: glowStrength),
            blurRadius: size * .5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Gradient CTA ─────────────────────────────────────────────────────────────

class VerifyCta extends StatefulWidget {
  const VerifyCta({
    required this.label,
    required this.onTap,
    super.key,
    this.loading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool enabled;
  final IconData? icon;

  @override
  State<VerifyCta> createState() => _VerifyCtaState();
}

class _VerifyCtaState extends State<VerifyCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: active ? 1 : 0.5,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.cxAccent, context.cxAccent],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: context.cxAccent.withValues(alpha: .5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: widget.loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text button used for secondary actions ("Review photo tips").
class VerifyTextLink extends StatelessWidget {
  const VerifyTextLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.cxAccentSoft,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

// ── Top bar (back / close + optional center pill + trailing) ─────────────────

class VerifyTopBar extends StatelessWidget {
  const VerifyTopBar({
    super.key,
    this.onBack,
    this.onClose,
    this.center,
    this.trailing,
  });

  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget iconButton(IconData icon, VoidCallback onTap, String tip) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: context.cxInk),
        tooltip: tip,
        style: IconButton.styleFrom(
          backgroundColor: context.cxInk.withValues(alpha: .06),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null)
            iconButton(Icons.arrow_back_rounded, onBack!, 'Back')
          else if (onClose != null)
            iconButton(Icons.close_rounded, onClose!, 'Close')
          else
            const SizedBox(width: 48),
          Expanded(
            child: Center(child: center ?? const SizedBox.shrink()),
          ),
          if (trailing != null)
            trailing!
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// A pill like "FRONT • 1 OF 3".
class VerifyStepPill extends StatelessWidget {
  const VerifyStepPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: context.cxAccent.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.cxAccent.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: context.cxAccentSoft,
        ),
      ),
    );
  }
}

// ── Instruction card ─────────────────────────────────────────────────────────

class VerifyInstructionCard extends StatelessWidget {
  const VerifyInstructionCard({
    required this.asset,
    required this.title,
    required this.body,
    super.key,
  });

  final String asset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return VerifyGlass(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cxAccent.withValues(alpha: .14),
            ),
            child: VerifyGlyph(asset, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cxInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.cxSoft,
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

// ── Small indicator chip (Good lighting / 3–4 ft / No glasses) ───────────────

class VerifyIndicatorChip extends StatelessWidget {
  const VerifyIndicatorChip({
    required this.asset,
    required this.label,
    super.key,
  });

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VerifyGlyph(asset, size: 22, color: context.cxAccentSoft),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            color: context.cxSoft,
          ),
        ),
      ],
    );
  }
}