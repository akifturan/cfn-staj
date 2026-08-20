# 🎤 Circle — Mülakat Sunum Rehberi

> Bu doküman, staj mülakatında projeyi sunmak için bir **konuşma senaryosu** ve **provası** niteliğindedir.
> Her bölüm, hocanıza projeyi anlatırken kullanabileceğiniz konuşma akışını içerir.
> Tırnak içindeki cümleler direkt söyleyebileceğiniz ifadelerdir.

---

## 📋 Sunum Planı (Tahmini 10-15 dakika)

| Süre | Bölüm | Ne Anlatılacak |
|------|-------|----------------|
| 1 dk | Giriş & Motivasyon | Projenin ne olduğu, neden bu projeyi seçtiğin |
| 2 dk | Canlı Demo | Uygulamayı çalıştırıp giriş yap → harita → arkadaş ekle → konum paylaş |
| 2 dk | Mimari Genel Bakış | MVVM, katmanlar, Provider |
| 3 dk | Firebase & Firestore | Auth akışı, veritabanı şeması, güvenlik |
| 2 dk | Harita & Konum | GPS, Overpass API, gerçek zamanlı konum |
| 2 dk | Teknik Zorluklar | Karşılaştığın sorunlar ve çözümlerin |
| 2 dk | Kendi Kendine Eleştiri | Production'da neleri farklı yapardın |

---

## 🎯 Bölüm 1: Giriş (1 dakika)

### Söylemeniz gereken:

> "Bu projede **Circle** adında bir mobil uygulama geliştirdim. Uygulama, kullanıcıların canlı konumlarını paylaşmalarını, yakınlarındaki market ve eczaneleri bulmalarını ve arkadaşlarını harita üzerinde takip etmelerini sağlıyor. Ayrıca bir hava durumu sekmesi ve arkadaşlarla asenkron skor yarıştığı küçük bir mini oyun da ekledim."

> "Flutter ve Firebase tercih etmemin sebebi; Flutter ile tek kod tabanıyla hem Android hem iOS hedeflemek, Firebase ile de backend sunucusu kurmadan kimlik doğrulama, veritabanı ve gerçek zamanlı senkronizasyon elde etmek."

### Hocanın sorabilecekleri:

**S: "Neden Flutter?"**
> "Cross-platform olması en büyük avantajı. Tek bir Dart kod tabanıyla hem Android hem iOS'a çıkabiliyorum. Ayrıca hot reload ile geliştirme hızı çok yüksek. Widget tabanlı UI sistemi de bileşen odaklı düşünmeyi teşvik ediyor."

**S: "Neden native Android/Kotlin değil?"**
> "Flutter'ın widget sistemi daha yüksek seviyede soyutlama sunuyor ve öğrenme eğrisi daha düşük. Bu staj projesi kapsamında hızlı prototipleme önceliğimdi."

---

## 📱 Bölüm 2: Canlı Demo (2 dakika)

### Demo Senaryosu:

1. **Uygulamayı başlat** → Giriş ekranını göster (yeni logo: iki iç içe daire — lacivert + turkuaz)
2. **testuser1@example.com / test1234 ile giriş yap** → AuthGate'in otomatik yönlendirmesini göster
3. **Harita sekmesi** → "Bakın, cihazımın GPS konumunu mavi pin ile gösteriyor. Çevredeki yeşil pinler marketleri, kırmızı pinler eczaneleri temsil ediyor."
4. **Hava Durumu sekmesi** → "Bulunduğum konumun anlık sıcaklığını ve durumunu gösteriyor, Open-Meteo API'sinden çekiyorum, API anahtarı gerektirmiyor"
5. **Oyun sekmesi** → "Basılı tutarak nefes tutma süremi ölçüyorum, arkadaşlarımla asenkron olarak liderlik tablosunda yarışıyoruz"
6. **Profil sekmesi** → "Burada kullanıcı adı araması yapabiliyorum"
7. **Konum paylaşım switch'i** → "Bu switch'i açtığımda konumum Firestore'a yazılıyor"

