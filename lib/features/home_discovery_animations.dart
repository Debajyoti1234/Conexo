import 'package:flutter/material.dart';


/// Pure-Flutter shimmer that sweeps a soft highlight across [child].
///
/// The gradient moves with the controller's value; when [enabled] is false
/// the child is rendered untouched. Suitable for skeleton placeholders.
class Shimmer extends StatefulWidget {
  const Shimmer({
    required this.child,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final slide = _controller.value * 2.2 - 0.6;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.2 + slide, 0),
            end: Alignment(-0.2 + slide, 0),
            colors: const [
              Color(0xFF232C47),
              Color(0xFF3A4A72),
              Color(0xFF232C47),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A skeleton block with rounded corners, painted with the base
/// [color]. Used by both hero and panel placeholders.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    required this.height,
    super.key,
    this.width,
    this.radius = 14,
    this.color = const Color(0xFF232C47),
  });

  final double height;
  final double? width;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A skeleton circle, used for the avatar placeholder.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    required this.size,
    super.key,
    this.color = const Color(0xFF232C47),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A rounded skeleton line for text placeholders.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    required this.width,
    super.key,
    this.height = 12,
    this.color = const Color(0xFF232C47),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SkeletonBlock(
      width: width,
      height: height,
      radius: 8,
      color: color,
    );
  }
}

/// One-shot premium entrance: fade + slight upward slide + gentle scale.
///
/// Plays on mount with [Curves.easeOutCubic] — no bounce. Used for the
/// avatar, the details panel, and reusable sections.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 520),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.1),
    this.scaleFrom = 0.96,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final double scaleFrom;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.offset, end: Offset.zero)
            .animate(_curve),
        child: ScaleTransition(
          scale: Tween<double>(begin: widget.scaleFrom, end: 1)
              .animate(_curve),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Staggers a list of children with a per-index fade + slight rise.
///
/// All children share one controller; each entry is delayed with an
/// [Interval] so the reveal cascades smoothly from top to bottom.
class StaggeredChips extends StatefulWidget {
  const StaggeredChips({
    required this.children,
    super.key,
    this.duration = const Duration(milliseconds: 420),
    this.stagger = 0.06,
  });

  final List<Widget> children;
  final Duration duration;
  final double stagger;

  @override
  State<StaggeredChips> createState() => _StaggeredChipsState();
}

class _StaggeredChipsState extends State<StaggeredChips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _StaggeredItem(
            controller: _controller,
            start: i * widget.stagger,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  const _StaggeredItem({
    required this.controller,
    required this.start,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}
