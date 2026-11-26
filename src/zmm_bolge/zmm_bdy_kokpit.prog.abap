*&---------------------------------------------------------------------*
*& Report  ZMM_BDY_KOKPIT
*& Description: Bölge Depo Yönetimi - HTML/Fiori Tabanlı Akıllı Kokpit
*&---------------------------------------------------------------------*
REPORT zmm_bdy_kokpit.

TYPE-POOLS: vrm.

*----------------------------------------------------------------------*
* MAKROLAR (SUBMIT Sonrası Kaybolan/Yutulan Mesajları Yakalamak İçin)
*----------------------------------------------------------------------*
DEFINE m_clear_msg.
  CLEAR: sy-msgid, sy-msgno, sy-msgty, sy-msgv1, sy-msgv2, sy-msgv3, sy-msgv4.
END-OF-DEFINITION.

DEFINE m_show_msg.
  IF sy-msgid IS NOT INITIAL.
    IF sy-msgty = 'E' OR sy-msgty = 'A' OR sy-msgty = 'W'.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDIF.
END-OF-DEFINITION.

*----------------------------------------------------------------------*
* GLOBAL TANIMLAMALAR
*----------------------------------------------------------------------*
CLASS lcl_event_receiver DEFINITION DEFERRED.

DATA: gv_pernr TYPE pernr_d,
      gv_kunnr TYPE kunnr,
      gv_matnr TYPE matnr,
      gv_inco  TYPE inco2.

" YENİ EKLENEN SAYAÇ DEĞİŞKENLERİ
DATA: gv_err_zbdy01 TYPE i, " ZBDY01 Hatalı Kayıt Sayısı
      gv_err_zbdy02 TYPE i. " ZBDY02 Hatalı Kayıt Sayısı

DATA: go_docking   TYPE REF TO cl_gui_docking_container,
      go_html      TYPE REF TO cl_gui_html_viewer,
      go_event_rec TYPE REF TO lcl_event_receiver.

DATA: gv_url TYPE c LENGTH 255.

*----------------------------------------------------------------------*
* ANA EKRAN (KOKPİT TEPESİ) - TARİH VE ŞUBE(VSTEL) ALANI
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_main WITH FRAME TITLE text-m01.
PARAMETERS: p_datum TYPE sy-datum DEFAULT sy-datum OBLIGATORY,
            p_vstel TYPE vstel OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b_main.

*----------------------------------------------------------------------*
* POP-UP EKRANLARI
*----------------------------------------------------------------------*
" ZVF04 - Faturalama İşleme
SELECTION-SCREEN BEGIN OF SCREEN 0201 AS WINDOW TITLE text-z01.
SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE text-z02.
SELECT-OPTIONS: s_plas_z FOR gv_kunnr.
SELECTION-SCREEN END OF BLOCK b3.
SELECTION-SCREEN END OF SCREEN 0201.

" 3. İrsaliye & Fatura Toplu Yazdırma
SELECTION-SCREEN BEGIN OF SCREEN 0202 ."." AS WINDOW TITLE text-z03.
SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE text-z04.
SELECT-OPTIONS: s_plas2 FOR gv_kunnr.
SELECTION-SCREEN END OF BLOCK b4.

" Yazıcı ve Opsiyonel Formlar Bloğu
SELECTION-SCREEN BEGIN OF BLOCK b_print2 WITH FRAME TITLE text-prt.
PARAMETERS: p_front  TYPE rspoprname AS LISTBOX VISIBLE LENGTH 10 OBLIGATORY,
            p_copy_k TYPE tdsfcopies DEFAULT '1', " Kapak & Yükleme Formu Kopya
            p_copy_i TYPE tdsfcopies DEFAULT '2', " İrsaliye & Fatura Kopya
            cb_yukf  AS CHECKBOX . " Yükleme Formunu Tekrar Yazdır
SELECTION-SCREEN END OF BLOCK b_print2.
SELECTION-SCREEN END OF SCREEN 0202.

" 4. Kapak Yazdırma (Yükleme Formu & Özet Tablo)
SELECTION-SCREEN BEGIN OF SCREEN 0203 ." AS WINDOW TITLE text-z05.
SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE text-z06.
PARAMETERS: rb_yukf RADIOBUTTON GROUP grp2 USER-COMMAND u2 DEFAULT 'X',
            rb_ozet RADIOBUTTON GROUP grp2.
SELECTION-SCREEN END OF BLOCK b5.

SELECTION-SCREEN BEGIN OF BLOCK b6 WITH FRAME TITLE text-z07.
SELECT-OPTIONS: s_kplas FOR gv_kunnr.
SELECTION-SCREEN END OF BLOCK b6.

" --- KAPAK İÇİN YAZICI VE KOPYA BLOĞU ---
SELECTION-SCREEN BEGIN OF BLOCK b_print3 WITH FRAME TITLE text-prt.
PARAMETERS: p_kfron TYPE rspoprname AS LISTBOX VISIBLE LENGTH 10 OBLIGATORY,
            p_kcopy TYPE tdsfcopies DEFAULT '1'.
SELECTION-SCREEN END OF BLOCK b_print3.
SELECTION-SCREEN END OF SCREEN 0203.

" 5. ZSDEFSD - Eksik/Fazla Girişi
SELECTION-SCREEN BEGIN OF SCREEN 0204 ." AS WINDOW TITLE text-z08.
SELECTION-SCREEN BEGIN OF BLOCK b7 WITH FRAME TITLE text-z09.
SELECT-OPTIONS: s_matnr FOR gv_matnr.
SELECTION-SCREEN END OF BLOCK b7.
SELECTION-SCREEN END OF SCREEN 0204.

" 6. ZSDSPT - Sepet Tamamlama Düzeltme
SELECTION-SCREEN BEGIN OF SCREEN 0205 ." AS WINDOW TITLE text-z10.
SELECTION-SCREEN BEGIN OF BLOCK b8 WITH FRAME TITLE text-z11.
SELECT-OPTIONS: s_plas3 FOR gv_kunnr.
SELECTION-SCREEN END OF BLOCK b8.
SELECTION-SCREEN END OF SCREEN 0205.

" 7. VL10C - Toplu Teslimat
SELECTION-SCREEN BEGIN OF SCREEN 0206 ." AS WINDOW TITLE text-z12.
SELECTION-SCREEN BEGIN OF BLOCK b9 WITH FRAME TITLE text-z13.
SELECT-OPTIONS: s_plas4 FOR gv_kunnr.
SELECTION-SCREEN END OF BLOCK b9.
SELECTION-SCREEN END OF SCREEN 0206.

" 8. ZSD008 - Yükleme Formu Oluşturma
SELECTION-SCREEN BEGIN OF SCREEN 0207 ." AS WINDOW TITLE text-z14.
SELECTION-SCREEN BEGIN OF BLOCK b10 WITH FRAME TITLE text-z15.
SELECT-OPTIONS: s_plas5 FOR gv_kunnr.
SELECT-OPTIONS: s_inco  FOR gv_inco.
SELECTION-SCREEN END OF BLOCK b10.
SELECTION-SCREEN END OF SCREEN 0207.

" -----------------------------------------------------------------------
" YENİ EKLENEN: 9. ZBDY06 İade Süreçleri ve Tablo Bakım Ekranı Pop-up'ı
" -----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF SCREEN 0208 AS WINDOW TITLE text-z16.
SELECTION-SCREEN BEGIN OF BLOCK b11 WITH FRAME TITLE text-z17.
PARAMETERS: rb_prg RADIOBUTTON GROUP grp3 DEFAULT 'X', " İade Transfer Programı
            rb_tbl RADIOBUTTON GROUP grp3.             " Onaycı Mail Bakım Tablosu
SELECTION-SCREEN END OF BLOCK b11.
SELECTION-SCREEN END OF SCREEN 0208.

" 11. Fabrika Gönderim Çıktıları
SELECTION-SCREEN BEGIN OF SCREEN 0209 AS WINDOW.
SELECTION-SCREEN BEGIN OF BLOCK b12 WITH FRAME TITLE text-prt.
PARAMETERS: p_ffront TYPE rspoprname AS LISTBOX VISIBLE LENGTH 10 OBLIGATORY,
            p_fcopy  TYPE tdsfcopies DEFAULT '1'.
SELECTION-SCREEN END OF BLOCK b12.
SELECTION-SCREEN END OF SCREEN 0209.

*----------------------------------------------------------------------*
* HTML TIKLAMA OLAYLARINI YAKALAYAN SINIF (EVENT RECEIVER)
*----------------------------------------------------------------------*
CLASS lcl_event_receiver DEFINITION.
  PUBLIC SECTION.
    METHODS: on_sapevent
                FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action frame getdata postdata query_table.
ENDCLASS.

