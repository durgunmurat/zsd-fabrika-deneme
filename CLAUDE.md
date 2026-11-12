# CLAUDE.md — ZSD_FABRIKA (abapGit aynası, deneme)

Bu depo, ESD geliştirme sistemindeki `ZSD_FABRIKA` paketinin abapGit ile alınmış **salt aynasıdır**. SAP ana kaynaktır, bu depo değildir. Burada yaptığın her değişiklik bir öneridir; geliştirici onaylamadan SAP'a geri alınmaz.

Çalışma dili Türkçedir. Kod yorumları ve teknik adlar ABAP standardında İngilizce kalır.

## 1. Sistem

- SAP ERP 6.0 EHP7, NetWeaver 7.40 SP27. Veritabanı şu an HANA **değil**, yakında HANA'ya geçilecek.
- Sistem ECC. S/4HANA, RAP, ABAP Cloud, clean-core **yok**. Bunları önerme.
- OData: SAP Gateway / SEGW tabanlı **OData V2**. `*_MPC` ve `*_DPC` üretilmiş sınıflardır.
- UI5/Fiori ön yüzü bu depoda **yoktur** ve burada geliştirilmez.

### Sistem ve yayın yolu

- **ESD:** geliştirme sistemi (client 105). Bu depo ESD'nin aynasıdır, kodlar burada geliştirilir.
- **ESQ:** ESD'nin kalite sistemi. Transport ESD'den ESQ'ya taşınır (import'u kullanıcı/Basis yapar).
- **FRD:** Fiori front-end (Gateway hub) sunucusu. UI5 uygulaması FRD'de çalışır. OData servisi FRD'de `/IWFND/MAINT_SERVICE` ile kaydedilir ve **backend olarak ESQ**'ya (sistem alias) yönlendirilir.
- Sonuç: DPC/MPC ve servis modelindeki bir değişiklik canlıya şu sırayla gider: ESD → transport → ESQ → FRD'de servis kaydı/önbellek (`/IWFND/CACHE_CLEANUP`, `/IWBEP/CACHE_CLEANUP`). Servis kayıtları FRD'de bu depo dışında yapılır.
- Bu depoda yapacağın hiçbir değişiklik ESQ veya FRD'ye doğrudan bağlanmayı gerektirmez. Önerme.
- Servis sözleşmesini (entity set, property, function import adı) bozacak değişiklik FRD'deki UI5 uygulamasını da etkiler. Böyle bir değişiklikten önce uyar ve geriye dönük uyumlu alternatif öner.
- Gateway hub üzerinden gelen çağrılar kullanıcı SSO'suyla ESQ'da çalışır, yani yetki kontrolleri **ESQ'daki kullanıcı rolleriyle** değerlendirilir. Yetki önerirken bunu hesaba kat.

## 2. Depo yapısı

- `.abapgit.xml`: abapGit ayarı. Dokunma.
- `src/`: PREFIX mantığı, paket öneki (`zsd_fabrika`) dizinden çıkarılmış, düz dizin.
- `*.abap`: kaynak kod. Değiştirilebilir.
- `*.xml` (meta veri: `.clas.xml`, `.tabl.xml`, `.dtel.xml`, `.iwsv.xml`, `.iwmo.xml`, `.sicf.xml`, `.tran.xml`, `.devc.xml`, `package.devc.xml`): abapGit serileştirmesi. **Elle düzenleme.** Bir değişiklik meta veri gerektiriyorsa (yeni alan, yeni parametre, yeni nesne) bunu ayrıca listele ve geliştiriciye bırak.
- Dosya adlarında boşluk bulunan nesneler (`iwsv`, `iwmo`, `sicf`) bilerek öyledir. Yeniden adlandırma.

## 3. Paket içeriği (özet)

- Sınıflar: `ZSD_CL_FDY_GENERAL` (yardımcı mantık), `ZCL_SD_FDY_DELIVERY_REST`, `ZCL_SD_FDY_RETURN_REST` (SICF REST işleyicileri), `ZCL_ZSD_FDY_GR_DPC(_EXT)` ve `..._MPC(_EXT)` (OData).
- Fonksiyon grubu `ZSD_FABRIKA_FG`: otomatik mal girişi ve log fonksiyonları.
- Programlar: `ZSD_R_FDY_IRSALIYE_GIRIS` (+ `_CL`, `_TOP`, ekranlar), `ZSD_R_FDY_AUTO_GR_JOB`.
- İşlem kodları `ZFDY01`, `ZFDY02`. Tablolar ve yapılar `ZSD_T_FDY_*`, `ZSD_S_FDY_*`.
- **Bağımlılık notu:** Bu depo paketin kendi içeriğidir. Başka Z paketlerindeki nesnelere (ör. ZMM_BOLGE) ve SAP standart nesnelerine yapılan referanslar çözülmeyebilir. Göremediğin bir nesneyi **uydurma**. "Bu nesneyi depoda göremiyorum" de ve varsayımını açıkça yaz.

## 4. Kodlama kuralları (NW 7.40 SP27 sınırı)

Kullanılabilir ve tercih edilen: inline declaration (`DATA(...)`, `FIELD-SYMBOL(...)`), `VALUE`, `NEW`, `CORRESPONDING`, `CONV`, `COND`, `SWITCH`, `REDUCE`, `FOR`, `FILTER`, tablo ifadeleri, string template, yeni Open SQL (`@` host variable, virgüllü alan listesi).

Kullanma: 7.50+ özellikleri (`FINAL`, `UNION`, CTE/`WITH`, 7.50+ SQL işlevleri), RAP, ABAP Cloud kısıtlı söz dizimi. Emin olmadığın söz dizimini "doğrulanamadı, SAP'ta syntax check gerekir" diye işaretle.

