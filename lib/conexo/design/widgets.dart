import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Motion primitives
// ─────────────────────────────────────────────────────────────────────────────

/// Squishes slightly on press. The one tactile language used everywhere.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.scale = .96,
    this.haptic = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: widget.onTap == null ? .45 : 1,
            duration: const Duration(milliseconds: 200),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades + lifts a child in, staggered by [index].
class Reveal extends StatefulWidget {
  const Reveal({required this.child, this.index = 0, this.offset = 18, super.key});
  final Widget child;
  final int index;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand
// ─────────────────────────────────────────────────────────────────────────────

class ConexoMark extends StatelessWidget {
  const ConexoMark({this.size = 40, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo/conexo_logo2.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );
}

/// "conexo" wordmark — the x carries the brand gradient, echoing the logo.
class ConexoWordmark extends StatelessWidget {
  const ConexoWordmark({this.size = 26, this.color, super.key});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final style = ConexoType.display(color ?? c.ink, size: size);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('cone', style: style),
        ShaderMask(
          shaderCallback: (r) => c.brand.createShader(r),
          child: Text('x', style: style.copyWith(color: Colors.white)),
        ),
        Text('o', style: style),
      ],
    );
  }
}

/// Text painted with the brand gradient. Use sparingly: one phrase per screen.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {required this.style, this.textAlign, super.key});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => context.cx.brand.createShader(r),
    child: Text(text, style: style, textAlign: textAlign),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

class CxButton extends StatelessWidget {
  const CxButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.variant = CxButtonVariant.primary,
    this.height = 56,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final CxButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final primary = variant == CxButtonVariant.primary;
    final ink = variant == CxButtonVariant.ink;
    final fg = primary || ink ? (ink && c.isNight ? c.bg : Colors.white) : c.ink;

