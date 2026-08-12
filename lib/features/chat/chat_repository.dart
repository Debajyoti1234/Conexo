import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
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
          .update({'last_read_at': DateTime.now().toIso8601String()})
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

      final lastReadAt = membership != null
          ? DateTime.parse(membership['last_read_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final count = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .gt('created_at', lastReadAt.toIso8601String())
          .isFilter('deleted_at', null);

      return ChatResult.success(count.length);
    } on AuthException catch (e) {
      return ChatResult.failure(e.message);
    } catch (e) {
      return ChatResult.failure('Failed to load unread count');
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
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations
        .where((c) => c.type == ConversationType.group)
        .toList();
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
