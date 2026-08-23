import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_starter_prompts.dart';
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
    switch (c.status) {
      case ConversationStatus.online:
        return 'Active now';
      case ConversationStatus.recentlyConnected:
        return 'Recently connected';
      case ConversationStatus.offline:
        return 'Offline';
    }
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
    this.enableStarters = false,
  });

  final Future<void> Function(String)? onSend;
  final String? initialText;
  final ValueChanged<String>? onDraftChanged;

  /// Fired on every text change (used to drive the ephemeral typing indicator).
  /// Separate from [onDraftChanged] so draft persistence and typing stay
  /// decoupled.
  final ValueChanged<String>? onChanged;

  /// When true the `+` button opens the Conversation Starter sheet. Disabled in
  /// read-only/demo composers so the control stays inert there.
  final bool enableStarters;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

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
    super.dispose();
  }

  void _handleChanged(String text) {
    widget.onDraftChanged?.call(text);
    widget.onChanged?.call(text);
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.onSend == null) return;

    setState(() => _sending = true);
    _controller.clear();
    widget.onDraftChanged?.call('');
    // Text is now empty — let listeners (typing indicator) know immediately.
    widget.onChanged?.call('');
    try {
      await widget.onSend!(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Opens the Conversation Starter sheet. If the composer already contains
  /// text, confirms before replacing it (never silently overwrites). The
  /// selected prompt only POPULATES the composer — it is never auto-sent.
  Future<void> _openStarters() async {
    final current = _controller.text.trim();
    if (current.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141B2E),
          title: const Text(
            'Replace your message?',
            style: TextStyle(color: Color(0xFFEAEEF9)),
          ),
          content: const Text(
            'Your current message will be replaced with the starter you pick.',
            style: TextStyle(color: Color(0xFFB9C3DC)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep typing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _StarterPromptSheet(),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    _controller.text = selected;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    // Persist as draft; do NOT auto-send. The user reviews/edits, then Sends.
    widget.onDraftChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CircleButton(
              icon: Icons.add_rounded,
              onTap: widget.enableStarters ? _openStarters : () {},
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onChanged: _handleChanged,
                onSubmitted: (_) => _handleSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: _kSubtle,
                  ),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.arrow_upward_rounded,
              filled: true,
              onTap: () {
                if (!_sending) _handleSend();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
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
            size: 22,
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

/// The Conversation Starter sheet: a compact premium glass surface listing
/// [kConversationStarters]. Tapping a prompt pops it back to the composer,
/// which populates the text field (never auto-sends).
class _StarterPromptSheet extends StatelessWidget {
  const _StarterPromptSheet();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(maxHeight: media.size.height * 0.62),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .38),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFFB7A5FF),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Start a conversation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEAEEF9),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick one to add it to your message.',
                  style: TextStyle(fontSize: 12.5, color: _kMuted),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                itemCount: kConversationStarters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final prompt = kConversationStarters[i];
                  return _StarterTile(
                    prompt: prompt,
                    onTap: () => Navigator.of(context).pop(prompt),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterTile extends StatelessWidget {
  const _StarterTile({required this.prompt, required this.onTap});

  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _kAccent.withValues(alpha: .10),
        highlightColor: Colors.white.withValues(alpha: .03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE7ECF9),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.north_east_rounded, size: 16, color: _kSubtle),
            ],
          ),
        ),
      ),
    );
  }
}