CLASS lcl_event_receiver IMPLEMENTATION.
  METHOD on_sapevent.
    DATA: gv_subarea          TYPE vstel,
          lv_flag             TYPE c LENGTH 1 VALUE 'X',
          lv_auth_show_screen TYPE abap_bool,
          lt_dynp             TYPE TABLE OF dynpread,
          ls_dynp             TYPE dynpread,
          lr_vstel            TYPE RANGE OF likp-vstel,
          lr_wadat            TYPE RANGE OF likp-wadat_ist,
          lr_ledat            TYPE RANGE OF ledat,
          lr_datal            TYPE RANGE OF sy-datum,
          lr_parvw            TYPE RANGE OF parvw,
          lv_parvw            TYPE parvw,
          lr_plasiyer         TYPE RANGE OF zdty_ft_eg_plskd,
          lr_vstel_dsl        TYPE RANGE OF likp-vstel,
          lr_bldat            TYPE RANGE OF likp-bldat,
          lr_fkdat            TYPE RANGE OF vbrk-fkdat,
          ls_pri_params       TYPE pri_params,
          lv_valid            TYPE flag,
          lv_pdest            TYPE sypri_pdest,
          lr_plate            TYPE RANGE OF zmm_t_bdy_gr_h-platenumber,
          lr_werks            TYPE RANGE OF zmm_t_bdy_gr_h-werks,
          lr_wh               TYPE RANGE OF zmm_t_bdy_gr_h-warehousenum,
          lr_date             TYPE RANGE OF zmm_t_bdy_gr_h-arrivaldate,
          lr_status           TYPE RANGE OF zmm_t_bdy_gr_h-status,
          lr_inco             TYPE RANGE OF inco2,
          lv_return_lgort     TYPE lgort_d.

    SELECT SINGLE @abap_true
          FROM zmm_t_bdy_0006 INTO @DATA(lv_ok)
          WHERE uname = @sy-uname.

    IF lv_ok EQ abap_true.
      lv_auth_show_screen = abap_false. " Tabloda kaydı VAR, ekranı GÖSTERME (direkt arka planda çalışsın)
    ELSE.
      lv_auth_show_screen = abap_true.  " Tabloda kaydı YOK, seçim ekranını GÖRÜNTÜLESİN
    ENDIF.

    CLEAR lt_dynp.
    ls_dynp-fieldname = 'P_DATUM'. APPEND ls_dynp TO lt_dynp.
    ls_dynp-fieldname = 'P_VSTEL'. APPEND ls_dynp TO lt_dynp.

    CALL FUNCTION 'DYNP_VALUES_READ'
      EXPORTING
        dyname     = sy-repid
        dynumb     = '1000'
      TABLES
        dynpfields = lt_dynp
      EXCEPTIONS
        OTHERS     = 1.

    IF sy-subrc = 0.
      READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = 'P_DATUM'.
      IF sy-subrc = 0.
        CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
          EXPORTING
            date_external = ls_dynp-fieldvalue
          IMPORTING
            date_internal = p_datum
          EXCEPTIONS
            OTHERS        = 1.
      ENDIF.

      READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = 'P_VSTEL'.
      IF sy-subrc = 0.
        gv_subarea = ls_dynp-fieldvalue.
      ENDIF.
    ENDIF.

    IF gv_subarea IS INITIAL.
      gv_subarea = p_vstel. " Fallback
    ENDIF.

    " Memory'e yollayalım ki diğer programlar kilitleme yapabilsin
    IF gv_subarea IS NOT INITIAL.
      EXPORT subarea = gv_subarea from_zbdy = lv_flag TO MEMORY ID 'ZBDY_MEMORY'.
    ENDIF.

    DATA lv_tarih_char TYPE char10.
    lv_tarih_char = p_datum+6(2) && '.' && p_datum+4(2) && '.' && p_datum(4).

    " ====================================================================
    " BUTON YÖNLENDİRMELERİ (YETKİYE GÖRE DİNAMİK)
    " ====================================================================
    CASE action.
      WHEN 'ZSDEFSD'.
        CALL SELECTION-SCREEN 0204 STARTING AT 15 5 ENDING AT 100 10.
        IF sy-subrc = 0.
          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT zsdefs02
              WITH p_werks EQ '1900'
              WITH p_vstel EQ gv_subarea
              WITH p_lgort EQ gv_subarea
              WITH s_matnr IN s_matnr[]
              WITH p_edatu EQ p_datum
              VIA SELECTION-SCREEN
              AND RETURN.
          ELSE.
            SUBMIT zsdefs02
              WITH p_werks EQ '1900'
              WITH p_vstel EQ gv_subarea
              WITH p_lgort EQ gv_subarea
              WITH s_matnr IN s_matnr[]
              WITH p_edatu EQ p_datum
              AND RETURN.
          ENDIF.
          m_show_msg.
        ENDIF.

      WHEN 'ZSDSPT'.
        CALL SELECTION-SCREEN 0205 STARTING AT 15 5 ENDING AT 100 10.
        IF sy-subrc = 0.
          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT zsdefs02_sepet
              WITH p_werks EQ '1900'
              WITH p_vstel EQ gv_subarea
              WITH p_lgort EQ gv_subarea
              WITH s_kunn2 IN s_plas3[]
              WITH p_edatu EQ p_datum
              VIA SELECTION-SCREEN
              AND RETURN.
          ELSE.
            SUBMIT zsdefs02_sepet
              WITH p_werks EQ '1900'
              WITH p_vstel EQ gv_subarea
              WITH p_lgort EQ gv_subarea
              WITH s_kunn2 IN s_plas3[]
              WITH p_edatu EQ p_datum
              AND RETURN.
          ENDIF.
          m_show_msg.
        ENDIF.

      WHEN 'VL10C'.
        CALL SELECTION-SCREEN 0206 STARTING AT 15 5 ENDING AT 100 10.
        IF sy-subrc = 0.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum ) TO lr_datal.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = 'BL' )    TO lr_parvw.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum ) TO lr_wadat.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum - 1 high = p_datum ) TO lr_ledat.

          IF s_plas4[] IS NOT INITIAL.
            lv_parvw = 'BL'.
          ENDIF.

          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT rvv50r10c
              WITH st_datal IN lr_datal
              WITH p_parvw  EQ lv_parvw
              WITH st_kunn2 IN s_plas4[]
              WITH st_wadat IN lr_wadat
              WITH st_ledat IN lr_ledat
              VIA SELECTION-SCREEN
              AND RETURN.
          ELSE.
            SUBMIT rvv50r10c
              WITH st_datal IN lr_datal
              WITH p_parvw  EQ lv_parvw
              WITH st_kunn2 IN s_plas4[]
              WITH st_wadat IN lr_wadat
              WITH st_ledat IN lr_ledat
              AND RETURN.
          ENDIF.
          m_show_msg.
        ENDIF.

      WHEN 'ZSD008'.
        CALL SELECTION-SCREEN 0207 STARTING AT 15 5 ENDING AT 100 12.
        IF sy-subrc = 0.

          APPEND VALUE #( sign = 'I' option = 'EQ' low = gv_subarea ) TO lr_vstel.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_wadat.

          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT zsd_packaging01
              WITH s_vstel IN lr_vstel
              WITH s_wadat IN lr_wadat
              WITH s_kunnr IN s_plas5[]
              WITH s_inco2 IN s_inco
              VIA SELECTION-SCREEN
              AND RETURN.
          ELSE.
            SUBMIT zsd_packaging01
              WITH s_vstel IN lr_vstel
              WITH s_wadat IN lr_wadat
              WITH s_kunnr IN s_plas5[]
              WITH s_inco2 IN s_inco
              AND RETURN.
          ENDIF.
          m_show_msg.
        ENDIF.


      WHEN '/DSL/ES10_P100'.
        CALL SELECTION-SCREEN 0202 STARTING AT 15 5 ENDING AT 120 20.
        IF sy-subrc = 0.

          " ---------------------------------------------------------
          " 0. ORTAK PARAMETRELERİN VE YAZICI YAPISININ HAZIRLANMASI
          " ---------------------------------------------------------

          lr_plasiyer = VALUE #( FOR ls_p IN s_plas2 ( CORRESPONDING #( ls_p ) ) ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = gv_subarea ) TO lr_vstel_dsl.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_bldat.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_fkdat.

          lv_pdest = p_front.

          " İRSALİYE VE FATURA İÇİN KOPYA SAYISI (p_copy_i) ILE SPOOL PARAMETRELERİ
          CALL FUNCTION 'GET_PRINT_PARAMETERS'
            EXPORTING
              destination    = lv_pdest
              copies         = p_copy_i   " <--- Fatura/İrsaliye Kopya Sayısı Kullanılıyor
              immediately    = 'X'
              release        = 'X'
              no_dialog      = 'X'
            IMPORTING
              out_parameters = ls_pri_params
              valid          = lv_valid
            EXCEPTIONS
              OTHERS         = 4.

          " ---------------------------------------------------------
          " 1. ADIM: ÖNCE KAPAK (ÖZET TABLO) YAZDIRILIR
          " ---------------------------------------------------------
          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT zsd_ozet_tablo_yukleme_formu
              WITH s_plasiy IN s_plas2[]
              WITH p_vstel  EQ gv_subarea
              WITH p_wadat  =  p_datum
              WITH p_front  EQ p_front
     WITH p_copy   EQ p_copy_k    " <--- Kapak Kopya Sayısı Kullanılıyor
     VIA SELECTION-SCREEN AND RETURN.
          ELSE.
            SUBMIT zsd_ozet_tablo_yukleme_formu
              WITH s_plasiy IN s_plas2[]
              WITH p_vstel  EQ gv_subarea
              WITH p_wadat  =  p_datum
              WITH p_front  EQ p_front
     WITH p_copy   EQ p_copy_k    " <--- Kapak Kopya Sayısı Kullanılıyor
     AND RETURN.
          ENDIF.
          m_show_msg.

          " =========================================================
          " YETKİ KONTROLÜNE GÖRE YAZDIRMA AYRIMI (İRSALİYE & FATURA)
          " =========================================================
          IF lv_auth_show_screen = abap_true.

            " --- YETKİ VARSA: STANDART ALV EKRANLARINI AÇ ---
            SUBMIT /dsl/es10_p100
              WITH s_bukrs  EQ '1000'
              WITH s_wadat  IN lr_bldat
              WITH c_plskd  IN lr_plasiyer
              WITH s_vstel  IN lr_vstel_dsl
              WITH p_vermo  EQ '2'
              WITH p_unlckd EQ abap_true
              VIA SELECTION-SCREEN AND RETURN.

            SUBMIT /dsl/es00_p100
              WITH s_bukrs  EQ '1000'
              WITH s_fkdat  IN lr_fkdat
              WITH s_vkbur  IN lr_vstel_dsl
              WITH s_vkorg  EQ '1000'
              WITH s_vtweg  EQ '10'
              WITH s_spart  EQ '00'
              WITH p_inarc  EQ 'A'
              WITH p_modul  EQ 'SD'
              WITH p_vermo  EQ '1'
              WITH c_plskd  IN lr_plasiyer
              VIA SELECTION-SCREEN AND RETURN.

          ELSE.

            " --- YETKİ YOKSA: DOĞRUDAN OTONOM API İLE SESSİZ YAZDIR ---

            " Yazıcı (Spool) ayarlarını global memory'e ata ki classlar oradan okusun
            SET PARAMETER ID 'SPO' FIELD p_front.
            sy-pdest = p_front.

            " ---------------------------------------------------------
            " 2. ADIM: İRSALİYE API ENTEGRASYONU (/DSL/ES10)
            " ---------------------------------------------------------
            DATA: lo_data_irs TYPE REF TO /dsl/es10_cl_data.
            lo_data_irs ?= /dsl/es10_cl_data=>factory( iv_module = 'SD' ).
            lo_data_irs->set_initial_data( ).

            FREE lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'S_BUKRS' kind = 'S' sign = 'I' option = 'EQ' low = '1000' ) TO lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'S_WADAT' kind = 'S' sign = 'I' option = 'EQ' low = p_datum ) TO lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'S_VSTEL' kind = 'S' sign = 'I' option = 'EQ' low = gv_subarea ) TO lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'P_MODUL' kind = 'P' sign = 'I' option = 'EQ' low = 'SD' ) TO lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'P_VERMO' kind = 'P' sign = 'I' option = 'EQ' low = '2' ) TO lo_data_irs->gt_selopts.
            APPEND VALUE #( selname = 'P_UNLCKD' kind = 'P' sign = 'I' option = 'EQ' low = 'X' ) TO lo_data_irs->gt_selopts.
            LOOP AT s_plas2 INTO DATA(ls_p_irs).
              APPEND VALUE #( selname = 'C_PLSKD' kind = 'S' sign = ls_p_irs-sign option = ls_p_irs-option low = ls_p_irs-low high = ls_p_irs-high ) TO lo_data_irs->gt_selopts.
            ENDLOOP.

            DATA: ls_opt   TYPE rsparams,
                  ls_add   TYPE rsparams,
                  lt_add   TYPE TABLE OF rsparams,
                  lt_kunn2 TYPE RANGE OF kunnr,
                  ls_kunn2 LIKE LINE OF lt_kunn2,
                  lt_kunnr TYPE TABLE OF kunnr,
                  lv_kunnr TYPE kunnr.

            LOOP AT lo_data_irs->gt_selopts INTO ls_opt WHERE selname = 'C_PLSKD' AND low <> space.
              CLEAR lt_kunn2.
              IF ls_opt-sign = 'I' AND ls_opt-option = 'EQ'.
                ls_kunn2-sign = 'I'.
                ls_kunn2-option = 'EQ'.
                ls_kunn2-low = ls_opt-low.
                APPEND ls_kunn2 TO lt_kunn2.
              ELSEIF ls_opt-sign = 'I' AND ls_opt-option = 'BT'.
                ls_kunn2-sign = 'I'.
                ls_kunn2-option = 'BT'.
                ls_kunn2-low = ls_opt-low.
                ls_kunn2-high = ls_opt-high.
                APPEND ls_kunn2 TO lt_kunn2.
              ENDIF.

              SELECT DISTINCT kunnr INTO TABLE lt_kunnr FROM knvp
              WHERE parvw = 'BL' AND kunn2 IN lt_kunn2.

              IF sy-subrc = 0.
                LOOP AT lt_kunnr INTO lv_kunnr.
                  ls_add-selname = 'S_KUNAG'.
                  ls_add-kind = 'S'.
                  ls_add-sign = 'I'.
                  ls_add-option = 'EQ'.
                  ls_add-low = lv_kunnr.
                  APPEND ls_add TO lt_add.
                ENDLOOP.
              ENDIF.
            ENDLOOP.

            IF sy-subrc = 0 AND lt_add IS INITIAL.
              ls_add-selname = 'S_KUNAG'.
              ls_add-kind = 'S'.
              ls_add-sign = 'I'.
              ls_add-option = 'EQ'.
              ls_add-low = 'ZZZ'.
              APPEND ls_add TO lt_add.
            ENDIF.

            APPEND LINES OF lt_add TO lo_data_irs->gt_selopts.

            lo_data_irs->set_selscr_mapping( ).
            lo_data_irs->get_data( ).

            IF lo_data_irs->gt_data[] IS NOT INITIAL.
              DATA: lo_op_irs TYPE REF TO /dsl/es10_cl_op,
                    lv_url    TYPE string,
                    lv_count  TYPE i,
                    lv_pgbrk  TYPE flag.

              CREATE OBJECT lo_op_irs.
              CLEAR lv_count.

              LOOP AT lo_data_irs->gt_data INTO DATA(ls_irs_api).
                lo_op_irs->get_log_instance( iv_awtyp = ls_irs_api-awtyp iv_awkey = ls_irs_api-awkey ).
                CLEAR lv_url.

