import 'package:flutter/material.dart';

/// Phases of the one-tap connect flow.
///
/// none → sending (heart burst) → pending → connected.
enum ConnectPhase { none, sending, pending, connected }

/// A premium heart-burst that plays when a connect request is sent.
///
/// It grows, glows, and fades once — no bounce. Sized to sit centered over
/// the hero while the request transitions to "pending".
class HeartBurst extends StatefulWidget {
  const HeartBurst({required this.onCompleted, super.key});

  final VoidCallback onCompleted;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
    _glow = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward().whenComplete(widget.onCompleted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                height: 118,
                width: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF4D8D), Color(0xFF7C3AED)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D8D)
                          .withValues(alpha: _glow.value),
                      blurRadius: 46,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 58,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
