*&---------------------------------------------------------------------*
*& Report  ZSD_R_FDY_AUTO_GR_JOB
*&---------------------------------------------------------------------*
*& FDY (Fabrika Depo Yönetimi) mal kabul kayıtlarını yeniden işler.
*& ZSD_T_FDY_GR_H'de hata alan (3) ya da arka plan görevi çalışmamış
*& (1) kayıtlar için ZSD_FM_FDY_AUTO_GR LPID bazında çağrılır.
*& Mal girişi mantığı yalnız FM'dedir; job bu mantığı tekrar etmez.
*& ZMM_R_BDY_AUTO_GR_JOB programının FDY karşılığıdır.
*& PU-MATABAY M.DURGUN 03.11.2026
*&---------------------------------------------------------------------*
REPORT zsd_r_fdy_auto_gr_job.

TABLES zsd_t_fdy_gr_h.

TYPES: BEGIN OF ty_out,
         lpid        TYPE zsd_t_fdy_gr_h-lpid,
         werks       TYPE zsd_t_fdy_gr_h-werks,
         platenumber TYPE zsd_t_fdy_gr_h-platenumber,
         erdat       TYPE zsd_t_fdy_gr_h-erdat,
         erzet       TYPE zsd_t_fdy_gr_h-erzet,
         old_status  TYPE zsd_t_fdy_gr_h-status,
         new_status  TYPE zsd_t_fdy_gr_h-status,
         mblnr       TYPE zsd_t_fdy_gr_i-mblnr,
         mjahr       TYPE zsd_t_fdy_gr_i-mjahr,
         result      TYPE char20,
         message     TYPE bapi_msg,
       END OF ty_out.

DATA gt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
SELECT-OPTIONS: s_lpid  FOR zsd_t_fdy_gr_h-lpid,
                s_werks FOR zsd_t_fdy_gr_h-werks,
                s_erdat FOR zsd_t_fdy_gr_h-erdat.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-002.
PARAMETERS: p_err  AS CHECKBOX DEFAULT 'X',
            p_new  AS CHECKBOX DEFAULT 'X',
            p_wait TYPE i DEFAULT 30,
            p_test AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK b2.

INITIALIZATION.
  "BDY job'undaki gibi varsayılan olarak dün ve bugünün kayıtları.
  s_erdat-sign   = 'I'.
  s_erdat-option = 'BT'.
  s_erdat-low    = sy-datum - 1.
  s_erdat-high   = sy-datum.
  APPEND s_erdat.

AT SELECTION-SCREEN.
  IF p_err IS INITIAL AND p_new IS INITIAL.
    MESSAGE 'En az bir statü (Hatalı / Yeni) seçiniz.' TYPE 'E'.
  ENDIF.
  IF p_wait < 0.
    MESSAGE 'Bekleme süresi negatif olamaz.' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  PERFORM process.
  PERFORM display.