* IF ls_irs_api-id IS INITIAL.
* lo_op_irs->create_despatch_view(
* EXPORTING
* iv_awtyp  = ls_irs_api-awtyp
* iv_awkey  = ls_irs_api-awkey
* iv_type   = '2'
* iv_action = 'PRINT'
* IMPORTING
* ev_url    = lv_url ).
* ELSE.
                lo_op_irs->get_despatch_view(
                  EXPORTING
                    iv_despatch_type    = 'O'
                    iv_taxno            = ls_irs_api-vktcn
                    iv_uuid             = ls_irs_api-uuid
                    iv_bukrs            = ls_irs_api-bukrs
                    iv_awkey            = ls_irs_api-awkey
                    iv_awtyp            = ls_irs_api-awtyp
                    iv_html_viewer_type = '2'
                    iv_action           = 'PRINT'
                  IMPORTING
                    ev_html_url         = lv_url ).
* ENDIF.

                IF lv_url IS NOT INITIAL.
                  cl_gui_frontend_services=>execute(
                    EXPORTING
                      document               = lv_url
                    EXCEPTIONS
                      OTHERS                 = 1 ).
                ENDIF.
              ENDLOOP.
            ENDIF.

            " ---------------------------------------------------------
            " 3. ADIM: FATURA API ENTEGRASYONU (/DSL/ES00)
            " ---------------------------------------------------------
            DATA: lo_data_fat TYPE REF TO /dsl/es00_cl_data.
            lo_data_fat ?= /dsl/es00_cl_data=>factory( iv_module = 'SD' iv_inarc = 'A' ).
            lo_data_fat->set_initial_data( ).

            FREE lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_BUKRS' kind = 'S' sign = 'I' option = 'EQ' low = '1000' ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_FKDAT' kind = 'S' sign = 'I' option = 'EQ' low = p_datum ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_VKBUR' kind = 'S' sign = 'I' option = 'EQ' low = gv_subarea ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_VKORG' kind = 'S' sign = 'I' option = 'EQ' low = '1000' ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_VTWEG' kind = 'S' sign = 'I' option = 'EQ' low = '10' ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'S_SPART' kind = 'S' sign = 'I' option = 'EQ' low = '00' ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'P_INARC' kind = 'P' sign = 'I' option = 'EQ' low = 'A' ) TO lo_data_fat->gt_selopts.
            APPEND VALUE #( selname = 'P_MODUL' kind = 'P' sign = 'I' option = 'EQ' low = 'SD' ) TO lo_data_fat->gt_selopts.
            IF sy-sysid EQ 'ESQ'.
              APPEND VALUE #( selname = 'P_VERMO' kind = 'P' sign = 'I' option = 'EQ' low = '2' ) TO lo_data_fat->gt_selopts.
            ENDIF.
            LOOP AT s_plas2 INTO DATA(ls_p_fat).
              APPEND VALUE #( selname = 'C_PLSKD' kind = 'S' sign = ls_p_fat-sign option = ls_p_fat-option low = ls_p_fat-low high = ls_p_fat-high ) TO lo_data_fat->gt_selopts.
            ENDLOOP.

            lo_data_fat->set_selscr_mapping( ).
            lo_data_fat->get_data( ).

            IF lo_data_fat->gt_data[] IS NOT INITIAL.
              DATA: lo_op_fat    TYPE REF TO /dsl/es00_cl_op,
                    lv_url_fat   TYPE string,
                    lv_count_fat TYPE i,
                    lv_pgbrk_fat TYPE flag.

              lo_op_fat ?= /dsl/es00_cl_op=>factory( iv_inarc = 'A' iv_bukrs = '1000' ).
              lo_op_fat->go_data = lo_data_fat.
              CLEAR lv_count_fat.

              LOOP AT lo_data_fat->gt_data INTO DATA(ls_fat_api).
                lo_op_fat->get_log_instance( iv_awtyp = ls_fat_api-awtyp iv_awkey = ls_fat_api-awkey ).
                CLEAR lv_url_fat.


