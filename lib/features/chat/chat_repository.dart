import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../profile/profile_photo_resolver.dart';
import 'chat_dtos.dart';
import 'chat_models.dart';
import 'demo_chat_data.dart';
import 'message_models.dart';

class ChatResult<T> {
  const ChatResult._(this._value, this._error);

  const ChatResult.success(T value) : this._(value, null);
  const ChatResult.failure(String error) : this._(null, error);

  final T? _value;
  final String? _error;

  T? get value => _value;
  String? get error => _error;
  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

class ChatRepository {
  const ChatRepository();

  static final Map<String, bool> _pendingLikes = <String, bool>{};

  Future<ChatResult<String>> getOrCreateConnectionConversation(
    String connectionId,
  ) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'get_or_create_connection_conversation',
        params: {'p_connection_id': connectionId},
      );

      final conversationId = result as String;
      return ChatResult.success(conversationId);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to open conversation');
    }
  }

  Future<ChatResult<void>> toggleLike(String messageId) async {
    if (_pendingLikes[messageId] == true) {
      return const ChatResult.success(null);
    }
    _pendingLikes[messageId] = true;
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatResult.failure('Not authenticated');
      }

      final existing = await Supabase.instance.client
          .from('message_likes')
          .select('message_id')
          .eq('message_id', messageId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        await Supabase.instance.client
            .from('message_likes')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client
            .from('message_likes')
            .insert({'message_id': messageId, 'user_id': user.id});
      }

      return const ChatResult.success(null);
    } on AuthException catch (e) {
      debugPrint('toggleLike AuthException: ${e.message}');
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint('toggleLike FAILED: messageId=$messageId user=${AuthService.currentUser?.id} error=${e.runtimeType}: $e');
      if (e is PostgrestException) {
        debugPrint('  code=${e.code} details=${e.details} hint=${e.hint}');
      }
      return const ChatResult.failure('Failed to update like');
    } finally {
      _pendingLikes.remove(messageId);
    }
  }

  Future<ChatResult<List<ChatMessage>>> loadMessages(
    String conversationId,
  ) async {
    try {
      // Soft-deleted messages are intentionally NOT filtered out here: they
      // must remain in the timeline so conversation ordering/history is
      // preserved. The UI renders them as "This message was deleted" using the
      // row's deleted_at. (Unread counts + inbox previews still exclude deleted
      // rows in their own queries below.)
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final messages = <ChatMessage>[];
      for (final row in response) {
        messages.add(ChatMessage.fromJson(row));
      }
      return ChatResult.success(messages);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint(
        'loadMessages FAILED: conversationId=$conversationId '
        'error=${e.runtimeType}: $e',
      );
      if (e is PostgrestException) {
        debugPrint(
          '  code=${e.code} details=${e.details} hint=${e.hint}',
        );
      }
      return ChatResult.failure('Failed to load messages');
    }
  }

  /// Soft-deletes a single message the current user authored by stamping
  /// `deleted_at`. This NEVER physically deletes the row, so conversation
  /// ordering, history, unread bookkeeping, and realtime all stay intact.
  ///
  /// Ownership is enforced twice: the `sender_id` predicate here AND the
  /// canonical "Senders can update own messages" UPDATE RLS policy
  /// (`auth.uid() = sender_id`). A caller can therefore only ever delete their
  /// own message; an attempt on someone else's message affects zero rows.
  ///
  /// Returns success when the row was stamped. An empty result means the
  /// message no longer exists or is not owned by the caller; when it was
  /// already deleted (e.g. a concurrent realtime update won the race) this
  /// still returns success because the desired end state is achieved.
  Future<ChatResult<void>> deleteMessage(String messageId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatResult.failure('Not authenticated');
      }

      final rows = await Supabase.instance.client
          .from('messages')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', messageId)
          .eq('sender_id', user.id)
          .select('id, deleted_at');

      if (rows.isEmpty) {
        // Either not ours / missing, or it was already deleted by a concurrent
        // update. Re-check the current state so an already-deleted own message
        // is treated as a success rather than a spurious failure.
        final existing = await Supabase.instance.client
            .from('messages')
            .select('deleted_at')
            .eq('id', messageId)
            .maybeSingle();
        final alreadyDeleted =
            existing != null && existing['deleted_at'] != null;
        if (alreadyDeleted) {
          return const ChatResult.success(null);
        }
        return const ChatResult.failure('Message no longer available');
      }

      return const ChatResult.success(null);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } on PostgrestException catch (e) {
      debugPrint('deleteMessage FAILED: code=${e.code} message=${e.message}');
      return const ChatResult.failure('Failed to delete message');
    } catch (e) {
      debugPrint('deleteMessage FAILED: ${e.runtimeType}: $e');
      return const ChatResult.failure('Failed to delete message');
    }
  }

  Future<ChatResult<ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      final response = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': user.id,
            'type': 'text',
            'content': content,
          })
          .select()
          .single();

      final message = ChatMessage.fromJson(response);
      return ChatResult.success(message);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to send message');
    }
  }

  Future<ChatResult<void>> updateLastReadAt(String conversationId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      await Supabase.instance.client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);

      return const ChatResult.success(null);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint('updateLastReadAt FAILED: ${e.runtimeType}: $e');
      return const ChatResult.failure('Failed to update read state');
    }
  }

  /// Returns the other participant's `last_read_at` for read-receipt derivation.
  /// For 1:1 chats this is exactly one row; for groups it returns the most
  /// recent co-member marker, or null when none is available.
  Future<ChatResult<DateTime?>> loadOtherMemberLastReadAt(
    String conversationId,
  ) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatResult.failure('Not authenticated');
      }

      final rows = await Supabase.instance.client
          .from('conversation_members')
          .select('user_id, last_read_at')
          .eq('conversation_id', conversationId)
          .neq('user_id', user.id)
          .limit(2);

      if (rows.isEmpty) return const ChatResult.success(null);

      DateTime? latest;
      for (final row in rows) {
        final raw = row['last_read_at'] as String?;
        if (raw == null || raw.isEmpty) continue;
        final parsed = DateTime.parse(raw);
        if (latest == null || parsed.isAfter(latest)) latest = parsed;
      }
      return ChatResult.success(latest);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint(
        'loadOtherMemberLastReadAt FAILED: ${e.runtimeType}: $e',
      );
      return const ChatResult.success(null);
    }
  }

  /// Mutes this conversation for the current user only. Persists a row in
  /// `conversation_mutes` (canonical per-user, per-conversation mute table) so
  /// the state survives reopen/restart. Never affects the other participant.
  Future<ChatResult<void>> muteConversation(String conversationId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      // Upsert so a repeated mute is idempotent (unique on
      // conversation_id + user_id).
      await Supabase.instance.client.from('conversation_mutes').upsert(
        {
          'conversation_id': conversationId,
          'user_id': user.id,
          'muted_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'conversation_id,user_id',
      );

      return const ChatResult.success(null);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to mute conversation');
    }
  }

  /// Unmutes this conversation for the current user only by removing the
  /// `conversation_mutes` row for (conversation, current user).
  Future<ChatResult<void>> unmuteConversation(String conversationId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      await Supabase.instance.client
          .from('conversation_mutes')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);

      return const ChatResult.success(null);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to unmute conversation');
    }
  }

  /// Returns whether the current user has muted this conversation, based on the
  /// presence of a `conversation_mutes` row for (conversation, current user).
  Future<ChatResult<bool>> isConversationMuted(String conversationId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ChatResult.success(false);
      }

      final mute = await Supabase.instance.client
          .from('conversation_mutes')
          .select('muted_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id)
          .maybeSingle();

      final mutedAt = mute?['muted_at'] as String?;
      return ChatResult.success(mutedAt != null && mutedAt.isNotEmpty);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return const ChatResult.success(false);
    }
  }

  /// Resolves the other participant's user id for a 1:1 connection, using the
  /// canonical `connections` row (requester/recipient). Used by entry points
  /// that only hold a connectionId (e.g. notification taps) so the opened
  /// conversation carries a real `otherUserId` for profile/block/report.
  Future<ChatResult<String>> resolveConnectionOtherUserId(
    String connectionId,
  ) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      final row = await Supabase.instance.client
          .from('connections')
          .select('requester_id, recipient_id')
          .eq('id', connectionId)
          .maybeSingle();

      if (row == null) {
        return const ChatResult.failure('Connection not found');
      }

      final requesterId = row['requester_id'] as String?;
      final recipientId = row['recipient_id'] as String?;
      final otherId = requesterId == user.id ? recipientId : requesterId;
      if (otherId == null || otherId.isEmpty) {
        return const ChatResult.failure('Could not resolve user');
      }
      return ChatResult.success(otherId);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return const ChatResult.failure('Could not resolve user');
    }
  }

  Future<ChatResult<int>> loadUnreadCount(String conversationId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return ChatResult.failure('Not authenticated');
      }

      final membership = await Supabase.instance.client
          .from('conversation_members')
          .select('last_read_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id)
          .maybeSingle();

      final rawLastRead = membership?['last_read_at'] as String?;
      final lastReadAt = rawLastRead != null
          ? DateTime.parse(rawLastRead)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final count = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .neq('sender_id', user.id)
          .gt('created_at', lastReadAt.toIso8601String())
          .isFilter('deleted_at', null);

      return ChatResult.success(count.length);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to load unread count');
    }
  }

  Future<ChatResult<Map<String, dynamic>?>> getLatestMessagePreview(
    String conversationId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('content, created_at, sender_id')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return const ChatResult.success(null);
      }

      return ChatResult.success(response.first);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to load latest message');
    }
  }

  // ── Plan group chat ───────────────────────────────────────────────────
  // These mirror the connection-chat methods above but operate on the single
  // per-plan conversation (conversations.type = 'plan'). Creation and member
  // seeding happen exclusively inside the SECURITY DEFINER RPC
  // get_or_create_plan_conversation, which authorizes creator-or-joined before
  // creating anything. Reads are gated by conversation_members RLS.

  /// Finds or lazily creates the single group conversation for [planId] and
  /// returns its id. The server rejects callers who are not the creator or a
  /// currently joined member.
  Future<ChatResult<String>> getOrCreatePlanConversation(String planId) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'get_or_create_plan_conversation',
        params: {'p_plan_id': planId},
      );
      final conversationId = result as String;
      return ChatResult.success(conversationId);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final code = e.code?.toUpperCase() ?? '';
      if (message.contains('not authorized')) {
        return const ChatResult.failure(
          "You are not a member of this plan's group chat.",
        );
      }
      if (message.contains('not authenticated')) {
        return const ChatResult.failure('Please sign in to open the group chat.');
      }
      if (message.contains('plan not found')) {
        return const ChatResult.failure('This plan is no longer available.');
      }
      if (message.contains('chat temporarily revoked by host')) {
        return const ChatResult.failure('Chat temporarily revoked by host');
      }
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('schema cache')) {
        return const ChatResult.failure(
          'Plan chat is unavailable. Apply the latest database migrations, then retry.',
        );
      }
      return const ChatResult.failure('Failed to open plan chat');
    } catch (e) {
      return const ChatResult.failure('Failed to open plan chat');
    }
  }

  /// Returns the existing plan conversation for [planId], or null when the
  /// current user has no chat access (RLS filters non-members) or none exists.
  Future<ChatResult<ChatConversation?>> findConversationForPlan(
    String planId,
  ) async {
    try {
      final row = await Supabase.instance.client
          .from('conversations')
          .select('id, type, plan_id, created_at, updated_at')
          .eq('plan_id', planId)
          .eq('type', 'plan')
          .maybeSingle();

      if (row == null) return const ChatResult.success(null);
      return ChatResult.success(ChatConversation.fromJson(row));
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return const ChatResult.failure('Failed to find plan chat');
    }
  }

  /// Loads every plan conversation the current user can access. RLS on
  /// `conversations` restricts the result to conversations the user is a
  /// `conversation_members` row of, i.e. creator + joined participants only.
  Future<ChatResult<List<PlanConversationSummary>>>
      loadPlanConversations() async {
    try {
      final rows = await Supabase.instance.client
          .from('conversations')
          .select('id, plan_id, plans(title, cover_url)')
          .eq('type', 'plan');

      final summaries = <PlanConversationSummary>[];
      for (final row in rows) {
        final planId = row['plan_id'] as String?;
        if (planId == null) continue;
        final plan = row['plans'] as Map<String, dynamic>?;
        final rawTitle = (plan?['title'] as String?)?.trim();
        summaries.add(
          PlanConversationSummary(
            conversationId: row['id'] as String,
            planId: planId,
            title: (rawTitle == null || rawTitle.isEmpty) ? 'Plan chat' : rawTitle,
            coverPath: plan?['cover_url'] as String?,
          ),
        );
      }
      return ChatResult.success(summaries);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint('loadPlanConversations FAILED: ${e.runtimeType}: $e');
      return const ChatResult.failure('Failed to load plan chats');
    }
  }

  /// Builds real group metadata (title, host, joined participants with real
  /// names + signed avatars) for a plan conversation. Reuses the canonical
  /// profile-photo signing pipeline. Returns null when the conversation is not
  /// a plan conversation or is inaccessible.
  Future<ChatResult<GroupMetadata?>> loadGroupMetadata(
    String conversationId,
  ) async {
    try {
      final client = Supabase.instance.client;

      final conv = await client
          .from('conversations')
          .select('id, plan_id, type')
          .eq('id', conversationId)
          .maybeSingle();
      if (conv == null) return const ChatResult.success(null);
      final planId = conv['plan_id'] as String?;
      if (planId == null) return const ChatResult.success(null);

      final plan = await client
          .from('plans')
          .select('id, title, creator_id')
          .eq('id', planId)
          .maybeSingle();
      if (plan == null) return const ChatResult.success(null);

      final rawTitle = (plan['title'] as String?)?.trim();
      final title =
          (rawTitle == null || rawTitle.isEmpty) ? 'Plan chat' : rawTitle;
      final creatorId = plan['creator_id'] as String? ?? '';

      final members = await client
          .from('plan_members')
          .select('user_id, role, status')
          .eq('plan_id', planId)
          .eq('status', 'joined');

      final userIds = <String>[
        for (final m in members)
          if (m['user_id'] is String) m['user_id'] as String,
      ];

      final nameById = <String, String>{};
      final rawPhotoByUser = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await client
            .from('profiles')
            .select('id, display_name, photos')
            .inFilter('id', userIds);
        for (final p in profiles) {
          final id = p['id'] as String?;
          if (id == null) continue;
          final name = (p['display_name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) nameById[id] = name;
          final photos = p['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final primary = photos.firstWhere(
              (x) => x is Map && x['isPrimary'] == true,
              orElse: () => photos.first,
            );
            if (primary is Map) {
              final remote = (primary['remoteUrl'] as String?)?.trim();
              if (remote != null && remote.isNotEmpty) {
                rawPhotoByUser[id] = remote;
              }
            }
          }
        }
      }

      final signedByUser = <String, String>{};
      final resolver = ProfilePhotoResolver.instance;
      final toSignUsers = <String>[];
      final toSignPaths = <String>[];
      rawPhotoByUser.forEach((uid, value) {
        if (value.startsWith('http://') || value.startsWith('https://')) {
          signedByUser[uid] = value;
        } else if (value.startsWith('profiles/')) {
          toSignUsers.add(uid);
          toSignPaths.add(value);
        }
      });
      if (toSignPaths.isNotEmpty) {
        final futures = toSignPaths.map((p) => resolver.resolvePhoto(p));
        final signedResults = await Future.wait(futures);
        for (var i = 0; i < toSignUsers.length; i++) {
          final url = signedResults[i].signedUrl;
          if (url.isNotEmpty) {
            signedByUser[toSignUsers[i]] = url;
          }
        }
      }

      String fallbackName(String uid) =>
          'User ${uid.substring(0, uid.length >= 8 ? 8 : uid.length)}';

      final participants = <Participant>[
        for (final uid in userIds)
          Participant(
            id: uid,
            name: nameById[uid] ?? fallbackName(uid),
            avatarAsset: signedByUser[uid] ?? '',
            isHost: uid == creatorId,
          ),
      ];

      return ChatResult.success(
        GroupMetadata(
          conversationId: conversationId,
          title: title,
          hostId: creatorId,
          participants: participants,
        ),
      );
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      debugPrint('loadGroupMetadata FAILED: ${e.runtimeType}: $e');
      return const ChatResult.failure('Failed to load group details');
    }
  }

  Future<ChatResult<Map<String, List<String>>>> loadLikesForConversation(
    String conversationId,
  ) async {
    try {
      final messageIds = await _messageIdsInConversation(conversationId);
      if (messageIds.isEmpty) {
        return const ChatResult.success(<String, List<String>>{});
      }

      final rows = await Supabase.instance.client
          .from('message_likes')
          .select('message_id, user_id')
          .inFilter('message_id', messageIds);

      final likes = <String, List<String>>{};
      for (final row in rows) {
        final messageId = row['message_id'] as String;
        final userId = row['user_id'] as String;
        likes.putIfAbsent(messageId, () => <String>[]).add(userId);
      }
      return ChatResult.success(likes);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to load likes');
    }
  }

  Future<void> ensureLikesSubscription(
    String conversationId,
    void Function(Map<String, List<String>> likes) onLikesUpdated,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    disposeLikesSubscription(conversationId);

    final channel = Supabase.instance.client.channel('likes:$conversationId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_likes',
          callback: (payload) {
            try {
              final record = payload.eventType == PostgresChangeEvent.delete
                  ? payload.oldRecord
                  : payload.newRecord;
              if (record.isEmpty) return;
              final messageId = record['message_id'] as String;
              final changedUserId = record['user_id'] as String;
              final likes = Map<String, List<String>>.from(
                _likesCacheByConversation.putIfAbsent(
                  conversationId,
                  () => <String, List<String>>{},
                ),
              );
              final list = likes.putIfAbsent(messageId, () => <String>[]);
              if (payload.eventType == PostgresChangeEvent.delete) {
                list.remove(changedUserId);
                if (list.isEmpty) likes.remove(messageId);
              } else {
                if (!list.contains(changedUserId)) {
                  list.add(changedUserId);
                }
              }
              _likesCacheByConversation[conversationId] = likes;
              onLikesUpdated(likes);
            } catch (e) {
              debugPrint('Likes realtime error: $e');
            }
          },
        )
        .subscribe();

    _likesSubscriptions[conversationId] = channel;
  }

  void disposeLikesSubscription(String conversationId) {
    final channel = _likesSubscriptions.remove(conversationId);
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _likesCacheByConversation.remove(conversationId);
  }

  Future<List<String>> _messageIdsInConversation(
    String conversationId,
  ) async {
    final rows = await Supabase.instance.client
        .from('messages')
        .select('id')
        .eq('conversation_id', conversationId);
    return rows.map((row) => row['id'] as String).toList();
  }
}

