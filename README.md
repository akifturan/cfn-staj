# 📍 Yakında

Canlı konum paylaşımı, yakındaki yerler ve arkadaş takip sistemi sunan Flutter & Firebase mobil uygulaması.

---

## Özellikler

- **Kimlik Doğrulama** — Firebase Auth ile e-posta/şifre tabanlı kayıt & giriş
- **Canlı Harita** — OpenStreetMap + `flutter_map` ile dinamik harita arayüzü
- **GPS Konum Takibi** — `geolocator` ile yüksek hassasiyetli konum alma ve izin yönetimi
- **Yakındaki Yerler** — Overpass API ile market ve eczane sorgulama (yeşil/kırmızı pin)
- **Arkadaşlık Sistemi** — Prefix-tabanlı kullanıcı arama ve atomic batch write ile karşılıklı arkadaş ekleme
- **Gerçek Zamanlı Konum Paylaşımı** — Arkadaşların haritada anlık konumlarını mor pin ile görme
- **Profil Fotoğrafı** — Galeriden seçim, Base64 olarak Firestore'da saklama
- **Otomatik Tema** — Material 3 ile sistem temasına göre Light/Dark geçişi

---

## Teknoloji Yığını

| Paket | Sürüm | Açıklama |
|:---|:---|:---|
| Flutter SDK | `>=3.35.0` | Cross-platform framework |
| Dart SDK | `^3.9.0` | Dil ve çalışma zamanı |
| firebase_core | `^4.13.0` | Firebase başlatma |
| firebase_auth | `^6.5.7` | Oturum yönetimi |
| cloud_firestore | `^6.8.0` | Gerçek zamanlı NoSQL veritabanı |
| provider | `^6.1.5+1` | State management |
| flutter_map | `^8.3.1` | OpenStreetMap harita widget'ı |
| latlong2 | `^0.10.1` | Coğrafi koordinat hesaplamaları |
| geolocator | `^14.0.2` | GPS konum servisi |
| http | `^1.6.0` | HTTP istemcisi |
| image_picker | `1.2.2` | Galeri/kamera erişimi |

### Android Build Araçları

| Araç | Sürüm |
|:---|:---|
| Gradle | `8.12` |
| Android Gradle Plugin (AGP) | `8.9.1` |
| Kotlin | `2.1.0` |
| Java Uyumluluk | `11` |

---

## Proje Yapısı

```
lib/
├── main.dart                  # Uygulama giriş noktası, Provider & Tema
├── firebase_options.dart      # Firebase platform konfigürasyonu
│
├── models/
│   └── app_user.dart          # Firestore → Dart veri modeli
│
├── providers/
│   ├── auth_provider.dart     # Auth state yönetimi
│   └── friends_provider.dart  # Arkadaşlık & konum paylaşma
│
├── screens/
│   ├── auth_gate.dart         # Oturum yönlendirme
│   ├── root_shell.dart        # Bottom navigation scaffold
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart   # Harita ekranı
│   └── profile/
│       └── profile_screen.dart
│
├── services/
│   ├── location_service.dart  # GPS servisi
│   └── overpass_service.dart  # Overpass API servisi
│
└── widgets/
    └── user_avatar.dart       # Avatar bileşeni
```

---

## Firestore Şeması

**Koleksiyon:** `/users/{uid}`

| Alan | Tip | Açıklama |
|:---|:---|:---|
| `username` | String | Kullanıcı adı |
| `email` | String | E-posta |
| `friends` | List\<String\> | Arkadaş UID listesi |
| `locationSharing` | Boolean | Konum paylaşım durumu |
| `location` | GeoPoint | Enlem/boylam |
| `locationUpdatedAt` | Timestamp | Son konum güncelleme zamanı |
| `photoBase64` | String? | Base64 profil fotoğrafı |
| `createdAt` | Timestamp | Hesap oluşturulma tarihi |

---

## Kurulum

```bash
# 1. Bağımlılıkları yükle
flutter pub get

# 2. Fiziksel cihazda çalıştır (önerilen)
flutter run

# 3. Veya emulator ile
emulator -avd <emulator_adi>
flutter run
```

> **Not:** Firebase yapılandırma dosyaları (`firebase_options.dart`, `google-services.json`) depoda mevcuttur. Ekstra kurulum gerekmez.

---

## Test Hesapları

| Hesap | E-posta | Şifre |
|:---|:---|:---|
| Kullanıcı 1 | `test1@yakinda.com` | `test123456` |
| Kullanıcı 2 | `test2@yakinda.com` | `test123456` |

İki farklı cihazda giriş yapıp **Profil → Konum Paylaş** seçeneğini aktifleştirerek birbirinizi haritada takip edebilirsiniz.

---

## Mimari Kararlar

### Neden Provider?
Projenin ölçeğinde BLoC'un getirdiği boilerplate gereksiz. Provider, Flutter ekibinin önerdiği hafif bir DI & state management çözümü.

### Neden Base64 Profil Fotoğrafı?
Hızlı prototipleme için tercih edildi. **Production'da** Firebase Storage + `CachedNetworkImage` kullanılmalı. Firestore doküman limiti 1MB ve Base64 dosya boyutunu ~%33 artırır.

### Neden Batch Write?
Arkadaş ekleme iki dokümanı günceller. Okuma gerektirmediği için Transaction yerine daha performanslı olan Batch Write tercih edildi.

### Neden Overpass API?
Google Maps API ücretli. OpenStreetMap verileri üzerinden Overpass QL ile ücretsiz, hızlı mekansal sorgulama yapılıyor.

---

## Gelecek İyileştirmeler

- [ ] Firebase Storage'a geçiş (profil fotoğrafları)
- [ ] Geohash tabanlı coğrafi sorgular (`geoflutterfire2`)
- [ ] Arka plan konum takibi (`flutter_background_service`)
- [ ] Arkadaşlık istek sistemi (pending/accepted)
- [ ] Unit & integration test kapsamı
