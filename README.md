# Yakında

Kullanıcının konumunu ve yakındaki market/eczaneleri harita üzerinde gösteren,
arkadaş ekleme özelliğine sahip bir Flutter uygulaması.

## Kurulum

Bağımlılıkları indir:

```
flutter pub get
```

## Uygulamayı çalıştırma

İki yoldan biriyle çalıştırabilirsin:

### Yöntem 1 — Fiziksel Android telefon (önerilen)

1. Telefonunda **Ayarlar > Telefon Hakkında** kısmından "Yapı Numarası"na
   (Build Number) art arda 7 kez dokunarak Geliştirici Seçenekleri'ni aç.
2. **Ayarlar > Geliştirici Seçenekleri** içinden **USB Hata Ayıklama**'yı
   (USB Debugging) aç.
3. Telefonu USB kabloyla bilgisayara bağla, telefonda çıkan "Bu bilgisayara
   güven" uyarısını onayla.
4. Bağlantıyı doğrula:
   ```
   adb devices
   ```
   Telefonun `device` durumunda listelenmesi gerekir.
5. Uygulamayı çalıştır:
   ```
   flutter run
   ```

Gerçek telefonda gerçek GPS kullanıldığı için konum özelliği doğrudan
çalışır, ekstra bir ayar gerekmez.

### Yöntem 2 — Android Emulator

1. Emulator'ü başlat:
   ```
   emulator -avd pixel_api34
   ```
2. Emulator açıldıktan sonra uygulamayı çalıştır:
   ```
   flutter run -d pixel_api34
   ```
3. Emulator'de gerçek GPS olmadığı için sahte bir konum girmen gerekir:
   emulator penceresindeki `...` (Extended Controls) simgesine tıkla >
   **Location** sekmesi > bir enlem/boylam gir > **Send**.

> Not: Bu depoyu geliştirirken kullanılan geliştirme makinesinde emulator
> grafik kütüphanesiyle (SwiftShader) ilgili bir uyumsuzluk nedeniyle
> açılamadı; bu yüzden uygulama bu makinede sadece derleme (`flutter build
> apk --debug`) ve statik analiz (`flutter analyze`) ile doğrulandı, gerçek
> cihazda uçtan uca akış testi henüz yapılmadı. Farklı bir makinede veya
> fiziksel telefonda emulator/çalıştırma sorunsuz olmalıdır.

## Ekranlar

- **Harita** (alt menü, sol sekme): Kendi konumunu mavi bir işaretçiyle,
  yakındaki marketleri yeşil, eczaneleri kırmızı işaretçilerle gösterir.
  Bir işaretçiye dokununca yer adı ekranın altında kısa süreliğine
  görünür.
- **Profil** (alt menü, sağ sekme): Kullanıcı adı/e-posta bilgisini,
  kullanıcı adına göre arkadaş arama ve ekleme alanını, ve mevcut
  arkadaş listesini gösterir. Sağ üstteki simgeden çıkış yapılabilir.

## Fiziksel telefona geçiş

Geliştirme sürecinde emulator kullanıp daha sonra gerçek telefona
geçmek istersen kodda hiçbir değişiklik gerekmez — telefonu USB Hata
Ayıklama açık şekilde bağlayıp `flutter run` çalıştırman yeterli
(bkz. Yöntem 1 yukarıda).
