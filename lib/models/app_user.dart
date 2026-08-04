class AppUser {
  final String uid;
  final String username;
  final String email;
  final List<String> friends;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.friends,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      friends: List<String>.from(data['friends'] as List? ?? const []),
    );
  }
}