* IF ls_fat_api-id IS INITIAL.
* lo_op_fat->create_invoice_view(
* EXPORTING
* iv_awtyp  = ls_fat_api-awtyp
* iv_awkey  = ls_fat_api-awkey
* iv_type   = '2'
* iv_action = 'PRINT'
* IMPORTING
* ev_url    = lv_url_fat ).
* ELSE.
                lo_op_fat->get_invoice_view(
                  EXPORTING
                    iv_invoice_type     = 'O'
                    iv_taxno            = ls_fat_api-vktcn
                    iv_uuid             = ls_fat_api-uuid
                    iv_bukrs            = ls_fat_api-bukrs
                    iv_inarc            = ls_fat_api-inarc
                    iv_html_viewer_type = '2'
                    iv_awkey            = ls_fat_api-awkey
                    iv_awtyp            = ls_fat_api-awtyp
                    iv_action           = 'PRINT'
                  IMPORTING
                    ev_html_url         = lv_url_fat ).
* ENDIF.

                IF lv_url_fat IS NOT INITIAL.
                  cl_gui_frontend_services=>execute(
                    EXPORTING
                      document               = lv_url_fat
                    EXCEPTIONS
                      OTHERS                 = 1 ).
                ENDIF.
              ENDLOOP.
            ENDIF.

          ENDIF.

          " ---------------------------------------------------------
          " 4. ADIM: OPSİYONEL YÜKLEME FORMU
          " ---------------------------------------------------------
          IF cb_yukf = 'X'.
            m_clear_msg.
            IF lv_auth_show_screen = abap_true.
              SUBMIT zsd_shipment_report_new
                WITH s_blonr  IN s_plas2[]
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  EQ p_datum
                WITH p_front  EQ p_front
            WITH p_copy   EQ p_copy_k  " <--- Yükleme Formu Kopya Sayısı
            VIA SELECTION-SCREEN AND RETURN.
            ELSE.
              SUBMIT zsd_shipment_report_new
                WITH s_blonr  IN s_plas2[]
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  EQ p_datum
                WITH p_front  EQ p_front
            WITH p_copy   EQ p_copy_k  " <--- Yükleme Formu Kopya Sayısı
            AND RETURN.
            ENDIF.
            m_show_msg.
          ENDIF.

          MESSAGE 'Belge yazdırma akışı başarıyla tamamlandı.' TYPE 'S'.

        ENDIF.

      WHEN 'ZSDYFR1'.
        m_clear_msg.
        IF lv_auth_show_screen = abap_true.
          SUBMIT zsd_shipment_report_new
            WITH s_blonr  IN s_kplas[]
            WITH s_inco2  IN lr_inco
            WITH p_vstel  EQ gv_subarea
            WITH p_wadat  EQ p_datum
            WITH p_front  EQ p_kfron
            WITH p_copy   EQ p_kcopy
            VIA SELECTION-SCREEN
            AND RETURN.
        ELSE.
          SUBMIT zsd_shipment_report_new
            WITH s_blonr  IN s_kplas[]
            WITH s_inco2  IN lr_inco
            WITH p_vstel  EQ gv_subarea
            WITH p_wadat  EQ p_datum
            WITH p_front  EQ p_kfron
            WITH p_copy   EQ p_kcopy
            AND RETURN.
        ENDIF.
        m_show_msg.

      WHEN 'ZKAPAK'.
        CALL SELECTION-SCREEN 0203 STARTING AT 15 5 ENDING AT 120 20.
        IF sy-subrc = 0.
          IF rb_yukf = 'X'.
            m_clear_msg.
            IF lv_auth_show_screen = abap_true.
              SUBMIT zsd_shipment_report_new
                WITH s_blonr  IN s_kplas[]
                WITH s_inco2  IN lr_inco
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  EQ p_datum
                WITH p_front  EQ p_kfron
                WITH p_copy   EQ p_kcopy
                VIA SELECTION-SCREEN
                AND RETURN.
            ELSE.
              SUBMIT zsd_shipment_report_new
                WITH s_blonr  IN s_kplas[]
                WITH s_inco2  IN lr_inco
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  EQ p_datum
                WITH p_front  EQ p_kfron
                WITH p_copy   EQ p_kcopy
                AND RETURN.
            ENDIF.
            m_show_msg.
          ELSEIF rb_ozet = 'X'.
            m_clear_msg.
            IF lv_auth_show_screen = abap_true.
              SUBMIT zsd_ozet_tablo_yukleme_formu
                WITH s_plasiy IN s_kplas[]
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  =  p_datum
                WITH p_front  EQ p_kfron
                WITH p_copy   EQ p_kcopy
                VIA SELECTION-SCREEN
                AND RETURN.
            ELSE.
              SUBMIT zsd_ozet_tablo_yukleme_formu
                WITH s_plasiy IN s_kplas[]
                WITH p_vstel  EQ gv_subarea
                WITH p_wadat  =  p_datum
                WITH p_front  EQ p_kfron
                WITH p_copy   EQ p_kcopy
                AND RETURN.
            ENDIF.
            m_show_msg.
          ENDIF.
        ENDIF.

      WHEN 'ZBDY01'.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = gv_subarea ) TO lr_werks.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_date.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = '3' )        TO lr_status.

        m_clear_msg.
        IF lv_auth_show_screen = abap_true.
          SUBMIT zmm_r_bdy_gr_cockpit
            WITH s_wh     IN lr_werks
            WITH s_date   IN lr_date
            WITH s_status IN lr_status
            VIA SELECTION-SCREEN
            AND RETURN.
        ELSE.
          SUBMIT zmm_r_bdy_gr_cockpit
            WITH s_wh     IN lr_werks
            WITH s_date   IN lr_date
            WITH s_status IN lr_status
            AND RETURN.
        ENDIF.
        m_show_msg.

      WHEN 'ZBDY02'.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_date.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = '0' )        TO lr_status.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = '3' )        TO lr_status.
        m_clear_msg.
        IF lv_auth_show_screen = abap_true.
          SUBMIT zmm_r_bdy_gi_cockpit
            WITH p_vstel  EQ p_vstel
            WITH s_wadat  IN lr_date
            WITH s_status IN lr_status
            VIA SELECTION-SCREEN
            AND RETURN.
        ELSE.
          SUBMIT zmm_r_bdy_gi_cockpit
            WITH p_vstel  EQ p_vstel
            WITH s_wadat  IN lr_date
            WITH s_status IN lr_status
            AND RETURN.
        ENDIF.
        m_show_msg.

      WHEN 'ZVF04'.
        CALL SELECTION-SCREEN 0201 STARTING AT 15 5 ENDING AT 100 10.
        IF sy-subrc = 0.
          DATA lr_vstel_zvf TYPE RANGE OF vbco7-vstel.
          DATA lr_fkart TYPE RANGE OF fkart.

          APPEND VALUE #( sign = 'I' option = 'EQ' low = gv_subarea ) TO lr_vstel_zvf.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = 'ZBS2' ) TO lr_fkart.

          m_clear_msg.
          IF lv_auth_show_screen = abap_true.
            SUBMIT sdbilldl
            WITH p_fkdat EQ p_datum
            WITH p_fkdab EQ p_datum
            WITH p_fkart IN lr_fkart
            WITH p_allea EQ 'X'
            WITH p_allel EQ 'X'
            WITH s_vstel IN lr_vstel_zvf
            WITH s_zzpls IN s_plas_z[]
            VIA SELECTION-SCREEN
            AND RETURN.
          ELSE.
            SUBMIT sdbilldl
              WITH p_fkdat EQ p_datum
              WITH p_fkdab EQ p_datum
              WITH p_fkart IN lr_fkart
              WITH p_allea EQ 'X'
              WITH p_allel EQ 'X'
              WITH s_vstel IN lr_vstel_zvf
              WITH s_zzpls IN s_plas_z[]
              AND RETURN.
          ENDIF.

          m_show_msg.
        ENDIF.

        " =======================================================================
        " YENİ GELİŞTİRME: ZBDY06 Pop-up Menüsü (İade Programı & Tablo Bakımı)
        " =======================================================================
      WHEN 'ZBDY06'.
        CALL SELECTION-SCREEN 0208 STARTING AT 15 5 ENDING AT 75 10.
        IF sy-subrc = 0.
          " Kullanıcı Pop-up'tan onaylayıp (Execute) geçtiyse:
          IF rb_prg = 'X'.
            " --- Seçenek 1: ZBDY06 İade Programını Aç ---
            EXPORT p_vstel = p_vstel
                   p_datum = p_datum TO MEMORY ID 'ZBDY06_MEM'.

            SUBMIT zmm_r_bdy_iade VIA SELECTION-SCREEN AND RETURN.

            FREE MEMORY ID 'ZBDY06_MEM'.

          ELSEIF rb_tbl = 'X'.
            " --- Seçenek 2: Mail Bakım Tablosunu (SM30) Aç ---
            CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
              EXPORTING
                action                       = 'U' " U = Update/Değiştir modu
                view_name                    = 'ZMM_T_BDY_IADE_M'
              EXCEPTIONS
                client_reference             = 1
                foreign_lock                 = 2
                invalid_action               = 3
                no_clientindependent_auth    = 4
                no_database_function         = 5
                no_editor_function           = 6
                no_show_auth                 = 7
                no_tvdir_entry               = 8
                no_upd_auth                  = 9
                only_show_allowed            = 10
                system_failure               = 11
                unknown_field_in_dba_sellist = 12
                view_not_found               = 13
                maintenance_prohibited       = 14
                OTHERS                       = 15.
            IF sy-subrc <> 0.
              MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
                      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
            ENDIF.
          ENDIF.
        ENDIF.
        " =======================================================================

      WHEN 'ZBDY_FSH_PRINT'.
        " PU-17919 M.DURGUN 03.11.2026 >>> Mal çıkışı devam eden, yarıda kalan,
        " hatalı veya onay bekleyen fabrika gönderimi varken çıktı alınmaz.
        DATA lv_fsh_block TYPE abap_bool.
        lv_return_lgort = gv_subarea.
        IF lv_return_lgort(2) = '19'.
          lv_return_lgort(2) = '18'.
        ENDIF.
        PERFORM check_fsh_before_print USING    p_datum
                                                lv_return_lgort
                                       CHANGING lv_fsh_block.
        IF lv_fsh_block = abap_true.
          RETURN.
        ENDIF.
        " PU-17919 M.DURGUN 03.11.2026 <<<
        CALL SELECTION-SCREEN 0209 STARTING AT 15 5 ENDING AT 75 11.
        IF sy-subrc = 0.
          lv_return_lgort = gv_subarea.
          IF lv_return_lgort(2) = '19'.
            lv_return_lgort(2) = '18'.
          ENDIF.

          SUBMIT zmm_r_bdy_fsh_output
            WITH p_date  EQ p_datum
            WITH p_lgort EQ lv_return_lgort
            WITH p_front EQ p_ffront
            WITH p_copy  EQ p_fcopy
            AND RETURN.
        ENDIF.

      WHEN 'ZBDY09'.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = gv_subarea ) TO lr_vstel.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = p_datum )    TO lr_wadat.
        SUBMIT zmm_r_bdy_fsh_retry
        WITH s_date  IN lr_wadat
        WITH s_lgort IN lr_vstel
