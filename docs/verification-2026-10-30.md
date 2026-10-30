# Pocket Plan doğrulama — 30 Ekim 2026

## Kapsam

44.9 üst menü değişikliği ve finansal dosya girişlerinin güvenlik sınırları.
Testler yalnızca sahte veri/depolama kullanır. Gerçek finansal kayıtlar, uygulama
kimlikleri, depolama anahtarları ve veri biçimi değiştirilmedi.

## Otomatik kontroller

- `flutter analyze`: hatasız.
- `flutter test`: 108 test başarılı.
- `flutter test --platform chrome`: 108 test başarılı.
- Yeni `security_boundaries_test.dart`: yanlış yedek alan türleri, negatif/sıfır
  tutarlar, geçersiz tarihler, geçersiz bütçe değerleri ve korunan anahtarlar
  reddedildiğinde depolamaya yazılmadığını doğrular. JSON ve CSV dosya limitlerinin
  UTF-8 baytlarını saymasını ve CSV'de sonlu olmayan tutarların atlanmasını sınar.
- Mevcut testler: bozuk yükleme, başarısız kayıt, eski ekranın yeni veriyi ezmesinin
  engellenmesi, aktarım tekrarları, açık geri yükleme onayı ve kesinti sonrası
  geri yükleme kurtarması.
- Seçili kaynak ve platform dosyalarında yaygın özel anahtar/token kalıpları ile
  Git'teki tipik anahtar dosya adları tarandı; eşleşme bulunmadı. Bu sınırlı tarama,
  tüm gizli bilgilerin yokluğunu veya Git geçmişinin temizliğini garanti etmez.

## Android/iOS ortamı

- Flutter 3.44.9 / Dart 3.12.2, macOS arm64.
- `flutter doctor -v`: bazı Android SDK lisansları kabul edilmemiş.
- İlk kontrolde `adb devices -l`: bağlı Android cihazı yoktu. Android SDK
  Platform 35 lisansı mevcut olduğundan Gradle eksik Platform 35 bileşenini kurdu.
  `flutter build apk --debug --no-pub`: başarılı; debug APK üretildi.
- `Medium_Phone_API_35`, `-read-only -no-snapshot -no-window -no-audio` ile
  geçici test oturumu için başlatıldı. Bu mod temel emülatör verilerini kalıcı
  değiştirmez. Test, uygulamadan önce SharedPreferences kanalını sahte
  depolamayla değiştirir; gerçek finansal kayıtları okumaz/yazmaz.
- Flutter SDK `integration_test` yalnızca geliştirme bağımlılığı olarak eklendi;
  altı test bağımlılığı çözümlendi, üretim paketlerinin sürümleri değişmedi.
- `flutter test integration_test/app_smoke_test.dart -d emulator-5554`:
  **1 native test başarılı**. Menüden aylık özet, arama, işlem düzenleme,
  aktarım kimliğinin korunması, silmeyi iptal/onay ve bakiye güncellemeleri
  Android API 35 emülatöründe doğrulandı.
- Bu test sahte SharedPreferences kullanır; native diskte kalıcılığı,
  dosya seçici/paylaşım eklentilerini veya fiziksel cihaz güvenliğini doğrulamaz.
- `xcrun simctl list devices available` ve `list runtimes`: boş.
- CocoaPods kurulu değil; Flutter, iPhone'a erişemiyor.
- `flutter build ios --simulator --debug --no-pub`: başarısız. Xcode,
  iOS Simulator hedefi bulamadı ve iOS 26.5 platformunun kurulu olmadığını
  bildirdi. iOS derlemesi ve cihaz testi geçmedi.
- Gerçek cihazdaki kayıtlar üzerinde test yapılmadı. Web testleri cihaz testi
  sayılmaz; başarılı debug derlemesi de cihazda çalıştırma testi sayılmaz.

## Yayın öncesi açık işler

1. Android SDK lisanslarını kullanıcı inceleyip kabul etmeli; uyumlu SDK/JDK ve
   izole emülatör/cihaz test ortamı doğrulanmalı.
2. iOS Simulator runtime ve gerekli native bağımlılık araçları kurulmalı;
   fiziksel iPhone testi için cihaz bağlantısı ve Developer Mode hazırlanmalı.
3. İzole test ortamında ekleme/düzenleme/silme, yeniden açılışta kalıcılık,
   dosya seçme/paylaşma, CSV aktarımı ve yedek geri yükleme cihazda sınanmalı.
4. Android release yapılandırması debug imzası kullanıyor; yayın imzası ayrı
   planlanmalı. Mevcut application ID/bundle ID bu doğrulamada değiştirilmedi.
5. SharedPreferences ve JSON yedekleri uygulama düzeyinde şifreli değil.
   Şifreli depolama/yedek için veri taşıma ve anahtar yönetimi planı gerekir.

Bu çalışma sızma testi, bağımlılık CVE denetimi veya mağaza yayını için güvenlik
sertifikası değildir. Üretim bağımlılıklarının sürümleri ve platform izinleri değiştirilmedi.
