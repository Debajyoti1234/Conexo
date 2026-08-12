import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'connection_data.dart';

class ConnectionRepository {
  const ConnectionRepository();

  Future<ConnectionResult<Connection>> sendRequest(String recipientId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      if (user.id == recipientId) {
        return const ConnectionResult.failure('Cannot connect with yourself');
      }

      final now = DateTime.now().toIso8601String();
      final data = await Supabase.instance.client
          .from('connections')
          .insert({
            'requester_id': user.id,
            'recipient_id': recipientId,
            'status': 'pending',
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      return ConnectionResult.success(Connection.fromJson(data));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const ConnectionResult.failure('A connection already exists');
      }
      return ConnectionResult.failure(e.message);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<void>> acceptRequest(String connectionId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client
          .from('connections')
          .update({
            'status': 'accepted',
            'updated_at': now,
          })
          .eq('id', connectionId)
          .eq('recipient_id', user.id)
          .eq('status', 'pending');

      return const ConnectionResult.success(null);
    } on PostgrestException catch (e) {
      return ConnectionResult.failure(e.message);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<void>> rejectRequest(String connectionId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client
          .from('connections')
          .update({
            'status': 'rejected',
            'updated_at': now,
          })
          .eq('id', connectionId)
          .eq('recipient_id', user.id)
          .eq('status', 'pending');

      return const ConnectionResult.success(null);
    } on PostgrestException catch (e) {
      return ConnectionResult.failure(e.message);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<void>> cancelRequest(String connectionId) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client
          .from('connections')
          .update({
            'status': 'cancelled',
            'updated_at': now,
          })
          .eq('id', connectionId)
          .eq('requester_id', user.id)
          .eq('status', 'pending');

      return const ConnectionResult.success(null);
    } on PostgrestException catch (e) {
      return ConnectionResult.failure(e.message);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<Connection?>> getConnectionBetween(
      String userId1, String userId2) async {
    try {
      final data = await Supabase.instance.client
          .from('connections')
          .select()
          .or('and(requester_id.eq.$userId1,recipient_id.eq.$userId2),and(requester_id.eq.$userId2,recipient_id.eq.$userId1)')
          .inFilter('status', ['pending', 'accepted'])
          .maybeSingle();

      if (data == null) return const ConnectionResult.success(null);
      return ConnectionResult.success(Connection.fromJson(data));
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<List<Connection>>> getMyConnections() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final data = await Supabase.instance.client
          .from('connections')
          .select()
          .or('requester_id.eq.${user.id},recipient_id.eq.${user.id}')
          .inFilter('status', ['pending', 'accepted'])
          .order('updated_at', ascending: false);

      final connections = data
          .map((json) => Connection.fromJson(json))
          .toList();
      return ConnectionResult.success(connections);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<List<Connection>>> getIncomingRequests() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final data = await Supabase.instance.client
          .from('connections')
          .select()
          .eq('recipient_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final connections = data
          .map((json) => Connection.fromJson(json))
          .toList();
      return ConnectionResult.success(connections);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }

  Future<ConnectionResult<List<Connection>>> getOutgoingRequests() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return const ConnectionResult.failure('You must be signed in');
      }

      final data = await Supabase.instance.client
          .from('connections')
          .select()
          .eq('requester_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final connections = data
          .map((json) => Connection.fromJson(json))
          .toList();
      return ConnectionResult.success(connections);
    } catch (e) {
      return ConnectionResult.failure('Network error. Please try again.');
    }
  }
}
