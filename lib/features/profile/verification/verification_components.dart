import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'verification_theme.dart';

/// The three controlled capture angles, in canonical order.
enum VerifyAngle {
  front,
  left,
  right;

  String get label => switch (this) {
        VerifyAngle.front => 'FRONT',
        VerifyAngle.left => 'LEFT',
        VerifyAngle.right => 'RIGHT',
      };

  String get title => switch (this) {
        VerifyAngle.front => 'Look straight\nat the camera',
        VerifyAngle.left => 'Turn your face\nslightly left',
        VerifyAngle.right => 'Turn your face\nslightly right',
      };

  String get hint => switch (this) {
        VerifyAngle.front => 'Look straight at the camera',
        VerifyAngle.left => 'Turn your face slightly left',
        VerifyAngle.right => 'Turn your face slightly right',
      };

  String get glyph => switch (this) {
        VerifyAngle.front => VerifyAsset.faceFront,
        VerifyAngle.left => VerifyAsset.faceLeft,
        VerifyAngle.right => VerifyAsset.faceRight,
      };

  int get step => index + 1;
}

// ── Face guide frame (rounded safe-area + purple corner brackets) ────────────

class VerifyGuideFrame extends StatelessWidget {
  const VerifyGuideFrame({
    required this.child,
    super.key,
    this.captured = false,
    this.pulse = false,
  });

  final Widget child;
  final bool captured;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final accent = captured ? VerifyColors.verified : VerifyColors.accent;
    return AspectRatio(
      aspectRatio: 0.84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .22),
              blurRadius: 34,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                color: Colors.black.withValues(alpha: .35),
                child: child,
              ),
            ),
            IgnorePointer(
              child: CustomPaint(painter: _CornerBracketPainter(accent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const inset = 10.0;
    const len = 34.0;
    const r = 22.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + r + len)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.left + r, rect.top),
            radius: const Radius.circular(r))
        ..lineTo(rect.left + r + len, rect.top),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - r - len, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + r),
            radius: const Radius.circular(r))
        ..lineTo(rect.right, rect.top + r + len),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - r - len)
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(Offset(rect.right - r, rect.bottom),
            radius: const Radius.circular(r))
        ..lineTo(rect.right - r - len, rect.bottom),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + r + len, rect.bottom)
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - r),
            radius: const Radius.circular(r))
        ..lineTo(rect.left, rect.bottom - r - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The faint angle silhouette shown inside the guide frame before capture.
class VerifyGuidePlaceholder extends StatelessWidget {
  const VerifyGuidePlaceholder({required this.angle, super.key});

  final VerifyAngle angle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: VerifyGlyph(
        angle.glyph,
        size: 132,
        color: Colors.white.withValues(alpha: .16),
      ),
    );
  }
}

// ── Angle preview card (angle-overview screen) ───────────────────────────────

class VerifyAnglePreviewCard extends StatelessWidget {
  const VerifyAnglePreviewCard({required this.angle, super.key});

  final VerifyAngle angle;

  @override
  Widget build(BuildContext context) {
    return VerifyGlass(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  VerifyColors.accent.withValues(alpha: .22),
                  VerifyColors.accent2.withValues(alpha: .12),
                ],
              ),
              border: Border.all(color: VerifyColors.line),
            ),
            child: VerifyGlyph(angle.glyph, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  angle.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: VerifyColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  angle.hint,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: VerifyColors.soft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _NumberBadge(angle.step),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VerifyColors.accent.withValues(alpha: .18),
        border: Border.all(color: VerifyColors.accent.withValues(alpha: .5)),
      ),
      child: Text(
        '$n',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: VerifyColors.accentSoft,
        ),
      ),
    );
  }
}

// ── Angle progress card (during/after capture) ───────────────────────────────

class VerifyAngleProgressCard extends StatelessWidget {
  const VerifyAngleProgressCard({
    required this.angle,
    required this.captured,
    super.key,
    this.thumbnail,
    this.active = false,
  });

  final VerifyAngle angle;
  final bool captured;
  final bool active;
  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    return VerifyGlass(
      padding: const EdgeInsets.all(12),
      radius: 18,
      borderColor: active
          ? VerifyColors.accent.withValues(alpha: .55)
          : (captured ? VerifyColors.verified.withValues(alpha: .4) : null),
      child: Row(
        children: [
          _Thumb(angle: angle, thumbnail: thumbnail, captured: captured),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  angle.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: VerifyColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  captured
                      ? 'Captured'
                      : (active ? 'Capturing' : 'Pending'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: captured ? VerifyColors.verified : VerifyColors.soft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: captured
                ? const _CheckBadge(key: ValueKey('done'))
                : _NumberBadge(angle.step),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.angle,
    required this.captured,
    this.thumbnail,
  });

  final VerifyAngle angle;
  final bool captured;
  final Uint8List? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: .05),
        border: Border.all(color: VerifyColors.line),
      ),
      child: thumbnail != null
          ? Image.memory(thumbnail!, fit: BoxFit.cover)
          : Center(
              child: VerifyGlyph(
                angle.glyph,
                size: 26,
                color: Colors.white.withValues(alpha: .35),
              ),
            ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [VerifyColors.verified, VerifyColors.verified2],
        ),
      ),
      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
    );
  }
}
