import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';

class RealtimeConnectionsService {
  RealtimeConnectionsService._();

  static final RealtimeConnectionsService instance =
      RealtimeConnectionsService._();

  RealtimeChannel? _channel;
  final _controller = StreamController<void>.broadcast();
  int _listenerCount = 0;
  String? _lastUserId;

  Stream<void> get onConnectionsChanged => _controller.stream;

  void start() {
    _listenerCount++;
    if (_channel != null) {
      final user = AuthService.currentUser;
      if (user != null && user.id == _lastUserId) {
        return;
      }
      stop();
    }

    final user = AuthService.currentUser;
    if (user == null) {
      _listenerCount--;
      return;
    }
    _lastUserId = user.id;

    _channel = Supabase.instance.client.channel('connections-realtime');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'connections',
      callback: (payload) {
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        String? requesterId;
        String? recipientId;

        if (newRecord.isNotEmpty) {
          requesterId = newRecord['requester_id'] as String?;
          recipientId = newRecord['recipient_id'] as String?;
        } else if (oldRecord.isNotEmpty) {
          requesterId = oldRecord['requester_id'] as String?;
          recipientId = oldRecord['recipient_id'] as String?;
        }

        if (requesterId == user.id || recipientId == user.id) {
          _controller.add(null);
        }
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
        _lastUserId = null;
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
    _lastUserId = null;
  }
}
