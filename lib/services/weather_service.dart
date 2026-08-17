import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WeatherInfo {
  final double temperatureCelsius;
  final String description;
  final IconData icon;
  final String? locationName;
  WeatherInfo({
    required this.temperatureCelsius,
    required this.description,
    required this.icon,
    this.locationName,
  });
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
}

class WeatherService {
  static const _endpoint = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherInfo> fetchCurrentWeather(LatLng location, {int maxAttempts = 3}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,weather_code',
      'timezone': 'auto',
    });

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw WeatherException('Weather request failed: ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final current = decoded['current'] as Map<String, dynamic>;
        final code = (current['weather_code'] as num).toInt();
        final (description, icon) = _describeWeatherCode(code);

        return WeatherInfo(
          temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
          description: description,
          icon: icon,
        );
      } catch (e) {
        if (attempt == maxAttempts) {
          throw e is WeatherException ? e : WeatherException('Weather request failed: $e');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw WeatherException('Weather request failed');
  }

  (String, IconData) _describeWeatherCode(int code) {
    if (code == 0) return ('Açık', Icons.wb_sunny);
    if (code == 1) return ('Genelde açık', Icons.wb_sunny);
    if (code == 2) return ('Parçalı bulutlu', Icons.wb_cloudy);
    if (code == 3) return ('Kapalı', Icons.cloud);
    if (code == 45 || code == 48) return ('Sisli', Icons.blur_on);
    if ([51, 53, 55, 56, 57].contains(code)) return ('Çisenti', Icons.grain);
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return ('Yağmurlu', Icons.grain);
    if ([71, 73, 75, 77, 85, 86].contains(code)) return ('Kar yağışlı', Icons.ac_unit);
    if ([95, 96, 99].contains(code)) return ('Gök gürültülü fırtına', Icons.thunderstorm);
    return ('Bilinmiyor', Icons.help_outline);
  }
}
