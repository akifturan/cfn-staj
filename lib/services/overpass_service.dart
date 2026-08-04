import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NearbyPlace {
  final String name;
  final String type; // 'supermarket' or 'pharmacy'
  final LatLng location;
  NearbyPlace({required this.name, required this.type, required this.location});
}

class OverpassException implements Exception {
  final String message;
  OverpassException(this.message);
}

class OverpassService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  Future<List<NearbyPlace>> fetchNearbyPlaces(LatLng center, {double radiusMeters = 1500}) async {
    final query = '''
      [out:json][timeout:25];
      (
        node["shop"="supermarket"](around:$radiusMeters,${center.latitude},${center.longitude});
        node["amenity"="pharmacy"](around:$radiusMeters,${center.latitude},${center.longitude});
      );
      out body;
    ''';

    final response = await http
        .post(Uri.parse(_endpoint), body: {'data': query})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw OverpassException('Overpass request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];

    return elements.map((e) {
      final el = e as Map<String, dynamic>;
      final tags = el['tags'] as Map<String, dynamic>? ?? const {};
      final type = tags['shop'] == 'supermarket' ? 'supermarket' : 'pharmacy';
      return NearbyPlace(
        name: tags['name'] as String? ?? (type == 'supermarket' ? 'Market' : 'Eczane'),
        type: type,
        location: LatLng((el['lat'] as num).toDouble(), (el['lon'] as num).toDouble()),
      );
    }).toList();
  }
}
