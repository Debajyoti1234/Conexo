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

  Future<ChatResult<List<ChatMessage>>> loadMessages(
    String conversationId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
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
      return ChatResult.failure('Failed to update read state');
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