*        VIA SELECTION-SCREEN
        AND RETURN.

      WHEN OTHERS.
        CALL TRANSACTION action.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* EKRAN OLAYLARI & KOKPİTİN BAŞLATILMASI
*----------------------------------------------------------------------*
INITIALIZATION.
  p_datum = sy-datum.
  PERFORM get_frontend_printers.

  " ====================================================================
  " PROGRAM İLK AÇILDIĞINDA VSTEL (ŞUBE) BİLGİSİNİ SİCİLDEN BULUP EKRANA BASMA
  " ====================================================================
* DATA: lv_room_init TYPE ad_roomnum.
* SELECT SINGLE roomnumber FROM user_addr INTO @lv_room_init WHERE bname = @sy-uname.
* IF lv_room_init IS NOT INITIAL.
* SELECT SINGLE personnel_subarea FROM zsts_t999 INTO @p_vstel WHERE employee_id = @lv_room_init.
* ENDIF.

  DATA : lr_agrname TYPE RANGE OF agr_users-agr_name.
  APPEND VALUE #( sign ='I' option = 'CP' low = 'ZS:ST:BM:LOJISTIK_MEMURU*' ) TO lr_agrname.

  SELECT SINGLE agr_name
    FROM agr_users
    INTO @DATA(lv_agr_name)
    WHERE agr_name IN @lr_agrname
      AND uname    EQ @sy-uname.
  IF sy-subrc NE 0.
    REFRESH lr_agrname.
    APPEND VALUE #( sign ='I' option = 'CP' low = 'ZS:ST:BM:DEPO_MEMURU*' ) TO lr_agrname.
    SELECT SINGLE agr_name
      FROM agr_users
      INTO @lv_agr_name
      WHERE agr_name IN @lr_agrname
        AND uname    EQ @sy-uname.
    IF sy-subrc EQ 0.
      SPLIT lv_agr_name AT ':' INTO DATA(lv_1) DATA(lv_2) DATA(lv_3) DATA(lv_4) p_vstel.
    ENDIF.
  ELSE.
    SPLIT lv_agr_name AT ':' INTO lv_1 lv_2 lv_3 lv_4 p_vstel.
  ENDIF.


AT SELECTION-SCREEN OUTPUT.
  IF sy-uname NE 'BORAL' AND sy-uname NE 'M.DURGUN'.
    LOOP AT SCREEN.
      IF screen-name = 'P_VSTEL'.
