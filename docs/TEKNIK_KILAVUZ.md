# 📖 Circle — Teknik Çalışma Kılavuzu

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
9. [Hava Durumu Ekranı — WeatherScreen](#9-hava-durumu-ekranı--weatherscreen)
10. [Oyun Ekranı — GameScreen (Nefes Tutma Yarışı)](#10-oyun-ekranı--gamescreen-nefes-tutma-yarışı)
11. [Servisler — LocationService, OverpassService, WeatherService & GeocodingService](#11-servisler--locationservice-overpassservice-weatherservice--geocodingservice)
12. [Widget'lar — UserAvatar & AppMark](#12-widgetlar--useravatar--appmark)
13. [Firestore Veritabanı Tasarımı](#13-firestore-veritabanı-tasarımı)
14. [Tema ve Material 3](#14-tema-ve-material-3)
15. [Android Build Yapılandırması](#15-android-build-yapılandırması)
16. [Olası Mülakat Soru-Cevapları](#16-olası-mülakat-soru-cevapları)

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
  final int? breathHoldBestMs;   // ⑦ Nefes tutma oyunu — kişisel rekor (ms)
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
    breathHoldBestMs: (data['breathHoldBestMs'] as num?)?.toInt(),  // ⑦
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
| ⑦ | `(data[...] as num?)?.toInt()` | Firestore sayısal alanları platforma göre `int` veya `double` gelebilir; `num?` ile ikisini de kabul edip `toInt()` ile normalize ediyoruz. Oyun hiç oynanmadıysa alan yok → `null` |

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

### 4.7 `updateBreathHoldRecord` — Oyun Rekoru Kaydetme

```dart
Future<void> updateBreathHoldRecord(String uid, int ms) async {
  await _firestore.collection('users').doc(uid).update({
    'breathHoldBestMs': ms,
  });
}
```

- Nefes tutma oyununda (bkz. [Bölüm 10](#10-oyun-ekranı--gamescreen-nefes-tutma-yarışı)) tur bitince `GameScreen`, önce kullanıcının mevcut rekorunu okur, yeni süre daha yüksekse bu metodu çağırır
- Kontrol client tarafında yapılır (yeni süre eski rekordan büyük mü) — sunucu tarafında bir `max()` garantisi yoktur, bu yüzden yarış koşulu (race condition) teorik olarak mümkündür ama tek kullanıcı kendi rekorunu yazdığı için pratikte risksizdir

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
  static const _screens = [
    HomeScreen(), WeatherScreen(), GameScreen(), ProfileScreen(),  // ①
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),        // ②
      bottomNavigationBar: NavigationBar(                           // ③
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),   // ④
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Harita'),
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Hava Durumu'),
          NavigationDestination(icon: Icon(Icons.air_outlined), selectedIcon: Icon(Icons.air), label: 'Oyun'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
```

| # | Açıklama |
|---|----------|
| ① | `static const`: 4 ekran sabittir, her tab değişiminde yeniden oluşturulmaz → performans |
| ② | `IndexedStack`, `_screens[_index]`'in aksine **tüm ekranları aynı anda ağaçta tutar**, sadece görünen olanı değiştirir. Böylece Hava Durumu ekranı geri sekmeye geçilip dönüldüğünde tekrar API çağrısı yapmaz, state'i korunur |
| ③ | `NavigationBar`, Material 3'ün alt navigasyon bileşeni — eski `BottomNavigationBar`'ın yerini alır, seçili öğeyi pill-shaped bir arka planla vurgular |
| ④ | Tab'a tıklanınca `setState` ile index güncellenir → build yeniden çalışır → `IndexedStack` doğru ekranı öne getirir |

**StatefulWidget neden burada gerekli?** `_index` değişkeni state'tir. Tab seçimi değiştiğinde UI'ın güncellenmesi gerekir. StatelessWidget'ta `setState` çağıramazsın.

**`IndexedStack` vs doğrudan `_screens[_index]` (Kritik Mülakat Sorusu):** `_screens[_index]` her tab değişiminde eski ekranı `dispose` edip yeniyi `initState`'ten kurar — Hava Durumu ekranındaki `initState`'te tetiklenen API çağrısı her sekme değişiminde tekrar çalışırdı. `IndexedStack` tüm çocukları canlı tutar, sadece `Offstage` benzeri bir mekanizmayla gizler; bellek maliyeti biraz daha yüksektir ama state kaybı ve gereksiz network çağrısı olmaz.

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

## 9. Hava Durumu Ekranı — WeatherScreen

**Dosya:** `lib/screens/weather/weather_screen.dart`

### Yükleme Akışı — `_load()`

```dart
Future<void> _load() async {
  setState(() { _loading = true; _failed = false; });
  final location = await LocationService().getCurrentLocation() ?? _fallbackCenter;   // ①

  try {
    final results = await Future.wait([                        // ②
      WeatherService().fetchCurrentWeather(location),
      GeocodingService().reverseGeocode(location),
    ]);
    final weather = results[0] as WeatherInfo;
    final locationInfo = results[1] as LocationInfo?;
    setState(() {
      _weather = weather;
      _locationDisplay = locationInfo?.displayName;
      _lastUpdated = DateTime.now();
      _loading = false;
    });
    _fadeController.forward();                                 // ③
  } on WeatherException {
    setState(() { _failed = true; _loading = false; });         // ④
  }
}
```

| # | Açıklama |
|---|----------|
| ① | Konum bulunamazsa (izin yok, GPS kapalı) İstanbul fallback koordinatı kullanılır — `HomeScreen`'deki aynı desen tekrar kullanılıyor |
| ② | `Future.wait`: Hava durumu ve ters coğrafi kodlama (şehir/ilçe adı) **paralel** çekilir. Sırayla (`await` + `await`) yapılsaydı toplam süre iki isteğin toplamı olurdu, paralelde en yavaş isteğin süresi kadar sürer |
| ③ | Veri geldiğinde `AnimationController.forward()` ile `FadeTransition` tetiklenir — içerik aniden değil yumuşak biçimde belirir |
| ④ | Sadece hava durumu isteği (`WeatherException`) başarısız olursa hata ekranı gösterilir. Geocoding `null` dönerse (bkz. [Bölüm 11.3](#11-servisler--locationservice-overpassservice-weatherservice--geocodingservice)) uygulama konum etiketini basitçe göstermez, çökmez |

### Duruma Göre Gradient Arka Plan

```dart
List<Color> _gradientForWeatherCode(String? description) {
  final desc = description?.toLowerCase() ?? '';
  if (desc.contains('açık')) return [Color(0xFF4FC3F7), Color(0xFF0288D1)];   // Güneşli — mavi
  if (desc.contains('bulutlu')) return [Color(0xFF90A4AE), Color(0xFF546E7A)]; // Gri
  if (desc.contains('yağmur')) return [Color(0xFF5C6BC0), Color(0xFF283593)];  // Lacivert
  if (desc.contains('kar')) return [Color(0xFFB3E5FC), Color(0xFF81D4FA)];     // Açık mavi
  if (desc.contains('fırtına')) return [Color(0xFF37474F), Color(0xFF1A237E)]; // Koyu
  if (desc.contains('sis')) return [Color(0xFFB0BEC5), Color(0xFF78909C)];     // Gri-mavi
  return [Color(0xFF4FC3F7), Color(0xFF0288D1)];   // Varsayılan
}
```

- `AnimatedContainer` içinde kullanılır → hava durumu değiştiğinde arka plan renkleri **800ms**'de yumuşakça geçiş yapar, aniden değişmez
- Metin karşılaştırması Türkçe açıklama string'i üzerinden yapılır (WMO kodları zaten `WeatherService` içinde Türkçe açıklamaya çevrilmiş durumda)

### Glassmorphism Sıcaklık Kartı

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),      // ①
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),        // ②
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(children: [Text('${weather.temperatureCelsius.round()}°C'), Text(weather.description)]),
    ),
  ),
)
```

| # | Açıklama |
|---|----------|
| ① | `BackdropFilter` + `ImageFilter.blur`: Kartın **arkasındaki** gradient'i bulanıklaştırır — buzlu cam efekti (glassmorphism) |
| ② | Kartın kendisi yarı saydam beyaz (`alpha: 0.15`) — bulanık arka plan üzerinde "cam panel" hissi verir |

**`RefreshIndicator` ile Yenileme:** Ekran `RefreshIndicator(onRefresh: _load, ...)` ile sarılı — aşağı çekince `_load()` tekrar çalışır, tıpkı native hava durumu uygulamalarındaki gibi.

---

## 10. Oyun Ekranı — GameScreen (Nefes Tutma Yarışı)

**Dosya:** `lib/screens/game/game_screen.dart`

Basit ama tüm state yönetimi kalıplarını (Timer, GestureDetector, async Firestore yazma, stream+future birleşimi) bir arada gösteren küçük bir mini oyun.

### Basılı Tutma Mekaniği

```dart
void _onTapDown(TapDownDetails _) {
  setState(() { _holding = true; _elapsedMs = 0; _startTime = DateTime.now(); });  // ①
  _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {                  // ②
    setState(() => _elapsedMs = DateTime.now().difference(_startTime!).inMilliseconds);
  });
}

void _onTapUp(TapUpDetails _) => _stopHolding();
void _onTapCancel() => _stopHolding();   // ③
```

| # | Açıklama |
|---|----------|
| ① | Parmak ekrana değdiği an gerçek başlangıç zamanı (`DateTime.now()`) kaydedilir — sayaç bu referanstan hesaplanır |
| ② | `Timer.periodic(100ms)`: Ekranda gösterilen süreyi her 100ms'de bir günceller. **Not:** Bu sadece görsel bir yenileme — gerçek süre her zaman `DateTime.now().difference(_startTime!)` ile hesaplanır, Timer'ın kendi periyodu birikerek hata payı yaratmaz |
| ③ | `onTapCancel`: Kullanıcı parmağını ekran dışına kaydırırsa da (örneğin bildirim çekmecesini açarsa) tutma işlemi güvenli şekilde sonlanır — `onTapUp` tetiklenmez ama `onTapCancel` tetiklenir |

**Neden `Timer.periodic` ile `_elapsedMs`'i her 100ms'de yeniden hesaplıyoruz, biriktirmiyoruz?** `elapsedMs += 100` yaklaşımı kullansaydık, `setState`/timer callback'lerinin gerçek zamanlayıcı hassasiyeti (event loop yoğunluğu, GC duraklamaları) yüzünden gerçek süreden sapardı. `DateTime.now().difference(_startTime!)` her seferinde **gerçek** geçen süreyi verir — Timer sadece "ne zaman yeniden çizeceğini" tetikler, süreyi kendisi tutmaz.

### Rekor Kaydetme

```dart
Future<void> _stopHolding() async {
  _timer?.cancel();
  final finalMs = DateTime.now().difference(_startTime!).inMilliseconds;   // ① Son kez kesin hesap
  setState(() { _holding = false; _elapsedMs = finalMs; });

  final me = await friendsProvider.watchUser(myUid).first;                 // ②
  if (finalMs > (me.breathHoldBestMs ?? 0)) {                              // ③
    await friendsProvider.updateBreathHoldRecord(myUid, finalMs);
    setState(() => _isNewRecord = true);
  }
}
```

| # | Açıklama |
|---|----------|
| ① | Parmak kalktığı an son kez tam hassasiyetle hesaplanır — `Timer`'ın son 100ms'lik gecikmesinden etkilenmez |
| ② | `watchUser(uid).first`: Bir stream'i tek seferlik `Future`'a çevirme kalıbı — `FriendsProvider`'da zaten var olan gerçek zamanlı stream'i tekrar yazmaya gerek kalmadan yeniden kullanır |
| ③ | Rekor kontrolü **client tarafında**: mevcut en iyi süre `null` ise (`?? 0`) her sonuç yeni rekor sayılır |

### Liderlik Tablosu — Stream + Future Birleşimi

```dart
StreamBuilder<AppUser>(
  stream: friendsProvider.watchUser(myUid),              // ① Kendi profilimi canlı dinle
  builder: (context, snapshot) {
    final me = snapshot.data!;
    return FutureBuilder<List<AppUser>>(
      future: friendsProvider.getFriends(me.friends),    // ② Arkadaşları tek seferlik çek
      builder: (context, friendsSnapshot) {
        final allPlayers = [me, ...friendsSnapshot.data ?? const []];
        allPlayers.sort((a, b) {                          // ③ Yüksekten düşüğe, null'lar en sona
          if (a.breathHoldBestMs == null) return 1;
          if (b.breathHoldBestMs == null) return -1;
          return b.breathHoldBestMs!.compareTo(a.breathHoldBestMs!);
        });
        return ListView.builder(...);
      },
    );
  },
)
```

| # | Açıklama |
|---|----------|
| ① | Dış `StreamBuilder`, kendi rekorum her değiştiğinde (yeni rekor kaydedince) otomatik rebuild olur |
| ② | İç `FutureBuilder`, arkadaş listesini asenkron çeker — arkadaş sayısı değişmediği sürece bu veri değişmez |
| ③ | Sıralama mantığı: iki taraf da `null` → eşit; sadece `a` null → `a` sona; sadece `b` null → `b` sona; ikisi de dolu → büyükten küçüğe |

**Bilinen küçük iyileştirme alanı:** İç `FutureBuilder`'ın `future:` parametresi, dış `StreamBuilder` her rebuild olduğunda (yani her yeni rekorda) yeniden oluşturulur — bu, arkadaş listesini gereksiz yere tekrar çekmesine yol açabilir. Küçük arkadaş listelerinde (staj projesi ölçeği) fark edilmez; production'da `getFriends` sonucu `initState`'te bir kere çekilip state'te tutulur, sadece gerektiğinde yenilenirdi.

---

## 11. Servisler — LocationService, OverpassService, WeatherService & GeocodingService

### 11.1 LocationService — GPS Erişim Katmanı

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

### 11.2 OverpassService — Yakındaki Yerler API'si

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
1. **HTTP timeout (client):** `.timeout(const Duration(seconds: 30))` → 30 saniye client-side limit (sunucu limitinden **büyük** olmalı — aksi halde client, sunucu daha cevap veremeden isteği kendisi iptal eder)
2. **Overpass timeout (server):** `[timeout:25]` → 25 saniye server-side limit
3. **Retry + backoff:** `overpass-api.de` ücretsiz/paylaşımlı bir servis olduğu için ara sıra `429 Too Many Requests` veya yavaş cevap dönebilir. `fetchNearbyPlaces`, `maxAttempts = 3` ile dener; her denemede `attempt * 2` saniye bekler (2s → 4s), son denemede de başarısız olursa `OverpassException` fırlatır
4. **HTTP status kontrolü:** `statusCode != 200` → `OverpassException` fırlatır
5. **HomeScreen catch:** `on OverpassException` → kırmızı banner + manuel **"Tekrar Dene"** butonu gösterir (kullanıcı retry döngüsünü tekrar tetikleyebilir)

**Neden client timeout > server timeout olmalı?** İlk sürümde client timeout (20s), Overpass sorgusunun kendi `[timeout:25]` değerinden **küçüktü** — yani sunucu daha cevap üretemeden istemci bağlantıyı kesiyordu. Bu, "Yakındaki yerler yüklenemedi" hatasının sık görülmesinin asıl nedeniydi. Client timeout'u 30s'ye çekmek + retry eklemek bu sorunu çözdü.

### 11.3 WeatherService — Anlık Hava Durumu

**Dosya:** `lib/services/weather_service.dart`

```dart
Future<WeatherInfo> fetchCurrentWeather(LatLng location, {int maxAttempts = 3}) async {
  final uri = Uri.parse('https://api.open-meteo.com/v1/forecast').replace(queryParameters: {
    'latitude': '${location.latitude}', 'longitude': '${location.longitude}',
    'current': 'temperature_2m,weather_code', 'timezone': 'auto',
  });
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw WeatherException('...');
      final current = jsonDecode(response.body)['current'];
      final (description, icon) = _describeWeatherCode(current['weather_code']);   // ①
      return WeatherInfo(temperatureCelsius: current['temperature_2m'], description: description, icon: icon);
    } catch (e) {
      if (attempt == maxAttempts) throw e is WeatherException ? e : WeatherException('$e');
      await Future.delayed(Duration(seconds: attempt * 2));   // ② Aynı retry+backoff kalıbı
    }
  }
  throw WeatherException('Weather request failed');
}
```

| # | Açıklama |
|---|----------|
| ① | `(String, IconData) _describeWeatherCode(int code)`: **Dart 3 record** kullanır — iki değeri (açıklama metni + ikon) tek fonksiyondan, ayrı bir sınıf tanımlamadan döndürür. Open-Meteo, hava durumunu [WMO kodları](https://open-meteo.com/en/docs) (0 = açık, 61-82 = yağmur, 95-99 = fırtına vb.) ile döner; bu fonksiyon kodu Türkçe açıklama + Material ikonuna eşler |
| ② | `OverpassService` ile **birebir aynı** retry+backoff deseni — kod tekrarı gibi görünse de, iki servis farklı domain hatalarına (`WeatherException` vs `OverpassException`) sahip olduğu için ayrı tutuldu. Ortak bir `RetryableHttpClient` yardımcı sınıfı çıkarmak production'da mantıklı bir refactor olurdu |

**Neden Open-Meteo?** API anahtarı gerektirmez (OpenStreetMap gibi ücretsiz ve açık), `current` parametresiyle tek istekte anlık sıcaklık + hava kodu döner, projedeki "API key yönetmeden hızlı prototipleme" prensibiyle örtüşür.

### 11.4 GeocodingService — Ters Coğrafi Kodlama

**Dosya:** `lib/services/geocoding_service.dart`

```dart
Future<LocationInfo?> reverseGeocode(LatLng location, {int maxAttempts = 3}) async {
  final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(queryParameters: {
    'lat': '${location.latitude}', 'lon': '${location.longitude}',
    'format': 'json', 'accept-language': 'tr', 'zoom': '10',
  });
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final response = await http.get(uri, headers: {'User-Agent': 'flutter_proje/1.0'})  // ①
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) { if (attempt == maxAttempts) return null; ... continue; }
      final address = jsonDecode(response.body)['address'];
      final city = address['province'] ?? address['state'] ?? address['city'];
      if (city == null) return null;                                                     // ②
      return LocationInfo(city: city, district: address['district'] ?? address['town'] ?? ...);
    } catch (e) {
      if (attempt == maxAttempts) return null;                                            // ③
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
  return null;
}
```

| # | Açıklama |
|---|----------|
| ① | Nominatim'in [kullanım politikası](https://operations.osmfoundation.org/policies/nominatim/) `User-Agent` header'ı **zorunlu** kılar — olmadan istekler reddedilebilir |
| ② | Adres verisinde şehir bilgisi hiç yoksa `null` döner — exception fırlatmaz |
| ③ | **Diğer servislerden farklı olarak** son denemede de başarısız olursa exception fırlatmak yerine `null` döner. **Neden?** Konum etiketi (`"Ankara, Yenimahalle"`) sadece kozmetik bir bilgi — hava durumu ekranının asıl işlevi (sıcaklık göstermek) buna bağlı değil. `WeatherScreen`, `results[1] as LocationInfo?` ile bunu opsiyonel kabul eder; `null` gelirse konum satırını hiç göstermez, ekranın geri kalanı normal çalışmaya devam eder — **graceful degradation** |

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

## 12. Widget'lar — UserAvatar & AppMark

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

### AppMark — Marka Logosu

**Dosya:** `lib/widgets/app_mark.dart`

```dart
class AppMark extends StatelessWidget {
  final double size;
  const AppMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final scale = size / 100;                                    // ①
    final diameter = 54 * scale;
    Widget circle(double centerX, Color color, {double opacity = 1}) {
      return Positioned(
        left: centerX * scale - diameter / 2,
        top: size / 2 - diameter / 2,
        child: Opacity(
          opacity: opacity,
          child: Container(width: diameter, height: diameter,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
      );
    }
    return SizedBox(width: size, height: size, child: Stack(children: [
      circle(36, const Color(0xFF14213D)),                        // ② Lacivert daire
      circle(64, const Color(0xFF2DD4BF), opacity: 0.85),          // ③ Turkuaz daire
    ]));
  }
}
```

| # | Açıklama |
|---|----------|
| ① | Logo, 100 birimlik bir "viewBox" üzerinde tasarlandı (SVG mantığı). `scale = size / 100` ile bu tasarım istenen piksel boyutuna (`size`) orantılı biçimde ölçeklenir — 24px'de de 200px'de de aynı oranlar korunur |
| ② | Marka rengi **Lacivert** (`#14213D`) — sol daire, tam opak |
| ③ | Marka rengi **Turkuaz** (`#2DD4BF`) — sağ daire, `opacity: 0.85` ile lacivert dairenin üzerine hafif saydam bindirilir. İki dairenin kesişimi "buluşma/bağlantı" temasını simgeler — uygulamanın konum paylaşma/arkadaşlık temasıyla örtüşen bir görsel metafor |

**Neden `CustomPainter` değil de `Stack` + `Positioned`?** Logo sadece iki basit daireden oluşuyor; `CustomPainter` (canvas'a doğrudan çizim) burada gereksiz bir soyutlama olurdu. Mevcut widget'larla (`Container`, `BoxDecoration(shape: BoxShape.circle)`) aynı basit üsluba sadık kalındı — projede zaten `CustomPainter` kullanılan başka bir yer yok.

**Nerede kullanılıyor?** Login ekranındaki marka rozetinde (`AppMark(size: 56)`), önceki `Icon(Icons.explore)` placeholder'ının yerine. Uygulama ikonu (mipmap'ler) ise aynı logonun ImageMagick ile rasterize edilmiş, kirli krem arka planlı (`#FDF6EE`) 5 farklı yoğunluk (mdpi–xxxhdpi) versiyonu.

---

## 13. Firestore Veritabanı Tasarımı

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
  │     ├── breathHoldBestMs: 12800        (nullable — hiç oynamadıysa yok)
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

## 14. Tema ve Material 3

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

## 15. Android Build Yapılandırması

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

## 16. Olası Mülakat Soru-Cevapları

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

### S11: "Overpass ve Open-Meteo isteklerinde neden retry+backoff var, neden tek seferde deneyip hata göstermiyorsun?"

> `overpass-api.de` ve Open-Meteo ücretsiz/paylaşımlı public API'ler — ara sıra `429 Too Many Requests` dönebiliyorlar veya normalden yavaş cevap verebiliyorlar. Gerçek cihazda test ederken bunu doğrudan gözlemledim (curl ile tekrarlanan isteklerde değişken 2-16 saniye yanıt süreleri ve zaman zaman 429). Tek denemeyle hata göstermek yerine, `attempt * 2` saniye artan beklemeyle 3 kez deniyorum — geçici bir yoğunluk anını atlatmak için genelde yeterli. Son denemede de başarısız olursa ancak o zaman kullanıcıya hata gösteriyorum.

### S12: "GeocodingService neden hata durumunda exception fırlatmak yerine null dönüyor?"

> Çünkü konum etiketi (`"Ankara, Yenimahalle"`) hava durumu ekranının **kritik olmayan** bir parçası — sadece kozmetik bilgi. `WeatherService` başarısız olursa ekranın asıl amacı (sıcaklık göstermek) çöker, bu yüzden orada exception fırlatıp hata ekranı gösteriyorum. Ama geocoding başarısız olursa uygulamanın konum satırını göstermeden devam etmesi kullanıcı deneyimi açısından çok daha iyi — bu **graceful degradation** prensibi.

### S13: "IndexedStack kullanmasaydın ne olurdu?"

> `RootShell`, 4 ekranı `IndexedStack` içinde tutuyor, `_screens[_index]` gibi direkt indeksleme yapmıyor. Eğer direkt indeksleme yapsaydım, her sekme değişiminde eski ekran `dispose` edilir, yenisi sıfırdan `initState`'ten kurulurdu. Bu, Hava Durumu sekmesinde her seferinde yeniden API çağrısı yapılması (gereksiz network trafiği + kullanıcının her seferinde loading spinner görmesi) ve Oyun sekmesinde elde tutulmakta olan basılı-tutma state'inin sekme değişince sıfırlanması gibi sorunlara yol açardı. `IndexedStack` tüm ekranları canlı tutarak bunu önlüyor; bedeli biraz daha fazla bellek kullanımı.
