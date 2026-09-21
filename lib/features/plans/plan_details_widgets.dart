import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import 'plans_theme.dart';
import 'plans_widgets.dart';


/// Premium glass primitives specific to the Plan Details experience.
///
/// These reuse the shared discovery primitives ([PlanPortrait], [InfoChip],
/// etc.) wherever possible and keep the same luxurious dark-glass language.
/// Local + UI only.

/// A frosted glass panel used to group a details section.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.cxCanvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cxLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A large section title with a soft premium subtitle underneath.
class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: plansDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: plansBody(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: context.cxSoft,
            ),
          ),
        ],
      ],
    );
  }
}

/// A larger premium glass info chip (icon + label + value) for the plan
/// information grid. Distinct from the small discovery [InfoChip].
class DetailChip extends StatelessWidget {
  const DetailChip({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cxSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.cxInk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: plansBody(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.cxMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: plansBody(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.cxInk,
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

/// A circular glass control button (back / share) with soft press feedback.
class CircleGlassButton extends StatefulWidget {
  const CircleGlassButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<CircleGlassButton> createState() => _CircleGlassButtonState();
}

class _CircleGlassButtonState extends State<CircleGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.cxGlass,
            border: Border.all(color: context.cxLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: context.cxInk,
            semanticLabel: widget.semanticLabel,
          ),
        ),
      ),
    );
  }
}

/// A small stat block (value + label) for the host card.
class HostStat extends StatelessWidget {
  const HostStat({required this.value, required this.label, super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: plansDisplay(fontSize: 21, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: plansBody(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.cxMuted,
          ),
        ),
      ],
    );
  }
}

/// A single participant avatar with a soft press animation (no navigation).
class ParticipantAvatar extends StatefulWidget {
  const ParticipantAvatar({
    required this.asset,
    required this.accent,
    super.key,
    this.label = '',
    this.isHost = false,
    this.onTap,
  });

  final String asset;
  final Color accent;
  final String label;
  final bool isHost;
  final VoidCallback? onTap;

  @override
  State<ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<ParticipantAvatar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlanPortrait(
                  asset: widget.asset,
                  accent: widget.accent,
                  size: 54,
                  label: widget.label,
                ),
                if (widget.isHost)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accent,
                        border: Border.all(
                          color: context.cxCanvas,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.star_outline_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: 58,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: plansBody(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.cxSoft,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A "+N" overflow bubble matching the participant avatar size.
class ParticipantOverflow extends StatelessWidget {
  const ParticipantOverflow({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.cxSurface,
            border: Border.all(color: context.cxLine),
          ),
          alignment: Alignment.center,
          child: Text(
            '+$count',
            style: plansBody(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 58,
          child: Text(
            'more',
            textAlign: TextAlign.center,
            style: plansBody(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.cxMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A "why join" reason row with a soft accent bullet.
class WhyJoinRow extends StatelessWidget {
  const WhyJoinRow({required this.text, required this.accent, super.key});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cxSurface,
              border: Border.all(color: context.cxLine),
            ),
            child: Icon(
              Icons.check,
              size: 13,
              color: context.cxInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: plansBody(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: context.cxInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium static map placeholder — no Maps dependency. Shows a stylised
/// gradient "map", a location pin, distance, and a "coming soon" note.
class StaticMapPreview extends StatelessWidget {
  const StaticMapPreview({
    required this.city,
    required this.distance,
    required this.accent,
    super.key,
  });

  final String city;
  final String distance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Stylised "map" backdrop (pure gradient — no external tiles).
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.cxSurface,
                    Color.lerp(accent, Colors.white, .86) ?? context.cxSurface,
                  ],
                ),
              ),
            ),
            // Faint grid lines for a subtle "map" feel.
            const _MapGrid(),
            // Center pin.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 34,
                    color: context.cxInk,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    city,
                    style: plansBody(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.cxInk,
                    ),
                  ),
                ],
              ),
            ),
            // Distance chip.
            Positioned(
              left: 12,
              bottom: 12,
              child: InfoChip(
                icon: Icons.place_outlined,
                label: distance,
                onLight: true,
              ),
            ),
            // Coming soon note.
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.cxLine),
                ),
                child: Text(
                  'Interactive maps coming soon',
                  style: plansBody(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.cxSoft,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF1B1B1F).withValues(alpha: .06)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A safety action row: icon + label, with an optional "Coming Soon" pill.
class SafetyRow extends StatelessWidget {
  const SafetyRow({
    required this.icon,
    required this.label,
    super.key,
    this.trailingText,
    this.comingSoon = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailingText;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 19, color: context.cxInk),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: plansBody(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: context.cxInk,
                ),
              ),
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.cxSurface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Coming soon',
                  style: plansBody(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.cxMuted,
                  ),
                ),
              )
            else if (trailingText != null)
              Text(
                trailingText!,
                style: plansBody(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: context.cxSoft,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.cxMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// A subtle divider used inside glass panels.
class PanelDivider extends StatelessWidget {
  const PanelDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.cxLine,
    );
  }
}
