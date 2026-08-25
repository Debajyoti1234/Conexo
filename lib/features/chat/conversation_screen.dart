import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/services/push_notification_service.dart';
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
  RealtimeChannel? _memberRealtimeSubscription;
  SharedPreferences? _prefs;
  String _draftText = '';
  // Directional block relationship for this 1:1 conversation. Resolved before
  // the composer is enabled so a blocked user never sees a typable field.
  bool _blockedByMe = false;
  bool _blockedByThem = false;
  bool _blockStatusLoaded = false;
  bool _isMuted = false;
  bool _chatRevoked = false;
  // Chat P4: the other participant's read position. Own messages with
  // created_at <= this value render the blue ✓✓ tick.
  DateTime? _otherLastReadAt;
  // Guard to avoid redundant last_read_at writes while the conversation is
  // active (no point updating Supabase if nothing new arrived).
  DateTime? _lastMarkedReadAt;
  // Entrance-animate only messages that arrive AFTER the initial load. Ids
  // present on first load render statically so the whole thread never animates.
  Set<String> _initialMessageIds = <String>{};
  // Ephemeral typing indicator over Supabase Realtime BROADCAST (never
  // persisted, no DB row). One channel per open conversation.
  RealtimeChannel? _typingChannel;
  bool _typingChannelReady = false;
  bool _typingBroadcasting = false;
  DateTime? _lastTypingSentAt;
  Timer? _typingStopTimer;
  Timer? _typingReceiveTimer;
  // Isolated so toggling typing rebuilds ONLY the typing bubble, never the list.
  final ValueNotifier<bool> _otherTyping = ValueNotifier<bool>(false);

  String get _draftKey => 'chat_draft_${widget.conversation.id}';

  @override
  void initState() {
    super.initState();
    _isMuted = widget.conversation.isMuted;
    final otherId = widget.conversation.otherUserId;
    final needsBlockCheck = !widget.conversation.isGroup &&
        otherId != null &&
        otherId.isNotEmpty;
    // Groups and demo/unknown-peer chats have no 1:1 block gate, so the
    // composer is enabled immediately. Real 1:1 chats stay gated until the
    // block relationship resolves (avoids a type-then-fail race).
    _blockStatusLoaded = !needsBlockCheck;
    _load();
    // Realtime for BOTH private connection chats and group plan chats. The
    // per-conversation channel is generic; only pure demo (no chatRepository)
    // skips realtime.
    if (widget.chatRepository != null) {
      _startRealtime();
    }
    if (needsBlockCheck) {
      _checkBlockStatus(otherId);
    }
    _checkMuteStatus();
    PushNotificationService.setActiveConversation(widget.conversation.id);
  }

  Future<void> _checkBlockStatus(String otherId) async {
    final state = await const SafetyRepository().blockStateWith(otherId);
    if (!mounted) return;
    setState(() {
      _blockedByMe = state.iBlocked;
      _blockedByThem = state.theyBlocked;
      _blockStatusLoaded = true;
    });
  }

  Future<void> _checkMuteStatus() async {
    if (widget.chatRepository == null) return;
    final result =
        await widget.chatRepository!.isConversationMuted(widget.conversation.id);
    if (!mounted) return;
    setState(() => _isMuted = result.value ?? _isMuted);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    if (_memberRealtimeSubscription != null) {
      Supabase.instance.client.removeChannel(_memberRealtimeSubscription!);
      _memberRealtimeSubscription = null;
    }
    // Typing: best-effort stop broadcast + tear down channel/timers so the
    // other side's indicator clears when we leave, and nothing leaks.
    _typingStopTimer?.cancel();
    _typingReceiveTimer?.cancel();
    if (_typingChannel != null) {
      if (_typingBroadcasting) {
        _sendTypingEvent(false);
      }
      Supabase.instance.client.removeChannel(_typingChannel!);
      _typingChannel = null;
    }
    _otherTyping.dispose();
    RealtimeMessagesService.instance.stop();
    PushNotificationService.setActiveConversation(null);
    super.dispose();
  }

  void _startRealtime() {
    _realtimeSubscription =
        RealtimeMessagesService.instance
            .onMessageChanged
            .listen(_handleRealtimeEvent);
    RealtimeMessagesService.instance.start(widget.conversation.id);

    // Chat P4: listen for conversation_members updates so we can refresh the
    // sender-side read tick when the other participant's last_read_at changes.
    // conversation_members is already in supabase_realtime; we just subscribe
    // here for this conversation.
    _memberRealtimeSubscription = Supabase.instance.client
        .channel('members-realtime-${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversation_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversation.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final updatedUserId = row['user_id'] as String?;
            final currentUserId = AuthService.currentUser?.id;
            if (updatedUserId == null || updatedUserId == currentUserId) return;

            final rawLastRead = row['last_read_at'] as String?;
            final lastReadAt = rawLastRead != null && rawLastRead.isNotEmpty
                ? DateTime.parse(rawLastRead)
                : null;
            // Diagnostic (debug builds only): confirms the sender actually
            // receives the recipient's conversation_members UPDATE in realtime.
            if (kDebugMode) {
              debugPrint(
                'READ RECEIPT REALTIME: conversation=${widget.conversation.id} '
                'user=$updatedUserId last_read_at=$rawLastRead',
              );
            }
            if (lastReadAt == _otherLastReadAt) return;

            setState(() {
              _otherLastReadAt = lastReadAt;
            });
            _refreshDeliveryStatuses();
          },
        )
        .subscribe();

    _startTypingChannel();
  }

  /// Ephemeral typing indicator over Supabase Realtime BROADCAST. No database
  /// row is ever written. The channel is per-conversation and torn down on
  /// dispose. Receiving is block-gated so a blocked pair never exchanges typing.
  void _startTypingChannel() {
    final me = AuthService.currentUser?.id;
    if (me == null) return;
    final channel =
        Supabase.instance.client.channel('typing:${widget.conversation.id}');
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (!mounted) return;
        // Never surface typing across a block relationship (either direction).
        if (_blockedByMe || _blockedByThem) return;
        // Broadcast delivers the sent map nested under 'payload'; fall back to
        // the top level for resilience across client versions.
        final raw = payload['payload'];
        final data = raw is Map
            ? Map<String, dynamic>.from(raw)
            : payload;
        final fromUser = data['user_id'] as String?;
        if (fromUser == null || fromUser == me) return;
        final isTyping = data['typing'] == true;
        _otherTyping.value = isTyping;
        // Safety auto-clear in case a stop event is missed/dropped.
        _typingReceiveTimer?.cancel();
        if (isTyping) {
          _typingReceiveTimer = Timer(const Duration(seconds: 5), () {
            _otherTyping.value = false;
          });
        }
      },
    );
    channel.subscribe((status, error) {
      _typingChannelReady = status == RealtimeSubscribeStatus.subscribed;
    });
    _typingChannel = channel;
  }

  /// Called on every composer text change. Drives the ephemeral typing
  /// broadcast with a throttle (re-broadcast `true` at most every ~1.5s) and a
  /// stop timer (broadcast `false` after ~2s of inactivity). Blocked pairs
  /// never broadcast.
  void _handleTypingInput(String text) {
    if (_blockedByMe || _blockedByThem) return;
    if (_typingChannel == null || !_typingChannelReady) return;

    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }

    final now = DateTime.now();
    final shouldSend = !_typingBroadcasting ||
        _lastTypingSentAt == null ||
        now.difference(_lastTypingSentAt!) > const Duration(milliseconds: 1500);
    if (shouldSend) {
      _sendTypingEvent(true);
      _typingBroadcasting = true;
      _lastTypingSentAt = now;
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    if (!_typingBroadcasting) return;
    _typingBroadcasting = false;
    _sendTypingEvent(false);
  }

  void _sendTypingEvent(bool typing) {
    final me = AuthService.currentUser?.id;
    final channel = _typingChannel;
    if (me == null || channel == null || !_typingChannelReady) return;
    // Fire-and-forget; typing is best-effort and must never block chat.
    channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': me, 'typing': typing},
    );
  }

  void _refreshDeliveryStatuses() {
    if (_otherLastReadAt == null) return;
    setState(() {
      _messages = _messages.map((msg) {
        if (msg.author != MessageAuthor.me || msg.isDeleted) return msg;
        final read = msg.timestamp.isBefore(_otherLastReadAt!) ||
            msg.timestamp.isAtSameMomentAs(_otherLastReadAt!);
        return msg.copyWith(
          deliveryStatus: read
              ? MessageDeliveryStatus.read
              : MessageDeliveryStatus.sent,
        );
      }).toList();
    });
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
            // Chat P4: a new incoming message while the conversation is active
            // means the recipient has implicitly seen it. Mark read so the
            // sender flips to ✓✓ without manual refresh.
            final senderId = event.message!.senderId;
            final currentUserId = AuthService.currentUser?.id;
            if (senderId.isNotEmpty && senderId != currentUserId) {
              _markConversationRead();
            }
          }
        }
        break;
      case ChatEventType.updated:
        // A soft delete (deleted_at set) arrives as an UPDATE. The message must
        // REMAIN in the timeline for BOTH participants — rendered as
        // "This message was deleted" — and never be removed. Replace it in
        // place so its chronological position + timestamp are preserved.
        //
        // If the updated row is not in memory yet (e.g. the UPDATE raced the
        // initial load, or the recipient had not loaded it), insert it in
        // chronological position instead of silently dropping the event, so
        // the delete converges purely over realtime without a reopen.
        if (event.message != null) {
          final mapped = _mapDtoToMessage(event.message!);
          final existingIndex = _messages.indexWhere(
            (m) => m.id == event.messageId,
          );
          setState(() {
            final next = List<Message>.from(_messages);
            if (existingIndex >= 0) {
              next[existingIndex] = mapped;
            } else {
              var insertAt = next.length;
              for (var i = 0; i < next.length; i++) {
                if (next[i].timestamp.isAfter(mapped.timestamp)) {
                  insertAt = i;
                  break;
                }
              }
              next.insert(insertAt, mapped);
            }
            _messages = next;
          });
        }
        break;
      case ChatEventType.deleted:
        // Physical row deletes are not part of the soft-delete design, but if
        // one ever arrives, drop the message defensively.
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

    // Chat P4: derive delivery status for own, non-deleted messages.
    // A message is "read" (blue ✓✓) only when the other participant's
    // last_read_at is at or after the message timestamp.
    MessageDeliveryStatus deliveryStatus = MessageDeliveryStatus.sent;
    if (isMine && !isSystem && dto.deletedAt == null) {
      if (_otherLastReadAt != null) {
        final isRead = dto.createdAt.isBefore(_otherLastReadAt!) ||
            dto.createdAt.isAtSameMomentAs(_otherLastReadAt!);
        if (isRead) deliveryStatus = MessageDeliveryStatus.read;
      }
    }

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
      deliveryStatus: deliveryStatus,
      // Soft-deleted rows stay in the timeline; the bubble renders a subtle
      // "This message was deleted" placeholder instead of the original content.
      isDeleted: dto.deletedAt != null,
    );
  }

  /// Marks the conversation as read for the current user. A lightweight guard
  /// avoids redundant writes when no new unread content has arrived.
  Future<void> _markConversationRead() async {
    if (widget.chatRepository == null) return;
    final latest = _messages.isNotEmpty ? _messages.last.timestamp : null;
    if (latest != null &&
        _lastMarkedReadAt != null &&
        !latest.isAfter(_lastMarkedReadAt!)) {
      return;
    }
    final result = await widget.chatRepository!.updateLastReadAt(
      widget.conversation.id,
    );
    if (result.isSuccess && latest != null) {
      _lastMarkedReadAt = latest;
    }
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
        // Chat P4: fetch the other participant's read position BEFORE mapping
        // so we can derive per-message delivery statuses (sent vs read).
        DateTime? otherLastReadAt;
        if (messagesResult.isSuccess && widget.chatRepository != null) {
          final otherReadResult =
              await widget.chatRepository!.loadOtherMemberLastReadAt(
            widget.conversation.id,
          );
          if (otherReadResult.isSuccess) {
            otherLastReadAt = otherReadResult.value;
          }
        }

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

        _otherLastReadAt = otherLastReadAt;
        final dtoMessages = messagesResult.value!;
        final mapped = <Message>[
          for (final dto in dtoMessages)
            _mapDtoToMessage(dto),
        ];

        // Track the latest message timestamp we just marked read so we don't
        // hammer Supabase with identical writes on every rebuild.
        if (mapped.isNotEmpty) {
          _lastMarkedReadAt = mapped.last.timestamp;
        }
        // These ids were present on first load — render them statically so the
        // entrance animation only plays for messages that arrive afterwards.
        _initialMessageIds = {for (final m in mapped) m.id};

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
        _initialMessageIds = {for (final m in messages) m.id};
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

    // Sending implies we're no longer typing — clear the indicator immediately.
    _stopTyping();

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

  /// Long-press → compact action sheet → confirmation → soft delete.
  ///
  /// Ownership is gated three ways: only the sender's own, non-deleted bubbles
  /// receive the long-press gesture (call site), this method re-guards, and the
  /// repository + UPDATE RLS both require `sender_id = auth.uid()`. Deletion is
  /// non-optimistic — the message only flips to its deleted state after the
  /// backend confirms — so a failure leaves the original message untouched.
  Future<void> _confirmAndDeleteMessage(Message msg) async {
    if (widget.chatRepository == null) return;
    if (msg.author != MessageAuthor.me || msg.isDeleted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _MessageActionSheet(),
    );
    if (action != 'delete' || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2E),
        title: const Text(
          'Delete message?',
          style: TextStyle(color: Color(0xFFEAEEF9)),
        ),
        content: const Text(
          'This message will be removed from the conversation.',
          style: TextStyle(color: Color(0xFFB9C3DC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D8D),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await widget.chatRepository!.deleteMessage(msg.id);
    if (!mounted) return;

    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to delete message'),
          backgroundColor: const Color(0xFFFF4D8D),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Reflect the deleted state immediately. Realtime delivers the same UPDATE
    // (idempotent replace) and a reload re-derives it from deleted_at, so this
    // just avoids waiting a round-trip for the local view to converge.
    final idx = _messages.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      setState(() {
        _messages = List<Message>.from(_messages);
        _messages[idx] = _messages[idx].copyWith(isDeleted: true);
      });
    }
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
      _openUserProfile(otherId);
      return;
    }

    if (actionId == 'mute') {
      () async {
        final repo = widget.chatRepository;
        if (repo == null) return;
        final result = await repo.muteConversation(widget.conversation.id);
        if (!mounted) return;
        if (result.isSuccess) {
          setState(() => _isMuted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications muted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to mute notifications'),
            ),
          );
        }
      }();
      return;
    }

    if (actionId == 'unmute') {
      () async {
        final repo = widget.chatRepository;
        if (repo == null) return;
        final result = await repo.unmuteConversation(widget.conversation.id);
        if (!mounted) return;
        if (result.isSuccess) {
          setState(() => _isMuted = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications unmuted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to unmute notifications'),
            ),
          );
        }
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

  /// Opens the person's canonical Public Profile (same View Profile logic),
  /// gated by the canonical block relationship. If either user has blocked the
  /// other, the full profile is NOT exposed — a blocked notice is shown and the
  /// local composer state is refreshed to reflect the block.
  Future<void> _openUserProfile(String otherId) async {
    final blockState = await const SafetyRepository().blockStateWith(otherId);
    if (!mounted) return;

    if (blockState.isBlocked) {
      setState(() {
        _blockedByMe = blockState.iBlocked;
        _blockedByThem = blockState.theyBlocked;
        _blockStatusLoaded = true;
      });
      final message = blockState.theyBlocked && !blockState.iBlocked
          ? "You can't view this profile."
          : 'You blocked this user. Go to Safety to unblock the user.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
      return;
    }

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
      // Blocking must immediately halt any outgoing typing broadcast to the
      // now-blocked user (the composer is also replaced by the blocked banner).
      _stopTyping();
      _otherTyping.value = false;
      setState(() {
        _blockedByMe = true;
        _blockStatusLoaded = true;
      });
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
    final canOpenProfile =
        !c.isGroup && (c.otherUserId?.isNotEmpty ?? false);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: ConversationAppBar(
        conversation: c,
        group: _group,
        menuActions: _buildMenuActions(c),
        onMenuSelected: _handleMenuAction,
        onAvatarTap:
            canOpenProfile ? () => _openUserProfile(c.otherUserId!) : null,
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
                  : Column(
                      children: [
                        Expanded(
                          child: _messages.isEmpty
                              ? _EmptyThread(name: c.name)
                              : _MessageList(
                                  messages: _messages,
                                  conversation: c,
                                  group: _group,
                                  initialMessageIds: _initialMessageIds,
                                  onDeleteMessage: widget.chatRepository != null
                                      ? _confirmAndDeleteMessage
                                      : null,
                                ),
                        ),
                        // Ephemeral typing bubble — isolated behind a
                        // ValueListenableBuilder so toggling it rebuilds ONLY
                        // this strip, never the message list.
                        ValueListenableBuilder<bool>(
                          valueListenable: _otherTyping,
                          builder: (context, typing, _) {
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.bottomLeft,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 160),
                                opacity: typing ? 1 : 0,
                                child: typing
                                    ? const TypingBubble()
                                    : const SizedBox(
                                        width: double.infinity,
                                        height: 0,
                                      ),
                              ),
                            );
                          },
                        ),
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: _composerArea(),
                        ),
                      ],
                    ),
    );
  }

  /// The bottom input area. A blocked relationship (either direction) replaces
  /// the composer with a premium banner and never exposes a typable field. The
  /// composer stays disabled until the block relationship is known, so a user
  /// can never type-then-fail during the brief status load.
  Widget _composerArea() {
    // Demo/no-repository conversations keep the original read-only composer.
    if (widget.chatRepository == null) {
      return MessageComposer(
        initialText: _draftText,
        onDraftChanged: _onDraftChanged,
        onSend: null,
      );
    }

    if (_blockedByMe) {
      return const _BlockedComposerBanner(
        title: 'You blocked this user.',
        subtitle: 'Go to Safety to unblock the user.',
      );
    }
    if (_blockedByThem) {
      return const _BlockedComposerBanner(
        title: 'This user has blocked you.',
        subtitle: "You can't send messages to this user.",
      );
    }
    if (!_blockStatusLoaded) {
      return const _DisabledComposerPlaceholder();
    }

    return MessageComposer(
      initialText: _draftText,
      onDraftChanged: _onDraftChanged,
      onChanged: _handleTypingInput,
      onSend: _sendMessage,
      enableStarters: true,
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
        if (_isMuted)
          const ChatMenuAction(
            id: 'unmute',
            label: 'Unmute notifications',
            icon: 0xe7f6,
          )
        else
          const ChatMenuAction(
            id: 'mute',
            label: 'Mute notifications',
            icon: 0xe7f5,
          ),
      ];
    }

    return [
      const ChatMenuAction(
        id: 'view_profile',
        label: 'View Profile',
        icon: 0xe491,
      ),
      if (_isMuted)
        const ChatMenuAction(
          id: 'unmute',
          label: 'Unmute notifications',
          icon: 0xe7f6,
        )
      else
        const ChatMenuAction(
          id: 'mute',
          label: 'Mute notifications',
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
    required this.initialMessageIds,
    this.onDeleteMessage,
  });

  final List<Message> messages;
  final ConversationPreview conversation;
  final GroupMetadata? group;

  /// Message ids present on the initial load. These render statically; only
  /// messages NOT in this set (arrived afterwards) get the entrance animation.
  final Set<String> initialMessageIds;

  /// Invoked when the user long-presses one of their own (non-deleted)
  /// messages. Null in demo/no-repository mode, which disables deletion.
  final Future<void> Function(Message)? onDeleteMessage;

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
        // Animate only messages that arrived after the initial load. Keyed by
        // id, so the entrance plays exactly once when the message first mounts.
        final animate = !initialMessageIds.contains(msg.id);

        return RepaintBoundary(
          key: key,
          child: MessageEntrance(
            animate: animate,
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
        // Only the current user's own, non-deleted messages are deletable.
        final canDelete = onDeleteMessage != null &&
            msg.author == MessageAuthor.me &&
            !msg.isDeleted;
        return MessageBubble(
          message: msg,
          showSenderName: showSenderNames && msg.author == MessageAuthor.them,
          onLongPress: canDelete ? () => onDeleteMessage!(msg) : null,
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

class _BlockedComposerBanner extends StatelessWidget {
  const _BlockedComposerBanner({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFE36D9D).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE36D9D).withValues(alpha: .30)),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE36D9D).withValues(alpha: .16),
              ),
              child: const Icon(
                Icons.block_rounded,
                size: 20,
                color: Color(0xFFE36D9D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEAEEF9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB9C3DC),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-interactive composer look-alike shown only briefly while the block
/// relationship is still resolving, so the user never types-then-fails.
class _DisabledComposerPlaceholder extends StatelessWidget {
  const _DisabledComposerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Opacity(
        opacity: .5,
        child: IgnorePointer(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .04),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9DB2E8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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

/// A compact premium action surface shown on long-press of an own message.
///
/// Deliberately minimal — a single destructive "Delete message" action plus a
/// Cancel — styled to match the app's glass dialogs/sheets rather than a
/// generic Material menu. Returns 'delete' via [Navigator.pop] when chosen.
class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete message',
              isDestructive: true,
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            _SheetAction(
              icon: Icons.close_rounded,
              label: 'Cancel',
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? const Color(0xFFFF6B6B) : const Color(0xFFEAEEF9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
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