### Demo sırasında vurgulanacak noktalar:

- "Haritadaki veriler OpenStreetMap'ten geliyor, Google Maps API kullanmadık — **tamamen ücretsiz**"
- "Hava durumu da aynı prensiple Open-Meteo'dan, API anahtarı yönetmiyoruz"
- "Konum paylaşımını kapattığımda Firestore'daki konum verim de temizleniyor — **gizlilik odaklı tasarım**"
- "Tema otomatik olarak cihaz ayarına göre değişiyor — dark mode açarsak uygulama da karanlık temaya geçer"
- "Alt navigasyonda 4 sekmeyi `IndexedStack` ile aynı anda ayakta tutuyorum, böylece Hava Durumu sekmesine her dönüşte tekrar API çağrısı yapmıyor"

---

## 🏗️ Bölüm 3: Mimari (2 dakika)

### Söylemeniz gereken:

> "Projeyi MVVM mimarisinden esinlenerek katmanlı bir yapıda kurdum."

Katmanları açıklarken bu sırayı takip et:

```
┌─────────────────────────────────────────┐
│            SCREENS (View)                │  ← Kullanıcının gördüğü arayüz
│  login, register, home, weather,          │
│  game, profil                             │
├─────────────────────────────────────────┤
│         PROVIDERS (ViewModel)             │  ← İş mantığı ve state yönetimi
│     auth_provider                         │
│     friends_provider                      │
├─────────────────────────────────────────┤
│            MODELS (Model)                 │  ← Veri yapıları
│            app_user.dart                  │
├─────────────────────────────────────────┤
│           SERVICES (Data)                 │  ← Dış dünya ile iletişim
│   location_service, overpass_service      │
│   weather_service, geocoding_service      │
├─────────────────────────────────────────┤
│          WIDGETS (Shared)                 │  ← Yeniden kullanılabilir UI parçaları
│   user_avatar.dart, app_mark.dart         │
└─────────────────────────────────────────┘
```

> "Katmanlar arasında tek yönlü bağımlılık var: **Screens → Providers → Models/Services**. Bir service asla doğrudan UI'a erişmez, bir model asla bir widget'ı bilmez."

### Hocanın sorabilecekleri:

**S: "MVVM'in buradaki karşılığı ne?"**
> "Model = `AppUser` sınıfı, View = Screen dosyaları, ViewModel = Provider sınıfları. Provider'lar iş mantığını tutar, screen'ler sadece UI render eder."

**S: "State Management için neden Provider?"**
> "Projenin ölçeğinde BLoC'un getirdiği Event-State yapısı gereksiz karmaşıklık olurdu. Riverpod daha modern ama öğrenme eğrisi var. Provider, Flutter ekibinin de önerdiği, basit ve etkili bir çözüm."

**S: "AuthProvider ChangeNotifier ama FriendsProvider değil, neden?"**
> "AuthProvider auth durumu değiştiğinde UI'ı bilgilendirmesi gerekebilir, bu yüzden ChangeNotifier'ı extend eder. FriendsProvider ise sadece Firestore'a CRUD işlemleri yapar ve UI'ı stream'ler aracılığıyla bilgilendirir, kendi state'i yoktur. Bu yüzden basit Provider yeterli."

---

## 🔥 Bölüm 4: Firebase & Firestore (3 dakika)

### Auth Akışı:

> "Firebase Authentication kullanarak e-posta/şifre tabanlı kimlik doğrulama kurdum."

```
Kullanıcı → Kayıt Ol butonuna basar
  → Firebase Auth: createUserWithEmailAndPassword()
  → Başarılı: UID oluşur
  → Firestore: users/{uid} dokümanı oluşturulur (username, email, friends)
  → authStateChanges stream tetiklenir
  → AuthGate: StreamBuilder rebuild olur → RootShell ekranına geçer
```

> "Bu akışın güzel tarafı: Login sonrası ekran geçişini manuel yapmıyoruz. `authStateChanges` stream'i otomatik olarak AuthGate'i tetikliyor ve doğru ekrana yönlendiriyor."

