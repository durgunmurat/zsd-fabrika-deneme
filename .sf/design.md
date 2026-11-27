# SMT-262 Plasiyer sevkiyat özeti raporu — Tasarım

## Özet

Yeni rapor **ZMM_R_BDY_PLASIYER_OZET** (paket ZMM_BOLGE, işlem kodu ZBDY11 — elle oluşturulacak, bkz. `manual-steps.md`).

- Seçim ekranı: **Sevkiyat noktası** (çoklu seçim, zorunlu) ve **Tarih** (fiili mal çıkış tarihi, varsayılan bugün, zorunlu).
- Yalnızca mal çıkışı tamamlanmış teslimatlar gelir.
- Her plasiyer için bir satır: Plasiyer, Plasiyer adı, **Toplam teslimat**, **Normal teslimat**, **Depozito teslimatı**. Sayı sütunlarının altında genel toplam vardır.
- Bir teslimatta en az bir depozito kalemi varsa o teslimat depozito sayılır, normal sayılmaz. Toplam = Normal + Depozito.
- Plasiyeri olmayan teslimatlar "Plasiyer atanmamış" satırında toplanır.
- Liste ALV olarak açılır; standart araç çubuğundaki dışa aktarma ile Excel'e alınabilir.

## Teknik kararlar

0. **Program adı (geri bildirim, 2. üretim).** Eski ad `ZMM_R_PLASIYER_OZET` → yeni ad `ZMM_R_BDY_PLASIYER_OZET`. Neden: geliştirici geri bildirimi; kontrolün önerdiği ve paketteki `ZMM_R_BDY_*` düzenine uyan ad. Yeni adın sistemde olmadığı `object_exists` ile doğrulandı. Önceki turdaki `src/zmm_bolge/zmm_r_plasiyer_ozet.prog.abap` dosyası `objects.json`'da `REMOVE` olarak bildirildi. Kodda yalnızca başlık yorumu ve `REPORT` satırı değişti; mantık aynı.
1. **Kokpitle aynı kaynak ve filtre (orta risk notu).** ZMM_BDY_KOKPIT `FORM show_plasiyer_f4` (satır ~1182-1200) okundu. Plasiyer orada `ZSD_PACKHDR-KUNNR`, adı `KNA1-NAME1` (LEFT JOIN); filtre `ZSD_PACKHDR-VSTEL`, `ZSD_PACKHDR-WADAT_IST = tarih`, `VBUK-WBSTK = 'C'`; teslimat `ZSD_PACKITM-VBELN`. Rapor birebir aynı join ve filtreyi kullanır; tek fark depozitoları **hariç tutmak yerine** `DELTY` alanını okuyup sınıflandırmasıdır. Not: teknik notta "LIKP-WBSTK" geçiyordu; kokpit gerçekte `VBUK-WBSTK` kullanıyor, rapor da öyle yapar.
2. **Depozito sınıflandırma (orta risk notu).** Önce `DELTY = 'D'` kalemi olan teslimat numaraları tekil bir tabloya alınır; sonra plasiyer + teslimat bazında tekilleştirilip her teslimat bir kez sayılır (depozito tablosunda varsa depozito, yoksa normal). Böylece birden çok kalemi/paketi olan teslimat iki kez sayılmaz.
3. **Plasiyer satırı:** Birden fazla sevkiyat noktası seçilirse plasiyer, seçilen noktaların toplamıyla tek satırda gösterilir (varsayım "her plasiyer için tek satır").
4. **Tek veritabanı okuması**, döngü içinde SELECT yok, FOR ALL ENTRIES yok. `SELECT *` kullanılmadı.
5. **Klasik Open SQL söz dizimi.** İlk denetimde `@` host değişkenli (yeni) söz dizimi "sabit nokta aritmetiği bayrağı" hatası verdi (program henüz SAP'ta olmadığından öznitelikleri yok). Bayrağa bağımlılığı kaldırmak için klasik söz dizimine geçildi; işlev aynı.
6. **Tek program, include yok.** Teknik notta _TOP/_SEL/_CL include'ları önerilmişti. Program kısa (~200 satır) ve `check_source` SAP'ta olmayan include'ları denetleyemediği için tek dosya + yerel sınıf (`LCL_REPORT`) tercih edildi. İstenirse sonradan include'lara bölünebilir.
7. **Yetki:** Analist cevabına göre ek yetki kontrolü yok (ZBDY_KONT kullanılmadı); yalnızca işlem kodu başlangıç yetkisi geçerli.
8. **Metinler:** Mesaj, sütun başlıkları ve "Plasiyer atanmamış" metni `'...'(xxx)` biçiminde metin sembolüyle yazıldı; semboller oluşturulmasa da literal gösterilir. Seçim ekranı çerçeve başlığı (`TEXT-B01`) ve seçim metinleri elle girilmelidir.

## Varsayımlar

- "Tarih" fiili mal çıkış tarihidir (`ZSD_PACKHDR-WADAT_IST`), kokpitteki `P_DATUM` ile aynı anlam; tek gün seçilir.
- "Plasiyer" kokpitteki gibi paket başlığındaki müşteri numarasıdır (`ZSD_PACKHDR-KUNNR`).
- Aynı teslimat farklı plasiyerli iki paket başlığında görünürse (beklenmez) her plasiyerde birer kez sayılır.
- Kokpitteki "9. seçenek" (S_PLAS2) F4'ü depozitoları hariç tutar; bu rapordaki **Normal** sütunu oradaki listeyle, Toplam sütunu ise filtresiz F4 listeleriyle karşılaştırılmalıdır.

## Sözdizimi denetimi

| Nesne | Tür | Sonuç |
|---|---|---|
| ZMM_R_BDY_PLASIYER_OZET | PROG | **Temiz** (yeniden adlandırma sonrası ilk denetimde; önceki üretimde "fixed point arithmetic" hatası klasik Open SQL söz dizimiyle giderilmişti) |

## Test önerisi

1. **Temel sayım:** ZBDY11 → bir bölge deposu sevkiyat noktası ve mal çıkışı yapılmış bir gün seç → çalıştır. Beklenen: her plasiyer bir satır; Toplam = Normal + Depozito; alt satırda genel toplamlar.
2. **Kokpit karşılaştırması:** Aynı sevkiyat noktası/tarih için ZMM_BDY_KOKPIT'te plasiyer F4 listeleri (irsaliye yazdırma ekranı) açılır. Beklenen: raporda satırı olan plasiyerler, kokpit F4 listesindekilerle aynı; 9. seçenek (depozito hariç) listesinde yalnızca Normal > 0 olan plasiyerler görünür.
3. **Depozito kuralı:** Hem normal hem depozito kalemi olan bir teslimat seçilir (SE16: ZSD_PACKITM, aynı VBELN için DELTY = 'D' ve başka değer). Beklenen: teslimat yalnızca Depozito sütununda, bir kez sayılır.
4. **Mal çıkışı filtresi:** Mal çıkışı yapılmamış (VBUK-WBSTK ≠ 'C') teslimat raporda sayılmaz.
5. **Plasiyer atanmamış:** KUNNR'ı boş paket başlığı varsa "Plasiyer atanmamış" satırında görünür.
6. **Çoklu seçim:** İki sevkiyat noktası seçilir; sayılar tek tek çalıştırmaların toplamıyla tutmalı.
7. **Boş sonuç:** Veri olmayan bir gün seçilir. Beklenen: "Seçim kriterlerine uygun mal çıkışı yapılmış teslimat bulunamadı" mesajı.
8. **Excel:** ALV araç çubuğundan Dışa aktar → Elektronik tablo. Beklenen: tüm sütunlar Excel'e gelir.
