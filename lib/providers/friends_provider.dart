import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_user.dart';

class FriendsProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AppUser>> searchUsersByUsername(String queryText) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: queryText)
        .where('username', isLessThanOrEqualTo: '$queryText')
        .limit(20)
        .get();
    return snapshot.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> addFriend(String myUid, String friendUid) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(myUid), {
      'friends': FieldValue.arrayUnion([friendUid]),
    });
    batch.update(_firestore.collection('users').doc(friendUid), {
      'friends': FieldValue.arrayUnion([myUid]),
    });
    await batch.commit();
  }

  Stream<AppUser> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => AppUser.fromFirestore(doc.id, doc.data() ?? const {}));
  }

  Future<List<AppUser>> getFriends(List<String> friendUids) async {
    if (friendUids.isEmpty) return const [];
    // Firestore whereIn caps at 10 values; fine for this project's scale.
    final snapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendUids.take(10).toList())
        .get();
    return snapshot.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> setLocationSharing(String uid, bool enabled) async {
    if (enabled) {
      await _firestore.collection('users').doc(uid).update({'locationSharing': true});
    } else {
      await _firestore.collection('users').doc(uid).update({
        'locationSharing': false,
        'location': null,
        'locationUpdatedAt': null,
      });
    }
  }

  Future<void> updateLocation(String uid, LatLng location) async {
    await _firestore.collection('users').doc(uid).update({
      'location': GeoPoint(location.latitude, location.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
