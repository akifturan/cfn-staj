# 📖 Yakında — Teknik Çalışma Kılavuzu

> Bu doküman, projedeki **her dosyayı, her fonksiyonu, her mimari kararı** satır satır açıklar.
> Mülakat öncesi bu dokümanı baştan sona çalışarak projeye tam hakimiyet sağlayabilirsin.

---

## 📑 İçindekiler

1. [Uygulama Başlatma Akışı](#1-uygulama-başlatma-akışı-maindart)
2. [Veri Modeli — AppUser](#2-veri-modeli--appuser)
3. [State Management — AuthProvider](#3-state-management--authprovider)
4. [State Management — FriendsProvider](#4-state-management--friendsprovider)
5. [Navigasyon Mimarisi — AuthGate & RootShell](#5-navigasyon-mimarisi--authgate--rootshell)
6. [Auth Ekranları — Login & Register](#6-auth-ekranları--login--register)
7. [Harita Ekranı — HomeScreen](#7-harita-ekranı--homescreen)
8. [Profil Ekranı — ProfileScreen](#8-profil-ekranı--profilescreen)
9. [Servisler — LocationService & OverpassService](#9-servisler--locationservice--overpassservice)
10. [Widget — UserAvatar](#10-widget--useravatar)
11. [Firestore Veritabanı Tasarımı](#11-firestore-veritabanı-tasarımı)
12. [Tema ve Material 3](#12-tema-ve-material-3)
13. [Android Build Yapılandırması](#13-android-build-yapılandırması)
14. [Olası Mülakat Soru-Cevapları](#14-olası-mülakat-soru-cevapları)

---

## 1. Uygulama Başlatma Akışı (`main.dart`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();          // ①
  await Firebase.initializeApp(                        // ②
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());                               // ③
}
```

### Ne yapıyor, neden yapıyor?

| # | Satır | Açıklama |
|---|-------|----------|
| ① | `WidgetsFlutterBinding.ensureInitialized()` | `main()` fonksiyonu `async` olduğu için Flutter'ın widget binding'ini manuel başlatmamız gerekir. Bunu yapmazsak Firebase.initializeApp() çağrısında crash alırız. **Neden?** Çünkü Firebase yerel platform kanallarını (MethodChannel) kullanır ve bu kanallar binding olmadan çalışmaz. |
| ② | `Firebase.initializeApp(...)` | `firebase_options.dart` dosyasındaki platforma özel API anahtarları ve proje ID'leri ile Firebase'i başlatır. Bu dosya `flutterfire configure` CLI komutuyla otomatik üretilir. |
| ③ | `runApp(const MyApp())` | Widget tree'nin kökünü oluşturur. `const` kullanımı, bu widget'ın immutable olduğunu ve yeniden build edilmesine gerek olmadığını derleyiciye bildirir → performans kazanımı. |

### MultiProvider Yapısı

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),   // A
    Provider(create: (_) => FriendsProvider()),               // B
  ],
  child: MaterialApp(...),
);
```

| # | Provider Tipi | Sınıf | Neden Bu Tip? |
|---|---------------|-------|---------------|
| A | `ChangeNotifierProvider` | `AuthProvider` | Auth durumu değiştiğinde UI'ı yeniden çizmesi gerekir (`notifyListeners()` çağrılabilir). `ChangeNotifier`'ı extends eder. |
| B | `Provider` (basit) | `FriendsProvider` | `ChangeNotifier` değil, sadece metod çağrıları yapar. State tutmaz, UI'a `notifyListeners()` göndermez. Dolayısıyla basit `Provider` yeterlidir. |

**Kritik Bilgi:** `ChangeNotifierProvider` vs `Provider` farkı mülakatta sorulabilir:
- `ChangeNotifierProvider`: Dinleyicilere bildirim gönderebilir → UI rebuild tetikler
- `Provider`: Sadece nesneyi tree'ye enjekte eder, bildirim mekanizması yoktur

### Tema Yapılandırması

```dart
theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
darkTheme: ThemeData(
  colorSchemeSeed: Colors.blue,
  brightness: Brightness.dark,
  useMaterial3: true,
),
themeMode: ThemeMode.system,
```

- `colorSchemeSeed`: Bir seed renk vererek Material 3'ün tüm renk paletini otomatik ürettirir (primary, secondary, surface, onPrimary, vs.). Tek tek renk tanımlamak yerine harmonik bir palet elde edersin.
- `themeMode: ThemeMode.system`: Cihazın karanlık/aydınlık tema ayarını otomatik takip eder. Kullanıcı telefonunda dark mode açarsa uygulama da karanlık temaya geçer.

---

## 2. Veri Modeli — `AppUser`

**Dosya:** `lib/models/app_user.dart`

```dart
class AppUser {
  final String uid;
  final String username;
  final String email;
  final List<String> friends;
  final bool locationSharing;
  final LatLng? location;
  final DateTime? locationUpdatedAt;
  final String? photoBase64;
}
```

### Factory Constructor: `fromFirestore`

```dart
factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
  final geo = data['location'] as GeoPoint?;        // ①
  final updatedAt = data['locationUpdatedAt'] as Timestamp?;  // ②
  return AppUser(
    uid: uid,
    username: data['username'] as String? ?? '',      // ③
    friends: List<String>.from(data['friends'] as List? ?? const []),  // ④
    location: geo != null ? LatLng(geo.latitude, geo.longitude) : null,  // ⑤
    locationUpdatedAt: updatedAt?.toDate(),            // ⑥
    photoBase64: data['photoBase64'] as String?,
  );
}
```

| # | Ne Yapıyor | Neden Önemli |
|---|-----------|--------------|
| ① | Firestore `GeoPoint` tipini okur | Firestore, konum verisini kendi özel `GeoPoint` tipinde saklar (`latitude`, `longitude` alanları var) |
| ② | Firestore `Timestamp` tipini okur | Dart'ın `DateTime`'ından farklı bir tip. `toDate()` ile dönüştürmek gerekir |
| ③ | `as String? ?? ''` | Null-safety: Eğer Firestore'da alan yoksa `null` döner, biz de `''` default değer atarız → NullPointerException engellenir |
| ④ | `List<String>.from(...)` | Firestore'dan gelen `List<dynamic>` tipini `List<String>`'e cast eder. Doğrudan cast (`as List<String>`) runtime hatası verir çünkü Firestore dynamic list döndürür |
| ⑤ | `GeoPoint` → `LatLng` dönüşümü | Firestore `GeoPoint` kullanırken, `flutter_map` kütüphanesi `LatLng` bekler. Model katmanında bu dönüşümü yaparak UI'ın Firestore'a bağımlılığını kırıyoruz |
| ⑥ | `updatedAt?.toDate()` | `?.` (null-aware operator): eğer `updatedAt` null ise `toDate()` çağrılmaz, direkt `null` döner |

**Mülakat İpucu:** "Neden `toJson()` / serialization metodu yok?" → Yazma işlemlerini provider katmanında direkt `Map` literal olarak yapıyoruz. Küçük projede `toJson()` gereksiz boilerplate olurdu. Büyük projelerde `freezed` veya `json_serializable` kullanılabilir.

---

## 3. State Management — `AuthProvider`

**Dosya:** `lib/providers/auth_provider.dart`

```dart
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;       // Singleton erişim
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;              // ①
  Stream<User?> get authStateChanges => _auth.authStateChanges();  // ②
}
```

### Getter'lar

| Getter | Dönen Tip | Kullanım Yeri | Açıklama |
|--------|-----------|---------------|----------|
| `currentUser` | `User?` | ProfileScreen, HomeScreen | O anki oturum açmış kullanıcının Firebase User nesnesini verir. Oturum yoksa `null`. |
| `authStateChanges` | `Stream<User?>` | AuthGate | Firebase oturum durumu her değiştiğinde (login, logout, token yenileme) yeni bir event yayınlar. StreamBuilder bunu dinler. |

### Register Metodu — Satır Satır

```dart
Future<void> register(String email, String password, String username) async {
  // 1. Firebase Auth'ta kullanıcı oluştur
  final credential = await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  // 2. Auth'tan gelen UID'yi al
  final uid = credential.user!.uid;
  
  // 3. Firestore'da kullanıcı dokümanı oluştur
  await _firestore.collection('users').doc(uid).set({
    'username': username,
    'email': email,
    'friends': <String>[],
    'createdAt': FieldValue.serverTimestamp(),   // ← Sunucu saati
  });
}
```

**Kritik Detay — `FieldValue.serverTimestamp()`:**
- İstemcinin saati yanlış olabilir (kullanıcı telefonun saatini değiştirebilir)
- `serverTimestamp()` Firebase sunucusunun saatini kullanır → güvenilir ve tutarlı zaman damgası
- Bu değer Firestore'a yazıldığında sunucu tarafında doldurulur

**Kritik Detay — `doc(uid).set(...)`:**
- Doküman ID'si olarak Firebase Auth UID'sini kullanıyoruz
- Bu sayede `users` koleksiyonunda bir kullanıcıyı bulmak O(1) — UID zaten biliniyor
- Otomatik ID (`add()`) kullansaydık, her sorguda `where('uid', isEqualTo: ...)` yapmamız gerekirdi

### SignIn ve SignOut

```dart
Future<void> signIn(String email, String password) async {
  await _auth.signInWithEmailAndPassword(email: email, password: password);
  // NOT: notifyListeners() çağırmıyoruz çünkü
  // authStateChanges stream'i zaten AuthGate'i tetikliyor
}

Future<void> signOut() => _auth.signOut();
```

**Neden `notifyListeners()` yok?** `AuthGate`, `authStateChanges` stream'ini dinliyor. Login/logout olduğunda bu stream otomatik fire eder → `StreamBuilder` rebuild olur → doğru ekrana yönlendirir. Yani çift bildirime gerek yok.

---

## 4. State Management — `FriendsProvider`

**Dosya:** `lib/providers/friends_provider.dart`

Bu sınıf projenin en yoğun iş mantığını barındırır. Her metodu tek tek inceleyelim:

### 4.1 `searchUsersByUsername` — Prefix Arama

```dart
Future<List<AppUser>> searchUsersByUsername(String queryText) async {
  final snapshot = await _firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: queryText)
      .where('username', isLessThanOrEqualTo: '$queryText\uf8ff')
      .limit(20)
      .get();
  return snapshot.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
}
```

**`\uf8ff` Unicode Tekniği:**
- `\uf8ff`, Unicode tablosundaki en son kullanılabilir Private Use Area karakteridir
- `"ak" ≤ username ≤ "ak\uf8ff"` demek → "ak ile başlayan tüm stringler" demek
- Çünkü "ak" ile başlayan her string ("akif", "akın", "akmehmet") sözlüksel olarak "ak" ile "ak\uf8ff" arasında kalır
- **Firestore LIKE operatörü desteklemez**, bu yüzden range query ile prefix arama simüle edilir

**`limit(20)`:** Arama sonucu çok fazla kullanıcı dönebilir. 20 ile sınırlayarak ağ trafiğini ve Firestore okuma maliyetini azaltıyoruz.

### 4.2 `addFriend` — Atomic Batch Write

```dart
Future<void> addFriend(String myUid, String friendUid) async {
  final batch = _firestore.batch();
  
  // Benim friends listeme onun UID'sini ekle
  batch.update(_firestore.collection('users').doc(myUid), {
    'friends': FieldValue.arrayUnion([friendUid]),
  });
  
  // Onun friends listesine benim UID'mi ekle
  batch.update(_firestore.collection('users').doc(friendUid), {
    'friends': FieldValue.arrayUnion([myUid]),
  });
  
  await batch.commit();  // İki işlem ya ikisi birden başarılı olur, ya ikisi birden iptal olur
}
```

**`FieldValue.arrayUnion`:**
- Dizi içinde zaten varsa tekrar eklemez (idempotent)
- Diziyi tamamen okuyup client'ta ekleyip tekrar yazmak yerine, sunucu tarafında atomik olarak ekler
- Concurrent (eş zamanlı) yazımlarda veri kaybı olmaz

**Batch Write vs Transaction Farkı (Kritik Mülakat Sorusu):**

| Özellik | Batch Write | Transaction |
|---------|-------------|-------------|
| Okuma gerektirir mi? | ❌ Hayır | ✅ Evet (önce oku, sonra yaz) |
| Atomik mi? | ✅ Evet | ✅ Evet |
| Kullanım senaryosu | Sadece yazma (create/update/delete) | Oku → Karar ver → Yaz (ör: bakiye kontrolü) |
| Performans | Daha hızlı (okuma yok) | Daha yavaş (okuma + yazma) |
| Max işlem | 500 | 500 |

**Biz neden Batch seçtik?** Arkadaş eklerken mevcut veriyi okumaya gerek yok. `arrayUnion` zaten idempotent. Sadece "ekle" diyoruz → okuma gereksiz → Batch yeterli ve daha performanslı.

### 4.3 `watchUser` — Gerçek Zamanlı Stream

```dart
Stream<AppUser> watchUser(String uid) {
  return _firestore
      .collection('users')
      .doc(uid)
      .snapshots()                    // ← Gerçek zamanlı dinleme
      .map((doc) => AppUser.fromFirestore(doc.id, doc.data() ?? const {}));
}
```

**`.snapshots()` vs `.get()` Farkı:**

| Metod | Davranış | Kullanım |
|-------|----------|----------|
| `.get()` | Tek seferlik okuma. Future döner. | Arkadaş listesi çekme gibi anlık ihtiyaçlar |
| `.snapshots()` | Sürekli dinleme. Stream döner. Veri değiştiğinde yeni event yayınlar. | Profil ekranı gibi canlı güncelleme gereken yerler |

**Nasıl çalışır?**
1. Firestore SDK, WebSocket/gRPC bağlantısı üzerinden dokümanı dinlemeye başlar
2. Sunucuda doküman değiştiğinde (konum güncelleme, arkadaş ekleme, vb.) sunucu değişen veriyi push eder
3. Client tarafında stream yeni event yayınlar → `StreamBuilder` rebuild olur → UI güncellenir

### 4.4 `getFriends` — Toplu Kullanıcı Çekme

```dart
Future<List<AppUser>> getFriends(List<String> friendUids) async {
  if (friendUids.isEmpty) return const [];
  final snapshot = await _firestore
      .collection('users')
      .where(FieldPath.documentId, whereIn: friendUids.take(10).toList())
      .get();
  return snapshot.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
}
```

**Firestore `whereIn` Limiti:**
- Firestore `whereIn` sorgusunda **max 30 eleman** (eski sürümlerde 10) desteklenir
- Biz `take(10)` ile 10'a sınırladık (başlangıçta eski limit baz alındı)
- **10+ arkadaşı olan kullanıcı varsa ne olur?** İlk 10 arkadaş gösterilir, geri kalanı gösterilmez
- **Production çözümü:** UID listesini 10'arlık parçalara bölüp (`chunk`) paralel sorgular yapıp birleştirmek (`Future.wait`)

### 4.5 `setLocationSharing` — Konum Paylaşım Toggle

```dart
Future<void> setLocationSharing(String uid, bool enabled) async {
  if (enabled) {
    await _firestore.collection('users').doc(uid).update({
      'locationSharing': true,
    });
  } else {
    await _firestore.collection('users').doc(uid).update({
      'locationSharing': false,
      'location': null,              // Konum verisini sil
      'locationUpdatedAt': null,      // Zaman damgasını sil
    });
  }
}
```

**Neden kapatırken `location` ve `locationUpdatedAt` da siliniyor?**
- Kullanıcı paylaşımı kapattığında eski konumunun hâlâ görünmemesi gerekir
- `null` atamak Firestore'da o alanı silmez ama değerini boşaltır
- Bu sayede arkadaşları eski konumunu haritada göremez

### 4.6 `updateLocation` ve `updatePhoto`

```dart
Future<void> updateLocation(String uid, LatLng location) async {
  await _firestore.collection('users').doc(uid).update({
    'location': GeoPoint(location.latitude, location.longitude),  // LatLng → GeoPoint
    'locationUpdatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updatePhoto(String uid, String photoBase64) async {
  await _firestore.collection('users').doc(uid).update({
    'photoBase64': photoBase64,
  });
}
```

- `LatLng` → `GeoPoint` dönüşümü: `flutter_map` `LatLng` kullanırken, Firestore `GeoPoint` bekler
- `serverTimestamp()`: Konum ne zaman güncellendiğini sunucu saatiyle kaydeder

---

## 5. Navigasyon Mimarisi — AuthGate & RootShell

### AuthGate — Oturum Yönlendirmesi

```dart
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();         // ①
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,                   // ②
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));  // ③
        }
        return snapshot.hasData ? const RootShell() : const LoginScreen();  // ④
      },
    );
  }
}
```

| # | Açıklama |
|---|----------|
| ① | `context.read` → Provider'dan tek seferlik okuma, rebuild tetiklemez |
| ② | Firebase Auth stream'ini dinle |
| ③ | Stream henüz ilk event'i yayınlamadıysa loading göster |
| ④ | `hasData` = oturum var → ana ekrana, yoksa → login ekranına yönlendir |

**`context.read` vs `context.watch` (Kritik Fark):**
- `context.read<T>()`: Bir kere okur, değiştiğinde rebuild tetiklemez. Tek seferlik erişim.
- `context.watch<T>()`: Her değişiklikte build metodunu tekrar çağırır. Sürekli dinleme.
- AuthGate'te `read` kullanıyoruz çünkü zaten `StreamBuilder` ile dinliyoruz, ekstra `watch` gereksiz olurdu.

**`hide AuthProvider` İfadesi:**
```dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
```
Firebase Auth paketi kendi `AuthProvider` sınıfını içerir. Bizim yazdığımız `AuthProvider` ile isim çakışmasını engellemek için Firebase'inkini gizliyoruz (`hide`).

### RootShell — Bottom Navigation

```dart
class _RootShellState extends State<RootShell> {
  int _index = 0;
  static const _screens = [HomeScreen(), ProfileScreen()];  // ①

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],                                // ②
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),            // ③
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Harita'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
```

| # | Açıklama |
|---|----------|
| ① | `static const`: Ekranlar sabittir, her tab değişiminde yeniden oluşturulmaz → performans |
| ② | Aktif index'e göre hangi ekranı göstereceğini seçer |
| ③ | Tab'a tıklanınca `setState` ile index güncellenir → build yeniden çalışır → doğru ekran gösterilir |

**StatefulWidget neden burada gerekli?** `_index` değişkeni state'tir. Tab seçimi değiştiğinde UI'ın güncellenmesi gerekir. StatelessWidget'ta `setState` çağıramazsın.

---

## 6. Auth Ekranları — Login & Register

### Ortak Kalıplar

Her iki ekran da aynı pattern'i kullanır:

1. **TextEditingController** ile form alanlarını yönetir
2. **dispose()** ile controller'ları temizler (bellek sızıntısını önler)
3. **`_isLoading` flag** ile çift tıklamayı engeller (buton disabled olur)
4. **`_errorMessage` state** ile hata mesajını gösterir
5. **try-catch-finally** ile Firebase hatalarını yakalar
6. **`if (mounted)` kontrolü** ile async işlem sonrası widget'ın hâlâ tree'de olduğunu doğrular

### `mounted` Kontrolü (Çok Önemli)

```dart
} finally {
  if (mounted) setState(() => _isLoading = false);
}
```

**Neden gerekli?**
- `await` ile beklenen async işlem sırasında kullanıcı geri tuşuna basabilir
- Widget tree'den kaldırılmış bir widget üzerinde `setState` çağırmak → **hata fırlatır**
- `mounted` property'si widget'ın hâlâ canlı olup olmadığını söyler

### Login'den Register'a Navigasyon

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const RegisterScreen()),
);
```

- `push`: Mevcut ekranın üstüne yeni ekran koyar (stack yapısı)
- Kayıt başarılı olduğunda `Navigator.pop(context)` ile register ekranı kapanır → login'e dönülür
- Login ekranında zaten `authStateChanges` stream'i tetiklenir → otomatik olarak ana ekrana geçiş

---

## 7. Harita Ekranı — HomeScreen

Bu ekran projenin en karmaşık parçasıdır. Adım adım inceleyelim:

### State Değişkenleri

```dart
LatLng? _center;                    // Haritanın merkez koordinatı
bool _locationUnavailable = false;  // GPS alınamadıysa true
List<NearbyPlace> _nearbyPlaces = [];    // Overpass'tan gelen yerler
bool _nearbyPlacesFailed = false;        // API çağrısı başarısız olduysa
List<AppUser> _friendLocations = [];     // Konum paylaşan arkadaşlar
```

### `_resolveLocation()` — Başlatma Zinciri

```dart
Future<void> _resolveLocation() async {
  final location = await LocationService().getCurrentLocation();  // ①
  if (!mounted) return;                                            // ②
  final center = location ?? _fallbackCenter;                      // ③
  setState(() {
    _center = center;
    _locationUnavailable = location == null;
  });
  _loadNearbyPlaces(center);      // ④ — Paralel başlatma
  _syncFriendLocations(location); // ⑤ — Paralel başlatma
}
```

| # | Açıklama |
|---|----------|
| ① | GPS'ten konum al (izin iste, sensörden oku) |
| ② | Async işlem sırasında ekran kapatılmış olabilir |
| ③ | GPS alınamazsa İstanbul'u (41.0082, 28.9784) fallback olarak kullan |
| ④⑤ | `await` yok! İki metod paralel çalışır. Birinin bitmesini beklemeden diğeri başlar |

**Fallback Koordinat Kalıbı:**
```dart
const _fallbackCenter = LatLng(41.0082, 28.9784);  // İstanbul
```
- Top-level `const` olarak tanımlanmış → uygulama boyunca tek bir nesne, bellek tasarrufu
- GPS açık değilken veya izin reddedildiğinde kullanıcı boş ekran görmez, İstanbul haritasını görür

### `_syncFriendLocations()` — Arkadaş Konumlarını Çekme

```dart
Future<void> _syncFriendLocations(LatLng? realLocation) async {
  try {
    final myUid = context.read<AuthProvider>().currentUser!.uid;
    final friendsProvider = context.read<FriendsProvider>();
    final me = await friendsProvider.watchUser(myUid).first;  // ①

    if (realLocation != null && me.locationSharing) {          // ②
      await friendsProvider.updateLocation(myUid, realLocation);
    }

    final friends = await friendsProvider.getFriends(me.friends);  // ③
    final sharing = friends
        .where((f) => f.locationSharing && f.location != null)    // ④
        .toList();
    if (!mounted) return;
    setState(() => _friendLocations = sharing);
  } catch (_) {
    // Sessiz hata — harita yine de çalışsın
  }
}
```

| # | Açıklama |
|---|----------|
| ① | Stream'den `.first` ile tek seferlik okuma (Stream → Future dönüşümü) |
| ② | Gerçek konum varsa VE paylaşım açıksa → kendi konumumu Firestore'a yaz |
| ③ | Arkadaş UID'lerinden kullanıcı detaylarını çek |
| ④ | Sadece konum paylaşımı açık olan ve konumu null olmayan arkadaşları filtrele |

### FlutterMap Widget Yapısı

```dart
FlutterMap(
  options: MapOptions(initialCenter: center, initialZoom: 15),
  children: [
    TileLayer(                                          // ① Harita karoları
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MarkerLayer(markers: [                              // ② İşaretçiler
      Marker(point: center, child: Icon(Icons.my_location, color: Colors.blue)),  // Benim konumum
      for (final place in _nearbyPlaces) Marker(...),   // Yakındaki yerler
      for (final friend in _friendLocations) Marker(...), // Arkadaşlar
    ]),
  ],
)
```

**Harita Katman Hiyerarşisi:**
1. `TileLayer`: Zemin harita görselleri (OpenStreetMap tile sunucusundan çekilir)
2. `MarkerLayer`: Tile'ların üstüne yerleştirilen pin/işaretçiler

**Pin Renk Kodlaması:**
- 🔵 Mavi (`my_location`): Kullanıcının kendi konumu
- 🟢 Yeşil (`local_grocery_store`): Marketler
- 🔴 Kırmızı (`local_pharmacy`): Eczaneler
- 🟣 Mor (`person_pin_circle`): Konum paylaşan arkadaşlar

### Hata Banner'ları (Stack + Positioned)

```dart
Stack(
  children: [
    FlutterMap(...),                    // Harita tam ekran
    if (_locationUnavailable)           // Turuncu uyarı
      Positioned(top: 0, left: 0, right: 0, child: Material(...)),
    if (_nearbyPlacesFailed)            // Kırmızı uyarı
      Positioned(top: _locationUnavailable ? 48 : 0, ...),
  ],
)
```

- `Stack`: Widget'ları üst üste koyar (z-index mantığı)
- `Positioned`: Stack içinde kesin konumlandırma
- İki hata aynı anda olursa `top: 48` ile üst üste binmelerini önler
- `if` ile conditional rendering: hata yoksa banner hiç build edilmez

---

## 8. Profil Ekranı — ProfileScreen

### StreamBuilder ile Canlı Profil

```dart
StreamBuilder<AppUser>(
  stream: context.read<FriendsProvider>().watchUser(myUid),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final me = snapshot.data!;
    return ListView(...);
  },
)
```

- Kullanıcı başka cihazdan profil güncellese bile bu ekran anlık yenilenir
- `watchUser` stream döndürür → Firestore'daki her değişiklikte builder tekrar çalışır

### Fotoğraf Seçme — `_pickPhoto()`

```dart
Future<void> _pickPhoto(String myUid) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 200,            // ① Boyut sınırı
    maxHeight: 200,
    imageQuality: 60,         // ② Kalite sınırı (%60)
  );
  if (picked == null) return;
  final bytes = await picked.readAsBytes();        // ③ Byte dizisi oku
  final base64Photo = base64Encode(bytes);         // ④ Base64'e çevir
  await context.read<FriendsProvider>().updatePhoto(myUid, base64Photo);  // ⑤ Firestore'a yaz
}
```

| # | Açıklama |
|---|----------|
| ① | 200x200 piksel → Firestore doküman boyutunu düşük tutmak için |
| ② | %60 JPEG kalitesi → dosya boyutunu ~%40 azaltır |
| ③ | Dosyayı bellekte byte array olarak okur |
| ④ | Binary veriyi ASCII-safe Base64 string'e çevirir |
| ⑤ | String olarak Firestore dokümanına yazılır |

**Base64 Nedir?**
- Binary veriyi (resim, dosya) 64 ASCII karakterle temsil eden kodlama
- Her 3 byte → 4 karakter olur → dosya boyutu ~%33 artar
- Avantaj: Herhangi bir metin alanında (Firestore string, JSON, URL) saklanabilir
- Dezavantaj: Boyut artışı, Firestore 1MB doküman limiti

### Arkadaş Arama ve Ekleme UI Akışı

```
Kullanıcı adı yazar → 🔍 butonuna basar → _search() çağrılır
→ Firestore prefix query → Sonuçlar _searchResults'a yazılır
→ Her sonuç için "Ekle" butonu gösterilir
→ "Ekle" → _addFriend() → Batch write → Listeler temizlenir
```

### `context.watch` vs `context.read` Kullanımı

```dart
final myUid = context.watch<AuthProvider>().currentUser!.uid;  // watch: rebuild tetikler
```

**Neden burada `watch`?** Oturum değişirse (logout gibi) bu ekranın da rebuild olması gerekir. `read` kullansak logout'ta eski UID'yi tutmaya devam ederdi.

---

## 9. Servisler — LocationService & OverpassService

### LocationService — GPS Erişim Katmanı

```dart
Future<LatLng?> getCurrentLocation() async {
  // 1. Konum servisleri (GPS) açık mı kontrol et
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  // 2. İzin durumunu kontrol et
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();  // İzin iste (popup)
  }
  
  // 3. İzin kesin reddedildiyse (bir daha sorma) → null dön
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  // 4. GPS'ten konum al
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return LatLng(position.latitude, position.longitude);
}
```

**İzin Akışı (Permission Flow):**
```
isLocationServiceEnabled? → hayır → null (GPS kapalı)
                          → evet ↓
checkPermission → denied → requestPermission (popup göster) → denied/deniedForever → null
                                                             → granted ↓
                → granted ↓
getCurrentPosition → LatLng döner
```

**`LocationAccuracy.high`:**  GPS + Wi-Fi + Cell Tower triangulation kullanarak en hassas konumu alır (±3-5 metre). `low` kullanılsaydı sadece Cell Tower ile ~500m hassasiyet olurdu.

### OverpassService — Yakındaki Yerler API'si

```dart
class NearbyPlace {
  final String name;
  final String type;      // 'supermarket' veya 'pharmacy'
  final LatLng location;
}

class OverpassException implements Exception {
  final String message;
  OverpassException(this.message);
}
```

**Özel Exception Sınıfı Neden Var?**
- `catch (e)` ile genel hata yakalamak yerine, spesifik `on OverpassException` ile yakalayabiliriz
- UI katmanında farklı hata tiplerini farklı şekilde ele alabiliriz
- Kod okunabilirliğini artırır: "Bu catch bloğu sadece Overpass hatalarını yakalar"

### Overpass QL Sorgusu

```
[out:json][timeout:25];
(
  node["shop"="supermarket"](around:1500,41.0082,28.9784);
  node["amenity"="pharmacy"](around:1500,41.0082,28.9784);
);
out body;
```

**Satır satır:**
- `[out:json]`: Sonucu JSON formatında döndür (XML yerine)
- `[timeout:25]`: 25 saniye içinde yanıt gelmezse sunucu tarafında iptal et
- `node["shop"="supermarket"]`: OSM tag sistemi — `shop` etiketi `supermarket` olan düğümleri bul
- `(around:1500,lat,lon)`: Verilen koordinattan 1500 metre yarıçapta ara
- `out body;`: Tüm tag'ları dahil ederek döndür

**Hata Yönetimi Katmanları:**
1. **HTTP timeout (client):** `.timeout(const Duration(seconds: 20))` → 20 saniye client-side limit
2. **Overpass timeout (server):** `[timeout:25]` → 25 saniye server-side limit
3. **HTTP status kontrolü:** `statusCode != 200` → OverpassException fırlatır
4. **HomeScreen catch:** `on OverpassException` → kırmızı banner gösterir

**Tag Parsing Mantığı:**
```dart
final tags = el['tags'] as Map<String, dynamic>? ?? const {};
final type = tags['shop'] == 'supermarket' ? 'supermarket' : 'pharmacy';
return NearbyPlace(
  name: tags['name'] as String? ?? (type == 'supermarket' ? 'Market' : 'Eczane'),
  ...
);
```
- OSM'de bazı yerler `name` tag'ı olmadan girilmiş olabilir → fallback isim atanır
- Sorguda sadece supermarket ve pharmacy çektiğimiz için, supermarket değilse kesinlikle pharmacy'dir

---

## 10. Widget — UserAvatar

```dart
class UserAvatar extends StatelessWidget {
  final String? photoBase64;
  final String username;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = photoBase64;
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(photo)),  // ① Base64 → Bytes → Image
      );
    }
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      child: Text(initial),   // ② Fotoğraf yoksa baş harf göster
    );
  }
}
```

**`MemoryImage(base64Decode(photo))`:**
1. `base64Decode(photo)`: Base64 string'i → `Uint8List` (byte array) dönüştürür
2. `MemoryImage(...)`: Byte array'den bir `ImageProvider` oluşturur
3. `backgroundImage`: CircleAvatar'ın arka planına yerleştirir

**Reusable Widget Tasarım Prensibi:**
- `radius` parametresi ile farklı boyutlarda kullanılabilir (profil: 40, liste: 20)
- Fotoğraf yoksa graceful degradation: baş harf gösterilir, hata fırlatılmaz
- Her yerde aynı görünüm: profil ekranı, arkadaş listesi, arama sonuçları

---

## 11. Firestore Veritabanı Tasarımı

### Neden Tek Koleksiyon (`users`)?

```
Firestore Yapısı:
users/
  ├── uid_abc123/
  │     ├── username: "akif"
  │     ├── email: "akif@example.com"
  │     ├── friends: ["uid_def456", "uid_ghi789"]
  │     ├── locationSharing: true
  │     ├── location: GeoPoint(41.0082, 28.9784)
  │     ├── locationUpdatedAt: Timestamp(...)
  │     ├── photoBase64: "iVBORw0KGgo..."
  │     └── createdAt: Timestamp(...)
  └── uid_def456/
        └── ...
```

**Avantajları:**
- Tek sorguyla tüm kullanıcı verisine ulaşılır (join yok)
- `watchUser()` ile tek doküman dinlemek ucuz ve hızlı
- Basit ve anlaşılır

**Dezavantajları (Production için):**
- `photoBase64` büyük resimler için 1MB doküman limitini aşabilir
- Arkadaş sayısı çok artarsa `friends` array'i doküman boyutunu şişirir
- Production çözümü: Alt koleksiyonlar (`users/{uid}/friends/{friendUid}`) kullanılabilir

### Neden Alt Koleksiyon Kullanmadık?

| Yaklaşım | Avantaj | Dezavantaj |
|-----------|---------|-----------|
| `friends` array (mevcut) | Tek okumada tüm arkadaş ID'leri | Max array boyutu, doküman limiti |
| `users/{uid}/friends` alt koleksiyon | Sınırsız arkadaş, pagination mümkün | Her arkadaş için ayrı okuma, maliyet artar |

Projenin ölçeğinde (staj projesi, sınırlı kullanıcı) array yaklaşımı yeterli ve daha basit.

---

## 12. Tema ve Material 3

### `colorSchemeSeed` Nasıl Çalışır?

```dart
ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true)
```

Material 3'ün HCT (Hue-Chroma-Tone) renk uzayını kullanarak tek bir seed renkten 29 farklı renk tonu üretir:

| Üretilen Renk | Kullanım |
|---------------|----------|
| `primary` | Ana butonlar, FAB |
| `onPrimary` | Primary üzerindeki metin |
| `secondary` | İkincil aksiyonlar |
| `surface` | Kart, dialog arka planları |
| `error` | Hata mesajları |
| `outline` | Border, divider |

### Dark Theme Geçişi

```dart
darkTheme: ThemeData(
  colorSchemeSeed: Colors.blue,
  brightness: Brightness.dark,    // ← Bu satır dark modda farklı tonlar üretir
  useMaterial3: true,
),
themeMode: ThemeMode.system,       // ← Cihaz ayarını takip et
```

- `Brightness.dark` ile aynı `Colors.blue` seed'inden daha koyu ve kontrast tonlar üretilir
- `ThemeMode.system`: `MediaQuery.platformBrightness` ile sistem temasını okur

---

## 13. Android Build Yapılandırması

### Gradle Yapısı

```
android/
├── build.gradle.kts       → Proje seviyesi (kullanılmıyor, settings.gradle.kts'de)
├── settings.gradle.kts    → Plugin sürümleri tanımlanır
├── gradle/wrapper/
│   └── gradle-wrapper.properties  → Gradle sürümü (8.12)
└── app/
    └── build.gradle.kts   → Uygulama seviyesi build yapılandırması
```

### Sürüm Uyumluluk Tablosu

| Araç | Sürüm | Neden Bu Sürüm? |
|------|-------|-----------------|
| Gradle | 8.12 | Flutter 3.35.x ile uyumlu |
| AGP (Android Gradle Plugin) | 8.9.1 | Gradle 8.12 ile uyumlu |
| Kotlin | 2.1.0 | AGP 8.9.1 ile uyumlu |
| Java | 11 | Minimum Android geliştirme gereksinimleri |
| compileSdk | 35 | En son Android API'lerine erişim |
| minSdk | 23 | Android 6.0+ desteklenir (~%97 cihaz) |
| targetSdk | 35 | Google Play Store gereksinimleri |

---

## 14. Olası Mülakat Soru-Cevapları

### S1: "Provider yerine neden Riverpod veya BLoC kullanmadın?"

> Provider, Flutter ekibinin de önerdiği ve projemizin ölçeğine uygun hafif bir çözüm. BLoC'un getireceği Event-State sınıfları bu projede gereksiz boilerplate yaratırdı. Riverpod compile-time safety sağlar ama öğrenme eğrisi daha dik. Provider iki provider'la (AuthProvider, FriendsProvider) tüm ihtiyaçları karşıladı.

### S2: "Profil fotoğrafını neden Base64 olarak tuttun?"

> Hızlı prototipleme için. Firebase Storage ayrı bir SDK kurup, upload/download URL yönetimi gerektirir. Base64 ile tek bir Firestore alanında tutarak tek sorguda fotoğrafı da çektik. **Ama production'da bunu yapmam.** Çünkü:
> 1. Firestore doküman limiti 1MB
> 2. Base64 dosya boyutunu %33 artırır
> 3. Firestore okuma/yazma maliyetleri byte bazlı
>
> Production çözümü: Firebase Storage'a upload → URL'yi Firestore'da sakla → `CachedNetworkImage` ile göster

### S3: "Firestore'da LIKE sorgusu nasıl yaptın?"

> Firestore doğrudan text search veya LIKE desteklemez. Prefix arama için Unicode range query tekniği kullandım. `\uf8ff` Unicode Private Use Area'daki son karakter olduğu için, `where >= "ak"` ve `where <= "ak\uf8ff"` ile "ak" ile başlayan tüm stringleri çekebiliyoruz.

### S4: "Batch Write ile Transaction arasındaki fark nedir?"

> İkisi de atomiktir. **Batch** sadece yazma işlemi yapar, okuma gerekmez. **Transaction** önce okur, okuduğu veriye göre yazma kararı verir. Biz arkadaş eklerken `FieldValue.arrayUnion` kullandığımız için sunucu tarafında idempotent ekleme yapılır, mevcut veriyi okumaya gerek kalmaz. Bu yüzden Batch daha performanslı.

### S5: "Haritadaki arkadaş konumları gerçek zamanlı mı güncelleniyor?"

> Şu anki implementasyonda tam gerçek zamanlı değil. HomeScreen açıldığında `_syncFriendLocations` bir kere çalışır. Ama profil ekranında `watchUser` stream'i ile canlı veri akışı kurulu. Production'da HomeScreen'de de bir Timer veya stream ile periyodik güncelleme yapılabilir.

### S6: "WidgetsFlutterBinding.ensureInitialized() neden gerekli?"

> `main()` fonksiyonu `async` olduğunda ve `runApp()` öncesinde platform kanallarını (MethodChannel) kullanan bir operasyon yapıyorsak (Firebase.initializeApp gibi), Flutter engine'inin başlatılmış olması gerekir. Bu metod, binding'i garanti altına alır.

### S7: "OpenStreetMap kullanmanın avantajı/dezavantajı nedir?"

> **Avantaj:** Tamamen ücretsiz, API anahtarı gerektirmez, açık veri. Google Maps'in aksine kullanım limitinden ötürü ücretlendirilmezsin.
> **Dezavantaj:** Google Maps kadar detaylı değil (Türkiye'de bazı yerler eksik olabilir), trafik bilgisi yok, Street View yok, geocoding için ayrı servis gerekir.

### S8: "whereIn sorgusunun 10 limiti ne anlama geliyor?"

> Firestore `whereIn` sorgusunda tek seferde max 30 (eski sürümlerde 10) eleman sorgulanabilir. Biz güvenli tarafta kalmak için 10 aldık. 10'dan fazla arkadaşı olan kullanıcı için çözüm: UID listesini 10'arlık parçalara bölüp (chunking) `Future.wait` ile paralel sorgular yapmak.

### S9: "Neden single collection kullandın, alt koleksiyon neden kullanmadın?"

> Tek koleksiyon, bu proje ölçeğinde her şeyi tek okumada getirme avantajı sağlıyor. Alt koleksiyonlar daha büyük projelerde (binlerce arkadaş, mesaj geçmişi gibi) gerekli olurdu. Firestore'da join operasyonu olmadığı için, veriyi mümkün olduğunca flat (düz) tutmak sorgu maliyetini düşürür.

### S10: "Bu projeyi production'a çıkarsaydın ilk 3 değişikliğin ne olurdu?"

> 1. **Firebase Storage geçişi** — Profil fotoğrafları için
> 2. **Arkadaşlık istek sistemi** — Doğrudan eklemek yerine pending/accepted mekanizması
> 3. **Geohash tabanlı spatial query** — Binlerce kullanıcıda tüm arkadaşları çekmek yerine sadece yakındakileri sorgulamak
