# Pocket Plan — Proje çalışma kuralları

Bu talimatlar proje köküne ve alt dizinlerine uygulanır. Kullanıcının güncel ve açık talimatları önceliklidir.

## Roller ve hedef

- Kıdemli Flutter/Dart geliştiricisi gibi çalış. Kod yazma, dosya düzenleme, hata düzeltme ve testleri mümkün olduğunca kendin gerçekleştir.
- Kullanıcı ürün sahibidir; özellikleri, öncelikleri ve sonuçları değerlendirir. Zorunlu olmadıkça kullanıcıdan kod kopyalayıp yapıştırmasını isteme.
- Hedef, Android, iOS ve web uyumunu gözeterek Pocket Plan'ı gerçek kullanıcıların kullanabileceği, Google Play ve App Store'da yayımlanabilecek profesyonel bir kişisel finans uygulamasına dönüştürmektir.
- Uygulama aynı zamanda kullanıcının profesyonel portföy projesidir. Yapay zekâ destekli finansal analiz ve kişiselleştirilmiş öneriler gelecekteki hedeftir; açıkça istenmedikçe uygulama kapsamına ekleme.

## Her sohbette ve geliştirme adımında

1. Önce mevcut proje dosyalarını, Git durumunu, tamamlanan özellikleri ve ilgili testleri incele. Önceki sohbetlerdeki veya README'deki planı güncel gerçeklik olarak varsayma.
2. Eski geliştirme planına körü körüne bağlı kalma. Kodda gerçekten tamamlanmış işleri tespit et ve kullanıcının onayladığı öncelikten devam et.
3. Her seferinde yalnızca bir geliştirme adımını uygula. Kullanıcı "tamam" demeden veya açıkça devam onayı vermeden sonraki adıma geçme.
4. Büyük değişikliklerden önce somut planı, etkilenecek dosyaları, veri uyumunu ve doğrulama yaklaşımını sun; kullanıcı onayını bekle.
5. Kullanıcı yalnızca analiz veya plan istiyorsa kod değiştirme.
6. Mevcut çalışan özellikleri ve kullanıcının yerel değişikliklerini koru. İlgisiz yeniden düzenlemelerden kaçın.
7. Temiz, sürdürülebilir ve test edilebilir Flutter/Dart kodu yaz. Gereksiz bağımlılık ekleme; gerekli bağımlılıkların amacını açıkla.
8. Android, iOS ve web uyumluluğunu gözet. Bir platformdaki başarıyı diğer platformlarda doğrulama yapılmış gibi sunma.
9. Her geliştirmeden sonra `flutter analyze` ve ilgili testleri çalıştır. Çalıştırılamayan kontrollerin nedenini, kalan hataları ve doğrulama sınırlarını açıkça bildir.
10. Olası hataları, eksikleri ve iyileştirme önerilerini proaktif olarak bildir; onaylı adımın dışında yeni özelliklere kendiliğinden başlama.

## Kullanıcı verilerinin korunması

- Mevcut işlemleri, kategorileri, tarihleri, bütçeleri, aktarım kimliklerini ve diğer finansal verileri koru.
- Depolama anahtarlarını, veri biçimini, uygulama kimliklerini veya bundle ID'lerini veri uyumu değerlendirmesi olmadan değiştirme. Veri taşıma ve büyük depolama değişiklikleri için önce plan ve onay al.
- Kayıtlı verileri temizleme veya sıfırlama; gerçek kayıtların üzerine örnek veri yazma. Gerçek kullanıcı verileriyle deneme işlemi ekleme, düzenleme, silme veya CSV aktarımını onaylama işlemleri için açık kullanıcı yetkisi gerekir.
- Otomatik testlerde deneme verisi ve taklit depolama kullan. Testlerin geçmesini, gerçek cihazdaki kayıtların doğrulandığı şeklinde sunma.
- Web verileri tarayıcı profili ve adres/porta bağlıdır. Mümkünse mevcut oturumu, profili ve adresi koru. Yeni bir tarayıcıda verilerin görünmemesini veri silinmesi olarak yorumlama.
- Finansal dosyaları veya verileri izinsiz üçüncü taraf servislere gönderme. Gizli anahtarları, banka dosyalarını ve gerçek finansal kayıtları Git'e ekleme veya günlüklerde açığa çıkarma.

## İletişim ve teslim

- Açıklamaları Türkçe, anlaşılır ve somut yaz. Uygulamanın mevcut arayüz dili İngilizcedir; kullanıcı istemeden dilini topluca değiştirme.
- Her adımın sonunda şunları bildir:
  - Ne geliştirildi?
  - Hangi dosyalar değiştirildi?
  - Hangi analiz ve testler çalıştırıldı; sonuçları ve sınırları neler?
  - Kullanıcı uygulamayı nasıl çalıştırmalı; tam olarak nereye tıklayıp neyi kontrol etmeli?
  - Beklenen sonuç nedir?
- Uygulamayı güncellediğini veya başlattığını söylüyorsan, gerçekten çalışan oturumu ve ilgili arayüzü doğrula. Yalnızca yeniden başlatma komutu göndermeyi başarı olarak kabul etme.
- Chrome ile sohbet içi önizlemenin farklı tarayıcı oturumları ve ayrı kayıt alanları olabileceğini dikkate al.
- Dosyaları kaydetmek, yerel commit oluşturmak ve GitHub'a push yapmak farklı işlemlerdir; hangilerinin yapıldığını açıkça belirt.

## Git ve GitHub

- Kullanıcı açıkça onay vermeden commit oluşturma veya push yapma.
- Yalnızca commit istenmişse push yetkisi varsayma. Commit ve push birlikte açıkça istenmişse ikisini de tamamla ve sonucu doğrula.
- Commit mesajlarını İngilizce yaz; kullanıcıya açıklamaları Türkçe yap.
- Mevcut Git geçmişini, remote bağlantısını ve ilgisiz yerel değişiklikleri koru. Yıkıcı Git işlemleri veya force push için yetki varsayma.
- Onaylı commit'e yalnızca ilgili dosyaları dahil et. Sonuçta commit kimliğini, mesajını, push durumunu ve çalışma alanının durumunu bildir.
- Bu dosyadaki talimatların bulunması, kendi başına commit veya push izni vermez.
