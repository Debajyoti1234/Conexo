import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../chat/chat_screen.dart';

/// The match moment. Two photos slide together while the logo's C-arc draws
/// itself around them — the Spark, at full scale.
class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.match, super.key});
  final Match match;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final them = widget.match.person;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final slide = _seg(0, .45, Curves.easeOutBack);
                  final arc = _seg(.3, .9);
                  final text = _seg(.55, 1);
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: CxIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 300,
                        width: 320,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(300, 300),
                              painter: _BigArc(arc, c),
                            ),
                            Transform.translate(
                              offset: Offset(-58 - 60 * (1 - slide), 0),
                              child: Transform.rotate(
                                angle: -.14,
                                child: _Polaroid(photo: s.profile.firstPhoto),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(58 + 60 * (1 - slide), 14),
                              child: Transform.rotate(
                                angle: .12,
                                child: _Polaroid(photo: them.firstPhoto),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 104),
                              child: Transform.scale(
                                scale: _seg(.5, .85, Curves.elasticOut),
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: c.softShadow,
                                  ),
                                  child: ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (r) => c.warm.createShader(r),
                                    child: const Icon(Icons.favorite_rounded, size: 28),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Opacity(
                        opacity: text,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - text)),
                          child: Column(
                            children: [
                              Text('Well, well.', style: ConexoType.display(c.ink, size: 46)),
                              GradientText('It\'s mutual.', style: ConexoType.display(c.ink, size: 46)),
                              const SizedBox(height: 14),
                              Text(
                                'You and ${them.name} liked each other. Don\'t overthink the first message — a good hi works.',
                                textAlign: TextAlign.center,
                                style: ConexoType.body(c.inkSoft, size: 15.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: text,
                        child: Column(
                          children: [
                            CxButton(
                              label: 'Say hi to ${them.name}',
                              icon: Icons.chat_bubble_rounded,
                              onTap: () => Navigator.of(context).pushReplacement(
                                cxRoute(ChatScreen(match: widget.match)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CxButton(
                              label: 'Keep exploring',
                              variant: CxButtonVariant.soft,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.photo});
  final String photo;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Container(
      width: 138,
      height: 180,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: c.isNight ? .5 : .16),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.asset(photo, fit: BoxFit.cover),
      ),
    );
  }
}

class _BigArc extends CustomPainter {
  _BigArc(this.t, this.c);
  final double t;
  final ConexoColors c;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final rect = (Offset.zero & size).deflate(8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [c.violet, c.magenta, c.cyan, c.violet],
        transform: const GradientRotation(-math.pi * .2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi * .22, -math.pi * 1.56 * t, false, paint);
  }

  @override
  bool shouldRepaint(_BigArc old) => old.t != t;
}