class LocalChatRepository {
  const LocalChatRepository();

  Future<List<ConversationPreview>> loadConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations;
  }

  Future<List<ConversationPreview>> loadConnectionConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations
        .where((c) => c.type == ConversationType.private)
        .toList();
  }

  Future<List<ConversationPreview>> loadPlanConversations() async {
    // P1.2B.9: Plan chats are backed by the real ChatRepository. The local
    // repository intentionally surfaces NO demo plan conversations in
    // production flows.
    return const <ConversationPreview>[];
  }

  Future<List<Message>> loadMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return demoMessageThreads[conversationId] ?? const <Message>[];
  }

  Future<GroupMetadata?> loadGroupMetadata(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return demoGroupMetadata[conversationId];
  }

  ConversationPreview? findConversationForConnection(String connectionId) {
    const idMap = <String, String>{
      'network_002': 'c2',
    };
    final conversationId = idMap[connectionId];
    if (conversationId == null) return null;
    try {
      return demoConversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      return null;
    }
  }

  ConversationPreview? findConversationForPlan(String planId) {
    return null;
  }
}

final Map<String, Map<String, List<String>>> _likesCacheByConversation =
    <String, Map<String, List<String>>>{};
final Map<String, RealtimeChannel> _likesSubscriptions =
    <String, RealtimeChannel>{};