### Veritabanı Tasarımı:

> "Tek koleksiyonlu flat bir yapı kullandım. `users` koleksiyonunda her kullanıcı tek bir doküman."

**Hocanın sorabilecekleri:**

**S: "Neden Firestore, neden SQL veritabanı değil?"**
> "Firestore'un avantajları: gerçek zamanlı senkronizasyon (snapshots), serverless (sunucu yönetmeye gerek yok), offline destek (internet kesilse bile cache'ten çalışır). SQL veritabanı için backend API yazmam gerekirdi, bu da projenin kapsamını aşardı."

**S: "friends listesini neden array olarak tuttun, ayrı koleksiyon neden yapmadın?"**
> "Tek sorguda tüm arkadaş ID'lerini çekebilmek için array kullandım. Projede max 10-20 arkadaş olacağını varsaydım. Binlerce arkadaş olsaydı `users/{uid}/friends` alt koleksiyonu kullanırdım — pagination yapılabilir, doküman boyutu şişmez."

**S: "FieldValue.serverTimestamp() nedir?"**
> "İstemcinin saati yanlış olabilir — kullanıcı telefonunun saatini değiştirebilir. `serverTimestamp()` Firebase sunucusunun saatini kullanır, bu da tüm kullanıcılar arasında tutarlı bir zaman kaynağı sağlar."

**S: "arrayUnion ne işe yarıyor?"**
> "Bir array alanına eleman ekler ama aynı eleman zaten varsa tekrar eklemez. Bu idempotent bir operasyon — yani aynı arkadaş ekleme isteğini 10 kere gönderseniz bile array'de bir kere yer alır. Ayrıca sunucu tarafında çalışır, client'ta array'i okuyup tekrar yazmak gerekmez."

---

## 🗺️ Bölüm 5: Harita & Konum (2 dakika)

### Harita Yapısı:

> "Haritada üç katman var: tile layer, marker layer ve hata banner'ları."

> "OpenStreetMap tile'larını kullanıyoruz. Harita görselleri `tile.openstreetmap.org` sunucusundan çekiliyor. Google Maps'in aksine ücretsiz ve API anahtarı gerektirmiyor."

### GPS İzin Akışı:

> "Konum almak için üç aşamalı bir kontrol yapıyoruz: GPS servisi açık mı → izin verilmiş mi → izin iste. Her aşamada başarısızlık olursa null dönüyoruz ve fallback koordinat (İstanbul) kullanıyoruz."

### Overpass API:

> "Yakındaki yerler için Overpass API kullanıyorum. Bu, OpenStreetMap'in sorgu arayüzü. Overpass QL adında bir sorgu dili var. 'Benim etrafımdaki 1.5 kilometre içindeki tüm marketleri ve eczaneleri getir' diyorum."

**Hocanın sorabilecekleri:**

**S: "Overpass API'den veri gelmezse ne oluyor?"**
> "Katmanlı bir hata yönetimi var: HTTP timeout (30 saniye), `attempt * 2` saniyelik artan beklemeyle 3 denemelik retry, ve özel `OverpassException` sınıfı. Hata olursa haritanın üstüne kırmızı bir banner ve manuel 'Tekrar Dene' butonu gösteriyoruz — harita çalışmaya devam eder, sadece yakındaki yerler gösterilmez. Kullanıcı deneyimi kesilmez. Bunu gerçek cihazda test ederken keşfettim: `overpass-api.de` ücretsiz/paylaşımlı bir servis, ara sıra 429 dönüyor ya da yavaş cevap veriyor — retry+backoff bu durumu büyük ölçüde çözdü."

**S: "Gerçek zamanlı konum takibi nasıl çalışıyor?"**
> "Kullanıcı profil ekranından konum paylaşımını açtığında, GPS konumu Firestore'daki dokümanına yazılıyor. Arkadaşları harita ekranını açtığında bu veriyi çekip mor pin olarak gösteriyor. Firestore'un `snapshots()` stream'i sayesinde anlık güncelleme mümkün."