* screen-active = 0.
        screen-input = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.


  IF sy-dynnr = '1000' AND go_docking IS INITIAL.
    " ====================================================================
    " DİNAMİK SAYAÇLARIN (BADGE) ARKA PLANDA EKRANDAN ÖNCE HESAPLANMASI
    " ====================================================================
    CLEAR: gv_err_zbdy01, gv_err_zbdy02.

    " 1. ZBDY01 (Mal Kabul) için Hatalı Kayıtları (Status = '3') Say
    SELECT COUNT( * )
      FROM zmm_t_bdy_gr_h
      INTO @gv_err_zbdy01
      WHERE arrivaldate = @p_datum
        AND werks       = @p_vstel
        AND status      = '3'. " 3 = Hatalı

    " 2. ZBDY02 (Araç Yükleme) için Hatalı Kayıtları (Status = '3') Say
    SELECT COUNT( DISTINCT h~pckno )
      FROM zmm_t_bdy_gi_h AS h
      INNER JOIN zsd_packitm AS p ON p~pckno = h~pckno
      INNER JOIN likp AS l ON l~vbeln = p~vbeln
      INTO @gv_err_zbdy02
      WHERE l~wadat_ist = @p_datum
        AND l~vstel     = @p_vstel
        AND h~status    = '3'. " 3 = Hatalı

    " HTML çizimi için string değişkenleri
    DATA: lv_badge01 TYPE string,
          lv_badge02 TYPE string.

    " Hata varsa kırmızı kutucuğu (badge) oluştur, yoksa boş bırak
    IF gv_err_zbdy01 > 0.
      lv_badge01 = |<div class="badge">| && gv_err_zbdy01 && |</div>|.
    ELSE.
      lv_badge01 = ''.
    ENDIF.

    IF gv_err_zbdy02 > 0.
      lv_badge02 = |<div class="badge">| && gv_err_zbdy02 && |</div>|.
    ELSE.
      lv_badge02 = ''.
    ENDIF.
    " ====================================================================
    CREATE OBJECT go_docking
      EXPORTING
        repid = sy-repid
        dynnr = sy-dynnr
        side  = cl_gui_docking_container=>dock_at_bottom
        ratio = 90
        style = cl_gui_control=>ws_child.

    CREATE OBJECT go_html EXPORTING parent = go_docking.

    CREATE OBJECT go_event_rec.
    SET HANDLER go_event_rec->on_sapevent FOR go_html.

    DATA: lt_events TYPE cntl_simple_events, ls_event TYPE cntl_simple_event.
    ls_event-eventid = go_html->m_id_sapevent. ls_event-appl_event = 'X'. APPEND ls_event TO lt_events.
    go_html->set_registered_events( events = lt_events ).

    " HTML CSS YAPISI
    DATA: lt_html TYPE w3htmltab, ls_html TYPE w3html.
    DEFINE add_html. ls_html = &1. APPEND ls_html TO lt_html. END-OF-DEFINITION.

    add_html '<!DOCTYPE html><html><head>'.
    add_html '<meta http-equiv="X-UA-Compatible" content="IE=edge">'.
    add_html '<meta charset="UTF-8"><style>'.
    add_html 'body { font-family: Arial, sans-serif; background-color: #F3F4F7; padding: 20px; margin: 0; overflow-x: hidden; }'.
    add_html '.header-title { font-size: 20px; font-weight: bold; margin-bottom: 20px; color: #1D2D3E; border-bottom: 2px solid #ddd; padding-bottom: 8px; }'.
    add_html '.grid-container { width: 100%; overflow: hidden; }'.

    " --- KART TASARIMI ---
    add_html '.card { position: relative; float: left; width: 31%; margin: 1%; background: #FFFFFF; border-radius: 6px; padding: 18px; cursor: pointer; '.
    add_html '        box-sizing: border-box; box-shadow: 0 2px 4px rgba(0,0,0,0.1); transition: all 0.2s ease; min-height: 75px; }'.
    add_html '.card:hover { background-color: #FAFAFA; box-shadow: 0 4px 8px rgba(0,0,0,0.2); transform: translateY(-1px); }'.

    " --- YENİ EKLENEN BADGE (HATA SAYACI) CSS'İ ---
    add_html '.badge { position: absolute; top: -10px; right: -10px; background-color: #E52929; color: white; '.
    add_html '         font-size: 12px; font-weight: bold; padding: 4px 8px; border-radius: 12px; '.
    add_html '         box-shadow: 0 2px 4px rgba(0,0,0,0.2); z-index: 10; }'.

    add_html '.border-blue { border-left: 5px solid #0070F2; }'.
    add_html '.border-orange { border-left: 5px solid #E9730C; }'.
    add_html '.border-red { border-left: 5px solid #BB0000; }'.
    add_html '.border-green { border-left: 5px solid #107E3E; }'.
    add_html '.border-purple { border-left: 5px solid #8B3EE8; }'.
    add_html '.card-icon { float: left; font-size: 26px; width: 40px; text-align: center; line-height: 34px; }'.
    add_html '.card-content { margin-left: 50px; }'.
    add_html '.card-title { font-size: 14px; font-weight: bold; color: #1D2D3E; margin-bottom: 4px; }'.
    add_html '.card-tcode { font-size: 11px; color: #666; font-family: monospace; }'.
    add_html '</style></head><body>'.

    add_html '<div class="header-title">Bölge Depo Yönetimi Kokpiti</div>'.
    add_html '<div class="grid-container">'.

    add_html '  <div class="card border-blue" onclick="window.location.href=''sapevent:ZSDEFSD''">'.
    add_html '    <div class="card-icon">📦</div>'.
    add_html '    <div class="card-content"><div class="card-title">1. Eksik/Fazla</div><div class="card-tcode">ZSDEFSD</div></div></div>'.

    add_html '  <div class="card border-orange" onclick="window.location.href=''sapevent:ZSDSPT''">'.
    add_html '    <div class="card-icon">🛒</div>'.
    add_html '    <div class="card-content"><div class="card-title">2. Sepet Tamamlama Düz.</div><div class="card-tcode">ZSDSPT</div></div></div>'.

    add_html '  <div class="card border-green" onclick="window.location.href=''sapevent:VL10C''">'.
    add_html '    <div class="card-icon">🚚</div>'.
    add_html '    <div class="card-content"><div class="card-title">3. Toplu Teslimat</div><div class="card-tcode">VL10C</div></div></div>'.

    add_html '  <div class="card border-blue" onclick="window.location.href=''sapevent:ZSD008''">'.
    add_html '    <div class="card-icon">📋</div>'.
    add_html '    <div class="card-content"><div class="card-title">4. Yükleme Formu Olşt.</div><div class="card-tcode">ZSD008</div></div></div>'.

    add_html '  <div class="card border-purple" onclick="window.location.href=''sapevent:ZSDYFR1''">'.
    add_html '    <div class="card-icon">🖨️</div>'.
    add_html '    <div class="card-content"><div class="card-title">5. Yükleme Formu Çıktısı</div><div class="card-tcode">ZSDYFR1</div></div></div>'.

    add_html '  <div class="card border-red" onclick="window.location.href=''sapevent:ZBDY01''">'.
    add_html lv_badge01.
    add_html '    <div class="card-icon">⚠️</div>'.
    add_html '    <div class="card-content"><div class="card-title">6. Mal Kabul Hatalı İşl.</div><div class="card-tcode">ZBDY01</div></div></div>'.

    add_html '  <div class="card border-red" onclick="window.location.href=''sapevent:ZBDY02''">'.
    add_html lv_badge02.
    add_html '    <div class="card-icon">🛑</div>'.
    add_html '    <div class="card-content"><div class="card-title">7. Araç Yükleme Hatalı</div><div class="card-tcode">ZBDY02</div></div></div>'.

    add_html '  <div class="card border-blue" onclick="window.location.href=''sapevent:ZVF04''">'.
    add_html '    <div class="card-icon">🧾</div>'.
    add_html '    <div class="card-content"><div class="card-title">8.Faturalama İşleme</div><div class="card-tcode">ZVF04</div></div></div>'.

    add_html '  <div class="card border-purple" onclick="window.location.href=''sapevent:/DSL/ES10_P100''">'.
    add_html '    <div class="card-icon">📄</div>'.
    add_html '    <div class="card-content"><div class="card-title">9. İrsaliye & Fatura Yazdırma</div><div class="card-tcode">ÇOKLU İŞLEM</div></div></div>'.

    " ----------------------------------------------------------------------------------
    " YORUMA ALINDI: 9. Adım (Kapak Yazdırma) Butonu GİZLENDİ!
    " ----------------------------------------------------------------------------------
    " add_html '  <div class="card border-purple" onclick="window.location.href=''sapevent:ZKAPAK''">'.
    " add_html '    <div class="card-icon">📑</div>'.
    " add_html '    <div class="card-content"><div class="card-title">9. Kapak Yazdırma</div><div class="card-tcode">ZKAPAK</div></div></div>'.

    add_html '  <div class="card border-blue" onclick="window.location.href=''sapevent:ZBDY06''">'.
    add_html '    <div class="card-icon">🔄</div>'.
    add_html '    <div class="card-content"><div class="card-title">10. İade/Satış Depo Transferleri</div><div class="card-tcode">ZBDY06</div></div></div>'.

    add_html '  <div class="card border-green" onclick="window.location.href=''sapevent:ZBDY_FSH_PRINT''">'.
    add_html '    <div class="card-icon">🖨️</div>'.
    add_html '    <div class="card-content"><div class="card-title">11. Fabrika Gönderim</div><div class="card-tcode">İMHA LİSTESİ · TUTANAK · İRSALİYE</div></div></div>'.

    add_html '  <div class="card border-green" onclick="window.location.href=''sapevent:ZBDY09''">'.
    add_html '    <div class="card-icon">📑</div>'.
    add_html '    <div class="card-content"><div class="card-title">12. Fabrika Gönderim Hatalıları İşleme</div><div class="card-tcode">ZBDY09</div></div></div>'.

    add_html '</div></body></html>'.

    go_html->load_data( IMPORTING assigned_url = gv_url CHANGING data_table = lt_html ).
    go_html->show_url( url = gv_url ).
  ENDIF.

*----------------------------------------------------------------------*
* DİNAMİK ARAMA YARDIMI (F4) - PLASİYER FİLTRELEME VE YAZDIRMA DURUMU
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_plas_z-low.
  PERFORM show_plasiyer_f4 USING 'S_PLAS_Z'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_plas3-low.
  PERFORM show_plasiyer_f4 USING 'S_PLAS3'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR s_plas2-low.
  PERFORM show_plasiyer_f4 USING 'S_PLAS2'.
*&---------------------------------------------------------------------*
*& Form show_plasiyer_f4
*& Description: Tek merkezden F4 yönetimi ve Print durumlarının çekilmesi
*&---------------------------------------------------------------------*
FORM show_plasiyer_f4 USING pv_dynprofield TYPE help_info-dynprofld.
  DATA: lt_dynp  TYPE TABLE OF dynpread,
        ls_dynp  TYPE dynpread,
        lv_datum TYPE sy-datum,
        lv_vstel TYPE vstel.

  CLEAR lt_dynp.
  ls_dynp-fieldname = 'P_DATUM'. APPEND ls_dynp TO lt_dynp.
  ls_dynp-fieldname = 'P_VSTEL'. APPEND ls_dynp TO lt_dynp.

  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname     = sy-repid
      dynumb     = '1000'
    TABLES
      dynpfields = lt_dynp
    EXCEPTIONS
      OTHERS     = 1.

  IF sy-subrc = 0.
    READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = 'P_DATUM'.
    IF sy-subrc = 0.
      CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
        EXPORTING
          date_external = ls_dynp-fieldvalue
        IMPORTING
          date_internal = lv_datum
        EXCEPTIONS
          OTHERS        = 1.
    ENDIF.

    READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = 'P_VSTEL'.
    IF sy-subrc = 0.
      lv_vstel = ls_dynp-fieldvalue.
    ENDIF.
  ENDIF.

  IF lv_datum IS INITIAL. lv_datum = sy-datum. ENDIF.
  IF lv_vstel IS INITIAL. lv_vstel = p_vstel. ENDIF.

  " --- DÜZELTME: CHAR1 (Sadece X atılacak) ---
  TYPES: BEGIN OF ty_plas,
           kunnr   TYPE knvp-kunnr,
           name1   TYPE kna1-name1,
           irs_prt TYPE char1, " Sadece 'X' veya Boş
           fat_prt TYPE char1, " Sadece 'X' veya Boş
         END OF ty_plas.
  DATA: lt_plas TYPE TABLE OF ty_plas,
        ls_plas TYPE ty_plas.

