import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

import 'chat_attachment_service.dart';
import 'chat_models.dart';
import 'chat_widgets.dart';
import 'message_models.dart';

/// Composed conversation-screen chrome for Phase 6.2 messaging.
///
/// UI only — the app bar, the (disabled) composer, and small header pieces.
/// No sending, no realtime, no persistence.

// ── Palette (kept local + minimal) ──────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kSubtle = Color(0xFF9DB2E8);
const _kMuted = Color(0xFFB9C3DC);
const _kOnline = Color(0xFF47D7A5);

/// The premium conversation app bar: back, avatar, name + presence subtitle,
/// and an overflow menu that emits declarative [ChatMenuAction] ids.
class ConversationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ConversationAppBar({
    required this.conversation,
    required this.group,
    required this.menuActions,
    required this.onMenuSelected,
    this.onAvatarTap,
    super.key,
  });

  final ConversationPreview conversation;
  final GroupMetadata? group;
  final List<ChatMenuAction> menuActions;
  final ValueChanged<String> onMenuSelected;

  /// Tapping the person's avatar opens their canonical Public Profile — the
  /// same action as the "View Profile" menu item. Null disables the tap (e.g.
  /// group/plan chats, or before the profile target is known).
  final VoidCallback? onAvatarTap;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              ConversationAvatar(
                asset: c.avatarAsset,
                name: c.name,
                status: c.status,
                size: 44,
                onTap: onAvatarTap,
              ),
              const SizedBox(width: 12),

              Expanded(child: _TitleBlock(conversation: c, group: group)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                color: const Color(0xFF161C30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  for (final a in menuActions)
                    PopupMenuItem<String>(
                      value: a.id,
                      child: Row(
                        children: [
                          Icon(
                            _iconFor(a.icon),
                            size: 18,
                            color: a.isDestructive
                                ? const Color(0xFFFF6B6B)
                                : _kSubtle,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            a.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: a.isDestructive
                                  ? const Color(0xFFFF6B6B)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves a stored [ChatMenuAction.icon] code point to a Material glyph.
/// A tiny lookup keeps the icon tree-shaker happy (const IconData required).
IconData _iconFor(int codePoint) {
  switch (codePoint) {
    case 0xe491:
      return Icons.person_outline_rounded;
    case 0xe7f6:
      return Icons.notifications_active_rounded;
    case 0xe7f5:
      return Icons.notifications_off_rounded;
    case 0xe88a:
      return Icons.group_rounded;
    case 0xe14a:
      return Icons.block_rounded;
    case 0xe160:
      return Icons.flag_rounded;
    default:
      return Icons.circle_outlined;
  }
}

/// Name + a context-aware subtitle (presence for private, member count for
/// groups; "typing…" when active).
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.conversation, required this.group});

  final ConversationPreview conversation;
  final GroupMetadata? group;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final subtitle = _subtitle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
            ),
            if (c.isVerified) ...[
              const SizedBox(width: 5),
              const VerifiedBadge(size: 15),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.isTyping
                ? _kOnline
                : (c.status == ConversationStatus.online ? _kOnline : _kSubtle),
          ),
        ),
      ],
    );
  }

  String _subtitle() {
    final c = conversation;
    if (c.isTyping) return 'typing…';
    if (c.isGroup && group != null) {
      final online = group!.participants.where((p) => p.isOnline).length;
      final count = group!.participantCount;
      return online > 0 ? '$count members • $online online' : '$count members';
    }
    return formatConnectionActivityStatus(c) ?? 'Offline';
  }
}