### HANA'ya hazır yazım

- `SELECT *` yok. Yalnızca gereken alanlar.
- Döngü içinde `SELECT` yok. Veriyi `JOIN` ile veya `FOR ALL ENTRIES` ile (önce iç tablonun boş olmadığını kontrol et, yinelenenleri düşün) topla.
- Sıralamaya güvenme. Sıra gerekiyorsa `ORDER BY` veya `SORT` yaz.
- `SELECT SINGLE` yalnızca tam anahtarla. Aksi halde `UP TO 1 ROWS` + `ORDER BY`.
- Native SQL, DB'ye özgü hint, cluster/pool tablo bağımlılığı yok.
- Standart tablolara doğrudan erişimde S/4'te değişen tabloları (BSEG, MKPF/MSEG, KONV, VBUK/VBUP) not et. Mümkünse standart API/BAPI kullan.

### Genel

- Yeni geliştirme **sınıf tabanlı**. Yeni `FORM` veya fonksiyon grubu açma (mevcut yapıyı sürdürmek hariç). Eski söz dizimi (`WITH HEADER LINE`, `TABLES`, `OCCURS`, `MOVE`, `COMPUTE`) yazma.
- Veri erişimi, iş mantığı ve sunum ayrı sınıflarda. Bağımlılıkları arayüzle enjekte et.
- Hata yönetimi sınıf tabanlı istisnalarla. Kullanıcı mesajları mesaj sınıfından, sabit metin gömme.
- Kullanıcıya veri döndüren her yerde `AUTHORITY-CHECK`. `SY-SUBRC` kontrolünü atlama.
- Müşteri namespace'i **Z** (Y değil). Yerel değişkenler `lv_/ls_/lt_/lo_/lr_`, nitelikler `mv_/ms_/mt_/mo_`, parametreler `iv_/is_/it_/io_/ev_/es_/et_/rv_`. Mevcut dosyanın kalıbı farklıysa onu izle.
- Public metotlara kısa ABAP Doc. "Neden" yorumu yaz, "ne" yorumu yazma. Yorum satırına alınmış eski kod bırakma.

## 5. OData ve REST kuralları

- `*_DPC` ve `*_MPC` üretilmiş sınıflardır, **değiştirme**. Değişiklik `*_DPC_EXT` ve `*_MPC_EXT` içinde yapılır.
- Servis sözleşmesini (entity set, property adları) bozacak değişiklikten önce uyar.
- `$filter`, `$select`, `$top/$skip`, `$orderby`, `$expand` desteğini düşün. Tüm veriyi tek çağrıda döndürme.
- Hata dönüşünde `/IWBEP/CX_MGW_BUSI_EXCEPTION` ile anlamlı mesaj ver. SQL hatası, tablo adı gibi teknik ayrıntıyı istemciye sızdırma.

## 6. Güvenlik ve gizlilik

- Depoda şifre, token, kullanıcı adı, IP, gerçek müşteri/personel verisi **olmamalı**. Rastlarsan değiştirmeden raporla.
- Değişiklik yazarken yeni gizli bilgi, sabit sunucu adresi veya sabit kullanıcı ekleme.
- Gerçek veriyle çalışıyormuş gibi örnek üretme. Testlerde anonim, minimal örnek veri kullan.
- SAP standart nesnelerini değiştirmeyi önerme. Sıra: kullanıcı exit/BAdI > implicit/explicit enhancement > Z kopya > modification (yalnızca açık talimatla).

## 7. Çalışma biçimi

Her görevde sırasıyla:

1. İlgili dosyaları oku. Neyi okuduğunu belirt.
2. Varsayımlarını ve göremediğin bağımlılıkları listele.
3. Küçük, hedefli değişiklik öner. Tüm dosyayı baştan yazma. Değişiklikleri `diff` olarak ver.
4. Yeni iş mantığı için **ABAP Unit** testi yaz (yerel test sınıfı, `FOR TESTING`, `RISK LEVEL HARMLESS`, `DURATION SHORT`). Gerçek veritabanına bağımlı olma, bağımlılığı test double ile değiştir.
5. Özet ver: ne değişti, neden, hangi kontroller **yapılamadı** (syntax check ve ATC SAP'ta yapılır), bilinen riskler.

Yapamadığını veya doğrulayamadığını açıkça söyle. Tahmin ile gerçeği ayır. Uzun açıklama yazma.

## 8. Görev şablonları

- **Açıkla:** Nesnenin amacı, giriş/çıkış, ana metotlar, veri akışı, çağıranlar. Emin olmadığın yeri işaretle.
- **Spec kontrolü:** Verilen spesifikasyonda eksik veya belirsiz noktaları (alan tanımları, hata durumları, yetki, performans, test edilebilirlik) listele, 0–100 puan ver ve nedenini yaz. Eşik altında kod üretme, önce eksikleri sor.
- **Kod üret:** Yalnızca `.abap` dosyası ve ABAP Unit testi üret. Meta veri gereksinimini (yeni tablo, data element, mesaj) ayrı bir liste olarak ver.
- **Gözden geçir:** Bu dosyadaki HANA hazırlığı, yetki, hata yönetimi ve test edilebilirlik sorunlarını önem sırasıyla listele.

## 9. Yapmayacakların

- `.xml` meta veri dosyalarını elle düzenlemek, nesne dosyalarını yeniden adlandırmak veya silmek.
- `.abapgit.xml` ve `package.devc.xml` içeriğini değiştirmek.
- Depoda olmayan nesneleri var saymak.
- Üretim sistemine, transporta veya SAP'a doğrudan bağlanmayı önermek. SAP'a geri alma ve transport, geliştirici onayıyla ayrı süreçte yapılır.