    return Pressable(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: height,
        decoration: BoxDecoration(
          gradient: primary ? c.warm : null,
          color: primary
              ? null
              : ink
              ? c.ink
              : c.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: variant == CxButtonVariant.soft ? Border.all(color: c.line, width: 1.2) : null,
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: c.violet.withValues(alpha: c.isNight ? .45 : .28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? SizedBox(
                  key: const ValueKey('l'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : Row(
                  key: const ValueKey('t'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: ConexoType.body(fg, size: 16, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum CxButtonVariant { primary, ink, soft }

class CxIconButton extends StatelessWidget {
  const CxIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    this.filled = true,
    this.badge = false,
    super.key,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final bool filled;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final btn = Pressable(
      onTap: onTap,
      scale: .9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? c.surface : Colors.transparent,
          shape: BoxShape.circle,
          border: filled ? Border.all(color: c.line) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * .46, color: c.ink),
            if (badge)
              Positioned(
                top: size * .22,
                right: size * .22,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.magenta,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 1.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The Spark — Conexo's signature like interaction.
// A heart inside a ring; on tap the logo's "C" arc sweeps around it in the
// brand gradient, the heart pops and fills.
// ─────────────────────────────────────────────────────────────────────────────

class SparkButton extends StatefulWidget {
  const SparkButton({required this.onTap, this.size = 54, this.icon = Icons.favorite_rounded, super.key});
  final VoidCallback onTap;
  final double size;
  final IconData icon;

  @override
  State<SparkButton> createState() => _SparkButtonState();
}

class _SparkButtonState extends State<SparkButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.mediumImpact();
    await _c.forward(from: 0);
    widget.onTap();
    if (mounted) _c.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = widget.size;
    return Semantics(
      button: true,
      label: 'Like',
      child: GestureDetector(
        onTap: _c.isAnimating ? null : _tap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final sweep = Curves.easeOutCubic.transform((t / .7).clamp(0, 1));
            final pop = t < .45
                ? 1 + .28 * Curves.easeOut.transform(t / .45)
                : 1.28 - .28 * Curves.elasticOut.transform(((t - .45) / .55).clamp(0, 1));
            final filled = t > .2;
            return SizedBox(
              width: s,
              height: s,
              child: CustomPaint(
                painter: _ArcPainter(progress: sweep, colors: c),
                child: Center(
                  child: Container(
                    width: s - 8,
                    height: s - 8,
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                      boxShadow: c.softShadow,
                    ),
                    child: Transform.scale(
                      scale: pop,
                      child: filled
                          ? ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (r) => c.warm.createShader(r),
                              child: Icon(widget.icon, size: s * .42),
                            )
                          : Icon(widget.icon, size: s * .42, color: c.violet),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.colors});
  final double progress;
  final ConexoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [colors.violet, colors.magenta, colors.cyan, colors.violet],
        transform: const GradientRotation(-math.pi * .15),
      ).createShader(rect);
    // Opens on the right like the C in the logo.
    const start = -math.pi * .22;
    canvas.drawArc(rect.deflate(1.6), start, -math.pi * 1.56 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Inputs & selection
// ─────────────────────────────────────────────────────────────────────────────

class CxField extends StatefulWidget {
  const CxField({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.action,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CxField> createState() => _CxFieldState();
}

class _CxFieldState extends State<CxField> {
  late bool _hidden = widget.obscure;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final focused = _focus.hasFocus;
    OutlineInputBorder border(Color col, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: col, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: ConexoType.label(focused ? c.violet : c.inkSoft),
            child: Text(widget.label),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          textInputAction: widget.action,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          autofocus: widget.autofocus,
          onFieldSubmitted: widget.onSubmitted,
          cursorColor: c.violet,
          style: ConexoType.body(c.ink, size: 16, w: FontWeight.w600),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: ConexoType.body(c.inkMute, size: 16),
            filled: true,
            fillColor: focused ? c.surface : c.surfaceAlt.withValues(alpha: c.isNight ? 1 : .6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, size: 20, color: focused ? c.violet : c.inkMute),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: c.inkMute,
                    ),
                  )
                : null,
            counterStyle: ConexoType.label(c.inkMute, size: 11),
            errorStyle: ConexoType.body(c.danger, size: 12.5, w: FontWeight.w600),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(c.violet, 1.6),
            errorBorder: border(c.danger.withValues(alpha: .6)),
            focusedErrorBorder: border(c.danger, 1.6),
          ),
        ),
      ],
    );
  }
}

class VibeChip extends StatelessWidget {
  const VibeChip({required this.label, this.selected = false, this.onTap, this.icon, super.key});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final fg = selected ? (c.isNight ? c.bg : Colors.white) : c.ink;
    return Pressable(
      onTap: onTap,
      scale: .94,
      haptic: onTap != null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: selected ? c.ink : c.line, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? fg : c.violet),
              const SizedBox(width: 6),
            ],
            Text(label, style: ConexoType.body(fg, size: 14, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A slim segmented progress bar for multi-step flows.
class StepBar extends StatelessWidget {
  const StepBar({required this.count, required this.index, super.key});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                color: c.line,
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  widthFactor: i <= index ? 1 : 0,
                  heightFactor: 1,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: c.warm)),
                ),
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────────────

class Avatar extends StatelessWidget {
  const Avatar({required this.photo, this.size = 56, this.ring = false, this.online = false, super.key});
  final String photo;
  final double size;

  /// Gradient ring = "your move".
  final bool ring;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(ring ? 2.5 : 0),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: ring ? c.brand : null),
            child: Container(
              padding: EdgeInsets.all(ring ? 2 : 0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
              child: ClipOval(
                child: Image.asset(photo, fit: BoxFit.cover, width: size, height: size),
              ),
            ),
          ),
          if (online)
            Positioned(
              right: size * .02,
              bottom: size * .02,
              child: Container(
                width: size * .24,
                height: size * .24,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 2.2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CxCard extends StatelessWidget {
  const CxCard({required this.child, this.padding = const EdgeInsets.all(20), this.onTap, this.radius = 26, super.key});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line.withValues(alpha: c.isNight ? 1 : .7)),
        boxShadow: c.softShadow,
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: .98, child: card);
  }
}

/// Screen title row used at the top of every tab.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({required this.title, this.subtitle, this.trailing, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ConexoType.display(c.ink, size: 34)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: ConexoType.body(c.inkSoft, size: 14)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    super.key,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => c.brand.createShader(r),
                child: Icon(icon, size: 38),
              ),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: ConexoType.title(c.ink, size: 24)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: ConexoType.body(c.inkSoft)),
            if (action != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: CxButton(label: action!, onTap: onAction, variant: CxButtonVariant.ink, height: 50),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