*{SMT-260 Depozito teslimatları 9. seçenekte (S_PLAS2) hariç
  DATA: lr_delty TYPE RANGE OF zsd_packitm-delty.
  IF pv_dynprofield = 'S_PLAS2'.
    APPEND VALUE #( sign = 'E' option = 'EQ' low = 'D' ) TO lr_delty.
  ENDIF.
*}SMT-260

  IF lv_vstel IS NOT INITIAL.
    " 1. Ham veriyi (Müşteri ve Teslimat Listesi) çek
    SELECT DISTINCT h~kunnr AS kunnr, a~name1 AS name1, i~vbeln
      INTO TABLE @DATA(lt_raw)
      FROM zsd_packhdr AS h
      INNER JOIN zsd_packitm AS i ON i~pckno = h~pckno
      INNER JOIN vbuk AS v ON v~vbeln = i~vbeln
      LEFT JOIN kna1 AS a ON a~kunnr = h~kunnr
      WHERE h~vstel     = @lv_vstel
        AND h~wadat_ist = @lv_datum
        AND v~wbstk     = 'C'
        AND i~delty     IN @lr_delty. "SMT-260

    IF lt_raw[] IS NOT INITIAL.

      " İrsaliye için AWKEY Ara Tablo
      TYPES: BEGIN OF ty_awkey_likp,
               awkey TYPE /dsl/es10_t010-awkey,
             END OF ty_awkey_likp.
      DATA: lt_awkey_likp TYPE TABLE OF ty_awkey_likp.

      LOOP AT lt_raw INTO DATA(ls_raw_key).
        APPEND VALUE #( awkey = ls_raw_key-vbeln ) TO lt_awkey_likp.
      ENDLOOP.
      SORT lt_awkey_likp BY awkey.
      DELETE ADJACENT DUPLICATES FROM lt_awkey_likp COMPARING awkey.

      " 2. İrsaliye Yazdırma Durumu (/DSL/ES10_T010)
      TYPES: BEGIN OF ty_es10,
               awkey    TYPE /dsl/es10_t010-awkey,
               print_ir TYPE /dsl/es10_t010-print_ir,
             END OF ty_es10.
      DATA: lt_es10 TYPE TABLE OF ty_es10.

      IF lt_awkey_likp[] IS NOT INITIAL.
        SELECT awkey, print_ir FROM /dsl/es10_t010
          INTO TABLE @lt_es10
          FOR ALL ENTRIES IN @lt_awkey_likp
          WHERE awtyp = 'LIKP' AND awkey = @lt_awkey_likp-awkey.
      ENDIF.

      " 3. Teslimata Bağlı Faturaları Bul (VBFA)
      SELECT vbeln,posnr,vgbel,vgpos
        FROM lips
        INTO TABLE @DATA(lt_lips)
        FOR ALL ENTRIES IN @lt_raw
        WHERE vbeln EQ @lt_raw-vbeln.
      IF sy-subrc EQ 0.
        SELECT vbelv, vbeln FROM vbfa
        INTO TABLE @DATA(lt_vbfa)
        FOR ALL ENTRIES IN @lt_lips
        WHERE vbelv = @lt_lips-vgbel AND vbtyp_n = 'M'.
      ENDIF.

      " Fatura için AWKEY Ara Tablo
      TYPES: BEGIN OF ty_awkey_vbrk,
               awkey TYPE /dsl/es00_t100-awkey,
             END OF ty_awkey_vbrk.
      DATA: lt_awkey_vbrk TYPE TABLE OF ty_awkey_vbrk.

      LOOP AT lt_vbfa INTO DATA(ls_vbfa_key).
        APPEND VALUE #( awkey = ls_vbfa_key-vbeln ) TO lt_awkey_vbrk.
      ENDLOOP.
      SORT lt_awkey_vbrk BY awkey.
      DELETE ADJACENT DUPLICATES FROM lt_awkey_vbrk COMPARING awkey.

      " 4. Fatura Yazdırma Durumu (/DSL/ES00_T100)
      TYPES: BEGIN OF ty_es00,
               awkey  TYPE /dsl/es00_t100-awkey,
               prstat TYPE /dsl/es00_t100-prstat,
             END OF ty_es00.
      DATA: lt_es00 TYPE TABLE OF ty_es00.

      IF lt_awkey_vbrk[] IS NOT INITIAL.
        SELECT awkey, prstat FROM /dsl/es00_t100
          INTO TABLE @lt_es00
          FOR ALL ENTRIES IN @lt_awkey_vbrk
          WHERE awtyp = 'VBRK' AND awkey = @lt_awkey_vbrk-awkey.

*{INS ÖZCAN GÜRDAL 07.10.2026
        IF sy-dbcnt < lines( lt_awkey_vbrk ) .
          SELECT awkey, prstat FROM /dsl/es00_t100_a
            APPENDING TABLE @lt_es00
            FOR ALL ENTRIES IN @lt_awkey_vbrk
            WHERE awtyp = 'VBRK' AND awkey = @lt_awkey_vbrk-awkey.
        ENDIF.
*INS ÖZCAN GÜRDAL 07.10.2026}
      ENDIF.

      " 5. Verileri Birleştir (Plasiyer Bazında Grupla)
      DATA: lv_awkey_check TYPE /dsl/es10_t010-awkey.

      LOOP AT lt_raw INTO DATA(ls_raw).
        READ TABLE lt_plas ASSIGNING FIELD-SYMBOL(<fs_plas>) WITH KEY kunnr = ls_raw-kunnr.
        IF sy-subrc <> 0.
          CLEAR ls_plas.
          ls_plas-kunnr   = ls_raw-kunnr.
          ls_plas-name1   = ls_raw-name1.
          ls_plas-irs_prt = space.  " Başlangıçta boş atıyoruz
          ls_plas-fat_prt = space.  " Başlangıçta boş atıyoruz
          APPEND ls_plas TO lt_plas.
          READ TABLE lt_plas ASSIGNING <fs_plas> WITH KEY kunnr = ls_raw-kunnr.
        ENDIF.

        " İrsaliye durumu kontrolü
        IF <fs_plas>-irs_prt = space.
          lv_awkey_check = ls_raw-vbeln.
          READ TABLE lt_es10 INTO DATA(ls_es10_check) WITH KEY awkey = lv_awkey_check.
          IF sy-subrc = 0 AND ls_es10_check-print_ir IS NOT INITIAL AND ls_es10_check-print_ir <> '0'.
            <fs_plas>-irs_prt = 'X'.
          ENDIF.
        ENDIF.

        " Fatura durumu kontrolü
        IF <fs_plas>-fat_prt = space.
          READ TABLE lt_lips INTO DATA(ls_lips) WITH KEY vbeln = ls_raw-vbeln.
          IF sy-subrc EQ 0.
            LOOP AT lt_vbfa INTO DATA(ls_vbfa) WHERE vbelv = ls_lips-vgbel.
              lv_awkey_check = ls_vbfa-vbeln.
              READ TABLE lt_es00 INTO DATA(ls_es00_check) WITH KEY awkey = lv_awkey_check.
              IF sy-subrc = 0 AND ls_es00_check-prstat IS NOT INITIAL AND ls_es00_check-prstat <> '0'.
                <fs_plas>-fat_prt = 'X'.
                EXIT. " Bir faturanın yazdırılmış olması X koymak için yeterli
              ENDIF.
            ENDLOOP.
          ENDIF.

        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.

  " --- F4 Ekranı İçin Dinamik Kolon Başlıkları (OFFSET DÜZELTMESİ KORUNDU) ---
  DATA: lt_fieldtab TYPE TABLE OF dfies,
        ls_fieldtab TYPE dfies.

  CLEAR ls_fieldtab.
  ls_fieldtab-fieldname = 'KUNNR'.
  ls_fieldtab-datatype  = 'CHAR'.
  ls_fieldtab-inttype   = 'C'.
  ls_fieldtab-leng      = 10.
  ls_fieldtab-intlen    = 20.
  ls_fieldtab-offset    = 0.
  ls_fieldtab-outputlen = 10.
  ls_fieldtab-reptext   = 'Müşteri'.
  ls_fieldtab-scrtext_m = 'Müşteri'.
  APPEND ls_fieldtab TO lt_fieldtab.

  CLEAR ls_fieldtab.
  ls_fieldtab-fieldname = 'NAME1'.
  ls_fieldtab-datatype  = 'CHAR'.
  ls_fieldtab-inttype   = 'C'.
  ls_fieldtab-leng      = 35.
  ls_fieldtab-intlen    = 70.
  ls_fieldtab-offset    = 20.
  ls_fieldtab-outputlen = 30.
  ls_fieldtab-reptext   = 'Ad 1'.
  ls_fieldtab-scrtext_m = 'Ad 1'.
  APPEND ls_fieldtab TO lt_fieldtab.

  " 3. İrsaliyesi Yazdırılan Kolonu (Artık CHAR1)
  CLEAR ls_fieldtab.
  ls_fieldtab-fieldname = 'IRS_PRT'.
  ls_fieldtab-datatype  = 'CHAR'.
  ls_fieldtab-inttype   = 'C'.
  ls_fieldtab-leng      = 1.
  ls_fieldtab-intlen    = 2.
  ls_fieldtab-offset    = 90.  " <--- Ad 1 kolonundan sonra (20 + 70 = 90. byte)
  ls_fieldtab-outputlen = 22.
  ls_fieldtab-reptext   = 'İrsaliyesi Yazdırılan'.
  ls_fieldtab-scrtext_m = 'İrsaliyesi Yazdırıla'.
  APPEND ls_fieldtab TO lt_fieldtab.

  " 4. Faturası Yazdırılan Kolonu (Artık CHAR1)
  CLEAR ls_fieldtab.
  ls_fieldtab-fieldname = 'FAT_PRT'.
  ls_fieldtab-datatype  = 'CHAR'.
  ls_fieldtab-inttype   = 'C'.
  ls_fieldtab-leng      = 1.
  ls_fieldtab-intlen    = 2.
  ls_fieldtab-offset    = 92.  " <--- İrsaliye kolonundan sonra (90 + 2 = 92. byte)
  ls_fieldtab-outputlen = 22.
  ls_fieldtab-reptext   = 'Faturası Yazdırılan'.
  ls_fieldtab-scrtext_m = 'Faturası Yazdırılan'.
  APPEND ls_fieldtab TO lt_fieldtab.

  " Hazırlanan tablo ve kolon isimleriyle popup'ı çağır
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'KUNNR'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = pv_dynprofield
      value_org   = 'S'
    TABLES
      value_tab   = lt_plas
      field_tab   = lt_fieldtab
    EXCEPTIONS
      OTHERS      = 1.
