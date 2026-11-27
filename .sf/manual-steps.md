# SMT-262 Elle yapılacak adımlar

1. **Program özniteliklerini kontrol et** (SE38 → ZMM_R_PLASIYER_OZET → Nitelikler)
   - Tür: Yürütülebilir program, Paket: ZMM_BOLGE, Talep: ESDK968596
   - Başlık: "Plasiyer sevkiyat özeti"
   - "Sabit nokta aritmetiği" işaretli olsun (varsayılan).

2. **Metin sembolleri** (SE38 → Git → Metin öğeleri → Metin sembolleri)
   | Kimlik | Metin |
   |---|---|
   | B01 | Seçim kriterleri |
   | M01 | Seçim kriterlerine uygun mal çıkışı yapılmış teslimat bulunamadı |
   | T01 | Plasiyer atanmamış |
   | C01 | Plasiyer |
   | C02 | Adı |
   | C03 | Plasiyer adı |
   | C04 | Toplam |
   | C05 | Toplam teslimat |
   | C06 | Normal |
   | C07 | Normal teslimat |
   | C08 | Depozito |
   | C09 | Depozito teslimat |
   | C10 | Depozito teslimatı |

   (B01 dışındakiler kodda literal olarak da var; semboller oluşturulmasa da çalışır. "Metinleri karşılaştır" ile otomatik alınabilir.)

3. **Seçim metinleri** (Metin öğeleri → Seçim metinleri)
   - S_VSTEL: "Sevkiyat noktası"
   - P_DATUM: "Mal çıkış tarihi"

4. **İşlem kodu ZBDY11** (SE93)
   - Tür: Program ve seçim ekranı (rapor işlemi)
   - Program: ZMM_R_PLASIYER_OZET, Ekran: 1000
   - Kısa metin: "Plasiyer sevkiyat özeti"
   - Paket: ZMM_BOLGE, Talep: ESDK968596
   - GUI desteği: SAP GUI for Windows işaretli.

5. **Yetki:** Ek yetki nesnesi yok. Depo sorumlularının rollerine (PFCG) S_TCODE = ZBDY11 eklenmeli.
