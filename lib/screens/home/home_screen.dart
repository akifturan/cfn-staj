import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/location_service.dart';
import '../../services/overpass_service.dart';

const _fallbackCenter = LatLng(41.0082, 28.9784);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng? _center;
  bool _locationUnavailable = false;
  List<NearbyPlace> _nearbyPlaces = [];
  bool _nearbyPlacesFailed = false;
  List<AppUser> _friendLocations = [];

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final location = await LocationService().getCurrentLocation();
    if (!mounted) return;
    final center = location ?? _fallbackCenter;
    setState(() {
      _center = center;
      _locationUnavailable = location == null;
    });
    _loadNearbyPlaces(center);
    _syncFriendLocations(location);
  }

  Future<void> _loadNearbyPlaces(LatLng center) async {
    setState(() => _nearbyPlacesFailed = false);
    try {
      final places = await OverpassService().fetchNearbyPlaces(center);
      if (!mounted) return;
      setState(() => _nearbyPlaces = places);
    } on OverpassException {
      if (!mounted) return;
      setState(() => _nearbyPlacesFailed = true);
    }
  }

  Future<void> _syncFriendLocations(LatLng? realLocation) async {
    try {
      final myUid = context.read<AuthProvider>().currentUser!.uid;
      final friendsProvider = context.read<FriendsProvider>();
      final me = await friendsProvider.watchUser(myUid).first;

      if (realLocation != null && me.locationSharing) {
        await friendsProvider.updateLocation(myUid, realLocation);
      }

      final friends = await friendsProvider.getFriends(me.friends);
      final sharing =
          friends.where((f) => f.locationSharing && f.location != null).toList();
      if (!mounted) return;
      setState(() => _friendLocations = sharing);
    } catch (_) {
      // Konum paylaşımı senkronizasyonu başarısız olsa da harita çalışmaya devam etsin.
    }
  }

  void _showPlaceName(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(name)));
  }

  void _showFriendInfo(AppUser friend) {
    final updatedAt = friend.locationUpdatedAt;
    final when = updatedAt == null ? '' : ' · ${_relativeTime(updatedAt)}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${friend.username}$when')));
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
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
                  for (final place in _nearbyPlaces)
                    Marker(
                      point: place.location,
                      child: GestureDetector(
                        onTap: () => _showPlaceName(place.name),
                        child: Icon(
                          place.type == 'supermarket'
                              ? Icons.local_grocery_store
                              : Icons.local_pharmacy,
                          color: place.type == 'supermarket' ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  for (final friend in _friendLocations)
                    Marker(
                      point: friend.location!,
                      child: GestureDetector(
                        onTap: () => _showFriendInfo(friend),
                        child: const Icon(Icons.person_pin_circle, color: Colors.purple),
                      ),
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
          if (_nearbyPlacesFailed)
            Positioned(
              top: _locationUnavailable ? 48 : 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Yakındaki yerler yüklenemedi')),
                      TextButton(
                        onPressed: () => _loadNearbyPlaces(center),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