*&---------------------------------------------------------------------*
*& FORM process
*&---------------------------------------------------------------------*
FORM process.
  CONSTANTS lc_base_date TYPE d VALUE '20000101'.

  DATA: lr_status   TYPE RANGE OF zsd_t_fdy_gr_h-status,
        lv_now_sec  TYPE p LENGTH 16 DECIMALS 0,
        lv_rec_sec  TYPE p LENGTH 16 DECIMALS 0,
        lv_varkey   TYPE rstable-varkey,
        lv_cur_stat TYPE zsd_t_fdy_gr_h-status,
        ls_out      TYPE ty_out.

  IF p_err = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '3' ) TO lr_status.
  ENDIF.
  IF p_new = abap_true.
    APPEND VALUE #( sign = 'I' option = 'EQ' low = '1' ) TO lr_status.
  ENDIF.

  SELECT lpid, werks, platenumber, erdat, erzet, status
    FROM zsd_t_fdy_gr_h
    WHERE lpid   IN @s_lpid
      AND werks  IN @s_werks
      AND erdat  IN @s_erdat
      AND status IN @lr_status
    ORDER BY erdat, erzet, lpid
    INTO TABLE @DATA(lt_head).

  IF lt_head IS INITIAL.
    RETURN.
  ENDIF.

  lv_now_sec = ( sy-datum - lc_base_date ) * 86400 + sy-uzeit.

  LOOP AT lt_head INTO DATA(ls_head).
    CLEAR ls_out.
    ls_out-lpid        = ls_head-lpid.
    ls_out-werks       = ls_head-werks.
    ls_out-platenumber = ls_head-platenumber.
    ls_out-erdat       = ls_head-erdat.
    ls_out-erzet       = ls_head-erzet.
    ls_out-old_status  = ls_head-status.
    ls_out-new_status  = ls_head-status.

    "Statü 1: Fiori onayından sonra FM arka plan görevinde (IN BACKGROUND
    "TASK) henüz çalışıyor olabilir. Çift mal girişini önlemek için kayıt
    "en az P_WAIT dakika önce oluşturulmuşsa alınır.
    IF ls_head-status = '1'.
      lv_rec_sec = ( ls_head-erdat - lc_base_date ) * 86400 + ls_head-erzet.
      IF lv_now_sec - lv_rec_sec < p_wait * 60.
        ls_out-result  = 'Beklemede'.
        ls_out-message = |Kayıt { p_wait } dakikadan yeni; arka plan görevi bekleniyor.|.
        APPEND ls_out TO gt_out.
        CONTINUE.
      ENDIF.
    ENDIF.

    IF p_test = abap_true.
      ls_out-result  = 'Test'.
      ls_out-message = 'Test çalıştırma: ZSD_FM_FDY_AUTO_GR çağrılmadı.'.
      APPEND ls_out TO gt_out.
      CONTINUE.
    ENDIF.

    "Aynı LPID'nin iki job/cockpit çalışmasında birlikte işlenmesini engelle.
    lv_varkey = sy-mandt && ls_head-lpid.
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname        = 'ZSD_T_FDY_GR_H'
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      ls_out-result  = 'Kilitli'.
      ls_out-message = |Kayıt başka bir işlem tarafından kilitli: { sy-msgv1 }|.
      APPEND ls_out TO gt_out.
      CONTINUE.
    ENDIF.

    "Seçimden sonra statü değişmiş olabilir (arka plan görevi bitmiş vb.).
    CLEAR lv_cur_stat.
    SELECT SINGLE status
      FROM zsd_t_fdy_gr_h
      WHERE lpid = @ls_head-lpid
      INTO @lv_cur_stat.
    IF lv_cur_stat NOT IN lr_status.
      CALL FUNCTION 'DEQUEUE_E_TABLE'
        EXPORTING
          tabname = 'ZSD_T_FDY_GR_H'
          varkey  = lv_varkey.
      ls_out-new_status = lv_cur_stat.
      ls_out-result     = 'Atlandı'.
      ls_out-message    = |Statü { lv_cur_stat } oldu; yeniden işlenmedi.|.
      APPEND ls_out TO gt_out.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'ZSD_FM_FDY_AUTO_GR'
      EXPORTING
        iv_lpid = ls_head-lpid.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZSD_T_FDY_GR_H'
        varkey  = lv_varkey.

    SELECT SINGLE status
      FROM zsd_t_fdy_gr_h
      WHERE lpid = @ls_head-lpid
      INTO @ls_out-new_status.

    IF ls_out-new_status = '2'.
      SELECT mblnr, mjahr
        FROM zsd_t_fdy_gr_i
        WHERE lpid  = @ls_head-lpid
          AND mblnr <> @space
        ORDER BY mblnr
        INTO (@ls_out-mblnr, @ls_out-mjahr)
        UP TO 1 ROWS.
      ENDSELECT.
      ls_out-result  = 'Başarılı'.
      ls_out-message = |Malzeme belgesi { ls_out-mblnr }/{ ls_out-mjahr } oluşturuldu.|.
    ELSE.
      ls_out-result = 'Hatalı'.
      SELECT item_message
        FROM zsd_t_fdy_gr_i
        WHERE lpid         = @ls_head-lpid
          AND item_status  = 'E'
          AND item_message <> @space
        ORDER BY ebeln, ebelp
        INTO @ls_out-message
        UP TO 1 ROWS.
      ENDSELECT.
      IF ls_out-message IS INITIAL.
        ls_out-message = 'Mal girişi yapılamadı; ayrıntı için SLG1 (ZSD_FDY / AUTO_GR).'.
      ENDIF.
    ENDIF.

    APPEND ls_out TO gt_out.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& FORM display
*&---------------------------------------------------------------------*
FORM display.
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lv_ok      TYPE i,
        lv_err     TYPE i,
        lv_other   TYPE i,
        ls_out     TYPE ty_out.

  IF gt_out IS INITIAL.
    WRITE: / 'İşlenecek kayıt bulunamadı.'.
    RETURN.
  ENDIF.

  LOOP AT gt_out INTO ls_out.
    CASE ls_out-result.
      WHEN 'Başarılı'.
        lv_ok = lv_ok + 1.
      WHEN 'Hatalı'.
        lv_err = lv_err + 1.
      WHEN OTHERS.
        lv_other = lv_other + 1.
    ENDCASE.
  ENDLOOP.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_out ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_display_settings( )->set_list_header(
        |FDY mal giriş tekrar işleme - Başarılı: { lv_ok } Hatalı: { lv_err } Diğer: { lv_other }| ).

      DATA(lo_cols) = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).
      lo_cols->get_column( 'OLD_STATUS' )->set_short_text( 'Eski St.' ).
      lo_cols->get_column( 'OLD_STATUS' )->set_medium_text( 'Eski Statü' ).
      lo_cols->get_column( 'OLD_STATUS' )->set_long_text( 'Eski Statü' ).
      lo_cols->get_column( 'NEW_STATUS' )->set_short_text( 'Yeni St.' ).
      lo_cols->get_column( 'NEW_STATUS' )->set_medium_text( 'Yeni Statü' ).
      lo_cols->get_column( 'NEW_STATUS' )->set_long_text( 'Yeni Statü' ).
      lo_cols->get_column( 'RESULT' )->set_short_text( 'Sonuç' ).
      lo_cols->get_column( 'RESULT' )->set_medium_text( 'Sonuç' ).
      lo_cols->get_column( 'RESULT' )->set_long_text( 'Sonuç' ).
      lo_cols->get_column( 'MESSAGE' )->set_short_text( 'Mesaj' ).
      lo_cols->get_column( 'MESSAGE' )->set_medium_text( 'Mesaj' ).
      lo_cols->get_column( 'MESSAGE' )->set_long_text( 'Mesaj' ).

      lo_alv->display( ).
    CATCH cx_salv_msg cx_salv_not_found.
      LOOP AT gt_out INTO ls_out.
        WRITE: / ls_out-lpid, ls_out-old_status, ls_out-new_status,
                 ls_out-result, ls_out-message.
      ENDLOOP.
  ENDTRY.
ENDFORM.
