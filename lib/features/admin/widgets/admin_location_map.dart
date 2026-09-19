import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Admin-only live-location map, used exclusively inside
/// `AdminUserDetailScreen._LiveLocationCard`.
///
/// Constraints (see Phase 1E.1D scope):
///   * receives coordinates only from the authorized `AdminUserDetail` data
///     returned by `public.admin_get_user_detail`;
///   * only renders a map when the caller has already gated on
///     `location_status` == live/stale with valid, finite, in-range coords;
///   * single marker, centered, single zoom level; no routes, no history,
///     no nearby users, no search, no navigation controls.
///
/// Tile source: public OpenStreetMap-compatible tiles (development/testing),
/// with a visible attribution overlay and a descriptive User-Agent package
/// name, per OSM tile-usage requirements.
class AdminLocationMap extends StatelessWidget {
  const AdminLocationMap({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final double latitude;
  final double longitude;

  @visibleForTesting
  static bool coordinatesValid(
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!coordinatesValid(latitude, longitude)) {
      return _Placeholder();
    }

    final center = LatLng(latitude, longitude);

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                backgroundColor: const Color(0xFF0F172A),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'conexo_admin',
                  tileDimension: 256,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 32,
                      height: 32,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 30,
                        color: Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    color: Color(0xFFB3C7D6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Text(
              'Map unavailable',
              style: TextStyle(color: Color(0xFF7E88A8)),
            ),
          ),
        ),
      ),
    );
  }
}
