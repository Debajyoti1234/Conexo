import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:geolocator/geolocator.dart';

import 'permission_manager.dart';
import '../../features/profile/live_location_repository.dart';
import '../../core/supabase/auth_service.dart';

abstract final class LiveLocationTracker {
  static const _interval = Duration(minutes: 15);
  static const _accuracy = LocationAccuracy.high;

  static Timer? _timer;
  static bool _backgroundEnabled = false;
  static final LiveLocationRepository _repo = const LiveLocationRepository();

  static bool get isRunning => _timer != null && _timer!.isActive;

  static Future<void> start() async {
    if (isRunning) return;

    final granted = await _checkPermission();
    if (!granted) return;

    await _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());

    await _tryEnableBackground();
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _disableBackground();
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
    return false;
  }

  static Future<Position?> _getPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: _accuracy),
      );
    } on Exception catch (e) {
      debugPrint('LiveLocationTracker._getPosition failed: $e');
      return null;
    }
  }

  static Future<void> _tryEnableBackground() async {
    if (kIsWeb) return;

    final status = await PermissionManager.check(PermissionType.locationAlways);
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      await _enableBackground();
      return;
    }

    if (status == PermissionStatus.denied) {
      final requested = await PermissionManager.request(
        PermissionType.locationAlways,
      );
      if (requested == PermissionStatus.granted ||
          requested == PermissionStatus.limited) {
        await _enableBackground();
      }
    }
  }

  static Future<void> _enableBackground() async {
    if (_backgroundEnabled) return;

    try {
      final initialized = await fb.FlutterBackground.initialize(
        androidConfig: const fb.FlutterBackgroundAndroidConfig(
          notificationTitle: 'Conexo Discovery',
          notificationText: 'Conexo is keeping your location updated for Discovery.',
          notificationIcon: fb.AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          notificationImportance: fb.AndroidNotificationImportance.normal,
          enableWifiLock: false,
          showBadge: false,
          shouldRequestBatteryOptimizationsOff: false,
        ),
      );

      if (initialized) {
        await fb.FlutterBackground.enableBackgroundExecution();
        _backgroundEnabled = true;
      }
    } on Exception catch (e) {
      debugPrint('LiveLocationTracker._enableBackground failed: $e');
    }
  }

  static Future<void> _disableBackground() async {
    if (!_backgroundEnabled) return;

    try {
      await fb.FlutterBackground.disableBackgroundExecution();
    } on Exception catch (e) {
      debugPrint('LiveLocationTracker._disableBackground failed: $e');
    } finally {
      _backgroundEnabled = false;
    }
  }
}
