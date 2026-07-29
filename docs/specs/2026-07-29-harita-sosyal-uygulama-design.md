# Harita Tabanlı Sosyal Keşif Uygulaması — Tasarım

**Tarih:** 2026-07-29
**Bağlam:** Bilgisayar mühendisliği staj dersi teslimi. 20 günlük stajda proje geliştirilememiş; şimdi 1-2 hafta içinde hızlı, göze hoş görünen, ciddi duran bir mobil uygulama gerekiyor. Rapor ayrıca yazılacak ama bu spec sadece uygulamayı kapsıyor.

## 1. Genel Bakış ve Kapsam

Kullanıcı kayıt olup giriş yapıyor, ana ekranda kendi konumunu harita üzerinde görüyor, yakınındaki marketler/eczaneler harita üzerinde işaretli çıkıyor, profilinden arkadaş ekleyip arkadaş listesini görebiliyor.

**Kapsam dışı (bilinçli olarak eklenmedi):**
- Gerçek zamanlı arkadaş konum takibi (canlı takip) — sadece statik arkadaş listesi
- Gönderi/feed, beğeni, yorum
- Bildirimler, mesajlaşma (DM)
- Arkadaşlık isteği/onay akışı — ekleme tek tıkla, karşılıklı ve anında
- Arkadaş çıkarma (unfriend)
- iOS derleme/test (geliştirme ortamı Linux, Xcode/Mac gerektirdiği için mümkün değil) — sadece Android hedefleniyor

## 2. Ekranlar ve Gezinme

1. **Splash/Auth kontrolü** — açılışta Firebase Auth durumu kontrol edilir; giriş yapılmışsa Ana ekrana, yapılmamışsa Giriş ekranına yönlendirilir.
2. **Giriş (Login)** — e-posta/şifre ile giriş, kayıt ekranına link.
3. **Kayıt (Register)** — e-posta/şifre/kullanıcı adı ile hesap oluşturma.
4. **Ana ekran (Home/Harita)** — tam ekran harita: kullanıcının canlı konumu bir işaretçiyle, çevresindeki market/eczaneler ayrı işaretçilerle gösterilir.
5. **Profil** — kullanıcı adı/e-posta, arkadaş listesi, "Arkadaş Ekle" (kullanıcı adına göre arama).
6. **Çıkış yap** — Profil ekranından.

**Gezinme:** Alt navigasyon çubuğu (Harita / Profil). Ekran sayısı az olduğu için drawer menü kullanılmıyor.

## 3. Veri Modeli (Firestore)

**`users` koleksiyonu** (doküman ID = Firebase Auth UID):

```
{
  username: string,
  email: string,
  friends: [uid, uid, ...],
  createdAt: timestamp
}
```

- Kullanıcının anlık konumu Firestore'a yazılmıyor; cihazdan `geolocator` ile doğrudan okunup sadece o an haritada gösteriliyor.
- Yakındaki yerler (market/eczane) Overpass API'den anlık çekiliyor, hiçbir yerde saklanmıyor.
- Arkadaşlık: A, B'yi eklediğinde her iki kullanıcının `friends` dizisine karşılıklı UID eklenir. Onay akışı yok.

## 4. Harita ve Konum Özelliği

- **Harita:** `flutter_map` + OpenStreetMap tile katmanı (API key gerekmez).
- **Konum:** `geolocator` ile izin istenir, anlık enlem/boylam alınır, haritada işaretçi olarak gösterilir. Harita açılışta kullanıcı konumuna ortalanır.
- **İzin reddedilirse:** Uygulama çökmez; basit bir uyarı gösterilir ve varsayılan bir konuma (örn. şehir merkezi) düşülür.
- **Emulator'da test:** Android emulator'da gerçek GPS olmadığından, Android Studio'nun "Extended Controls" panelinden manuel enlem/boylam girilerek sahte konum verilir.

## 5. Yakındaki Yerler (Overpass API)

- Kullanıcı konumunun ~1-2 km yarıçapında, Overpass API'ye `shop=supermarket` ve eczane (`amenity=pharmacy`) etiketleriyle sorgu gönderilir.
- Sonuçlar haritada farklı ikon/renkte işaretçiler olarak gösterilir; işaretçiye dokununca yer adı popup'ta gösterilir.
- İstek `http` paketiyle düz HTTP çağrısı olarak yapılır.
- Overpass genel sunucusu yavaş/limitli olabilir — hata durumunda sessiz bir uyarı gösterilip harita çalışmaya devam eder (uygulama çökmez).

## 6. Arkadaş Özelliği (UX Akışı)

- Profil ekranında "Arkadaş Ekle" → arama kutusu → kullanıcı adına göre `users` koleksiyonunda arama (basit prefix/eşleşme sorgusu).
- Bulunan kullanıcının yanında "Ekle" butonu; tıklanınca her iki tarafın `friends` dizisine karşılıklı UID eklenir.
- Profil ekranında kendi arkadaş listesi, kullanıcı adlarıyla basit liste halinde gösterilir.

## 7. Teknoloji Yığını

- **State management:** `provider` (ChangeNotifier) — basitliği ve hızlı öğrenilebilirliği nedeniyle seçildi.
- **Auth & veri:** `firebase_auth`, `cloud_firestore`, `firebase_core`
- **Harita:** `flutter_map`, `latlong2`
- **Konum:** `geolocator`
- **HTTP:** `http` (Overpass API çağrıları için)

## 8. Ortam Kurulumu (Ön Koşullar)

Geliştirme makinesinde (Linux/Fedora) şu an eksik olanlar, kod yazımına başlamadan önce kurulacak:

1. Android Studio → Android SDK + bir emulator (sanal Android cihaz) oluşturma
2. Firebase projesi oluşturma (console.firebase.google.com, ücretsiz Spark planı) → Auth (e-posta/şifre) ve Firestore aktif etme
3. `flutterfire configure` ile Firebase'in Flutter projesine bağlanması

Test için: Android emulator (şimdi) veya kullanıcının fiziksel Android telefonu üzerinden USB debugging (ileride, gerçek GPS testi için).

## 9. Bilinen Riskler

- Overpass API genel sunucusu bazen yavaş/limitli yanıt verebilir — kritik değil, sessiz hata yönetimiyle karşılanıyor.
- Kullanıcının hiç Flutter deneyimi yok — ortam kurulumu ve ilk çalıştırma adımları plan aşamasında ayrıntılı, adım adım yürütülecek.
