# 📍 Yakında — Canlı Konum, Yakındaki Yerler ve Arkadaşlar (Flutter & Firebase)

Bu proje; kullanıcıların canlı konumlarını harita üzerinde gösteren, yakındaki market ve eczaneleri listeleyen, arkadaş ekleme ve gerçek zamanlı (real-time) konum paylaşma yeteneklerine sahip modern bir Flutter mobil uygulamasıdır. 

Bu döküman, projenin tüm teknik altyapısını, mimari kararlarını ve veritabanı şemasını detaylıca açıklamakta olup, **teknik iş mülakatlarına hazırlık** amacıyla bir ders notu/çalışma kılavuzu niteliğinde hazırlanmıştır.

---

## 🚀 Proje Genel Bakış & Temel Özellikler

*   **Firebase Kimlik Doğrulama (Auth):** E-posta ve şifre ile güvenli kayıt olma, giriş yapma ve çıkış yapma mekanizması.
*   **Gerçek Zamanlı Harita:** OpenStreetMap altyapısı ve `flutter_map` paketi kullanılarak oluşturulmuş dinamik harita arayüzü.
*   **Canlı Konum Takibi:** `geolocator` kütüphanesi kullanılarak yüksek hassasiyetli GPS verisi alma ve konum izinlerinin dinamik yönetimi.
*   **Overpass API Entegrasyonu:** Kullanıcının etrafındaki market (`supermarket`) ve eczaneleri (`pharmacy`) OpenStreetMap verilerinden canlı olarak sorgulama ve haritaya yeşil/kırmızı pinler olarak yerleştirme.
*   **Arkadaşlık Sistemi:** Kullanıcı adına göre prefix-tabanlı arama yapma, karşılıklı arkadaş ekleme (atomic batch write ile) ve arkadaş listesi oluşturma.
*   **Gerçek Zamanlı Konum Paylaşımı (Sync):** Kullanıcının isteğe bağlı olarak konum paylaşımını açıp kapatabilmesi, açık olduğunda konumunun Firestore üzerinde güncellenmesi ve arkadaşlarının haritalarında anlık (purple pin) belirmesi.
*   **Profil Yönetimi:** Profil fotoğrafını galeriden seçip Base64 formatına çevirerek Firestore üzerinde saklama.
*   **Sistem Teması Desteği:** Material 3 standartlarında, sistem ayarlarına göre otomatik değişen Açık (Light) ve Koyu (Dark) tema entegrasyonu.

---

## 🔑 GitHub Ziyaretçileri için Giriş ve Test Yöntemi

Bu projeyi GitHub üzerinden inceleyen bir mülakatçı veya geliştirici, uygulamayı kendi ortamında ayağa kaldırdığında sistemi kolayca test edebilir:

1. **Hazır Firebase Yapılandırması:** Proje içerisindeki `lib/firebase_options.dart` ve `android/app/google-services.json` yapılandırma dosyaları depoda (repository) hazır olarak sunulmuştur. Bu dosyalar istemci taraflı (client-side) tanımlayıcılar olup gizli anahtar (secret key) barındırmazlar. Dolayısıyla, projeyi klonlayan herkes ekstra bir Firebase kurulumu yapmadan **doğrudan sizin Firebase projenize** bağlanarak uygulamayı çalıştırabilir.
2. **Yeni Kayıt Oluşturma:** Uygulama açıldığında gelen giriş ekranındaki **"Kayıt Ol"** butonu kullanılarak saniyeler içinde yeni bir test hesabı açılabilir ve sisteme dahil olunabilir.
3. **Karşılıklı Canlı Konum Takibi Testi (Önerilen Yöntem):** Canlı konum paylaşımını ve haritada arkadaş takibini tek bir cihazla test etmek zor olabileceğinden, Firebase Console veya uygulama üzerinden aşağıdaki gibi iki adet hazır test hesabı oluşturup birbirine arkadaş olarak eklemeniz önerilir. Bu hesapları README'de bu şekilde listeleyerek mülakatçının doğrudan giriş yapmasını sağlayabilirsiniz:
   * **1. Test Kullanıcısı:**
     * **E-posta:** `test1@yakinda.com`
     * **Şifre:** `test123456`
   * **2. Test Kullanıcısı:**
     * **E-posta:** `test2@yakinda.com`
     * **Şifre:** `test123456`
   * *💡 Test Adımı: İki farklı cihazda (örneğin bir fiziksel telefon ve bir emulator) bu hesaplarla oturum açıp Profil ekranından "Konumumu arkadaşlarımla paylaş" anahtarını aktif hale getirdiğinizde, Harita ekranında birbirinizi anlık (mor pinle) görebilir ve takip edebilirsiniz.*

