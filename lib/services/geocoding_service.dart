import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationInfo {
  final String city;
  final String? district;
  LocationInfo({required this.city, this.district});

  String get displayName => district != null ? '$city, $district' : city;
}

class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/reverse';

  /// Reverse-geocodes [location] into a city/district pair.
  /// Returns `null` on any failure so the caller can degrade gracefully.
  Future<LocationInfo?> reverseGeocode(LatLng location, {int maxAttempts = 3}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'lat': location.latitude.toString(),
      'lon': location.longitude.toString(),
      'format': 'json',
      'accept-language': 'tr',
      'zoom': '10',
    });

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(uri, headers: {
          'User-Agent': 'flutter_proje/1.0',
        }).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          if (attempt == maxAttempts) return null;
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final address = decoded['address'] as Map<String, dynamic>?;
        if (address == null) return null;

        final city = address['province'] as String? ??
            address['state'] as String? ??
            address['city'] as String?;
        if (city == null) return null;

        final district = address['district'] as String? ??
            address['town'] as String? ??
            address['county'] as String? ??
            address['suburb'] as String?;

        return LocationInfo(city: city, district: district);
      } catch (e) {
        if (attempt == maxAttempts) return null;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    return null;
  }
}
