import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<String?> webReverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'json',
    });
    final request = await html.HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: {'User-Agent': 'Conexo/1.0'},
    );
    if (request.status != 200) return null;
    final data = jsonDecode(request.responseText ?? '');
    if (data is! Map<String, dynamic>) return null;
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;
    final city = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['county'];
    final state = address['state'];
    final country = address['country'];
    final parts = <String>[
      if (city != null) city.toString(),
      if (state != null) state.toString(),
      if (country != null) country.toString(),
    ];
    return parts.join(', ');
  } catch (e) {
    // ignore: avoid_print
    print('Web reverse geocoding failed: $e');
    return null;
  }
}