---

## 🛠️ Teknoloji Yığını ve Bağımlılıklar (Tech Stack)

Uygulamanın mimarisinde kullanılan temel paketler ve tercih edilme nedenleri:

| Paket / Teknoloji | Sürüm | Kullanım Amacı & Açıklama |
| :--- | :--- | :--- |
| **Flutter SDK** | `^3.12.2` | Projenin geliştirildiği cross-platform mobil framework sürümü. |
| **firebase_core** | `^4.13.0` | Firebase servislerinin başlatılması ve yapılandırılması. |
| **firebase_auth** | `^6.5.7` | Kullanıcı oturum yönetimi (Register, Login, SignOut) ve JWT tabanlı güvenli kimlik doğrulama. |
| **cloud_firestore** | `^6.8.0` | NoSQL yapısında gerçek zamanlı veritabanı. Konum paylaşımı, arkadaşlık ilişkileri ve kullanıcı profillerinin anlık senkronizasyonu için kullanıldı. |
| **provider** | `^6.1.5+1` | Uygulama genelinde State Management ve Dependency Injection (Bağımlılık Enjeksiyonu) çözümü. |
| **flutter_map** | `^8.3.1` | Mapbox veya Google Maps gibi ücretli çözümler yerine, OpenStreetMap (OSM) tile'larını esnek ve performanslı bir şekilde render etmek için seçilen open-source harita kütüphanesi. |
| **latlong2** | `^0.10.1` | Coğrafi koordinatları (`LatLng`) tutmak, harita sınırlarını ve mesafeleri hesaplamak için kullanılan matematik kütüphanesi. |
| **geolocator** | `^14.0.3` | Cihazın GPS sensöründen konum verisi çekmek, konum servislerinin durumunu kontrol etmek ve izin yönetimi yapmak için endüstri standardı paket. |
| **http** | `^1.6.0` | Overpass API sunucularına HTTP POST istekleri göndererek yakındaki yerlerin koordinatlarını çekmek için kullanılan kütüphane. |
| **image_picker** | `^1.2.3` | Kullanıcının galerisinden profil fotoğrafı seçmesini sağlayan yerel (native) arayüz köprüsü. |

---

## 📂 Klasör Yapısı ve Mimari Tasarım

Uygulama, **MVVM (Model-View-ViewModel)** ve **Clean Architecture** prensiplerinden esinlenerek katmanlı bir yapıda tasarlanmıştır:

```text
lib/
├── firebase_options.dart      # FlutterFire CLI tarafından üretilen platform konfigürasyonları
├── main.dart                  # Uygulama giriş noktası, Provider tanımlamaları ve Tema ayarları
│
├── models/                    # Veri Modelleri (Data Models)
│   └── app_user.dart          # Firestore verisini Dart nesnesine dönüştüren veri modeli
│
├── providers/                 # State Management / ViewModels (Business Logic)
│   ├── auth_provider.dart     # Firebase Auth durumunu ve işlemlerini yöneten ViewModel
│   └── friends_provider.dart  # Arkadaş ekleme, arama, konum paylaşma durumlarını yöneten ViewModel
│
├── screens/                   # Görünüm Katmanı (Views / UI)
│   ├── auth_gate.dart         # Oturum durumuna göre yönlendirme yapan geçiş katmanı (Router)
│   ├── root_shell.dart        # Harita ve Profil sekmelerini tutan alt menü (Scaffold)
│   ├── auth/                  # Kimlik doğrulama ekranları (Giriş & Kayıt)
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/                  # Ana harita ekranı
│   │   └── home_screen.dart
│   └── profile/               # Profil ayarları, arkadaş arama/listeleme ekranı
│       └── profile_screen.dart
│
├── services/                  # Altyapı ve Harici API Servisleri (Data Sources)
│   ├── location_service.dart  # Cihazın yerel GPS modülüyle iletişim kuran servis
│   └── overpass_service.dart  # Overpass API üzerinden OSM yer sorgusu yapan servis
│
└── widgets/                   # Yeniden Kullanılabilir Arayüz Elemanları (Shared Widgets)
    └── user_avatar.dart       # Kullanıcı fotoğrafını veya baş harfini gösteren ortak avatar bileşeni
```