/// The premium message composer.
///
/// Phase 9.5.2 wires text state + sending through ChatRepository.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    this.onSend,
    this.initialText,
    this.onDraftChanged,
    this.onChanged,
    this.onImageSelected,
    this.onVoiceSelected,
    this.onGifSelected,
    this.conversationId,
    this.sendingGif = false,
    this.sendingGifUrl,
    this.gifMode = false,
    this.onCancelGif,
    this.onGifSearchChanged,
    this.focusNode,
  });

  final Future<void> Function(String)? onSend;
  final String? initialText;
  final ValueChanged<String>? onDraftChanged;

  /// Fired on every text change (used to drive the ephemeral typing indicator).
  /// Separate from [onDraftChanged] so draft persistence and typing stay
  /// decoupled.
  final ValueChanged<String>? onChanged;

  /// Called when the user picks an image from the device. The caller may
  /// insert an image message based on the completed upload.
  final Future<void> Function()? onImageSelected;

  /// Called when the user completes a voice recording. The caller may
  /// insert a voice message based on the completed upload.
  final Future<void> Function(String)? onVoiceSelected;

  /// Called when the user selects a GIF from the GIF picker. The caller may
  /// insert a GIF message based on the completed upload.
  final VoidCallback? onGifSelected;

  /// The conversation ID used for storage path construction during voice
  /// recording upload. Required so the `chat-attachments` Storage RLS
  /// INSERT policy can match `conversation_members`.
  final String? conversationId;

  /// When true, the GIF button shows a progress indicator instead of the label.
  final bool sendingGif;
  final String? sendingGifUrl;

  /// When true, the composer transforms into a GIF search field —
  /// placeholder changes to "Search GIFs...", and the send/mic button
  /// becomes an X (cancel) button.
  final bool gifMode;

  /// Called when the user taps the X button to close GIF mode.
  final VoidCallback? onCancelGif;

  /// Called when the user types in the GIF search field.
  final ValueChanged<String>? onGifSearchChanged;

  /// Optional focus node for the text field.
  final FocusNode? focusNode;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _uploadingImage = false;
  bool _recording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    // Programmatic set does NOT fire TextField.onChanged, so restoring a draft
    // never triggers an unnecessary save.
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _controller.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void _handleChanged(String text) {
    widget.onDraftChanged?.call(text);
    widget.onChanged?.call(text);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.onSend == null) return;

    setState(() {
      _sending = true;
      _controller.clear();
    });
    widget.onDraftChanged?.call('');
    // Text is now empty — let listeners (typing indicator) know immediately.
    widget.onChanged?.call('');
    try {
      await widget.onSend!(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleImageSelected() async {
    if (_uploadingImage) return;
    if (widget.onImageSelected == null) return;

    setState(() => _uploadingImage = true);
    try {
      await widget.onImageSelected!();
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _handleVoiceStop() async {
    if (!_recording) return;
    _stopRecordingTimer();
    final voiceUrl = await ChatAttachmentService.instance.stopVoiceRecording(
      conversationId: widget.conversationId,
    );
    setState(() => _recording = false);
    if (!mounted) return;
    if (voiceUrl.isFailure) {
      if (kDebugMode) {
        debugPrint('Voice recording stop FAILED: ${voiceUrl.error}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(voiceUrl.error ?? 'Failed to send voice'),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
      return;
    }
    final storagePath = voiceUrl.value;
    if (storagePath != null && storagePath.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('Voice recording stopped, storagePath=$storagePath, calling onVoiceSelected');
      }
      await widget.onVoiceSelected?.call(storagePath);
    } else {
      if (kDebugMode) {
        debugPrint('Voice recording stop returned empty storagePath');
      }
    }
  }

  Future<void> _handleVoiceCancel() async {
    await ChatAttachmentService.instance.cancelVoiceRecording();
    _stopRecordingTimer();
    if (mounted) {
      setState(() {
        _recording = false;
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _handleVoiceStart() async {
    if (_recording) return;
    final result = await ChatAttachmentService.instance.startVoiceRecording();
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to start recording'),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
      return;
    }
    setState(() {
      _recording = true;
      _recordingDuration = Duration.zero;
    });
    _startRecordingTimer();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _GifLabelButton(
              onTap: widget.gifMode
                  ? null
                  : (widget.sendingGif ? null : widget.onGifSelected),
              label: widget.sendingGif ? null : 'GIF',
              isLoading: widget.sendingGif,
            ),
            if (!widget.gifMode && widget.onImageSelected != null) ...[
              const SizedBox(width: 4),
              _CircleButton(
                icon: _uploadingImage
                    ? Icons.hourglass_empty_rounded
                    : Icons.image_rounded,
                onTap: _uploadingImage
                    ? null
                    : _handleImageSelected,
              ),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: _recording
                  ? _buildRecordingBar()
                  : _buildTextField(),
            ),
            if (!_recording) ...[
              const SizedBox(width: 6),
              widget.gifMode ? _buildCloseButton() : _buildAdaptiveSendButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    final isGifMode = widget.gifMode;
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      minLines: 1,
      maxLines: 5,
      textInputAction: isGifMode ? TextInputAction.search : TextInputAction.send,
      onChanged: (text) {
        _handleChanged(text);
        if (isGifMode) {
          widget.onGifSearchChanged?.call(text);
        }
      },
      onSubmitted: (text) {
        if (isGifMode) return;
        _handleSend();
      },
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: isGifMode ? 'Search GIFs...' : 'Message',
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isGifMode ? const Color(0xFF9DB2E8) : _kSubtle,
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isCollapsed: true,
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onCancelGif,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: .10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: const Icon(
            Icons.close_rounded,
            size: 20,
            color: Color(0xFFB9C3DC),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveSendButton() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (!hasText && widget.onVoiceSelected == null) {
      return const SizedBox.shrink();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: hasText
          ? _CircleButton(
              key: const ValueKey('send'),
              icon: Icons.arrow_upward_rounded,
              filled: true,
              onTap: _sending ? null : _handleSend,
            )
          : _CircleButton(
              key: const ValueKey('mic'),
              icon: Icons.mic_none_rounded,
              filled: false,
              onTap: _handleVoiceStart,
            ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D8D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_recordingDuration),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _handleVoiceCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFFFF4D8D),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _CircleButton(
            icon: Icons.stop_rounded,
            filled: true,
            size: 36,
            onTap: _handleVoiceStop,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.size = 40.0,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                  )
                : null,
            color: filled ? null : Colors.white.withValues(alpha: .06),
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
          child: Icon(
            icon,
            size: size * 0.52,
            color: filled ? Colors.white : _kSubtle,
          ),
        ),
      ),
    );
  }
}

/// A subtle encrypted-style hint shown at the top of a fresh private thread.
class ConversationIntro extends StatelessWidget {
  const ConversationIntro({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kAccent.withValues(alpha: .22),
                  _kAccent.withValues(alpha: .08),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 27,
              color: Color(0xFFB7A5FF),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'You\'re connected with $name',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Say hello and start the conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kMuted),
          ),
        ],
      ),
    );
  }
}

/// A left-aligned "them" bubble containing the animated typing dots. Shown at
/// the bottom of the thread while the other participant is typing. Purely a
/// presentation widget — visibility is controlled by the conversation screen.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 48, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(22),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: const TypingIndicator(color: _kSubtle),
        ),
      ),
    );
  }
}

/// Styled as muted text so the composer's outer container owns all visual
/// styling — this button adds no border, fill, or decoration of its own.
class _GifLabelButton extends StatelessWidget {
  const _GifLabelButton({
    this.onTap,
    this.label = 'GIF',
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final String? label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = onTap != null && !isLoading;
    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                effectiveEnabled ? _kAccent : _kMuted,
              ),
            ),
          )
        : Text(
            label ?? 'GIF',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: effectiveEnabled ? _kAccent : _kMuted,
            ),
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: _kAccent.withValues(alpha: .10),
        highlightColor: Colors.white.withValues(alpha: .03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// The Connection Chat welcome / start prompt shown at the top of a fresh
/// private thread that has not yet had its first message sent. Premium dark-glass
/// language. Only shown once per conversation (tracked by the caller via
/// SharedPreferences) and never on plan/group chats.
class ConnectionChatWelcome extends StatelessWidget {
  const ConnectionChatWelcome({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 14),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kAccent.withValues(alpha: .20),
                  _kAccent.withValues(alpha: .08),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 26,
              color: Color(0xFFB7A5FF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re connected with $name',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}
