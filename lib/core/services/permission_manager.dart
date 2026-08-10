import 'package:permission_handler/permission_handler.dart' as ph;

enum PermissionType {
  locationWhenInUse,
  camera,
  photos,
  microphone,
  notifications,
}

enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

abstract final class PermissionManager {
  static Future<PermissionStatus> check(PermissionType type) async {
    final status = await _toPermission(type).status;
    return _mapStatus(status);
  }

  static Future<PermissionStatus> request(PermissionType type) async {
    final status = await _toPermission(type).request();
    return _mapStatus(status);
  }

  static Future<bool> isGranted(PermissionType type) async {
    return await _toPermission(type).isGranted;
  }

  static Future<bool> isPermanentlyDenied(PermissionType type) async {
    return await _toPermission(type).isPermanentlyDenied;
  }

  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  static ph.Permission _toPermission(PermissionType type) {
    switch (type) {
      case PermissionType.locationWhenInUse:
        return ph.Permission.locationWhenInUse;
      case PermissionType.camera:
        return ph.Permission.camera;
      case PermissionType.photos:
        return ph.Permission.photos;
      case PermissionType.microphone:
        return ph.Permission.microphone;
      case PermissionType.notifications:
        return ph.Permission.notification;
    }
  }

  static PermissionStatus _mapStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return PermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return PermissionStatus.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return PermissionStatus.restricted;
      case ph.PermissionStatus.limited:
        return PermissionStatus.limited;
      case ph.PermissionStatus.provisional:
        return PermissionStatus.limited;
    }
  }
}
