import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase/auth_service.dart';
import '../home_discovery_animations.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_dtos.dart';
import 'conversation_widgets.dart';
import 'message_models.dart';
import 'message_widgets.dart';
import 'realtime_messages_service.dart';
import '../profile/profile_data.dart';
import '../profile/public_profile_data.dart';
import '../profile/public_profile_screen.dart';
import '../profile/report_problem_screen.dart';
import '../profile/safety_repository.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.conversation,
    super.key,
    this.repository = const LocalChatRepository(),
    this.chatRepository,
  });

  final ConversationPreview conversation;
  final LocalChatRepository repository;
  final ChatRepository? chatRepository;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<Message> _messages = const [];
  GroupMetadata? _group;
  bool _loading = true;
  String? _error;
  StreamSubscription<ChatMessageEvent>? _realtimeSubscription;
  SharedPreferences? _prefs;
  String _draftText = '';
  bool _isBlocked = false;

  String get _draftKey => 'chat_draft_${widget.conversation.id}';

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.chatRepository != null &&
        widget.conversation.type == ConversationType.private) {
      _startRealtime();
    }
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    final otherId = widget.conversation.otherUserId;
    if (otherId == null) return;
    final result = await const SafetyRepository().isBlocked(otherId);
    if (!mounted) return;
    setState(() => _isBlocked = result.value ?? false);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    RealtimeMessagesService.instance.stop();
    super.dispose();
  }

  void _startRealtime() {
    _realtimeSubscription =
        RealtimeMessagesService.instance
            .onMessageChanged
            .listen(_handleRealtimeEvent);
    RealtimeMessagesService.instance.start(widget.conversation.id);
  }

  void _handleRealtimeEvent(ChatMessageEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case ChatEventType.inserted:
        if (event.message != null) {
          final existingIndex = _messages.indexWhere(
            (m) => m.id == event.messageId,
          );
          final mapped = _mapDtoToMessage(event.message!);
          if (existingIndex >= 0) {
            setState(() {
              _messages = List<Message>.from(_messages);
              _messages[existingIndex] = mapped;
            });
          } else {
            setState(() {
              _messages = List<Message>.from(_messages)..add(mapped);
            });
          }
        }
        break;
      case ChatEventType.updated:
        if (event.message != null && event.message!.deletedAt != null) {
          setState(() {
            _messages = _messages
                .where((m) => m.id != event.messageId)
                .toList();
          });
        }
        break;
      case ChatEventType.deleted:
        setState(() {
          _messages = _messages.where((m) => m.id != event.messageId).toList();
        });
        break;
    }
  }

  Message _mapDtoToMessage(ChatMessage dto) {
    final isMine = dto.senderId == AuthService.currentUser?.id;
    return Message(
      id: dto.id,
      author: isMine ? MessageAuthor.me : MessageAuthor.them,
      timestamp: dto.createdAt,
      type: MessageType.text,
      text: dto.content,
      // Truthful status only: a persisted own message is "sent" (gray tick).
      // Blue "read" is deferred to a future backend read-receipt phase.
      deliveryStatus: MessageDeliveryStatus.sent,
    );
  }

  void _onDraftChanged(String text) {
    if (text.isEmpty) {
      _prefs?.remove(_draftKey);
    } else {
      _prefs?.setString(_draftKey, text);
    }
  }

  Future<void> _load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final draft = _prefs!.getString(_draftKey) ?? '';
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _draftText = draft;
    });

    try {
      if (widget.chatRepository != null &&
          widget.conversation.type == ConversationType.private) {
        final messagesResult = await widget.chatRepository!.loadMessages(
          widget.conversation.id,
        );
        final readResult = await widget.chatRepository!.updateLastReadAt(
          widget.conversation.id,
        );

        if (!mounted) return;
        if (messagesResult.isFailure) {
          setState(() {
            _error = messagesResult.error ?? 'Failed to load messages';
            _loading = false;
          });
          return;
        }

        if (readResult.isFailure) {
          setState(() {
            _error = readResult.error ?? 'Failed to update read state';
            _loading = false;
          });
          return;
        }

        final dtoMessages = messagesResult.value!;
        final mapped = <Message>[
          for (final dto in dtoMessages)
            _mapDtoToMessage(dto),
        ];

        setState(() {
          _messages = mapped;
          _group = null;
          _loading = false;
        });
      } else {
        final messages = await widget.repository.loadMessages(
          widget.conversation.id,
        );
        final group = await widget.repository.loadGroupMetadata(
          widget.conversation.id,
        );
        if (!mounted) return;
        setState(() {
          _messages = messages;
          _group = group;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (widget.chatRepository == null) return;

    final result = await widget.chatRepository!.sendMessage(
      conversationId: widget.conversation.id,
      content: text.trim(),
    );

    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to send message'),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
      return;
    }

    final sent = _mapDtoToMessage(result.value!);
    setState(() {
      _messages = List<Message>.from(_messages)..add(sent);
    });
  }

  void _handleMenuAction(String actionId) {
    if (actionId == 'view_profile') {
      final c = widget.conversation;
      final profile = UserProfile(
        id: c.id,
        photos: [
          ProfilePhoto(
            id: 'chat_${c.id}',
            assetPath: c.avatarAsset,
            isPrimary: true,
          ),
        ],
        bio: '',
        interests: const [],
        languages: const [],
        gender: '',
        location: '',
        socialLinks: const [],
        occupation: '',
        displayName: c.name,
        verificationStatus: c.isVerified
            ? VerificationStatus.verified
            : VerificationStatus.notVerified,
      );
      final data = PublicProfileViewData(
        profile: profile,
        displayName: c.name,
        viewerInterests: const [],
      );
      Navigator.of(context).push(premiumPublicProfileRoute(data: data));
      return;
    }

    if (actionId == 'block') {
      final otherId = widget.conversation.otherUserId;
      if (otherId == null) return;
      _showBlockDialog(otherId);
      return;
    }

    if (actionId == 'report') {
      final otherId = widget.conversation.otherUserId;
      if (otherId == null) return;
      _openReport(otherId);
      return;
    }

    debugPrint('Menu action: $actionId');
  }

  Future<void> _showBlockDialog(String otherId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2E),
        title: const Text('Block User', style: TextStyle(color: Color(0xFFEAEEF9))),
        content: Text(
          'Block ${widget.conversation.name}? You will no longer see each other in People or chat.',
          style: const TextStyle(color: Color(0xFFB9C3DC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await const SafetyRepository().blockUser(otherId);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isBlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.conversation.name} has been blocked'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to block user')),
      );
    }
  }

  Future<void> _openReport(String otherId) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReportProblemScreen(reportedUserId: otherId),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      resizeToAvoidBottomInset: false,
      appBar: ConversationAppBar(
        conversation: c,
        group: _group,
        menuActions: _buildMenuActions(c),
        onMenuSelected: _handleMenuAction,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                )
              : _isBlocked
                  ? _BlockedState(name: c.name)
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
                          child: MessageComposer(
                            initialText: _draftText,
                            onDraftChanged: _onDraftChanged,
                            onSend: widget.chatRepository != null
                                ? _sendMessage
                                : null,
                          ),
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
        icon: 0xe491,
      ),
      if (c.isMuted)
        const ChatMenuAction(
          id: 'unmute',
          label: 'Unmute',
          icon: 0xe7f6,
        )
      else
        const ChatMenuAction(
          id: 'mute',
          label: 'Mute',
          icon: 0xe7f5,
        ),
      if (c.isGroup)
        const ChatMenuAction(
          id: 'group_details',
          label: 'Group details',
          icon: 0xe88a,
        ),
      const ChatMenuAction(
        id: 'block',
        label: 'Block',
        icon: 0xe14a,
        isDestructive: true,
      ),
      const ChatMenuAction(
        id: 'report',
        label: 'Report',
        icon: 0xe160,
        isDestructive: true,
      ),
    ];
  }
}

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4D8D).withValues(alpha: .12),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 27,
              color: Color(0xFFFF4D8D),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFB9C3DC),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _BlockedState extends StatelessWidget {
  const _BlockedState({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE36D9D).withValues(alpha: .12),
              ),
              child: const Icon(
                Icons.block_rounded,
                size: 27,
                color: Color(0xFFE36D9D),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'This user is blocked',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have blocked $name. Unblock them from Safety to resume messaging.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFFB9C3DC),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Safety'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route<void> conversationRoute(
  ConversationPreview conversation, {
  ChatRepository? chatRepository,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) =>
        ConversationScreen(
          conversation: conversation,
          chatRepository: chatRepository,
        ),
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
