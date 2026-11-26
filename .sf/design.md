# SMT-260 – BDY kokpit İrsaliye yazdırmada plasiyer listeleme

## Özet
Kokpitteki **9. İrsaliye & Fatura Yazdırma** kartı açılınca gelen popup'ta plasiyer alanının F4 listesi değişti. Liste artık **depozito teslimatlarını** (`ZSD_PACKITM-DELTY = 'D'`) hesaba katmıyor. Depozito dışında mal çıkışı yapılmış en az bir teslimatı olan plasiyer listede görünmeye devam ediyor. Yalnızca depozito teslimatı olan plasiyer listeden çıkıyor. Kokpitteki diğer seçeneklerin listeleri aynı kaldı.

## Teknik kararlar
- **Filtre noktası:** 9. kart `sapevent:/DSL/ES10_P100` olayını tetikliyor. Bu olay 0202 ekranını açıyor, plasiyer alanı da `S_PLAS2`. Alanın F4'ü `FORM show_plasiyer_f4`. Filtre bu FORM'daki ham veri SELECT'ine eklendi (`zsd_packhdr` / `zsd_packitm` / `vbuk` / `kna1`).
- **Kapsamı yalnızca 9. seçenekle sınırlama:** `show_plasiyer_f4` FORM'unu `S_PLAS_Z` (8. Faturalama İşleme) ve `S_PLAS3` (2. Sepet Tamamlama) da kullanıyor. Bu yüzden yerel bir range (`lr_delty`) eklendi. Range yalnızca `pv_dynprofield = 'S_PLAS2'` iken `E EQ 'D'` satırıyla doluyor, diğer alanlarda boş kalıyor. Boş range'li `IN` koşulu filtre uygulamaz, yani diğer seçeneklerin davranışı değişmez.
- **Karışık teslimat:** Filtre kalem düzeyinde. SELECT `DISTINCT` ve teslimat numarası kaleme göre geliyor. Böylece 'D' olmayan en az bir kalemi olan teslimat (ve onun plasiyeri) listede kalıyor. `DELTY` boş olan kalemler de range `E EQ 'D'` olduğu için kalıyor.
- **Satır ~977'deki SELECT** (`zmm_t_bdy_gi_h JOIN zsd_packitm`) 7. kartın (ZBDY02) hata rozeti sayacı. 9. seçenekle ilgisi yok, dokunulmadı.
- **Etki analizi:** Depozito filtresi F4 sonrası yazdırma akışını (`/DSL/ES10_P100`, `/DSL/ES00_P100`, özet tablo, yükleme formu SUBMIT'leri) etkilemez. Kapsam yalnızca F4 plasiyer listesi.
- HANA: Ek bir veritabanı çağrısı eklenmedi. Koşul mevcut SELECT'in WHERE'ine eklendi. 7.40 sözdizimi (`IN @range`) kullanıldı.

## Varsayımlar
- Depozito = `ZSD_PACKITM-DELTY = 'D'` (talep sahibinin cevabı). `DELTY` alanı DDIC'de doğrulandı: `CHAR1`, veri elemanı/domain `ZSD_DELTY`, domain'de sabit değerler var. Sabit değer listesinin içeriği (yani 'D' değerinin domain'de tanımlı olduğu) MCP ile okunamadı. Talep sahibinin cevabına güvenildi.
- Tarih, sevkiyat noktası ve mal çıkışı (`WBSTK = 'C'`) kriterleri aynı kaldı.

## Sözdizimi denetimi
- `ZMM_BDY_KOKPIT` (PROG): **temiz**. Hata ve uyarı yok. Dosyanın tam metniyle denetlendi.

## Test önerisi
1. Aynı tarih ve sevkiyat noktası için şu plasiyerleri hazırla: A yalnızca depozito teslimatlı (`DELTY = 'D'`, mal çıkışı yapılmış), B depozito ve normal teslimatlı, C yalnızca normal teslimatlı.
2. ZMM_BDY_KOKPIT'te tarihi ve sevkiyat noktasını gir, **9. İrsaliye & Fatura Yazdırma** kartına tıkla, plasiyer alanında F4'e bas.
   - Beklenen: B ve C listede görünür, A görünmez.
3. B için "İrsaliyesi/Faturası Yazdırılan" kolonları yalnızca normal teslimata göre dolar. Depozito teslimatının yazdırma durumu kolonları etkilemez.
4. Regresyon: **8. Faturalama İşleme** ve **2. Sepet Tamamlama** popup'larında F4'e bas.
   - Beklenen: A dahil önceki liste aynen gelir.
5. 9. seçenekte bir plasiyer seçip yazdırmayı çalıştır. Akış değişmeden çalışır.
