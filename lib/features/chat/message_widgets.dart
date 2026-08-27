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
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.message,
    super.key,
    this.showSenderName = false,
    this.onLongPress,
    this.onDoubleTap,
    this.onSwipeRight,
    this.isLiked = false,
    this.currentUserId,
    this.currentUserName,
    this.totalLikes = 0,
    this.likers = const [],
    this.nameById = const {},
  });

  final Message message;
  final bool showSenderName;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSwipeRight;
  final bool isLiked;
  final String? currentUserId;
  final String? currentUserName;
  final int totalLikes;
  final List<String> likers;
  final Map<String, String> nameById;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  void _handleDoubleTap() {
    widget.onDoubleTap?.call();
  }

  static ({String? sender, String? quotedText, String? body})? _parseReply(String text) {
    final regex = RegExp(r'^Replying to (.+?):\s*(.*?)(?:\n\n|\n)(.*)$', dotAll: true);
    final match = regex.firstMatch(text);
    if (match == null) return null;
    return (
      sender: match.group(1),
      quotedText: match.group(2),
      body: match.group(3),
    );
  }

  String _replyAttribution(
    bool isMe,
    ({String? sender, String? quotedText, String? body}) reply,
  ) {
    final repliedTo = (reply.sender ?? '').trim();
    final hasName =
        repliedTo.isNotEmpty && repliedTo.toLowerCase() != 'message';
    final currentName = widget.currentUserName?.trim();

    if (isMe) {
      if (hasName && repliedTo.toLowerCase() != 'you') {
        return 'You replied to $repliedTo';
      }
      return 'You replied';
    }

    final authorName = widget.message.senderName?.trim();
    if (authorName == null || authorName.isEmpty) {
      return hasName ? 'Replied to $repliedTo' : 'Replied';
    }

    if (!hasName) {
      return '$authorName replied';
    }

    final repliedToLower = repliedTo.toLowerCase();
    if (currentName != null &&
        currentName.isNotEmpty &&
        repliedToLower == currentName.toLowerCase()) {
      return '$authorName replied to you';
    }

    return '$authorName replied to $repliedTo';
  }

  Widget _buildMessageText(String text, bool isMe) {
    final reply = _parseReply(text);
    if (reply != null) {
      // Instagram-style inverted quoted surface: a sent (purple) bubble carries
      // a dark/translucent quote, a received (dark) bubble carries a
      // purple-tinted quote. Both get a subtle vertical left accent bar.
      final quotedSurface = isMe
          ? Colors.black.withValues(alpha: .18)
          : _kAccent.withValues(alpha: .18);
      final accentBar =
          isMe ? Colors.white.withValues(alpha: .55) : _kAccent;
      final quotedSenderColor =
          isMe ? Colors.white : const Color(0xFFB7A5FF);
      final quotedTextColor = isMe
          ? Colors.white.withValues(alpha: .85)
          : const Color(0xFFCBD3E8);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              color: quotedSurface,
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: accentBar),
                    Flexible(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(9, 6, 11, 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              reply.sender ?? 'Message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: quotedSenderColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reply.quotedText ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                                color: quotedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (reply.body != null && reply.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reply.body!,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: isMe ? Colors.white : const Color(0xFFE7ECF9),
              ),
            ),
          ],
        ],
      );
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: isMe ? Colors.white : const Color(0xFFE7ECF9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.author == MessageAuthor.me;
    final isDeleted = widget.message.isDeleted;
    final replyInfo = isDeleted ? null : _parseReply(widget.message.text);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 7),
      bottomRight: Radius.circular(isMe ? 7 : 22),
    );

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
          : _buildMessageText(widget.message.text, isMe),
    );

    final interactiveBubble = (widget.onLongPress != null && !isDeleted)
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: widget.onLongPress,
            onDoubleTap: _handleDoubleTap,
            child: bubble,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _handleDoubleTap,
            child: bubble,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showSenderName &&
              !isMe &&
              widget.message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 3),
              child: Text(
                widget.message.senderName!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _kSubtle,
                ),
              ),
            ),
          if (replyInfo != null)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 12,
                right: isMe ? 12 : 0,
                bottom: 4,
              ),
              child: Text(
                _replyAttribution(isMe, replyInfo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kSubtle.withValues(alpha: .55),
                ),
              ),
            ),
          interactiveBubble,
          if (widget.isLiked || widget.totalLikes > 0)
            Padding(
              padding: EdgeInsets.only(
                top: 3,
                left: isMe ? 12 : 0,
                right: isMe ? 0 : 12,
              ),
              child: GestureDetector(
                onTap: () {
                  if (widget.isLiked) {
                    widget.onDoubleTap?.call();
                  } else if (widget.message.author == MessageAuthor.me) {
                    final likers = widget.likers;
                    if (likers.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (ctx) => _LikersPopover(
                          likers: likers,
                          nameById: widget.nameById,
                        ),
                      );
                    }
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 15,
                      color: widget.isLiked
                          ? const Color(0xFFFF4D8D)
                          : const Color(0xFFFF4D8D).withValues(alpha: .7),
                    ),
                    if (widget.totalLikes >= 2) ...[
                      const SizedBox(width: 3),
                      Text(
                        '+${widget.totalLikes - 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: widget.isLiked
                              ? const Color(0xFFFF4D8D)
                              : const Color(0xFFFF4D8D).withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: _MetaLine(message: widget.message, isMe: isMe),
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

class _LikersPopover extends StatelessWidget {
  const _LikersPopover({
    required this.likers,
    this.nameById = const {},
  });

  final List<String> likers;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: const Color(0xFFFF4D8D),
                ),
                const SizedBox(width: 8),
                Text(
                  'Liked by ${likers.length}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...likers.map(
              (id) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  nameById[id] ?? id,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFFB9C3DC),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
