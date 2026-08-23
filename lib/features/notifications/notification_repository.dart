import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'notification_models.dart';

class NotificationRepository {
  const NotificationRepository();

  static const _table = 'notifications';

  Future<List<AppNotification>> loadNotifications() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    try {
      final data = await Supabase.instance.client
          .from(_table)
          .select('id, user_id, actor_id, kind, title, body, entity_id, entity_type, read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      final notifications = <AppNotification>[];
      for (final row in data) {
        try {
          notifications.add(AppNotification.fromSupabase(row));
        } catch (_) {
          // skip malformed rows
        }
      }
      return notifications;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from(_table)
          .update({'read': true})
          .eq('id', notificationId)
          .eq('user_id', user.id);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  Future<void> markAllRead() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from(_table)
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthException(error.message));
    } on PostgrestException catch (error) {
      throw AuthFailure(_mapPostgrestException(error));
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  Future<int> getUnreadCount() async {
    final user = AuthService.currentUser;
    if (user == null) return 0;

    try {
      final data = await Supabase.instance.client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .eq('read', false);

      return data.length;
    } on AuthException catch (_) {
      return 0;
    } on PostgrestException catch (_) {
      return 0;
    } catch (_) {
      return 0;
    }
  }

  String _mapAuthException(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Network error. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _mapPostgrestException(PostgrestException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == '42501' || message.contains('permission') || message.contains('policy') || message.contains('rls')) {
      return 'You don\'t have permission to access notifications.';
    }
    if (message.contains('network') || message.contains('connection') || message.contains('timeout')) {
      return 'Network error. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Stream<List<AppNotification>> watchNotifications() {
    final user = AuthService.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    final controller = StreamController<List<AppNotification>>.broadcast();

    final channel = Supabase.instance.client
        .channel('notifications-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload payload) {
            _loadNotificationsInto(controller);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload payload) {
            _loadNotificationsInto(controller);
          },
        )
        .subscribe();

    controller.onCancel = () {
      Supabase.instance.client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> _loadNotificationsInto(
    StreamController<List<AppNotification>> controller,
  ) async {
    if (controller.isClosed) return;
    try {
      final items = await loadNotifications();
      if (!controller.isClosed) controller.add(items);
    } catch (_) {
      // ignore stream load errors
    }
  }
}
