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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: StreamBuilder<AppUser>(
        stream: context.read<FriendsProvider>().watchUser(myUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = snapshot.data!;
          return CustomScrollView(
            slivers: [
              // Gradient header
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary, cs.tertiary],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        children: [
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Profil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout,
                                    color: Colors.white70),
                                onPressed: () =>
                                    context.read<AuthProvider>().signOut(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Avatar
                          GestureDetector(
                            onTap: () => _pickPhoto(myUid),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        width: 3),
                                  ),
                                  child: UserAvatar(
                                    photoBase64: me.photoBase64,
                                    username: me.username,
                                    radius: 44,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit,
                                        size: 16,
                                        color: cs.onPrimaryContainer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            me.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            me.email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Location sharing card
                    Card(
                      child: SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        secondary: Icon(Icons.location_on_outlined,
                            color: cs.primary),
                        title: const Text('Konumumu paylaş'),
                        subtitle: const Text('Arkadaşların konumunu görebilir'),
                        value: me.locationSharing,
                        onChanged: (value) => context
                            .read<FriendsProvider>()
                            .setLocationSharing(myUid, value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Arkadaş Ara',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Kullanıcı adı gir...',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.search, color: cs.primary),
                                  onPressed: _search,
                                ),
                              ),
                            ),
                            for (final user in _searchResults)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: UserAvatar(
                                    photoBase64: user.photoBase64,
                                    username: user.username),
                                title: Text(user.username),
                                trailing: FilledButton.tonal(
                                  onPressed: () => _addFriend(user.uid),
                                  child: const Text('Ekle'),
                                ),
                              ),
                            if (_hasSearched && _searchResults.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Kullanıcı bulunamadı.',
                                  style: TextStyle(color: cs.outline),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Friends card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_outline,
                                    color: cs.primary, size: 22),
                                const SizedBox(width: 8),
                                Text('Arkadaşlar',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<List<AppUser>>(
                              future: context
                                  .read<FriendsProvider>()
                                  .getFriends(me.friends),
                              builder: (context, friendsSnapshot) {
                                final friends =
                                    friendsSnapshot.data ?? const [];
                                if (friends.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.person_add_outlined,
                                              size: 40, color: cs.outline),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Henüz arkadaşın yok.\nKullanıcı adı arayarak ekleyebilirsin.',
                                            textAlign: TextAlign.center,
                                            style:
                                                TextStyle(color: cs.outline),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final friend in friends)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: UserAvatar(
                                          photoBase64: friend.photoBase64,
                                          username: friend.username,
                                        ),
                                        title: Text(friend.username),
                                        trailing: friend.locationSharing
                                            ? Icon(Icons.location_on,
                                                color: cs.primary, size: 20)
                                            : null,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
