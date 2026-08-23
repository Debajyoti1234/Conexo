import 'package:flutter/foundation.dart';

import '../../core/supabase/auth_service.dart';
import 'plan_details_data.dart';
import 'plan_repository.dart';

class PlanJoinController extends ChangeNotifier {
  PlanJoinController({
    PlanRepository? repository,
    JoinStatus initial = JoinStatus.notJoined,
  })  : _repository = repository ?? const LocalPlanRepository(),
       _status = initial;

  final PlanRepository _repository;
  JoinStatus _status;
  JoinStatus get status => _status;

  bool get isJoined => _status == JoinStatus.joined;
  bool get isRequested => _status == JoinStatus.requested;
  bool get isHosting => _status == JoinStatus.hosting;
  bool get isInvited => _status == JoinStatus.invited;
  bool _loading = false;
  bool get isLoading => _loading;

  /// The id of the current pending invitation, when [status] is
  /// [JoinStatus.invited]. Used by accept/decline.
  String? _inviteId;
  String? get inviteId => _inviteId;

  void _set(JoinStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> loadMembership(String planId) async {
    if (_status == JoinStatus.hosting) return;
    try {
      final membership = await _repository.getMyMembership(planId);
      if (membership != null && membership.status == 'joined') {
        _set(JoinStatus.joined);
        return;
      }
      if (membership != null && membership.status == 'pending') {
        _set(JoinStatus.requested);
        return;
      }

      // No active membership. An invited user has a pending plan_invites row
      // (not a plan_members row), so check invitations before falling back to
      // notJoined. This keeps "invited" distinct from "requested".
      try {
        final invites = await _repository.getPendingInvitations();
        final match = invites.where((i) => i.planId == planId).toList();
        if (match.isNotEmpty) {
          _inviteId = match.first.id;
          _set(JoinStatus.invited);
          return;
        }
      } catch (_) {
        // Ignore invitation lookup failures; fall through to notJoined.
      }

      _set(JoinStatus.notJoined);
    } catch (_) {
      // Keep existing state on error.
    }
  }

  /// Accepts the current pending invitation. The invitation acceptance itself
  /// is the authorization to join — this must NOT send a discovery join
  /// request. On success the user becomes a joined member immediately.
  Future<void> acceptInvitation(String planId) async {
    if (_loading || _inviteId == null) return;
    _loading = true;
    notifyListeners();

    try {
      await _repository.acceptInvitation(_inviteId!);
      _inviteId = null;
      await loadMembership(planId);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Declines the current pending invitation. The user remains outside the plan.
  Future<void> declineInvitation(String planId) async {
    if (_loading || _inviteId == null) return;
    _loading = true;
    notifyListeners();

    try {
      await _repository.declineInvitation(_inviteId!);
      _inviteId = null;
      _set(JoinStatus.notJoined);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> joinOrRequest(String planId) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      await _repository.requestToJoin(planId);
      await loadMembership(planId);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Something went wrong. Please try again.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> approve(String planId, String memberId) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      await _repository.approvePlanMember(planId, memberId);
    } on AuthFailure catch (error) {
      debugPrint('[PlanJoinController] approve AuthFailure planId=$planId memberId=$memberId message=${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('[PlanJoinController] approve error planId=$planId memberId=$memberId error=$error');
      throw const AuthFailure('Something went wrong. Please try again.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> decline(String planId, String memberId) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      await _repository.declinePlanMember(planId, memberId);
    } on AuthFailure catch (error) {
      debugPrint('[PlanJoinController] decline AuthFailure planId=$planId memberId=$memberId message=${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('[PlanJoinController] decline error planId=$planId memberId=$memberId error=$error');
      throw const AuthFailure('Something went wrong. Please try again.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void cancel() => _set(JoinStatus.cancelled);
}
