import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final results = await context
        .read<FriendsProvider>()
        .searchUsersByUsername(_searchController.text.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _hasSearched = true;
    });
  }

  Future<void> _pickPhoto(String myUid) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 60,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final base64Photo = base64Encode(bytes);
    if (!mounted) return;
    await context.read<FriendsProvider>().updatePhoto(myUid, base64Photo);
  }

  Future<void> _addFriend(String friendUid) async {
    final myUid = context.read<AuthProvider>().currentUser!.uid;
    await context.read<FriendsProvider>().addFriend(myUid, friendUid);
    if (!mounted) return;
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.watch<AuthProvider>().currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<AppUser>(
        stream: context.read<FriendsProvider>().watchUser(myUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _pickPhoto(myUid),
                  child: Stack(
                    children: [
                      UserAvatar(photoBase64: me.photoBase64, username: me.username, radius: 40),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(me.username, style: Theme.of(context).textTheme.headlineSmall),
              Text(me.email),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Konumumu arkadaşlarımla paylaş'),
                value: me.locationSharing,
                onChanged: (value) =>
                    context.read<FriendsProvider>().setLocationSharing(myUid, value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı adı ara',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ),
              ),
              for (final user in _searchResults)
                ListTile(
                  leading: UserAvatar(photoBase64: user.photoBase64, username: user.username),
                  title: Text(user.username),
                  trailing: TextButton(
                    onPressed: () => _addFriend(user.uid),
                    child: const Text('Ekle'),
                  ),
                ),
              if (_hasSearched && _searchResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Kullanıcı bulunamadı.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              const Divider(),
              Text('Arkadaşlar', style: Theme.of(context).textTheme.titleMedium),
              FutureBuilder<List<AppUser>>(
                future: context.read<FriendsProvider>().getFriends(me.friends),
                builder: (context, friendsSnapshot) {
                  final friends = friendsSnapshot.data ?? const [];
                  if (friends.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz arkadaşın yok. Kullanıcı adı arayarak ekleyebilirsin.',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final friend in friends)
                        ListTile(
                          leading: UserAvatar(
                            photoBase64: friend.photoBase64,
                            username: friend.username,
                          ),
                          title: Text(friend.username),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
