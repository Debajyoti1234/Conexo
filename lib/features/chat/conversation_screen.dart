import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../home_discovery_animations.dart';
import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_dtos.dart';
import 'conversation_widgets.dart';
import 'message_models.dart';
import 'message_widgets.dart';
import 'realtime_messages_service.dart';
import '../plans/plan_details_screen.dart';
import '../plans/plan_members_screen.dart';
import '../plans/supabase_plan_repository.dart';
import '../profile/profile_navigation_mapper.dart';
import '../profile/public_profile_screen.dart';
import '../profile/report_problem_screen.dart';
import '../profile/safety_repository.dart';
import '../profile/supabase_profile_repository.dart';

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
  // P1.2B.9: sender lookup for group (plan) chats, so received bubbles show
  // the real participant name/avatar. Empty for 1:1 connection chats.
  final Map<String, Participant> _participantsById = {};
  bool _loading = true;
  String? _error;
  StreamSubscription<ChatMessageEvent>? _realtimeSubscription;
  SharedPreferences? _prefs;
  String _draftText = '';
  bool _isBlocked = false;
  bool _chatRevoked = false;

  String get _draftKey => 'chat_draft_${widget.conversation.id}';

  @override
  void initState() {
    super.initState();
    _load();
    // Realtime for BOTH private connection chats and group plan chats. The
    // per-conversation channel is generic; only pure demo (no chatRepository)
    // skips realtime.
    if (widget.chatRepository != null) {
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
    // For group (plan) chats, resolve the real sender identity for received
    // bubbles from the loaded participant list. 1:1 chats leave these null.
    String? senderName;
    String? senderAvatar;
    if (!isMine && widget.conversation.type == ConversationType.group) {
      final participant = _participantsById[dto.senderId];
      senderName = participant?.name;
      final avatar = participant?.avatarAsset ?? '';
      senderAvatar = avatar.isNotEmpty ? avatar : null;
    }
    final isSystem = dto.type == 'system';
    return Message(
      id: dto.id,
      author: isSystem
          ? MessageAuthor.system
          : (isMine ? MessageAuthor.me : MessageAuthor.them),
      timestamp: dto.createdAt,
      type: isSystem ? MessageType.system : MessageType.text,
      text: dto.content,
      senderName: senderName,
      senderAvatar: senderAvatar,
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
      if (widget.chatRepository != null) {
        final isGroup = widget.conversation.type == ConversationType.group;

        // Load group metadata FIRST so received-message sender identity
        // resolves during message mapping below.
        GroupMetadata? group;
        if (isGroup) {
          final groupResult = await widget.chatRepository!.loadGroupMetadata(
            widget.conversation.id,
          );
          if (groupResult.isSuccess) {
            group = groupResult.value;
          }
        }

        if (isGroup) {
          final conv = await Supabase.instance.client
              .from('conversations')
              .select('plan_id')
              .eq('id', widget.conversation.id)
              .maybeSingle();
          final planId = conv?['plan_id'] as String?;
          if (planId != null) {
            final plan = await Supabase.instance.client
                .from('plans')
                .select('status')
                .eq('id', planId)
                .maybeSingle();
            if (plan != null && plan['status'] == 'archived') {
              if (!mounted) return;
              setState(() {
                _chatRevoked = true;
                _loading = false;
              });
              return;
            }
          }
        }

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

        _participantsById.clear();
        if (group != null) {
          for (final participant in group.participants) {
            _participantsById[participant.id] = participant;
          }
        }

        final dtoMessages = messagesResult.value!;
        final mapped = <Message>[
          for (final dto in dtoMessages)
            _mapDtoToMessage(dto),
        ];

        setState(() {
          _messages = mapped;
          _group = group;
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
    final c = widget.conversation;

    if (actionId == 'view_members' && c.isGroup) {
      final planId = c.planId;
      if (planId == null || planId.isEmpty) return;
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              PlanMembersScreen(planId: planId),
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
      return;
    }

    if (actionId == 'view_plan' && c.isGroup) {
      final planId = c.planId;
      if (planId == null || planId.isEmpty) return;
      _openPlanFromChat(planId);
      return;
    }

    if (actionId == 'view_profile') {
      final otherId = widget.conversation.otherUserId;
      if (otherId == null || otherId.isEmpty) return;
      () async {
        final repo = const SupabaseProfileRepository();
        final profile = await repo.loadProfileByUserId(otherId);
        if (!mounted) return;
        if (profile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile not available'),
              backgroundColor: Color(0xFFFF4D8D),
            ),
          );
          return;
        }
        final data = mapUserProfileToPublicProfile(profile);
        if (!mounted) return;
        Navigator.of(context).push(premiumPublicProfileRoute(data: data));
      }();
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

  void _openPlanFromChat(String planId) {
    () async {
      final repo = SupabasePlanRepository();
      try {
        final experience = await repo.getPlanExperience(planId);
        if (experience == null) throw StateError('plan not found');
        if (!mounted) return;
        Navigator.of(context).push(premiumPlanRoute(experience));
      } on StateError {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open plan details'),
            backgroundColor: Color(0xFFFF4D8D),
          ),
        );
      } on AuthFailure catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFFF4D8D),
          ),
        );
      }
    }();
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
      backgroundColor: Colors.black,
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
          : _chatRevoked
              ? const _RevokedChatState()
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
    if (c.isGroup) {
      return [
        const ChatMenuAction(
          id: 'view_members',
          label: 'View Members',
          icon: 0xe7ef,
        ),
        const ChatMenuAction(
          id: 'view_plan',
          label: 'View Plan',
          icon: 0xe8b6,
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
      ];
    }

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

class _RevokedChatState extends StatelessWidget {
  const _RevokedChatState();

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
                color: const Color(0xFFF09A65).withValues(alpha: .12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 27,
                color: Color(0xFFF09A65),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chat temporarily revoked by host',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This chat will become available again if the host restores the plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFFB9C3DC),
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