---

## ⚡ Bölüm 6: Teknik Zorluklar (2 dakika)

### Zorluk 1: Firebase Auth ve bizim AuthProvider isim çakışması

> "Firebase Auth kendi `AuthProvider` sınıfını içeriyor. Ben de aynı isimde bir sınıf yazdım. Dart'ta `hide` anahtar kelimesiyle Firebase'inkini gizledim:
> `import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;`"

### Zorluk 2: Async işlemler ve mounted kontrolü

> "Kullanıcı giriş butonuna basıyor, Firebase'e istek gidiyor. Bu sırada kullanıcı geri tuşuna basıp ekranı kapatırsa ve biz `setState` çağırırsak hata alırız. Bu yüzden her async işlem sonrasında `if (mounted)` kontrolü yapıyorum."

### Zorluk 3: Firestore'da text search olmaması

> "Firestore LIKE sorgusu desteklemiyor. Unicode `\uf8ff` range query tekniğiyle prefix arama simüle ettim. Bu, sözlüksel sıralamadan faydalanan akıllıca bir workaround."

### Zorluk 4: Flutter versiyon uyumluluk sorunları

> "Projede hocanın Flutter sürümüyle (3.35.2) uyumluluk sağlamak için Dart SDK, Gradle, AGP ve Kotlin sürümlerini düşürdüm. Bu sürüm bağımlılık yönetimi deneyimi kazandırdı."

---

## 🔍 Bölüm 7: Kendi Kendine Eleştiri (2 dakika)

> "Bu projeyi production'a çıkarsam neleri farklı yapardım — bunu açıkça söylemek önemli çünkü kendi kodumun sınırlarını bildiğimi gösterir."

### 1. Profil Fotoğrafı

> "Şu an Base64 string olarak Firestore'da tutuyorum. Production'da Firebase Storage'a yükleyip URL'sini saklardım. Çünkü Base64 dosya boyutunu %33 artırıyor ve Firestore doküman limiti 1MB."

### 2. Arkadaşlık İstek Sistemi

> "Şu an direkt arkadaş ekleme var. Production'da `pending → accepted` akışı olmalı. Birisi sizi direkt arkadaş listesine ekleyememeli."

### 3. Test Kapsamı

> "Projede unit test ve integration test yok. Production'da `OverpassService` için mock HTTP client ile unit test, auth akışı için integration test yazardım."

### 4. Offline Desteği

> "Firestore otomatik cache sunuyor ama bunu bilinçli olarak kullanmadım. Offline durumda harita tile'ları yüklenmez, Overpass API çalışmaz. Production'da tile cache'leme ve offline-first mimari eklerdim."

### 5. Güvenlik

> "Firestore Security Rules tanımlamadım. Şu an herkes herkesin verisini okuyabilir/yazabilir. Production'da kullanıcının sadece kendi dokümanını yazabilmesini ve arkadaşlarının konumunu okuyabilmesini sağlayan kurallar eklerdim."

---

## 🎯 Sıkça Gelen Derin Mülakat Soruları

### "Widget lifecycle'ı açıkla"

> "StatefulWidget'ın yaşam döngüsü: `createState()` → `initState()` → `build()` → `setState()` tetiklenirse tekrar `build()` → `dispose()`. `initState` başlangıç işlemleri için, `dispose` temizlik (controller dispose, stream iptal) için kullanılır."

### "Hot Reload ile Hot Restart farkı?"

> "Hot Reload: State korunarak sadece değişen widget ağacını günceller. Hot Restart: State sıfırlanır, uygulama baştan başlar. Hot Reload daha hızlı ama bazı değişiklikler (global değişkenler, main fonksiyonu) için restart gerekir."

### "StatelessWidget vs StatefulWidget ne zaman hangisini kullanırsın?"

