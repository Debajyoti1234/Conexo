import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';

/// Premium, branded loading state for the People / Discovery page.
///
/// The Conexo logo remains the hero throughout. Around it, a calm, seamless
/// loop of orbiting connection nodes, converging light trails, a subtle
/// discovery pulse and a breathing glow communicates:
///
///   discover -> gather -> connect -> return
///
/// Nothing is aggressively fragmented — the original logo asset is always
/// rendered intact. The motion is restrained, elegant and runs on a single
/// repeating [AnimationController]. Reduced-motion is honoured: when the
/// platform requests it the animation is frozen on its resting frame.
class DiscoveryPreparationState extends StatefulWidget {
  const DiscoveryPreparationState({super.key});

  @override
  State<DiscoveryPreparationState> createState() =>
      _DiscoveryPreparationStateState();
}

class _DiscoveryPreparationStateState extends State<DiscoveryPreparationState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _logoAsset = 'assets/logo/conexo_logo2.png';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    // Start the seamless loop from the first frame, but only when the user has
    // not requested reduced motion / disabled animations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) {
        _controller.repeat();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to reduced-motion being toggled at runtime.
    if (MediaQuery.of(context).disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating && mounted) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = context.isLightTheme;
    final ink = context.cxInk;
    final accent = context.cxAccent;
    final accentSoft = context.cxAccentSoft;

    // Everything resolves to the existing theme tokens — in light mode the
    // animation is rendered in ink, in dark mode in the Conexo violet.
    final hubColor = light ? ink : accent;
    final nodeColor = light ? ink : accent;
    final nodeGlowColor = light ? ink : accentSoft;
    final particleColor = light ? ink : const Color(0xB3FFFFFF);
    final ringColor = light ? ink : accent;
    final trailColor = light ? ink : accentSoft;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoSize = (screenWidth * 0.34).clamp(112.0, 150.0);
    final diameter = math.min(logoSize * 2.4, screenWidth - 40);

    // The hero logo is built once and cached as the AnimatedBuilder child so
    // it is never rebuilt on every tick.
    final logo = SizedBox(
      width: logoSize,
      height: logoSize,
      child: Image.asset(_logoAsset, fit: BoxFit.contain),
    );

    return RepaintBoundary(
      child: Semantics(
        label: 'Conexo is gathering people nearby and preparing your '
            'discovery feed',
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: diameter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: diameter,
                  height: diameter,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Read fresh each frame so a runtime change to the
                      // platform's reduced-motion setting freezes/unfreezes
                      // the animation immediately.
                      final reduceMotion =
                          MediaQuery.of(context).disableAnimations;
                      final progress =
                          reduceMotion ? 0.0 : _controller.value;
                      final breath =
                          0.5 - 0.5 * math.cos(progress * 2 * math.pi);
                      final glowAlpha = 0.11 + 0.045 * breath;
                      final glowRadius = 28.0 + 8.0 * breath;
                      final scale = 1.0 + 0.014 * breath;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Subtle discovery pulse (two phased rings).
                          CustomPaint(
                            size: Size.square(logoSize * 2.4),
                            painter: _DiscoveryRingPainter(
                              progress: progress,
                              ringColor: ringColor,
                              light: light,
                            ),
                          ),
                          // Orbits + nodes + trails + particles.
                          CustomPaint(
                            size: Size.square(logoSize * 2.4),
                            painter: _OrbitPainter(
                              progress: progress,
                              hubRadius: logoSize * 0.5,
                              accentColor: nodeColor,
                              accentSoftColor: nodeGlowColor,
                              particleColor: particleColor,
                              trailColor: trailColor,
                            ),
                          ),
                          // Soft breathing glow behind the logo.
                          Opacity(
                            opacity: glowAlpha,
                            child: Container(
                              width: logoSize * 0.72,
                              height: logoSize * 0.72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: hubColor,
                                    blurRadius: glowRadius,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // The hero: the Conexo logo, intact and breathing.
                          Transform.scale(scale: scale, child: child),
                        ],
                      );
                    },
                    child: logo,
                  ),
                ),
                const SizedBox(height: 28),
                // Minimal supporting copy. The animation carries the meaning;
                // the text is deliberately restrained and secondary.
                Text(
                  'Gathering people near you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                    height: 1.35,
                    color: context.cxSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Preparing your discovery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    height: 1.4,
                    color: context.cxMuted,
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

@immutable
class _NodeSpec {
  const _NodeSpec({
    required this.radius,
    required this.speed,
    required this.phase,
    required this.size,
  });

  final double radius;
  final double speed;
  final double phase;
  final double size;
}

/// Draws the orbiting connection nodes, their converging light trails and the
/// soft background particles in a single canvas pass.
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.progress,
    required this.hubRadius,
    required this.accentColor,
    required this.accentSoftColor,
    required this.particleColor,
    required this.trailColor,
  });

  final double progress;
  final double hubRadius;
  final Color accentColor;
  final Color accentSoftColor;
  final Color particleColor;
  final Color trailColor;

  static const _nodes = <_NodeSpec>[
    _NodeSpec(radius: 1.05, speed: 0.85, phase: 0.00, size: 2.1),
    _NodeSpec(radius: 1.40, speed: 1.20, phase: 0.20, size: 1.7),
    _NodeSpec(radius: 1.85, speed: 0.70, phase: 0.42, size: 2.3),
    _NodeSpec(radius: 1.55, speed: 1.50, phase: 0.64, size: 1.5),
    _NodeSpec(radius: 1.25, speed: 1.05, phase: 0.86, size: 1.9),
  ];

  static const _particles = <Offset>[
    Offset(0.18, 0.82),
    Offset(0.30, 0.20),
    Offset(0.52, 0.12),
    Offset(0.74, 0.28),
    Offset(0.86, 0.66),
    Offset(0.62, 0.90),
    Offset(0.20, 0.60),
    Offset(0.44, 0.34),
    Offset(0.10, 0.48),
    Offset(0.88, 0.40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Seamless gather/contract pulse: 0 at the loop seam, peaks mid-cycle.
    final gather =
        math.sin(math.pi * progress) * math.sin(math.pi * progress);

    final particlePaint = Paint()..isAntiAlias = true;
    for (var i = 0; i < _particles.length; i++) {
      final seed = i * 0.73;
      final point = _particles[i];
      final twinkle =
          0.5 + 0.5 * math.sin(progress * 2 * math.pi * 0.35 + seed);
      final wobbleX = math.sin(progress * 2 * math.pi * 0.35 + seed) * 6;
      final wobbleY = math.cos(progress * 2 * math.pi * 0.28 + seed) * 8;
      particlePaint.color = particleColor.withValues(alpha: 0.10 * twinkle);
      canvas.drawCircle(
        Offset(
          point.dx * size.width + wobbleX,
          point.dy * size.height + wobbleY,
        ),
        i.isEven ? 1.4 : 1.0,
        particlePaint,
      );
    }

    final nodePaint = Paint()..isAntiAlias = true;
    final trailPaint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _nodes.length; i++) {
      final n = _nodes[i];
      final angle = math.pi * 2 * (n.speed * progress + n.phase);
      final orbitR = hubRadius * n.radius;
      // Elliptical orbits (flatter vertically) that contract toward the logo
      // during the gather pulse — "discover -> gather -> connect -> return".
      final rScale = 1.0 - 0.42 * gather;
      final px = math.cos(angle) * orbitR * rScale;
      final py = math.sin(angle) * orbitR * 0.58 * rScale;
      final pos = Offset(center.dx + px, center.dy + py);

      // A light trail converges toward the logo, intensified on gather.
      final trailStrength = (0.6 + 0.4 * gather) *
          (0.18 + 0.12 * math.sin(math.pi * progress * 2 + n.phase));
      final trailLen = hubRadius * 0.42;
      final dir = center - pos;
      final len = dir.distance;
      if (len > 0.0) {
        final unit = dir / len;
        final end = pos + unit * math.min(trailLen, len);
        const steps = 6;
        for (var s = 0; s < steps; s++) {
          final frac = s / steps;
          final tip = pos + (end - pos) * frac;
          trailPaint.color = trailColor.withValues(
            alpha: trailStrength * (1.0 - frac) * (1.0 - frac),
          );
          trailPaint.strokeWidth =
              1.6 * (1.0 - frac) * (0.5 + 0.5 * (1.0 - frac));
          final next = pos + (end - pos) * ((s + 1) / steps);
          if (!next.dx.isFinite) continue;
          canvas.drawLine(tip, next, trailPaint);
        }
      }

      // Node: a small disc with a soft glow, like a nearby person dot.
      final nodeAlpha = 0.65 + 0.25 * gather;
      nodePaint.color = i.isEven ? accentSoftColor : accentColor;
      canvas.drawCircle(pos, n.size * 0.6, nodePaint);
      canvas.drawCircle(
        pos,
        n.size * 1.6,
        Paint()
          ..color = accentSoftColor.withValues(alpha: 0.18 * nodeAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hubRadius != hubRadius;
  }
}

/// Two faint concentric rings that expand outward from the logo and fade, like
/// a gentle discovery scan. Phased so at least one ring is always present.
class _DiscoveryRingPainter extends CustomPainter {
  _DiscoveryRingPainter({
    required this.progress,
    required this.ringColor,
    required this.light,
  });

  final double progress;
  final Color ringColor;
  final bool light;

  static const _phases = <double>[0.0, 0.35];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = math.min(size.width, size.height) * 0.5;

    final ringPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final phase in _phases) {
      // Triangle wave 0 -> 1 -> 0 over one loop, continuous at the seam.
      final w = (progress - phase) % 1.0;
      final wave = w < 0.5 ? w * 2.0 : (1.0 - w) * 2.0;
      if (wave <= 0.0) continue;
      final radius = wave * maxRadius;
      final opacity = 0.06 * (1.0 - wave) * (light ? 1.0 : 1.3);
      ringPaint.color = ringColor.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoveryRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
