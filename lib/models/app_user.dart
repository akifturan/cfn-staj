import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class AppUser {
  final String uid;
  final String username;
  final String email;
  final List<String> friends;
  final bool locationSharing;
  final LatLng? location;
  final DateTime? locationUpdatedAt;
  final String? photoBase64;
  final int? breathHoldBestMs;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.friends,
    this.locationSharing = false,
    this.location,
    this.locationUpdatedAt,
    this.photoBase64,
    this.breathHoldBestMs,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    final geo = data['location'] as GeoPoint?;
    final updatedAt = data['locationUpdatedAt'] as Timestamp?;
    return AppUser(
      uid: uid,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      friends: List<String>.from(data['friends'] as List? ?? const []),
      locationSharing: data['locationSharing'] as bool? ?? false,
      location: geo != null ? LatLng(geo.latitude, geo.longitude) : null,
      locationUpdatedAt: updatedAt?.toDate(),
      photoBase64: data['photoBase64'] as String?,
      breathHoldBestMs: (data['breathHoldBestMs'] as num?)?.toInt(),
    );
  }
}