> "İç state'i olmayan, sadece dışarıdan gelen verileri gösteren widget'lar → StatelessWidget (UserAvatar, AuthGate). Kullanıcı etkileşimi veya zamana bağlı değişen state tutan widget'lar → StatefulWidget (HomeScreen, ProfileScreen, LoginScreen)."

### "context nedir?"

> "BuildContext, widget'ın widget tree'deki konumunu temsil eder. Provider'a erişim, Navigator kullanımı, Theme okuma gibi tüm tree-bağımlı işlemler context üzerinden yapılır. Her widget'ın build metodunda kendi context'ini alır."

### "Dart'ta Future ve Stream farkı?"

> "Future tek bir asenkron sonuç döndürür — tıpkı bir sözleşme gibi: 'bunu yapacağım ve bittiğinde sonucu vereceğim'. Stream ise birden fazla asenkron sonuç yayınlar — tıpkı bir TV kanalı gibi: sürekli veri akışı. Firestore'dan tek okuma → Future (`.get()`), sürekli dinleme → Stream (`.snapshots()`)."

### "const constructor ne işe yarar?"

> "Compile-time'da oluşturulan sabit nesneler. Flutter, const widget'ları build sırasında atlar (skip) çünkü değişmeyeceğini bilir. Bu performans optimizasyonudur. `const EdgeInsets.all(24)` her seferinde yeni nesne yaratmaz, tek bir sabit nesne kullanılır."

### "Navigator.push vs Navigator.pushReplacement?"

> "push: Mevcut ekranı stack'te tutar, üstüne yeni ekran koyar. Geri tuşu ile dönülebilir. pushReplacement: Mevcut ekranı stack'ten siler, yerine yenisini koyar. Geri tuşu ile dönülemez. Login'den ana ekrana geçişte pushReplacement kullanılabilir ama biz bunu AuthGate'in StreamBuilder'ı ile otomatik yapıyoruz."

---

## ✅ Son Kontrol Listesi — Mülakata Girmeden Önce

- [ ] **Uygulamayı çalıştırdın mı?** → `flutter run` ile cihazda veya emülatörde test et
- [ ] **Test hesaplarıyla giriş yaptın mı?** → `testuser1@example.com` / `test1234`
- [ ] **Harita yükleniyor mu?** → GPS izni ver, yeşil/kırmızı pinleri gör
- [ ] **Hava Durumu sekmesi çalışıyor mu?** → Sıcaklık ve konum etiketi geliyor mu kontrol et
- [ ] **Oyun sekmesi çalışıyor mu?** → Butona basılı tut, bırak, yeni rekor rozetini gör
- [ ] **Arkadaş arama çalışıyor mu?** → Profil ekranından kullanıcı adı ara
- [ ] **Konum paylaşımı çalışıyor mu?** → Switch'i aç, Firestore Console'dan kontrol et
- [ ] **Dark mode çalışıyor mu?** → Cihaz ayarlarından karanlık tema aç
- [ ] **Her dosyanın ne yaptığını 1 cümleyle anlatabiliyor musun?**
- [ ] **Batch vs Transaction farkını açıklayabiliyor musun?**
- [ ] **Production'da neleri değiştirirdin sorusuna hazır mısın?**
- [ ] **Provider / ChangeNotifier / context.read vs context.watch farkını biliyorsun?**

---

## 💡 Altın Kurallar

1. **"Bilmiyorum"** demekten korkma. "Henüz araştırmadım ama yaklaşımım şöyle olurdu..." de.
2. **Trade-off'ları açıkla.** "Base64 kullandım çünkü hızlı prototipleme, ama production'da Storage kullanırdım" gibi.
3. **Kodu ezberleme, mantığı kavra.** Hocan satır numarası sormaz, "neden böyle yaptın" sorar.
4. **Projenin zayıf noktalarını sen söyle.** Hocan bulmadan sen itiraf edersen, olgunluk gösterirsin.
5. **Gerçekçi ol.** "Bu projeyle dünyayı değiştireceğim" deme, "staj sürecinde Firebase ve Flutter'ın temel konseptlerini öğrendim" de.
