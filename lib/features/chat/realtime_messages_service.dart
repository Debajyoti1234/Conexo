import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_dtos.dart';

class RealtimeMessagesService {
  RealtimeMessagesService._();
  static final RealtimeMessagesService instance = RealtimeMessagesService._();

  RealtimeChannel? _channel;
  RealtimeChannel? _globalChannel;
  final _controller = StreamController<ChatMessageEvent>.broadcast();
  final _globalController = StreamController<ChatMessageEvent>.broadcast();
  int _listenerCount = 0;
  int _globalListenerCount = 0;
  String? _lastConversationId;

  Stream<ChatMessageEvent> get onMessageChanged => _controller.stream;
  Stream<ChatMessageEvent> get onGlobalMessageChanged => _globalController.stream;

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
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
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

  void startGlobal() {
    _globalListenerCount++;
    if (_globalChannel != null) return;
    _globalChannel = Supabase.instance.client.channel('messages-realtime-global');
    _globalChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (payload.newRecord.isEmpty) return;
        final eventType = _mapEventType(payload.eventType);
        final message = ChatMessage.fromJson(payload.newRecord);
        _globalController.add(ChatMessageEvent(
          messageId: message.id,
          type: eventType,
          message: message,
        ));
      },
    ).subscribe();
  }

  void stopGlobal() {
    _globalListenerCount--;
    if (_globalListenerCount <= 0) {
      _globalListenerCount = 0;
      if (_globalChannel != null) {
        Supabase.instance.client.removeChannel(_globalChannel!);
        _globalChannel = null;
      }
    }
  }

  void dispose() {
    _controller.close();
    _globalController.close();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    if (_globalChannel != null) {
      Supabase.instance.client.removeChannel(_globalChannel!);
      _globalChannel = null;
    }
    _listenerCount = 0;
    _lastConversationId = null;
    _globalListenerCount = 0;
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
