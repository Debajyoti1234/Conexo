import 'package:flutter/material.dart';

import '../home_discovery_animations.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'conversation_widgets.dart';
import 'message_models.dart';
import 'message_widgets.dart';

/// The premium conversation screen (Phase 6.2).
///
/// Displays a message thread for a private or group conversation. UI-only: the
/// composer is decorative, no sending happens, no realtime updates. Loads the
/// thread + optional group metadata through [LocalChatRepository], reverses
/// the chronological list for display, and uses a premium slide-fade route.

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.conversation,
    super.key,
    this.repository = const LocalChatRepository(),
  });

  final ConversationPreview conversation;
  final LocalChatRepository repository;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<Message> _messages = const [];
  GroupMetadata? _group;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final messages = await widget.repository.loadMessages(widget.conversation.id);
    final group = await widget.repository.loadGroupMetadata(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _group = group;
      _loading = false;
    });
  }

  void _handleMenuAction(String actionId) {
    // Phase 6.3: handle view_profile, mute, block, report, etc.
    debugPrint('Menu action: $actionId');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: ConversationAppBar(
        conversation: c,
        group: _group,
        menuActions: _buildMenuActions(c),
        onMenuSelected: _handleMenuAction,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _EmptyThread(name: c.name)
                      : _MessageList(
                          messages: _messages,
                          conversation: c,
                          group: _group,
                        ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: const MessageComposer(),
                ),
              ],
            ),
    );

  }

  List<ChatMenuAction> _buildMenuActions(ConversationPreview c) {
    return [
      const ChatMenuAction(
        id: 'view_profile',
        label: 'View profile',
        icon: 0xe491, // Icons.person_outline_rounded
      ),
      if (c.isMuted)
        const ChatMenuAction(
          id: 'unmute',
          label: 'Unmute',
          icon: 0xe7f6, // Icons.notifications_active_rounded
        )
      else
        const ChatMenuAction(
          id: 'mute',
          label: 'Mute',
          icon: 0xe7f5, // Icons.notifications_off_rounded
        ),
      if (c.isGroup)
        const ChatMenuAction(
          id: 'group_details',
          label: 'Group details',
          icon: 0xe88a, // Icons.group_rounded
        ),
      const ChatMenuAction(
        id: 'block',
        label: 'Block',
        icon: 0xe14a, // Icons.block_rounded
        isDestructive: true,
      ),
      const ChatMenuAction(
        id: 'report',
        label: 'Report',
        icon: 0xe160, // Icons.flag_rounded
        isDestructive: true,
      ),
    ];
  }
}

/// The reversed message list with entrance animations and smart sectioning.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.conversation,
    required this.group,
  });

  final List<Message> messages;
  final ConversationPreview conversation;
  final GroupMetadata? group;

  @override
  Widget build(BuildContext context) {
    // Repository stores chronological; UI displays newest at bottom.
    final reversed = messages.reversed.toList();
    final showSenderNames = conversation.isGroup;

    return ListView.builder(
      reverse: true,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),

      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final msg = reversed[index];
        final key = ValueKey(msg.id);

        return RepaintBoundary(
          key: key,
          child: EntranceFade(
            delay: Duration(milliseconds: index * 40),
            child: _buildMessage(msg, showSenderNames),
          ),
        );
      },
    );
  }

  Widget _buildMessage(Message msg, bool showSenderNames) {
    switch (msg.type) {
      case MessageType.system:
        return SystemMessageChip(message: msg);
      case MessageType.shared:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SharedContentCard(content: msg.sharedContent!),
        );
      case MessageType.text:
        return MessageBubble(
          message: msg,
          showSenderName: showSenderNames && msg.author == MessageAuthor.them,
        );
    }
  }
}

/// The empty state shown when a conversation has no messages yet.
class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EntranceFade(
        child: ConversationIntro(name: name),
      ),
    );
  }
}

/// Premium slide-fade route for entering a conversation from the inbox.
Route<void> conversationRoute(ConversationPreview conversation) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ConversationScreen(conversation: conversation),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
