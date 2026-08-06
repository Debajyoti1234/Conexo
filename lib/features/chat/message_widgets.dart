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
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    super.key,
    this.showSenderName = false,
  });

  final Message message;
  final bool showSenderName;

  @override
  Widget build(BuildContext context) {
    final isMe = message.author == MessageAuthor.me;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 7),
      bottomRight: Radius.circular(isMe ? 7 : 22),
    );

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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kMeStart, _kMeMid, _kMeEnd],
                    )
                  : null,
              color: isMe ? null : _kThem,
              borderRadius: radius,
              border: isMe
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: .08)),
              boxShadow: isMe
                  ? [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: .22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),

            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: isMe ? Colors.white : const Color(0xFFE7ECF9),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: _MetaLine(message: message, isMe: isMe),
          ),
        ],
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

        if (isMe) ...[
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
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}