---

## 🗄️ Veritabanı Tasarımı (Firestore Schema)

NoSQL yapısındaki Cloud Firestore üzerinde tek bir `/users` koleksiyonu kullanılarak veri bütünlüğü ve sorgu hızı optimize edilmiştir.

### `/users/{uid}` Doküman Yapısı

| Alan Adı (Field) | Veri Tipi (Type) | Açıklama |
| :--- | :--- | :--- |
| `username` | `String` | Kullanıcının benzersiz aramalar için kullandığı takma ad. |
| `email` | `String` | Giriş işlemlerinde kullanılan e-posta adresi. |
| `friends` | `List<String>` | Arkadaş olunan diğer kullanıcıların `uid` değerlerini tutan dizi. |
| `locationSharing` | `Boolean` | Konum paylaşımının aktif olup olmadığını belirten anahtar. |
| `location` | `GeoPoint` | Enlem ve boylam bilgisini tutan coğrafi veri tipi (Firestore Native). |
| `locationUpdatedAt`| `Timestamp` | Konum bilgisinin sunucu saatine göre en son ne zaman güncellendiği. |
| `photoBase64` | `String?` | Profil fotoğrafının Base64 kodlanmış hali (Nullable). |
| `createdAt` | `Timestamp` | Hesabın oluşturulma tarihi (serverTimestamp). |

---

## 🔧 Kritik Kod Blokları ve Algoritmik Detaylar

### 1. Firestore Prefix-Tabanlı Kullanıcı Arama
Firestore varsayılan olarak karmaşık `LIKE` veya metin aramalarını desteklemez. Uygulamada, girilen harflerle başlayan kullanıcıları getirmek için Firestore range query tekniği kullanılmıştır:
```dart
Future<List<AppUser>> searchUsersByUsername(String queryText) async {
  final snapshot = await _firestore
      .collection('users')
      .where('username', isGreaterThanOrEqualTo: queryText)
      .where('username', isLessThanOrEqualTo: '$queryText\uf8ff') // Unicode üst sınırı ( yerine \uf8ff kullanımı daha güvenlidir)
      .limit(20)
      .get();
  return snapshot.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList();
}
```
*   **Teknik Detay:** `$queryText\uf8ff` ifadesi, Firestore'a "kullanıcı adı `queryText` ile başlayan ve alfabetik olarak ondan hemen sonraki karakter sınırına kadar olan tüm dokümanları getir" talimatını verir.

### 2. Çift Yönlü Arkadaş Eklemede "Atomic Batch Write"
Arkadaşlık ilişkisi iki kullanıcının da `friends` listesine birbirinin `uid`sini eklemesini gerektirir. Ağ kesintisi veya hata durumunda verinin yarım kalmaması (veri tutarsızlığı) için `WriteBatch` kullanılmıştır:
```dart
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
```
*   **Teknik Detay:** `batch.commit()` işlemi atomiktir. Ya iki işlem birden başarılı olur ya da hata durumunda ikisi birden geri alınır (rollback).

### 3. Overpass QL ile Yakındaki Yerleri Sorgulama
OpenStreetMap'in güçlü veri sorgulama dili Overpass QL kullanılarak, kullanıcının koordinat merkezli belirli bir yarıçapındaki yerler sorgulanır:
```dart
final query = '''
  [out:json][timeout:25];
  (
    node["shop"="supermarket"](around:$radiusMeters,${center.latitude},${center.longitude});
    node["amenity"="pharmacy"](around:$radiusMeters,${center.latitude},${center.longitude});
  );
  out body;
''';
```
*   **Teknik Detay:** Bu sorgu, sunucu tarafında mekansal (spatial) indeksleme kullanarak çok hızlı bir şekilde eczane ve market düğümlerini (node) süzüp JSON formatında döndürür.

---

