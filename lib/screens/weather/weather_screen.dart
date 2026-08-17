import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../services/geocoding_service.dart';

const _fallbackCenter = LatLng(41.0082, 28.9784);

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _failed = false;
  WeatherInfo? _weather;
  String? _locationDisplay;
  DateTime? _lastUpdated;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _fadeController.reset();

    final location =
        await LocationService().getCurrentLocation() ?? _fallbackCenter;

    try {
      // Fetch weather and location info in parallel
      final results = await Future.wait([
        WeatherService().fetchCurrentWeather(location),
        GeocodingService().reverseGeocode(location),
      ]);

      if (!mounted) return;

      final weather = results[0] as WeatherInfo;
      final locationInfo = results[1] as LocationInfo?;

      setState(() {
        _weather = weather;
        _locationDisplay = locationInfo?.displayName;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
      _fadeController.forward();
    } on WeatherException {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  List<Color> _gradientForWeatherCode(String? description) {
    final desc = description?.toLowerCase() ?? '';
    if (desc.contains('açık') || desc.contains('genelde')) {
      return [const Color(0xFF4FC3F7), const Color(0xFF0288D1)];
    }
    if (desc.contains('bulutlu') || desc.contains('kapalı')) {
      return [const Color(0xFF90A4AE), const Color(0xFF546E7A)];
    }
    if (desc.contains('yağmur') || desc.contains('çisenti')) {
      return [const Color(0xFF5C6BC0), const Color(0xFF283593)];
    }
    if (desc.contains('kar')) {
      return [const Color(0xFFB3E5FC), const Color(0xFF81D4FA)];
    }
    if (desc.contains('fırtına')) {
      return [const Color(0xFF37474F), const Color(0xFF1A237E)];
    }
    if (desc.contains('sis')) {
      return [const Color(0xFFB0BEC5), const Color(0xFF78909C)];
    }
    return [const Color(0xFF4FC3F7), const Color(0xFF0288D1)];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _gradientForWeatherCode(_weather?.description);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _loading || _failed
                ? [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface,
                  ]
                : gradientColors,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              kBottomNavigationBarHeight,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildWeatherContent(),
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Hava durumu yüklenemedi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    final weather = _weather!;

    return Column(
      children: [
        const SizedBox(height: 48),
        // Location
        if (_locationDisplay != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Text(
                _locationDisplay!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Title
        const Text(
          'Hava Durumu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w300,
          ),
        ),
        const Spacer(),
        // Large weather icon
        Icon(weather.icon, size: 120, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(height: 24),
        // Glass card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${weather.temperatureCelsius.round()}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weather.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        // Last updated
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Son güncelleme: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
