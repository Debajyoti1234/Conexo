import 'package:flutter/material.dart';

import 'message_models.dart';

/// Reusable premium message primitives for Phase 6.2 messaging.
///
/// UI only — no sending, no realtime, no persistence. Every widget keeps the
/// luxury dark-glass language and stays const-constructible where possible.

// ── Palette (kept local + minimal) ──────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kMeStart = Color(0xFF9B6BFF);
const _kMeMid = Color(0xFF8B5CF6);
const _kMeEnd = Color(0xFF587BE2);

const _kThem = Color(0x14FFFFFF);
const _kSubtle = Color(0xFF9DB2E8);
const _kMuted = Color(0xFFB9C3DC);

/// A single chat bubble. Alignment + styling are derived purely from
/// [message.author]; group received bubbles optionally show the sender name.
///
/// When [message.isDeleted] the original content is never rendered — a subtle,
/// understated "This message was deleted" placeholder is shown in its place and
/// no long-press action is offered. [onLongPress] is only wired for the current
/// user's own, non-deleted messages (the caller decides ownership).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    super.key,
    this.showSenderName = false,
    this.onLongPress,
  });

  final Message message;
  final bool showSenderName;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isMe = message.author == MessageAuthor.me;
    final isDeleted = message.isDeleted;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 7),
      bottomRight: Radius.circular(isMe ? 7 : 22),
    );

    // Deleted bubbles are intentionally flat + translucent (no accent gradient,
    // no glow) so they read as understated rather than as an error.
    final bubble = Container(
      padding: isDeleted
          ? const EdgeInsets.fromLTRB(14, 10, 15, 10)
          : const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        gradient: (isMe && !isDeleted)
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kMeStart, _kMeMid, _kMeEnd],
              )
            : null,
        color: isDeleted
            ? Colors.white.withValues(alpha: .045)
            : (isMe ? null : _kThem),
        borderRadius: radius,
        border: (isMe && !isDeleted)
            ? null
            : Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: (isMe && !isDeleted)
            ? [
                BoxShadow(
                  color: _kAccent.withValues(alpha: .22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: isDeleted
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.do_not_disturb_alt_rounded,
                  size: 15,
                  color: _kMuted.withValues(alpha: .75),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'This message was deleted',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: _kMuted.withValues(alpha: .85),
                    ),
                  ),
                ),
              ],
            )
          : Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: isMe ? Colors.white : const Color(0xFFE7ECF9),
              ),
            ),
    );

    // A deleted message never offers actions; only own, non-deleted messages
    // receive a long-press gesture (wired by the caller).
    final interactiveBubble = (onLongPress != null && !isDeleted)
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            child: bubble,
          )
        : bubble;

    return Padding(
      padding: EdgeInsets.only(
        top: 2.5,
        bottom: 2.5,
        left: isMe ? 48 : 4,
        right: isMe ? 4 : 48,
      ),

      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName && !isMe && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 3),
              child: Text(
                message.senderName!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _kSubtle,
                ),
              ),
            ),
          interactiveBubble,
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: _MetaLine(message: message, isMe: isMe),
          ),
        ],
      ),
    );
  }
}

/// A one-shot premium entrance for a newly inserted message bubble.
///
/// When [animate] is true the child fades in with a small upward slide and a
/// very subtle scale, settling in ~210ms. When false (messages already present
/// on the initial load) the child is shown immediately, so the conversation as
/// a whole never animates — only newly inserted messages do. The widget is
/// keyed per message id by the caller, so the entrance plays exactly once when
/// the message first mounts (local send or realtime receive).
class MessageEntrance extends StatefulWidget {
  const MessageEntrance({
    required this.child,
    super.key,
    this.animate = false,
  });

  final Widget child;
  final bool animate;

  @override
  State<MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
      value: widget.animate ? 0.0 : 1.0,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(_curve),
          alignment: Alignment.bottomCenter,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The timestamp + delivery status shown beneath each bubble.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, required this.isMe});

  final Message message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final clock = _formatClock(message.timestamp);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clock,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: _kMuted,
          ),
        ),

        if (isMe && !message.isDeleted) ...[
          const SizedBox(width: 4),
          Icon(
            _statusGlyph(message.deliveryStatus),
            size: 13,
            color: message.deliveryStatus == MessageDeliveryStatus.read
                ? const Color(0xFF56B6FF)
                : _kMuted,
          ),
        ],
      ],
    );
  }
}

/// A system event chip centered in the timeline (joined/left/goal updates).
class SystemMessageChip extends StatelessWidget {
  const SystemMessageChip({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// An embedded shared-content card (plan/memory/event).
class SharedContentCard extends StatelessWidget {
  const SharedContentCard({required this.content, super.key});

  final SharedContentPreview content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Phase 6.3: navigate into the shared content.
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: _kAccent.withValues(alpha: .10),
          highlightColor: Colors.white.withValues(alpha: .03),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _kAccent.withValues(alpha: .28),
                        _kAccent.withValues(alpha: .12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _contentGlyph(content.type),
                    size: 21,
                    color: const Color(0xFFB7A5FF),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        content.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _kSubtle,
                ),
              ],
            ),
          ),

        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

IconData _statusGlyph(MessageDeliveryStatus status) {
  switch (status) {
    case MessageDeliveryStatus.sending:
      return Icons.schedule_rounded;
    case MessageDeliveryStatus.sent:
      return Icons.check_rounded;
    case MessageDeliveryStatus.delivered:
    case MessageDeliveryStatus.read:
      return Icons.done_all_rounded;
  }
}

IconData _contentGlyph(SharedContentType type) {
  switch (type) {
    case SharedContentType.plan:
      return Icons.event_rounded;
    case SharedContentType.memory:
      return Icons.photo_library_rounded;
    case SharedContentType.event:
      return Icons.celebration_rounded;
  }
}

String _formatClock(DateTime t) {
  final local = t.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}
