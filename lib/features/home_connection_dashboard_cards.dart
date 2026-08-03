import 'package:flutter/material.dart';

import '../app/theme/app_widgets.dart';
import 'home_connection_dashboard_data.dart';

/// Reusable premium widgets for the Connections dashboard.
///
/// Portrait-first cards, participant chips, and the gradient-fallback avatar
/// used across Network, Requests, Pending and Hosted Plans. Kept separate
/// from the screen itself to keep every file small and focused.

/// Portrait avatar backed by a local asset with a graceful gradient fallback.
/// Never uses network images.
class PortraitAvatar extends StatelessWidget {
  const PortraitAvatar({
    super.key,
    required this.name,
    required this.color,
    this.portrait = '',
    this.size = 54,
  });

  final String name;
  final Color color;
  final String portrait;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    Widget avatar;
    if (portrait.isNotEmpty) {
      avatar = ClipOval(
        child: Image.asset(
          portrait,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _fallback(radius: radius),
        ),
      );
    } else {
      avatar = _fallback(radius: radius);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: .16), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: avatar,
    );
  }

  Widget _fallback({required double radius}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.32) ?? color,
            color,
            Color.lerp(color, const Color(0xFF0A0F1F), 0.5) ?? color,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * .72,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The action pill used inside dashboard cards (e.g. Accept / Decline /
/// Cancel / View Profile). Smooth press feedback via [AnimatedScale].
class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (widget.primary) {
      background = const Color(0xFF7C3AED);
      foreground = Colors.white;
    } else if (widget.danger) {
      background = Colors.white.withValues(alpha: .06);
      foreground = const Color(0xFFFF8BAE);
    } else {
      background = Colors.white.withValues(alpha: .08);
      foreground = Colors.white;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.danger
                  ? const Color(0xFFFF8BAE).withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .14),
            ),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: .4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),

        ),
      ),
    );
  }
}

/// A premium card for an established network connection.
class NetworkConnectionCard extends StatelessWidget {
  const NetworkConnectionCard({super.key, required this.connection});

  final NetworkConnection connection;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortraitAvatar(
                name: connection.name,
                color: connection.color,
                portrait: connection.portrait,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            connection.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 17,
                          color: Color(0xFF77DFF1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${connection.age} • ${connection.occupation}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF9DB2E8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            connection.city,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF9DB2E8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF47D7A5).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.handshake_rounded,
                  size: 13,
                  color: Color(0xFF47D7A5),
                ),
                const SizedBox(width: 5),
                Text(
                  connection.connectedSince,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7FE3C0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mutual interests',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: Colors.white.withValues(alpha: .55),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final interest in connection.mutualInterests)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: .12)),
                  ),
                  child: Text(
                    interest,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDDE3F4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionPill(
                  label: 'View Profile',
                  icon: Icons.person_outline_rounded,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  label: 'Open Room',
                  icon: Icons.chat_bubble_outline_rounded,
                  primary: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An incoming connection request card with Accept / Decline actions.
class IncomingRequestCard extends StatelessWidget {
  const IncomingRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final IncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortraitAvatar(
                name: request.name,
                color: request.color,
                portrait: request.portrait,
                size: 54,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFFB9C3DC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final interest in request.mutualInterests)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: .3),
                    ),
                  ),
                  child: Text(
                    interest,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC9B6FF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionPill(
                  label: 'Accept Connection',
                  icon: Icons.check_rounded,
                  primary: true,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  danger: true,
                  onTap: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pending (user-sent) request card with a Cancel action.
class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    required this.onCancel,
  });

  final PendingRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PortraitAvatar(
            name: request.name,
            color: request.color,
            portrait: request.portrait,
            size: 48,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 13,
                      color: Color(0xFFFFC24D),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Waiting for response',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFC24D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: _ActionPill(
              label: 'Cancel',
              icon: Icons.close_rounded,
              danger: true,
              onTap: onCancel,
            ),
          ),
        ],
      ),

    );
  }
}

/// Premium portrait chip for an approved participant.
class ParticipantChip extends StatelessWidget {
  const ParticipantChip({super.key, required this.participant});

  final Participant participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 13, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PortraitAvatar(
            name: participant.name,
            color: participant.color,
            portrait: participant.portrait,
            size: 34,
          ),
          const SizedBox(width: 9),
          Text(
            participant.name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDDE3F4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A join request row inside a hosted plan with Approve / Decline actions.
class JoinRequestRow extends StatelessWidget {
  const JoinRequestRow({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onDecline,
  });

  final JoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          PortraitAvatar(
            name: request.name,
            color: request.color,
            portrait: request.portrait,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _ActionPill(
              label: 'Approve',
              icon: Icons.check_rounded,
              primary: true,
              onTap: onApprove,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _ActionPill(
              label: 'Decline',
              icon: Icons.close_rounded,
              danger: true,
              onTap: onDecline,
            ),
          ),
        ],
      ),

    );
  }
}

/// Animated wrapper that fades + slides a card out of existence. Used when a
/// request/connection is removed so the list collapses gracefully.
class CardDismiss extends StatelessWidget {
  const CardDismiss({
    super.key,
    required this.visible,
    required this.child,
    this.spacing = 12,
    this.duration = const Duration(milliseconds: 320),
  });

  final bool visible;
  final Widget child;
  final double spacing;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeInOutCubic,
        child: visible
            ? Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: child,
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}


