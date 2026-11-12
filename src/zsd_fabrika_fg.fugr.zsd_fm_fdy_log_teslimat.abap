FUNCTION zsd_fm_fdy_log_teslimat.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_PLAKA) TYPE  CHAR15
*"     REFERENCE(IV_SEFER_TARIHI) TYPE  DATS
*"     REFERENCE(IV_ROTA_NO) TYPE  CHAR20
*"     REFERENCE(IV_KUNNR) TYPE  KUNNR
*"     REFERENCE(IV_TESLIM_SONUCU) TYPE  CHAR20
*"     REFERENCE(IV_SUTAS) TYPE  CHAR1
*"     REFERENCE(IV_VARIS_TARIHSAAT) TYPE  DSTRING
*"     REFERENCE(IV_TAMAM_TARIHSAAT) TYPE  DSTRING
*"  EXPORTING
*"     REFERENCE(EV_SUCCESS) TYPE  FLAG
*"     REFERENCE(EV_MESSAGE) TYPE  STRING
*"     REFERENCE(EV_LOG_UID) TYPE  SYSUUID_C32
*"  TABLES
*"      IT_GORSELLER TYPE  ZSD_TT_FDY_GORSEL
*"----------------------------------------------------------------------
  DATA: ls_header    TYPE zsd_t_fdy_h,
        lt_images    TYPE STANDARD TABLE OF zsd_t_fdy_img WITH EMPTY KEY,
        ls_image     TYPE zsd_t_fdy_img,
        lt_items     TYPE STANDARD TABLE OF zsd_t_fdy_i WITH EMPTY KEY,
        ls_item      TYPE zsd_t_fdy_i,
        lv_img_posnr TYPE posnr, " Görsel Sayacı
        lv_itm_posnr TYPE posnr, " Ürün/Kalem Sayacı
        lv_dt_str    TYPE string,
        lv_xstring   TYPE xstring.

  CLEAR: ev_success, ev_message, ev_log_uid.

  CASE iv_teslim_sonucu.
    WHEN 'TamTeslim' OR 'EksikTeslim'.
    WHEN OTHERS.
      ev_message = 'Teslim sonucu TamTeslim veya EksikTeslim olmalıdır.'.
      RETURN.
  ENDCASE.

  TRY.
      ls_header-log_uid = cl_system_uuid=>create_uuid_c32_static( ).
      ev_log_uid        = ls_header-log_uid.
    CATCH cx_uuid_error.
      ev_message = 'UUID oluşturulamadı.'.
      RETURN.
  ENDTRY.

  IF iv_kunnr IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = iv_kunnr
      IMPORTING
        output = ls_header-kunnr.
  ENDIF.

  ls_header-plaka          = iv_plaka.
  ls_header-rota_no        = iv_rota_no.
  ls_header-sefer_tarihi   = COND #( WHEN iv_sefer_tarihi IS INITIAL THEN sy-datum ELSE iv_sefer_tarihi ).
  ls_header-teslim_sonucu  = iv_teslim_sonucu.
  ls_header-sutas          = iv_sutas.
  ls_header-status         = 'N'.
  ls_header-erdat          = sy-datum.
  ls_header-erzet          = sy-uzeit.
  ls_header-ernam          = sy-uname.

  IF iv_varis_tarihsaat IS NOT INITIAL.
    lv_dt_str = iv_varis_tarihsaat.
    REPLACE ALL OCCURRENCES OF REGEX '[- :T]' IN lv_dt_str WITH ''.
    IF strlen( lv_dt_str ) = 14 AND lv_dt_str CO '0123456789'.
      ls_header-varis_dat = CONV dats( lv_dt_str+0(8) ).
      ls_header-varis_tim = CONV tims( lv_dt_str+8(6) ).
    ENDIF.
  ENDIF.

  IF iv_tamam_tarihsaat IS NOT INITIAL.
    lv_dt_str = iv_tamam_tarihsaat.
    REPLACE ALL OCCURRENCES OF REGEX '[- :T]' IN lv_dt_str WITH ''.
    IF strlen( lv_dt_str ) = 14 AND lv_dt_str CO '0123456789'.
      ls_header-tamam_dat = CONV dats( lv_dt_str+0(8) ).
      ls_header-tamam_tim = CONV tims( lv_dt_str+8(6) ).
    ENDIF.
  ENDIF.

  LOOP AT it_gorseller INTO DATA(ls_gorsel).
    CASE ls_gorsel-gorsel_alani.
      WHEN 'MalKabulFisi' OR 'SutasIptalFaturaIrsaliye' OR 'IadeIrsaliyesiTutanak' OR 'TeslimataAitGorseller'.
      WHEN OTHERS.
        ev_message = |Geçersiz görsel alanı: { ls_gorsel-gorsel_alani }|.
        RETURN.
    ENDCASE.

    CLEAR ls_image.
    lv_img_posnr = lv_img_posnr + 10.

    ls_image-log_uid           = ls_header-log_uid.
    ls_image-posnr             = lv_img_posnr.
    ls_image-gorsel_alani      = ls_gorsel-gorsel_alani.
    ls_image-irsaliye_tarihi   = ls_gorsel-irsaliye_tarihi.
    ls_image-irsaliye_numarasi = ls_gorsel-irsaliye_numarasi.
    ls_image-ettn              = ls_gorsel-ettn.
    ls_image-erdat             = sy-datum.
    ls_image-erzet             = sy-uzeit.
    ls_image-ernam             = sy-uname.

    IF ls_gorsel-gorsel_base64 IS NOT INITIAL.
      CLEAR lv_xstring.
      CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
        EXPORTING
          input  = ls_gorsel-gorsel_base64
        IMPORTING
          output = lv_xstring
        EXCEPTIONS
          OTHERS = 2.
      IF sy-subrc = 0 AND lv_xstring IS NOT INITIAL.
        ls_image-image_b64 = lv_xstring.
      ENDIF.
    ENDIF.
    APPEND ls_image TO lt_images.

    " Ürünleri ZSD_T_FDY_I tablosuna ekleme
    LOOP AT ls_gorsel-urunler INTO DATA(ls_urun).
      CLEAR ls_item.
      lv_itm_posnr = lv_itm_posnr + 10.
      ls_item-log_uid = ls_header-log_uid.
      ls_item-posnr   = lv_itm_posnr.
      ls_item-img_posnr = lv_img_posnr.
      ls_item-matnr   = ls_urun-urun_kodu.
      ls_item-maktx   = ls_urun-urun_adi.
      ls_item-menge   = ls_urun-miktar.
      ls_item-erdat   = sy-datum.
      ls_item-erzet   = sy-uzeit.
      ls_item-ernam   = sy-uname.

      CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
        EXPORTING
          input  = ls_item-matnr
        IMPORTING
          output = ls_item-matnr
        EXCEPTIONS
          OTHERS = 1.

      APPEND ls_item TO lt_items.
    ENDLOOP.
  ENDLOOP.

  INSERT zsd_t_fdy_h FROM @ls_header.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    ev_message = 'Teslimat başlık tablosuna kayıt sırasında hata oluştu.'.
    RETURN.
  ENDIF.

  IF lt_images IS NOT INITIAL.
    INSERT zsd_t_fdy_img FROM TABLE @lt_images.
  ENDIF.

  IF lt_items IS NOT INITIAL.
    INSERT zsd_t_fdy_i FROM TABLE @lt_items.
  ENDIF.

  COMMIT WORK AND WAIT.
  ev_success = abap_true.
  ev_message = 'Teslimat takip kayıtları başarıyla loglandı.'.
ENDFUNCTION.
