# iOS Simulator hazırlığı ve temel test (45.2)

## Mevcut doğrulama — 30 Ekim 2026

Bu adım henüz tamamlanmadı. Xcode SDK'ları mevcut, ancak kullanılabilir iOS
Simulator runtime'ı yok. Runtime kurulmadan iOS derlemesi veya native test
başarılı kabul edilmemelidir.

Denemeler:
- Xcode CLI: iOS 26.5 / arm64, açık sürüm seçimiyle (23F73).
- Xcode CLI: uyumlu sürümün otomatik seçimi (23F77).
- Xcode CLI: geçici dizine export seçeneği.
- Xcode > Settings > Components: iOS 26.5.1 + iOS 26.5 Simulator.

CLI denemeleri hazırlıkta kaldı ve durduruldu. Apple MobileAsset kayıtlarında
iOS runtime görevi için tekrarlanan `Stalled` durumu görüldü. Xcode arayüzü de
`Preparing…` gösterdi. Runtime başarıyla indirilmiş veya kurulmuş değildir.
Ağ tercihlerinde değişiklik yapılmadı; sistem önbellekleri temizlenmedi,
güvenlik korumaları kapatılmadı ve CocoaPods kurulmadı.

`flutter analyze` hatasız geçti. Python çalıştırıcısının sözdizimi ve `--help`
kontrol edildi. Eksik runtime ile çalıştırıcı, simülatör oluşturmadan erken
hata verdi. Bu kontroller native iOS uygulama testi değildir.

## Runtime hazır olduğunda

Runtime'ın kurulduğunu doğrulayın:

```sh
xcrun simctl list runtimes
```

Çıktıdaki kullanılabilir iOS runtime kimliğini kullanarak proje kökünde:

```sh
python3 tool/test_ios_smoke.py \
  --flutter /absolute/path/to/flutter \
  --runtime com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

Çalıştırıcı yalnızca kendi oluşturduğu yeni iPhone 17 simülatörünü kullanır.
`integration_test/app_smoke_test.dart` uygulama açılmadan SharedPreferences
kanalını sahte depolamayla değiştirir. Menü, aylık özet, arama, düzenleme,
silmeyi iptal/onay, aktarım kimliği ve bakiye güncellemeleri sınanır.

Test sonrası yalnızca yeni simülatör kapatılır ve kaldırılır. Loglar çıktıda
belirtilen geçici klasörde kalır. Telefon, mevcut simülatör veya tarayıcı
kayıtları hedeflenmez. Bundle ID, uygulama imzası, veri biçimi ve üretim kodu
bu adımda değiştirilmedi; mevcut Swift Package Manager bağlantısı korunur.

Bu temel test native diskte kalıcılık, gerçek dosya seçici/paylaşım eklentileri
veya fiziksel iPhone doğrulaması değildir. Bunlar ayrı testler gerektirir.

## Referanslar

- Apple'ın Components ve CLI kurulum belgesi:
  https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components
- Benzer hazırlıkta kalma sorunu hakkında kullanıcı bildirimleri (Apple'ın
  onaylanmış çözüm duyurusu değildir):
  https://developer.apple.com/forums/thread/843992
