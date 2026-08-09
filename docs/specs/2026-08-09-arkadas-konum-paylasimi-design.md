# Arkadaş Konum Paylaşımı — Tasarım

**Tarih:** 2026-08-09
**Bağlam:** "Yakında" (eski adıyla Harita Sosyal) uygulamasının ilk spec'inde ([2026-07-29-harita-sosyal-uygulama-design.md](2026-07-29-harita-sosyal-uygulama-design.md)) bilinçli olarak kapsam dışı bırakılan "gerçek zamanlı arkadaş konum takibi" özelliğinin, kullanıcı isteğiyle şimdi eklenmesi.

## 1. Genel Bakış

Kullanıcılar isterlerse kendi konumlarını arkadaşlarıyla paylaşabilir; paylaşan arkadaşların son bilinen konumu Harita ekranında ayrı bir işaretçi ile gösterilir. Paylaşım varsayılan olarak kapalıdır, kullanıcı Profil ekranından açıp kapatabilir.

**Kapsam dışı (bilinçli olarak eklenmedi):**
- Gerçek zamanlı/sürekli konum takibi — sadece Harita ekranı her açıldığında bir kerelik güncelleme.
- Konum geçmişi — sadece "son bilinen konum" tutulur, geçmiş kayıt tutulmaz.
- Belirli arkadaşlara özel paylaşım (hepsi ya da hiçbiri) — tek bir genel anahtar.

## 2. Veri Modeli (Firestore)

`users/{uid}` dokümanına üç yeni alan eklenir:

```
{
  ...mevcut alanlar (username, email, friends, createdAt),
  locationSharing: bool,        // varsayılan false
  location: GeoPoint?,          // null = paylaşılmıyor / hiç paylaşılmadı
  locationUpdatedAt: Timestamp?
}
```

`AppUser` modeli bu üç alanı da içerecek şekilde genişletilir (`fromFirestore` içinde `data['locationSharing'] as bool? ?? false` gibi güvenli varsayılanlarla — eski kayıtlarda bu alanlar yok, hata vermemeli).

## 3. UX Akışı — Profil Ekranı

Profil ekranına, kullanıcı bilgisinin altına bir `SwitchListTile` eklenir: **"Konumumu arkadaşlarımla paylaş"**.

- **Açılırsa:** `users/{myUid}.locationSharing = true` yazılır. Konum bu anda yazılmaz; bir sonraki Harita ekranı ziyaretinde/konum okumasında yazılır.
- **Kapatılırsa:** `locationSharing = false`, `location = null`, `locationUpdatedAt = null` tek seferde yazılır — önceki konum de silinir, sadece gösterimi durdurulmaz.
- Anahtarın durumu, Profil ekranının zaten kullandığı `watchUser` akışından (`StreamBuilder`) canlı okunur.

## 4. Harita Ekranı Davranışı

- `LocationService` gerçek bir konum döndürdüğünde (fallback/İstanbul değil) ve kullanıcının `locationSharing == true` ise: aynı anda `users/{myUid}.location` ve `locationUpdatedAt` güncellenir. Fallback konuma düşülürse hiçbir şey yazılmaz.
- Arkadaş listesi (`FriendsProvider.getFriends`, mevcut) çekilir; `locationSharing == true && location != null` olan arkadaşlar filtrelenip haritada **mor renkte, kişi ikonlu** ayrı bir işaretçi katmanında gösterilir.
  - Renk/ikon şeması: mavi = kendi konumun, yeşil = market, kırmızı = eczane, mor = arkadaş konumu.
- Bir arkadaş işaretçisine dokununca `SnackBar` ile kullanıcı adı + "X dakika/saat önce" gibi göreli bir zaman bilgisi gösterilir (`locationUpdatedAt`'tan hesaplanır).
- Paylaşımı olmayan/kapatmış arkadaşlar haritada hiç görünmez.

## 5. Hata Yönetimi

- Kendi konumu Firestore'a yazma başarısız olursa: sessizce yutulur, harita ve diğer özellikler etkilenmez.
- Arkadaş konumlarını çekme başarısız olursa: arkadaş işaretçileri o seferlik gösterilmez, kendi konum ve yakındaki yerler etkilenmez (mevcut Overpass hata deseniyle tutarlı).
- Kendi konum işaretçisi (mavi) her zaman gösterilir, paylaşım anahtarından bağımsızdır — anahtar yalnızca *başkalarının seni görüp görmeyeceğini* belirler.
