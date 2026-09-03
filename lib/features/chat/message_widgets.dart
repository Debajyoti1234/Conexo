import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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
    this.resolveImage,
    this.onImageTap,
    this.resolveAudioUrl,
    this.isGif = false,
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
  final Future<ImageProvider?> Function(String storagePath)? resolveImage;
  final VoidCallback? onImageTap;
  final Future<String?> Function(String storagePath)? resolveAudioUrl;
  final bool isGif;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  ImageProvider? _imageProvider;
  bool _imageLoading = false;
  bool _imageError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.mediaUrl != widget.message.mediaUrl) {
      _imageProvider = null;
      _imageError = false;
      _resolveImageIfNeeded();
    }
  }

  void _resolveImageIfNeeded() {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return;
    if (_imageProvider != null || _imageLoading) return;

    final resolver = widget.resolveImage;
    if (resolver == null) return;

    _imageLoading = true;
    resolver(mediaUrl).then((provider) {
      if (!mounted) return;
      setState(() {
        _imageProvider = provider;
        _imageLoading = false;
        _imageError = provider == null;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _imageLoading = false;
        _imageError = true;
      });
    });
  }

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

  Widget _buildImageContent(bool isMe) {
    final hasCaption = widget.message.text.isNotEmpty;

    Widget imageWidget;
    if (_imageLoading) {
      imageWidget = Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_kSubtle),
            ),
          ),
        ),
      );
    } else if (_imageError || _imageProvider == null) {
      imageWidget = Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_rounded,
                size: 28,
                color: _kMuted.withValues(alpha: .6),
              ),
              const SizedBox(height: 6),
              Text(
                'Failed to load image',
                style: TextStyle(
                  fontSize: 12,
                  color: _kMuted.withValues(alpha: .7),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      imageWidget = GestureDetector(
        onTap: widget.onImageTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: _imageProvider!,
            width: double.infinity,
            gaplessPlayback: widget.isGif,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kSubtle),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 28,
                    color: _kMuted.withValues(alpha: .6),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final children = <Widget>[imageWidget];
    if (hasCaption) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.message.text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: isMe ? Colors.white : const Color(0xFFE7ECF9),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.author == MessageAuthor.me;
    final isDeleted = widget.message.isDeleted;
    final replyInfo = isDeleted ? null : _parseReply(widget.message.text);
    final isImage = widget.message.type == MessageType.image &&
        widget.message.mediaUrl != null;
    final isGif = widget.message.type == MessageType.gif &&
        widget.message.mediaUrl != null;
    final isVoice = widget.message.type == MessageType.voice &&
        widget.message.mediaUrl != null;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMe ? 22 : 7),
      bottomRight: Radius.circular(isMe ? 7 : 22),
    );

    final bubble = Container(
      padding: isDeleted
          ? const EdgeInsets.fromLTRB(14, 10, 15, 10)
        : isImage || isVoice || isGif
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 11, 16, 11),
       decoration: isDeleted
           ? BoxDecoration(
               color: Colors.white.withValues(alpha: .045),
               borderRadius: radius,
             )
           : isImage || isVoice || isGif
               ? null
              : BoxDecoration(
                  gradient: (isMe && !isDeleted)
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kMeStart, _kMeMid, _kMeEnd],
                        )
                      : null,
                  color: isMe ? null : _kThem,
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
          : isVoice
              ? VoiceMessageBubble(
                  message: widget.message,
                  resolveAudioUrl: widget.resolveAudioUrl ??
                      ( (_) async => null),
                )
              : isImage
                  ? _buildImageContent(isMe)
                  : isGif
                      ? _buildImageContent(isMe)
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

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    required this.message,
    required this.resolveAudioUrl,
    super.key,
  });

  final Message message;
  final Future<String?> Function(String storagePath) resolveAudioUrl;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  static const _kPlayIcon = Icons.play_arrow_rounded;
  static const _kPauseIcon = Icons.pause_rounded;

  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _error = false;
  String? _signedUrl;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _resolveAudio();
    _player.onPositionChanged.listen(_onPositionChanged);
    _player.onDurationChanged.listen(_onDurationChanged);
    _player.onPlayerStateChanged.listen(_onPlayerStateChanged);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _resolveAudio() async {
    final mediaUrl = widget.message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    try {
      final signedUrl = await widget.resolveAudioUrl(mediaUrl);
      if (!mounted) return;
      setState(() {
        _signedUrl = signedUrl;
        _loading = false;
        _error = signedUrl == null || signedUrl.isEmpty;
      });

      if (_signedUrl != null && _signedUrl!.isNotEmpty) {
        await _player.setSourceUrl(_signedUrl!);
        // Immediately capture any duration the player already knows — some
        // formats need a tick after setSourceUrl before onDurationChanged fires.
        unawaited(_captureDurationFromPlayer());
       }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _onPositionChanged(Duration position) {
    if (!mounted) return;
    setState(() => _position = position);
  }

  void _onDurationChanged(Duration duration) {
    if (!mounted) return;
    setState(() => _duration = duration);
  }

  /// After the source loads, [onDurationChanged] fires via the listener set up
  /// in [initState]. As a belt-and-suspenders measure, also call the player's
  /// `getDuration()` — some audio formats (notably m4a/aac) only resolve
  /// metadata after a brief async gap that the stream event can race ahead
  /// of. This guarantees [_duration] is populated from the real audio metadata
  /// rather than staying at [Duration.zero].
  Future<void> _captureDurationFromPlayer() async {
    if (_duration > Duration.zero) return;
    try {
      final playerDuration = await _player.getDuration();
      if (playerDuration != null &&
          playerDuration > Duration.zero &&
          playerDuration != _duration) {
        if (!mounted) return;
        setState(() => _duration = playerDuration);
      }
    } catch (_) {}
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (!mounted) return;
    setState(() => _playing = state == PlayerState.playing);
  }

  Future<void> _togglePlay() async {
    if (_signedUrl == null || _signedUrl!.isEmpty) return;

    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.author == MessageAuthor.me;

    Widget content;
    if (_loading) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: .08) : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_kSubtle),
          ),
        ),
      );
    } else if (_error) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: .08) : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 18,
              color: _kMuted.withValues(alpha: .6),
            ),
            const SizedBox(width: 8),
            Text(
              'Failed to load audio',
              style: TextStyle(
                fontSize: 12,
                color: _kMuted.withValues(alpha: .7),
              ),
            ),
          ],
        ),
      );
    } else {
      final progress = _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

       final displayDuration = _duration > Duration.zero
           ? _formatDuration(_duration)
           : _formatDuration(_position);

      content = GestureDetector(
        onTap: _togglePlay,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: .08) : Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _playing ? _kPauseIcon : _kPlayIcon,
                size: 22,
                color: isMe ? Colors.white : _kSubtle,
              ),
             const SizedBox(width: 10),
             SizedBox(
               width: 80,
               child: Text(
                 displayDuration,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : _kSubtle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: isMe
                        ? Colors.white.withValues(alpha: .12)
                        : Colors.white.withValues(alpha: .08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? Colors.white : _kSubtle,
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return content;
  }
}