ENDFORM.
*
*----------------------------------------------------------------------*
* PROGRAM BAŞLANGICI
*----------------------------------------------------------------------*
START-OF-SELECTION.

*&---------------------------------------------------------------------*
*& Form get_frontend_printers
*&---------------------------------------------------------------------*
FORM get_frontend_printers.
  DATA: l_prdest    TYPE rspoprname,
        l_is_front  TYPE fpboolean,
        l_no_choice TYPE rspotype-mode,
        is_mail     TYPE rspotype-mode,
        lt_prlist   TYPE STANDARD TABLE OF frprlist,
        lr_prlist   TYPE RANGE OF rspoprname,
        lt_option   TYPE TABLE OF spopli,
        ls_option   TYPE spopli,
        t_values    TYPE vrm_values,
        s_value     TYPE vrm_value,
        v_id        TYPE vrm_id.

  CALL FUNCTION 'RSPO_FRONTEND_PRINTERS_FOR_DEV'
    EXPORTING
      device         = 'LOC'
    IMPORTING
      prdefault      = l_prdest
      is_frontend    = l_is_front
      is_mail        = is_mail
      no_choice      = l_no_choice
    TABLES
      list           = lt_prlist
    EXCEPTIONS
      no_list        = 1
      list_truncated = 2
      name_not_found = 3
      OTHERS         = 4.

  IF sy-uname <> 'M.DURGUN' AND sy-uname <> 'E.GUNGORMEZ' AND sy-uname <> 'BORAL'.
    APPEND VALUE #( sign = 'I' option = 'CP' low = '*Micro*' )   TO lr_prlist.
    APPEND VALUE #( sign = 'I' option = 'CP' low = '*OneNote*' ) TO lr_prlist.
    APPEND VALUE #( sign = 'I' option = 'CP' low = '*PDF*' )     TO lr_prlist.
    APPEND VALUE #( sign = 'I' option = 'CP' low = '*Pdf*' )     TO lr_prlist.
    APPEND VALUE #( sign = 'I' option = 'CP' low = '*Fax*' )     TO lr_prlist.

    DELETE lt_prlist WHERE prname IN lr_prlist.
  ENDIF.

  LOOP AT lt_prlist INTO DATA(ls_prlist).
    s_value-key = ls_prlist-prname.
    APPEND s_value TO t_values.
  ENDLOOP.

  " 0202 (İrsaliye/Fatura) ekranı için
  v_id = 'P_FRONT'.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = v_id
      values = t_values.

  " 0203 (Kapak) ekranı için atama (İleride gerekirse diye tutuldu)
  v_id = 'P_KFRON'.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = v_id
      values = t_values.

  " 0209 (Fabrika Gönderim) ekranı; 0202 ile aynı Windows yazıcı listesi
  v_id = 'P_FFRONT'.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = v_id
      values = t_values.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form check_fsh_before_print
*& PU-17919 M.DURGUN 03.11.2026
*& 11. adım (Fabrika Gönderim çıktısı) öncesi gönderim durum kontrolü.
*& Öncelik: Hatalı (E) > yarıda kalmış (Q) > devam eden (Q) > onay bekleyen.
*& Devam eden/yarıda kalmış ayrımı: arka plan işlemi (ZMM_FM_BDY_FSH_
*& APPROVE_ASYNC) çalışırken EZMM_T_BDY_FSH kilidini tutar. Kilit boş ve
*& son güncelleme 10 dk'dan eskiyse işlem yarıda kalmış kabul edilir.
*&---------------------------------------------------------------------*
FORM check_fsh_before_print USING    pv_date  TYPE sy-datum
                                     pv_lgort TYPE lgort_d
                            CHANGING cv_block TYPE abap_bool.
  CONSTANTS: lc_stuck_sec TYPE i VALUE 600,
             lc_base_date TYPE d VALUE '20000101'.

  DATA: lv_now_sec    TYPE p LENGTH 16 DECIMALS 0,
        lv_rec_sec    TYPE p LENGTH 16 DECIMALS 0,
        lv_error      TYPE abap_bool,
        lv_stuck      TYPE abap_bool,
        lv_running    TYPE abap_bool,
        lv_approval   TYPE abap_bool,
        lv_err_msg    TYPE zmm_t_bdy_fsh_h-last_message,
        lv_stuck_step TYPE zmm_t_bdy_fsh_h-last_step,
        lv_stuck_date TYPE zmm_t_bdy_fsh_h-aedat,
        lv_stuck_time TYPE zmm_t_bdy_fsh_h-aezet,
        lv_run_step   TYPE zmm_t_bdy_fsh_h-last_step,
        lv_title      TYPE c LENGTH 40 VALUE 'Fabrika Gönderim',
        lv_t1         TYPE c LENGTH 70,
        lv_t2         TYPE c LENGTH 70,
        lv_t3         TYPE c LENGTH 70,
        lv_t4         TYPE c LENGTH 70.

  CLEAR cv_block.

  SELECT log_uid, status, last_step, last_message, aedat, aezet
    FROM zmm_t_bdy_fsh_h
    WHERE irs_tar      = @pv_date
      AND source_lgort = @pv_lgort
      AND ( status = 'E' OR status = 'Q' OR status = 'P' )
    INTO TABLE @DATA(lt_fsh).
  IF lt_fsh IS INITIAL.
    RETURN.
  ENDIF.

  lv_now_sec = ( sy-datum - lc_base_date ) * 86400 + sy-uzeit.

  LOOP AT lt_fsh INTO DATA(ls_fsh).
    IF ls_fsh-status = 'E'.
      IF lv_error = abap_false.
        lv_error   = abap_true.
        lv_err_msg = ls_fsh-last_message.
      ENDIF.

    ELSEIF ls_fsh-status = 'P' AND ls_fsh-last_step = 'WAIT_APPROVAL'.
      lv_approval = abap_true.

    ELSEIF ls_fsh-status = 'Q'
        OR ( ls_fsh-status = 'P' AND ls_fsh-last_step = 'QUEUED' ).
      "Kilit alınabiliyorsa arka plan işlemi çalışmıyordur.
      CALL FUNCTION 'ENQUEUE_EZMM_T_BDY_FSH'
        EXPORTING
          mandt          = sy-mandt
          log_uid        = ls_fsh-log_uid
          _scope         = '1'
          _wait          = abap_false
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      IF sy-subrc = 0.
        CALL FUNCTION 'DEQUEUE_EZMM_T_BDY_FSH'
          EXPORTING
            mandt   = sy-mandt
            log_uid = ls_fsh-log_uid
            _scope  = '1'.
        lv_rec_sec = ( ls_fsh-aedat - lc_base_date ) * 86400 + ls_fsh-aezet.
        IF lv_now_sec - lv_rec_sec >= lc_stuck_sec.
          lv_stuck      = abap_true.
          lv_stuck_step = ls_fsh-last_step.
          lv_stuck_date = ls_fsh-aedat.
          lv_stuck_time = ls_fsh-aezet.
          CONTINUE.
        ENDIF.
      ENDIF.
      lv_running  = abap_true.
      lv_run_step = ls_fsh-last_step.

    ELSE.
      "P/START: gönderim kaydı oluşturuluyor.
      lv_running  = abap_true.
      lv_run_step = ls_fsh-last_step.
    ENDIF.
  ENDLOOP.

  IF lv_error = abap_true.
    lv_t1 = 'Fabrika gönderiminde mal çıkış işlemlerinde hata alınmıştır:'.
    lv_t2 = lv_err_msg.
    lv_t3 = 'Lütfen önce 12 numaralı adımdan (Fabrika Gönderim Hatalıları'.
    lv_t4 = 'İşleme) tekrar tetikleme yapınız.'.
  ELSEIF lv_stuck = abap_true.
    lv_t1 = 'Fabrika gönderiminde mal çıkış işlemi yarıda kalmıştır.'.
    lv_t2 = |Son adım: { lv_stuck_step }, son güncelleme: { lv_stuck_date DATE = USER } { lv_stuck_time TIME = USER }|.
    lv_t3 = 'Lütfen önce 12 numaralı adımdan (Fabrika Gönderim Hatalıları'.
    lv_t4 = 'İşleme) tekrar tetikleme yapınız.'.
  ELSEIF lv_running = abap_true.
    lv_t1 = 'Fabrika gönderiminde mal çıkış işlemleri devam etmektedir.'.
    lv_t2 = |Son adım: { lv_run_step }|.
    lv_t3 = 'Lütfen yaklaşık 3 dakika sonra tekrar deneyiniz.'.
  ELSEIF lv_approval = abap_true.
    lv_t1 = 'Onay bekleyen fabrika gönderimi bulunmaktadır.'.
    lv_t2 = 'Gönderim onaylanıp mal çıkışı tamamlandıktan sonra'.
    lv_t3 = 'çıktı alınız.'.
  ELSE.
    RETURN.
  ENDIF.

  cv_block = abap_true.
  CALL FUNCTION 'POPUP_TO_INFORM'
    EXPORTING
      titel = lv_title
      txt1  = lv_t1
      txt2  = lv_t2
      txt3  = lv_t3
      txt4  = lv_t4.
ENDFORM.