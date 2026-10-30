# Android gerçek depolama ve yeniden açılış testi (45.1)

## Güvenli çalıştırma

Bu test yalnızca `tool/test_android_persistence.py` üzerinden çalıştırılmalıdır.
Üretim uygulamasının kimliklerini veya veri biçimini değiştirmez. Test için
SharedPreferences taklidi kullanılmaz; native Android depolaması kullanılır.

Gerekenler:
- Python 3 ve projenin Flutter SDK'sı.
- Android SDK emulator ve platform-tools araçları.
- Kurulu `system-images/android-35/google_apis_playstore/arm64-v8a` imajı.
- Debug derlemesi için hazır Android toolchain. Çalıştırıcı lisans kabul etmez veya
  sistem imajı indirmez; eksik imaj varsa durur.

Proje kökünde:

```sh
python3 tool/test_android_persistence.py \
  --flutter /absolute/path/to/flutter \
  --android-sdk /absolute/path/to/Android/sdk
```

Çalıştırıcı geçici dizinde yeni ve boş bir AVD tanımlar. Mevcut AVD config,
userdata veya snapshot dosyalarını kopyalamaz. Emülatör adı ve portu doğrulanır;
telefon veya kullanıcının açık emülatörü hedeflenmez. İşlem bitince, hata olsa
bile, kendi emülatörü durdurulur ve yalnızca kendi geçici AVD dizini kaldırılır.
Logların bulunduğu ayrı geçici dizin inceleme için korunur.

Test dosyasını doğrudan bir telefonda çalıştırmayın. Test ayrıca açık izin
bayrağı ve rastgele oturum kimliği olmadan çalışmayı reddeder. İlk aşamada
SharedPreferences boş değilse veri eklemez; sonraki aşamalarda oturum kimliği
ve önceki aşama işareti eşleşmeden işlem/bütçe servislerini çalıştırmaz.
Depolamayı temizleme (`clear`, `pm clear`) veya uygulama kaldırma kullanılmaz.

## Dört ayrı uygulama çalıştırması

1. **seed:** Native depolamaya tarih, kategori ve aktarım kimliği taşıyan €100
   gelir, €20 gider ve €150 aylık bütçe kaydeder. Bakiye €80 doğrulanır.
2. **edit:** Yeniden açılışta tüm alanları ve bütçeyi doğrular. Arayüzde gideri
   €25 olarak düzenler. Aktarım kimliği üretim düzenleme akışıyla korunur.
3. **delete:** Yeni açılışta €25 gideri, diğer alanları, €150 bütçeyi ve €75
   bakiyeyi doğrular. Arayüzden silmeyi onaylar.
4. **verify:** Son açılışta yalnızca gelirin kaldığını, silinen giderin geri
   gelmediğini, bakiyenin €100 ve bütçenin €150 olduğunu doğrular.

Her aşama öncesinde host `adb shell am force-stop` çalıştırır ve uygulama PID'sinin
kalmadığını doğrular. Her aşama ayrı `flutter test` çalıştırmasıdır. Flutter'ın
varsayılan test sonrası uygulama kaldırma davranışı `--no-uninstall` ile kapatılır.
Uygulama kaldırılır veya depolama sıfırlanırsa sonraki aşama işaret doğrulaması
başarısız olur; test sessizce yeniden örnek veri oluşturmaz.

Başarılı sonuç: her aşama için `PASS` ve sonunda
`PASS: 4 phases across stopped/relaunched Android app processes`.

## Sınırlar

Bu doğrulama Android API 35 arm64 emülatörü içindir. Fiziksel Android/iPhone,
iOS, cihaz yeniden başlatma, kaldırıp yeniden kurma, işletim sistemi yedeğinden
geri yükleme ve dosya seçici/paylaşım testleri yerine geçmez. Emülatörün geçici
diski oturum sonunda kaldırılır; doğrulanan şey aynı emülatör oturumunda uygulama
sürecinin tamamen kapanıp yeniden açılmasıdır. Gerçek kullanıcı kaydı kullanılmaz.

## Son doğrulama

30 Ekim 2026 tarihinde Android API 35 arm64 üzerinde dört aşama da geçti:
`seed`, `edit`, `delete`, `verify`. Host çalıştırıcı başarı koduyla tamamlandı;
her aşamada uygulama süreci durdurulup tekrar başlatıldı. Native SharedPreferences
üzerindeki işlem alanları ve bütçe doğrulandı. `flutter analyze` hatasız geçti.

Üretim kodu, uygulama kimlikleri ve depolama biçimi değişmedi. Çalıştırıcı test
emülatörünü kapattı ve geçici AVD dizinini kaldırdı. iOS veya fiziksel cihaz testi
bu adımda yapılmadı. Bu sonuç şifreleme veya cihaz güvenliği doğrulaması değildir.