## 👩‍💻 MÜLAKAT HAZIRLIK SORULARI & CEVAPLARI (Çalışma Kartları)

*Mülakata girmeden önce bu sorulara göz atmanız ve teknik detayları ezberlemek yerine mantığını kavramanız tavsiye edilir.*

### Soru 1: Neden State Management için Provider seçtin? Riverpod veya BLoC neden kullanmadın?
> **Cevap:** "Provider, Flutter ekibi tarafından da önerilen, basit ve orta ölçekli projelerde gereksiz boilerplate (şablon kod) yazımını engelleyen hafif bir Dependency Injection ve State Management kütüphanesidir. Projemizin ölçeği göz önüne alındığında, BLoC'un getireceği karmaşık olay-durum (event-state) akışlarına ve kod yoğunluğuna ihtiyaç duymadık. Riverpod ise derleme zamanı güvenliği (compile-time safety) sağlar fakat Provider bu projenin tüm ihtiyaçlarını (Auth ve arkadaşlık senkronizasyonunu) temiz bir şekilde karşılamaktadır."

### Soru 2: Profil fotoğrafını neden Firebase Storage yerine Firestore'da Base64 String olarak tuttun? Bunun dezavantajı nedir? Production'da nasıl yapardın?
> **Cevap:** "Firestore'da Base64 saklamak, ekstra bir Firebase kütüphanesi (Firebase Storage) kurmamızı engelledi ve tek sorguda kullanıcı verisiyle resmi getirmemizi sağladı (hızlı prototipleme avantajı). **Ancak bu yöntem production ortamı için uygun değildir.** 
> **Dezavantajları:**
> 1. Firestore doküman boyutu **1MB** ile sınırlıdır. Büyük resimler bu limiti aşarak uygulamanın çökmesine yol açar.
> 2. Base64 dönüşümü dosya boyutunu yaklaşık %33 oranında büyütür, bu da ağ trafiğini ve Firestore maliyetlerini (okuma/yazma boyutunu) artırır.
> 3. Firestore'un pahalı olan bant genişliğini resim transfer etmek için harcamış oluruz.
> **Production çözümü:** Resmi Firebase Storage'a yükleyip, elde edilen `URL` bilgisini Firestore'da `photoUrl` adıyla saklamak ve arayüzde `CachedNetworkImage` ile resmi önbelleğe alarak göstermektir."

### Soru 3: Arkadaş ekleme fonksiyonunda neden Transaction yerine Batch kullandın? Farkları nelerdir?
> **Cevap:** "Hem transaction hem de batch işlemleri Firestore'da atomiktir (ya hep ya hiç). Ancak **Batch write**, veritabanından önceden herhangi bir okuma (read) yapmaya gerek duymadığımız, sadece iki farklı dokümanı güncelleyeceğimiz durumlarda tercih edilir. **Transaction** ise güncelleyeceğimiz verinin yeni halinin, veritabanındaki mevcut haline bağlı olduğu (örneğin stok azaltma, bakiye güncelleme gibi önce okuyup sonra yazma gerektiren) durumlarda kullanılır. Biz arkadaş eklerken sadece ID'leri array'e push ettiğimiz için (`FieldValue.arrayUnion`) okuma yapmaya gerek duymadık, bu yüzden daha performanslı ve ucuz olan Batch Write'ı kullandık."

### Soru 4: Haritadaki arkadaşlarının konumunu canlı olarak nasıl güncelliyorsun? Stream mimarisini açıklar mısın?
> **Cevap:** "Firestore'un `snapshots()` metodunu kullanarak gerçek zamanlı veri akışları (Stream) kuruyoruz. `watchUser(uid)` metodu, Firestore'da ilgili kullanıcının dokümanı her değiştiğinde yeni bir `AppUser` nesnesi yayınlar. `HomeScreen` üzerinde kendi konumumuzu güncelledikçe, arkadaşlarımızın ekranında bizi dinleyen `FutureBuilder`/`StreamBuilder` yapıları otomatik tetiklenir. Bu sayede HTTP polling (belirli aralıklarla istek atma) yapmadan, soket seviyesinde (WebSockets/gRPC yardımıyla) anlık konum takibi sağlanmış olur."

