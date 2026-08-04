import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';

const _fallbackCenter = LatLng(41.0082, 28.9784);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng? _center;
  bool _locationUnavailable = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final location = await LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _center = location ?? _fallbackCenter;
      _locationUnavailable = location == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    if (center == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.haritasosyal.flutter_proje',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
          if (_locationUnavailable)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.orange.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Konum alınamadı, varsayılan konum gösteriliyor'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
