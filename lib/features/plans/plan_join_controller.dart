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
  bool _loading = false;
  bool get isLoading => _loading;

  void _set(JoinStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> loadMembership(String planId) async {
    if (_status == JoinStatus.hosting) return;
    try {
      final membership = await _repository.getMyMembership(planId);
      if (membership == null) {
        _set(JoinStatus.notJoined);
      } else {
        switch (membership.status) {
          case 'pending':
            _set(JoinStatus.requested);
          case 'joined':
            _set(JoinStatus.joined);
          default:
            _set(JoinStatus.notJoined);
        }
      }
    } catch (_) {
      // Keep existing state on error.
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
