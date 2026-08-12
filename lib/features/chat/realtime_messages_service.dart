import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_dtos.dart';

class RealtimeMessagesService {
  RealtimeMessagesService._();
  static final RealtimeMessagesService instance = RealtimeMessagesService._();

  RealtimeChannel? _channel;
  final _controller = StreamController<ChatMessageEvent>.broadcast();
  int _listenerCount = 0;
  String? _lastConversationId;

  Stream<ChatMessageEvent> get onMessageChanged => _controller.stream;

  void start(String conversationId) {
    _listenerCount++;
    if (_channel != null) {
      if (conversationId == _lastConversationId) return;
      stop();
    }
    _lastConversationId = conversationId;
    _channel = Supabase.instance.client.channel('messages-realtime-$conversationId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (payload.newRecord.isEmpty) return;
        final eventType = _mapEventType(payload.eventType);
        final message = ChatMessage.fromJson(payload.newRecord);
        _controller.add(ChatMessageEvent(
          messageId: message.id,
          type: eventType,
          message: message,
        ));
      },
    ).subscribe();
  }

  void stop() {
    _listenerCount--;
    if (_listenerCount <= 0) {
      _listenerCount = 0;
      if (_channel != null) {
        Supabase.instance.client.removeChannel(_channel!);
        _channel = null;
        _lastConversationId = null;
      }
    }
  }

  void dispose() {
    _controller.close();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _listenerCount = 0;
    _lastConversationId = null;
  }

  ChatEventType _mapEventType(PostgresChangeEvent eventType) {
    switch (eventType) {
      case PostgresChangeEvent.insert:
        return ChatEventType.inserted;
      case PostgresChangeEvent.update:
        return ChatEventType.updated;
      case PostgresChangeEvent.delete:
        return ChatEventType.deleted;
      default:
        return ChatEventType.inserted;
    }
  }
}
