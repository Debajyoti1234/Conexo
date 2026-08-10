# Phase 8.5 — Real Phone OTP Failure Diagnosis Plan

## Goal

Add temporary diagnostic logging to expose the exact Supabase error returned when a real/new phone number is used with `signInWithOtp`, without changing any behavior, UI, routing, or error presentation.

## Current Code Path

**File:** `lib/features/phone_auth_screen.dart`
**Function:** `_PhoneAuthScreenState._send()` (lines 34-57)
**Action:** Calls `AuthService.signInWithPhone(_phone.text.trim())`

**File:** `lib/core/supabase/auth_service.dart`
**Function:** `AuthService.signInWithPhone(String phone)` (lines 114-126)
**Supabase call:** `_client.auth.signInWithOtp(phone: phone, channel: OtpChannel.sms, shouldCreateUser: true)`
**Error handling:** `on AuthException catch (error)` → `_mapAuthException(error)` → throws `AuthFailure`

## Problem

When a real phone number is used:
- `_send()` calls `AuthService.signInWithPhone()`
- `signInWithOtp` throws an `AuthException`
- `_mapAuthException` maps it to a generic `AuthFailure('Network error. Please try again.')` or another mapped message
- The original Supabase error details (message, status code, etc.) are lost
- The UI shows a SnackBar but we cannot see the underlying Supabase error

## Proposed Diagnostic Logging

Add `print()` statements (temporary, debug-only) around the Supabase call in `auth_service.dart` to capture:
- The formatted phone number being sent
- Whether the call succeeded or failed
- The exact error type
- The exact error message
- The status code if available

**Do NOT log:**
- OTP codes
- Access tokens
- Refresh tokens
- Passwords
- API keys
- Secrets

## Exact Changes

### 1. `lib/core/supabase/auth_service.dart` — `signInWithPhone()`

**Current:**
```dart
static Future<void> signInWithPhone(String phone) async {
  try {
    await _client.auth.signInWithOtp(
      phone: phone,
      channel: OtpChannel.sms,
      shouldCreateUser: true,
    );
  } on AuthException catch (error) {
    throw _mapAuthException(error);
  } catch (_) {
    throw const AuthFailure('Network error. Please try again.');
  }
}
```

**Proposed (add diagnostics only):**
```dart
static Future<void> signInWithPhone(String phone) async {
  print('[PHONE_OTP] Send OTP pressed');
  print('[PHONE_OTP] formatted phone: $phone');
  print('[PHONE_OTP] calling Supabase signInWithOtp');
  try {
    await _client.auth.signInWithOtp(
      phone: phone,
      channel: OtpChannel.sms,
      shouldCreateUser: true,
    );
    print('[PHONE_OTP] SUCCESS');
  } on AuthException catch (error) {
    print('[PHONE_OTP] ERROR');
    print('[PHONE_OTP] error type: ${error.runtimeType}');
    print('[PHONE_OTP] error message: ${error.message}');
    print('[PHONE_OTP] status code: ${error.statusCode}');
    throw _mapAuthException(error);
  } catch (error) {
    print('[PHONE_OTP] ERROR');
    print('[PHONE_OTP] error type: ${error.runtimeType}');
    print('[PHONE_OTP] error message: $error');
    throw const AuthFailure('Network error. Please try again.');
  }
}
```

### 2. `lib/features/phone_auth_screen.dart` — `_send()` (optional additional logging)

If needed, add a single log line at the start of `_send()` to confirm button press:
```dart
Future<void> _send() async {
  print('[PHONE_OTP] _send() invoked, validating form...');
  if (_formKey.currentState!.validate()) {
    // existing code...
  }
}
```

## What This Will Reveal

Running the app with a real phone number will output to the debug console:

1. **If Supabase returns a specific error** (e.g., SMS provider failure, rate limit, invalid phone format):
   ```
   [PHONE_OTP] ERROR
   [PHONE_OTP] error type: AuthException
   [PHONE_OTP] error message: <exact Supabase message>
   [PHONE_OTP] status code: <HTTP status>
   ```

2. **If the call succeeds but SMS is not delivered** (provider issue outside Supabase):
   ```
   [PHONE_OTP] SUCCESS
   ```
   → This would indicate Supabase accepted the request but the SMS provider (Textlocal) failed to deliver.

3. **If it's a phone format issue**:
   ```
   [PHONE_OTP] ERROR
   [PHONE_OTP] error type: AuthException
   [PHONE_OTP] error message: Phone number is not valid
   ```

## What Remains Untouched

- `phone_auth_screen.dart` UI and routing
- `AuthGate`
- `SessionAwareProfileRepository`
- Profile system
- Supabase database/RLS
- Textlocal configuration
- Dependencies
- Error presentation to user (SnackBar still shows)

## Cleanup

After diagnosis, remove all `[PHONE_OTP]` print statements. They are temporary diagnostics only.

## Validation

1. `flutter analyze` — expect `No issues found!`
2. Run app with test phone number → should see `[PHONE_OTP] SUCCESS`
3. Run app with real phone number → should see exact error details in debug console
4. Report the exact error message, type, and status code
