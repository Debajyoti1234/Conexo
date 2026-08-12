# Phase 9.2 — Live Location Tracking: Implementation Plan

Status: READY FOR IMPLEMENTATION. No unanswered design questions.

---

## 1. ARCHITECTURAL CONTEXT (verified from codebase)

| Concern | Current State |
|---------|--------------|
| Auth access | `AuthService.currentUser` (static getter), `AuthService.authStateChanges` (stream) |
| Sign-out | `AuthService.signOut()` → emits `AuthChangeEvent.signedOut` → `ConexoApp` listener pushes `LoginScreen` |
| App lifecycle | **None** — no `WidgetsBindingObserver`, no `didChangeAppLifecycleState` anywhere |
| Periodic timers | **None** — all existing `Timer` usages are one-shot UI debounces (220ms–3s) |
| Background location | **None** — only `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` on Android; `NSLocationWhenInUseUsageDescription` on iOS |
| Existing location packages | `geolocator`, `geocoding`, `permission_handler` — already installed |
| State management | Static service classes + `StatefulWidget` + `ChangeNotifier`. Riverpod declared but unused. |
| Repository pattern | `ProfileRepository` interface → `SupabaseProfileRepository` / `LocalProfileRepository` / `SessionAwareProfileRepository` |
| Supabase project | Ref `wlfitdzhvfhuqgxwreed`; single `profiles` table; one owner-only RLS policy |
| `main.dart` | `ConexoApp` (StatefulWidget) owns `_authSubscription`; has `_navigatorKey`; no lifecycle observer |

---

## 2. SUPABASE MIGRATION

**File:** `supabase/migrations/20260811000000_create_live_locations_table.sql`

```sql
CREATE TABLE live_locations (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_live_locations_user_id ON live_locations(user_id);

ALTER TABLE live_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own live location"
  ON live_locations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own live location"
  ON live_locations FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated users can read all live locations"
  ON live_locations FOR SELECT
  USING (auth.role() = 'authenticated');
```

