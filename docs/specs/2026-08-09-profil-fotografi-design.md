# Profil Fotoğrafı — Tasarım

**Tarih:** 2026-08-09
**Bağlam:** Rapor'daki geliştirme önerilerinden biri ("Daha dolu / aktif göstermek için") — kullanıcıların profil fotoğrafı yükleyip profil ve arkadaş listesinde göstermesi.

## 1. Genel Bakış

Kullanıcılar galeriden bir fotoğraf seçip profillerine ekleyebilir. Fotoğraf Profil ekranında ve arkadaş listesi/arama sonuçlarında küçük bir avatar olarak gösterilir. Fotoğrafı olmayan kullanıcılar için kullanıcı adının ilk harfi renkli bir daire içinde gösterilir.

**Önemli karar — depolama:** Firebase Storage yerine Firestore kullanılıyor. Firebase Storage artık yeni projelerde ücretli Blaze planına geçiş istiyor (Google'ın 2024 kural değişikliği); bu proje boyunca tutarlı şekilde takip edilen "ücretsiz katman" ilkesini bozmamak için fotoğraf küçültülüp/sıkıştırılıp doğrudan Firestore kullanıcı dokümanına base64 metin olarak yazılıyor.

**Kapsam dışı:** Kamera ile fotoğraf çekme (sadece galeriden seçim), başka kullanıcıların fotoğrafını görüntüleme dışında bir etkileşim (büyütme/tam ekran görüntüleme yok), fotoğraf kırpma/döndürme arayüzü.

## 2. Veri Modeli (Firestore)

`users/{uid}` dokümanına yeni alan:

```
photoBase64: String?   // null = fotoğraf yok, baş harf avatarı gösterilir
```

`AppUser` modeli bu alanı içerecek şekilde genişletilir (`data['photoBase64'] as String?`, eski dokümanlarda alan yoksa `null` — hata vermez).

`image_picker` paketi eklenir. Seçilen fotoğraf, `image_picker`'ın kendi `maxWidth`/`maxHeight` (~200px) ve `imageQuality` (düşük, örn. %50-60) parametreleriyle küçültülüp sıkıştırılır — ayrı bir sıkıştırma paketi gerekmez. Sonuç `dart:convert`'in `base64Encode` ile metne çevrilip Firestore'a yazılır. Tipik boyut 15-40KB — Firestore'un 1MB doküman sınırının çok altında.

## 3. UX Akışı — Profil Ekranı

- Profil ekranının en üstüne, kullanıcı adının üzerine tıklanabilir bir `CircleAvatar` eklenir:
  - `photoBase64` doluysa: `base64Decode` ile çözülüp `MemoryImage` olarak gösterilir.
  - Boşsa: kullanıcı adının ilk harfi, renkli arka plan üzerinde büyük harfle gösterilir.
  - Köşesinde küçük bir kamera/kalem ikonu, avatarın tıklanabilir olduğunu belli eder.
- Avatara dokununca `image_picker` ile galeri açılır.
- Fotoğraf seçilince: otomatik küçültme/sıkıştırma → base64'e çevirme → `users/{uid}.photoBase64` güncelleme. Ekran, zaten var olan `watchUser` stream'i sayesinde yeni fotoğrafı otomatik gösterir — ekstra bir yenileme mantığı gerekmez.

## 4. Arkadaş Listesi ve Arama Sonuçları

- Hem Arkadaşlar listesindeki hem arama sonuçlarındaki `ListTile`'lara `leading` olarak küçük bir `CircleAvatar` eklenir — aynı gösterim mantığı (fotoğraf varsa göster, yoksa baş harf).
- Salt okunur: başka bir kullanıcının fotoğrafına dokunma/değiştirme yok.

## 5. Hata Yönetimi

- Fotoğraf seçimi iptal edilirse (kullanıcı geri gider, `image_picker` `null` döner): hiçbir şey değişmez.
- Firestore'a yazma başarısız olursa (ağ hatası vb.): sessizce yutulur, mevcut kod deseniyle tutarlı (bkz. konum paylaşımı/Overpass hata yönetimi) — uygulama çökmez, fotoğraf sadece değişmemiş olur.
- `photoBase64` alanı olmayan/`null` olan durumlarda her yerde güvenli şekilde baş harf avatarına düşülür.
