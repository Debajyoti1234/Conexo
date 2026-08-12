import 'package:flutter/material.dart';

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
    super.key,
  });

  final ConversationPreview conversation;
  final GroupMetadata? group;
  final List<ChatMenuAction> menuActions;
  final ValueChanged<String> onMenuSelected;

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
  });

  final ValueChanged<String>? onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.onSend == null) return;

    setState(() => _sending = true);
    _controller.clear();
    widget.onSend!(text);
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
              onTap: () {},
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
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