### Soru 5: Firestore sorgularında karşılaştığın kısıtlamalar nelerdi? `getFriends` metodundaki limit nedir?
> **Cevap:** "Firestore'da `whereIn` sorgusu, tek bir sorguda en fazla **30** (kod yazılırken eski limit olan 10 baz alınmıştı) eleman sorgulanmasına izin verir. Bu projede arkadaşlarımızın detaylarını çekmek için `whereIn: friendUids.take(10).toList()` kullandık. Eğer kullanıcının 100 arkadaşı olsaydı, bu sorguyu parçalara bölüp (chunking) paralel `Future.wait` sorguları atmamız veya arkadaş listesini alt koleksiyonlar halinde tasarlamamız gerekirdi."

### Soru 6: Overpass API kullanırken hata yönetimi ve zaman aşımı (Timeout) durumlarını nasıl ele aldın?
> **Cevap:** "Mobil cihazlarda harici API'lere yapılan isteklerde ağ kopmaları sık yaşanır. Bu yüzden `http.post` isteğimize `.timeout(const Duration(seconds: 20))` ekleyerek isteğin sonsuza kadar askıda kalmasını engelledik. Hata durumunda (HTTP 200 dönmemesi veya timeout olması durumunda) özel bir `OverpassException` fırlattık. UI katmanında (`HomeScreen`) bu hatayı `try-catch` ile yakalayıp ekranın üstünde kırmızı renkli bir uyarı bandı (`_nearbyPlacesFailed`) göstererek kullanıcının deneyimini kesintiye uğratmadan hata bildirimini sağladık."

---

## 🛠️ Kurulum ve Çalıştırma Kılavuzu

### 1. Bağımlılıkları İndirme
```bash
flutter pub get
```

### 2. Fiziksel Cihazda Çalıştırma (Android - Önerilen)
Gerçek GPS verileriyle en doğru testi yapmak için fiziksel cihaz kullanımı önerilir:
1. Telefonunuzun **Geliştirici Seçenekleri**'ni aktif hale getirin ve **USB Hata Ayıklama**'yı açın.
2. Bilgisayara bağlayıp terminalden cihazı doğrulayın:
   ```bash
   adb devices
   ```
3. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

### 3. Android Emulator ile Sahte Konum (Mock Location) Kullanımı
Emulator grafik kütüphaneleri bazı bilgisayarlarda yavaş çalışabilir veya hata verebilir. Eğer emulator kullanacaksanız:
1. Emulator'ü başlatın:
   ```bash
   emulator -avd <emulator_adiniz>
   ```
2. Uygulamayı ayağa kaldırın.
3. Emulator yan menüsündeki üç noktaya (`...`) tıklayın -> **Location** sekmesine gidin.
4. Haritadan bir konum seçip **Send** butonuna basın. Cihazın GPS konumu seçtiğiniz koordinata simüle edilecektir.

---

## 📈 Gelecek Yol Haritası (Production Sürümü İçin İyileştirmeler)

*Mülakatta "Bu projeyi sıfırdan yazsan neleri farklı yapardın?" sorusuna verilecek vizyoner yanıtlar:*

1. **Firebase Storage Geçişi:** Profil resimlerinin Base64 yerine Storage üzerinde tutulması.
2. **Geohash ve Coğrafi Sorgular (Geoqueries):** Şu an haritadaki tüm arkadaşları çekiyoruz. Kullanıcı sayısı arttığında bu performans kaybına yol açar. `geoflutterfire2` paketi kullanarak sadece kullanıcının 10km çevresindeki arkadaşlarını sorgulamak (spatial querying) gerekir.
3. **Arka Plan Konum Takibi (Background Location):** Uygulama kapalıyken de konum paylaşımının devam etmesi için `flutter_background_service` ile entegrasyon yapılması.
4. **Arkadaşlık İstekleri Sistemi (Friend Request System):** Doğrudan arkadaş eklemek yerine, önce arkadaşlık isteği gönderilmesi, karşı tarafın onaylaması durumunda (`status: pending/accepted`) çift yönlü ilişkinin kurulması.
5. **Gelişmiş Test Kapsamı:** Overpass servisleri için `http.MockClient` kullanılarak Unit Testlerin yazılması ve UI akışları için Integration Test kütüphanelerinin entegre edilmesi.