**Design decisions:**
- `user_id` is both `PRIMARY KEY` and `REFERENCES auth.users(id) ON DELETE CASCADE` — enforces one-row-per-user and auto-cleanup on auth deletion.
- `latitude`/`longitude` are `NOT NULL` because the tracker only writes after a successful GPS fix.
- `updated_at` uses `DEFAULT now()` — the application does NOT set this manually; Postgres handles it. The tracker can also explicitly set it on upsert if desired.
- **Read policy:** `auth.role() = 'authenticated'` — any logged-in user can read all live locations. This is the minimum required for Phase 9.2 nearby discovery (distance calculations against other users' positions). It is deliberately broader than owner-only; tighten later if discovery requirements change.
- **Insert/Update policies:** Strict owner-only via `auth.uid() = user_id`. A user cannot write another user's row.
- Existing `profiles` RLS is untouched.

---

## 3. LIVE LOCATION MODEL

**File:** `lib/features/profile/live_location_data.dart` (new)

```dart
class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory LiveLocation.fromJson(Map<String, dynamic> json) => LiveLocation(
        userId: json['user_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
      };

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
}
```

---

## 4. LIVE LOCATION REPOSITORY

**File:** `lib/features/profile/live_location_repository.dart` (new)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_location_data.dart';
import '../../core/supabase/auth_service.dart';

class LiveLocationRepository {
  const LiveLocationRepository();

  Future<void> upsert({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    final user = AuthService.currentUser;
    if (user == null || user.id != userId) return;

    await Supabase.instance.client
        .from('live_locations')
        .upsert({
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  Future<List<LiveLocation>> fetchAll() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];

    final data = await Supabase.instance.client
        .from('live_locations')
        .select()
        .order('updated_at', ascending: false);

    return [
      for (final item in data) LiveLocation.fromJson(item as Map<String, dynamic>),
    ];
  }
}
```

**Design decisions:**
- Guards against unauthenticated writes and cross-user writes via `AuthService.currentUser`.
- `upsert` uses `user_id` as the conflict key (it is the PK).
- `fetchAll` returns all live locations for discovery. The read RLS policy filters to authenticated users.
- No interface layer — follows the same concrete-class pattern as `SupabaseProfileRepository`.

---

## 5. LIVE LOCATION TRACKER SERVICE

**File:** `lib/core/services/live_location_tracker.dart` (new)

```dart
import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import 'permission_manager.dart';
import '../features/profile/live_location_repository.dart';

abstract final class LiveLocationTracker {
  static const _interval = Duration(minutes: 30);
  static const _accuracy = LocationAccuracy.high;

  static Timer? _timer;
  static final LiveLocationRepository _repo = const LiveLocationRepository();

  static bool get isRunning => _timer != null && _timer!.isActive;

  static Future<void> start() async {
    if (isRunning) return;

    final granted = await _checkPermission();
    if (!granted) return;

    await _tick(); // immediate first write
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _tick() async {
    if (AuthService.currentUser == null) {
      stop();
      return;
    }

    final position = await _getPosition();
    if (position == null) return;

    await _repo.upsert(
      userId: AuthService.currentUser!.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static Future<bool> _checkPermission() async {
    final status = await PermissionManager.check(
      PermissionType.locationWhenInUse,
    );
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      return true;
    }
    if (status == PermissionStatus.denied) {
      final requested = await PermissionManager.request(
        PermissionType.locationWhenInUse,
      );
      return requested == PermissionStatus.granted ||
          requested == PermissionStatus.limited;
    }
    return false; // permanentlyDenied / restricted — silent fail
  }

  static Future<Position?> _getPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: _accuracy),
      );
    } on Exception {
      return null;
    }
  }
}
```

**Design decisions:**
- Static class pattern — matches `LocationService` and `PermissionManager` in the project.
- Single `Timer.periodic` at 30 minutes — fires only while the app is in the foreground.
- First tick is immediate on `start()` so the user gets a write right away.
- `_checkPermission()` on every `start()` — handles the case where permission was revoked while the app was backgrounded.
- Graceful failure on every path: unauthenticated → stop, permission denied → return without starting, services disabled → return null, GPS failure → return null. Never throws.
- No reverse geocoding — raw coordinates only, as required.
- `isRunning` getter for testing/debugging.
- Reuses `PermissionManager` and `LocationService` patterns — no new permission architecture.
- Reuses `geolocator` — no new GPS package.

---

## 6. APP LIFECYCLE WIRING

**File:** `lib/main.dart` — modify `_ConexoAppState`

**Add lifecycle observation and tracker control:**

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme/app_theme.dart';
import 'core/services/live_location_tracker.dart';
import 'core/supabase/auth_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/login_screen.dart';
import 'features/splash/splash_screen.dart';

class _ConexoAppState extends State<ConexoApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = AuthService.authStateChanges.listen(_onAuthStateChanged);
    if (AuthService.currentUser != null) {
      LiveLocationTracker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    LiveLocationTracker.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthService.currentUser != null) {
      LiveLocationTracker.start();
    } else if (state == AppLifecycleState.paused) {
      LiveLocationTracker.stop();
    }
  }

  void _onAuthStateChanged(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      LiveLocationTracker.stop();
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else if (state.event == AuthChangeEvent.signedIn &&
        AuthService.currentUser != null) {
      LiveLocationTracker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexo',
      theme: AppTheme.darkTheme,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
    );
  }
}
```

**Design decisions:**
- `WidgetsBindingObserver` added to the existing `_ConexoAppState` — minimal footprint, no new widget tree changes.
- `resumed` → `start()` (idempotent — returns immediately if already running). This handles both initial launch and app-resume.
- `paused` → `stop()` to release the timer when backgrounded.
- `signedOut` → `stop()` immediately to halt all writes.
- `signedIn` → `start()` for cases where auth completes after the initial `initState` check.
- `dispose` → `stop()` as a safety net.
- `start()` is idempotent — calling it when already running is a no-op, so calling it on every `resumed` event is safe.

---

## 7. ANDROID PLATFORM CONFIG

**File:** `android/app/src/main/AndroidManifest.xml`

No changes required for Phase 9.2 foreground-only tracking. `ACCESS_FINE_LOCATION` and `ACCESS_COORSE_LOCATION` are already declared.

**Future limitation (documented, not fixed in this phase):** A foreground service notification would be required for continuous background tracking, and `ACCESS_BACKGROUND_LOCATION` would need to be added. This is out of scope for Phase 9.2.

---

## 8. iOS PLATFORM CONFIG

**File:** `ios/Runner/Info.plist`

No changes required. `NSLocationWhenInUseUsageDescription` already exists.

---

## 9. WHAT IS NOT CHANGED

| Item | Status |
|------|--------|
| `UserProfileDraft` / `UserProfile` models | Untouched |
| Profile creation UI (`LocationSection`) | Untouched |
| Profile management UI (`ManageLocationSection`) | Untouched |
| `SupabaseProfileRepository` | Untouched |
| `profile_data.dart` | Untouched |
| `location_service.dart` | Untouched |
| `permission_manager.dart` | Untouched |
| Auth logic (`auth_service.dart`, `auth_gate.dart`) | Untouched |
| Navigation / routing | Untouched |
| Existing RLS policies on `profiles` | Untouched |
| Supabase migrations (other than the new one) | Untouched |

---

## 10. DATA FLOW (end-to-end)

```
App resumed / user signed in
  → LiveLocationTracker.start()
    → checks PermissionManager.locationWhenInUse
      → if denied: requests permission
        → if granted: proceeds
        → if permanently denied: silent fail (no crash)
      → if granted: proceeds
    → Geolocator.getCurrentPosition(high accuracy)
      → if fails: silent fail
      → if succeeds: Position(lat, lng)
    → LiveLocationRepository.upsert(userId, lat, lng)
      → auth guard: AuthService.currentUser must match
      → Supabase: live_locations.upsert({user_id, latitude, longitude, updated_at})
        → RLS: WITH CHECK (auth.uid() = user_id)
    → Timer.periodic(30 min) repeats the above
  ← App paused / user signed out
    → LiveLocationTracker.stop()
      → Timer.cancel()
```

---

## 11. VALIDATION PLAN

| Step | Expected Result |
|------|-----------------|
| `flutter analyze` | No issues |
| `.\tool\run.ps1` on device | App launches, tracker starts silently |
| Auth state: sign in | Tracker starts, first GPS write within seconds |
| Auth state: sign out | Tracker stops, no further writes |
| App: pause (home button) | Tracker stops |
| App: resume | Tracker restarts |
| 30-minute wait (or reduce interval for testing) | Second write with new `updated_at` |
| Supabase `live_locations` table | One row per user, real lat/lng doubles |
| Supabase `live_locations` RLS | User A cannot insert/update User B's row |
| Permission denied | No crash, no write, app continues normally |
| Location services off | No crash, no write, silent fail |
| Profile location fields in `profiles` table | Unchanged by live tracking |

---

## 12. FILES TO CREATE/MODIFY

| File | Action | Purpose |
|------|--------|---------|
| `supabase/migrations/20260811000000_create_live_locations_table.sql` | CREATE | Table + index + RLS |
| `lib/features/profile/live_location_data.dart` | CREATE | `LiveLocation` model |
| `lib/features/profile/live_location_repository.dart` | CREATE | Supabase upsert/read |
| `lib/core/services/live_location_tracker.dart` | CREATE | 30-min periodic GPS + auth guard |
| `lib/main.dart` | MODIFY | Add `WidgetsBindingObserver`, wire tracker to auth + lifecycle |
| `android/app/src/main/AndroidManifest.xml` | NO CHANGE | Already has required foreground permissions |
| `ios/Runner/Info.plist` | NO CHANGE | Already has WhenInUse description |

---

## 13. OPEN QUESTIONS (none — all resolved)

- **Read RLS scope:** All authenticated users can read all live locations. This is the minimum for Phase 9.2 discovery. Can be tightened later.
- **Write frequency:** 30 minutes, foreground-only. Background tracking is out of scope.
- **No reverse geocoding in tracker:** Raw coordinates only. Name resolution stays in the profile location field.
- **Tracker location in app tree:** Owned by `ConexoApp` (root), not any feature screen. Survives navigation.
- **Error handling:** Silent fail everywhere. No user-facing UI for tracking status in this phase.
- **PostGIS readiness:** Schema uses plain `DOUBLE PRECISION`. A future migration can add a PostGIS `geography` column and spatial index without breaking this schema.

---

## 14. IMPLEMENTATION ORDER

1. Supabase migration (table + index + RLS)
2. `live_location_data.dart` (model)
3. `live_location_repository.dart` (Supabase ops)
4. `live_location_tracker.dart` (service)
5. `main.dart` (lifecycle + auth wiring)
6. `flutter analyze`
7. `.\tool\run.ps1` (device test)
8. `.\tool\build_apk.ps1`
