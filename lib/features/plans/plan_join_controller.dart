import 'package:flutter/foundation.dart';

import 'plan_details_data.dart';

/// A tiny, Plans-only controller for the local join state machine.
///
/// It owns the current [JoinStatus] and exposes intent methods. Today it just
/// updates local state; later it becomes the single swap point for
/// Firebase / API / offline sync WITHOUT any UI refactoring. Keeping this out
/// of the widget layer means only listeners (the sticky action bar) rebuild
/// when status changes — the rest of the details page stays static.
class PlanJoinController extends ChangeNotifier {
  PlanJoinController({JoinStatus initial = JoinStatus.notJoined})
      : _status = initial;

  JoinStatus _status;
  JoinStatus get status => _status;

  bool get isJoined => _status == JoinStatus.joined;
  bool get isRequested => _status == JoinStatus.requested;

  void _set(JoinStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  /// Public plans: join immediately.
  void join() => _set(JoinStatus.joined);

  /// Private plans: send a join request (pending approval, demo only).
  void request() => _set(JoinStatus.requested);

  /// Leave / withdraw. Surfaced later; the enum + method exist now so no
  /// future model change is needed.
  void cancel() => _set(JoinStatus.notJoined);
}
