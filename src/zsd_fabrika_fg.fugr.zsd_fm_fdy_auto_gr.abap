FUNCTION zsd_fm_fdy_auto_gr.
*"----------------------------------------------------------------------
*"* Local Interface:
*"  IMPORTING
*"     VALUE(IV_LPID) TYPE ZMM_DE_BDY_GR_LPID
*"----------------------------------------------------------------------

  DATA: lt_headers TYPE STANDARD TABLE OF zsd_t_fdy_gr_h WITH EMPTY KEY,
        lt_items   TYPE STANDARD TABLE OF zsd_t_fdy_gr_i WITH EMPTY KEY,
        ls_header  TYPE zsd_t_fdy_gr_h.

  DATA: lt_bapi_source   TYPE STANDARD TABLE OF zsd_t_fdy_gr_i
                           WITH EMPTY KEY,
        ls_bapi_source   TYPE zsd_t_fdy_gr_i,
        lv_log_uom       TYPE meins,
        lv_bapi_message  TYPE bapi_msg,
        lv_first_error   TYPE bapi_msg.

  DATA: ls_gm_head    TYPE bapi2017_gm_head_01,
        ls_gm_headret TYPE bapi2017_gm_head_ret,
        ls_gm_code    TYPE bapi2017_gm_code,
        lt_bapi_item  TYPE STANDARD TABLE OF bapi2017_gm_item_create WITH EMPTY KEY,
        ls_bapi_item  TYPE bapi2017_gm_item_create,
        lt_return     TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY,
        lv_mblnr      TYPE mkpf-mblnr,
        lv_mjahr      TYPE mkpf-mjahr,
        lv_ref_bwart  TYPE ekbe-bwart,
        lv_header_error TYPE abap_bool.

  DATA: ls_bal_log     TYPE bal_s_log,
        ls_bal_msg     TYPE bal_s_msg,
        lv_log_handle  TYPE balloghndl,
        lt_log_handles TYPE bal_t_logh,
        lv_log_ready   TYPE abap_bool,
        lv_log_text    TYPE bapi_msg,
        lv_log_msgty   TYPE symsgty.

  DEFINE add_log_text.
    IF lv_log_ready = abap_true.
      CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
        EXPORTING
          i_log_handle = lv_log_handle
          i_msgty      = &1
          i_text       = lv_log_text
        EXCEPTIONS
          log_not_found    = 1
          msg_inconsistent = 2
          log_is_full      = 3
          OTHERS           = 4.
    ENDIF.
  END-OF-DEFINITION.

  DEFINE save_application_log.
    IF lv_log_ready = abap_true.
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_client       = sy-mandt
          i_save_all     = abap_false
          i_t_log_handle = lt_log_handles
        EXCEPTIONS
          log_not_found     = 1
          save_not_allowed  = 2
          numbering_error   = 3
          OTHERS            = 4.
    ENDIF.
  END-OF-DEFINITION.

  IF iv_lpid IS INITIAL.
    RETURN.
  ENDIF.

  ls_bal_log-object    = 'ZSD_FDY'.
  ls_bal_log-subobject = 'AUTO_GR'.
  ls_bal_log-extnumber = |LPID { iv_lpid }|.
  ls_bal_log-aluser    = sy-uname.
  ls_bal_log-alprog    = sy-repid.

  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log      = ls_bal_log
    IMPORTING
      e_log_handle = lv_log_handle
    EXCEPTIONS
      log_header_inconsistent = 1
      OTHERS                  = 2.

  IF sy-subrc = 0.
    lv_log_ready = abap_true.
    APPEND lv_log_handle TO lt_log_handles.
  ENDIF.

  SELECT *
    FROM zsd_t_fdy_gr_h
    WHERE lpid = @iv_lpid
      AND ( status = '1' OR status = '3' )
    INTO TABLE @lt_headers.

  IF lt_headers IS INITIAL.
    lv_log_text = |LPID { iv_lpid }: status 1 veya 3 olan islenecek baslik bulunamadi.|.
    add_log_text 'W'.
    save_application_log.
    COMMIT WORK AND WAIT.
    RETURN.
  ENDIF.

  SELECT *
    FROM zsd_t_fdy_gr_i
    FOR ALL ENTRIES IN @lt_headers
    WHERE lpid = @lt_headers-lpid
    INTO TABLE @lt_items.

  " Parti satirlarinin islem ve log sirasi sabit olsun.
  SORT lt_items BY lpid ebeln ebelp deliverynumber itemnumber charg.

  IF lt_items IS NOT INITIAL.
    SELECT ebeln,
           ebelp,
           werks,
           lgort,
           menge,
           meins
      FROM ekpo
      FOR ALL ENTRIES IN @lt_items
      WHERE ebeln = @lt_items-ebeln
        AND ebelp = @lt_items-ebelp
      INTO TABLE @DATA(lt_ekpo).

    SORT lt_ekpo BY ebeln ebelp.
  ENDIF.

  LOOP AT lt_headers INTO ls_header.
    CLEAR: ls_gm_head,
           ls_gm_headret,
           ls_gm_code,
           lt_bapi_item,
           lt_bapi_source,
           lt_return,
           lv_mblnr,
           lv_mjahr,
           lv_first_error,
           lv_header_error.

    ls_gm_code-gm_code = '01'.

    IF ls_header-arrivaldate IS INITIAL.
      ls_gm_head-pstng_date = sy-datum.
      ls_gm_head-doc_date   = sy-datum.
    ELSE.
      ls_gm_head-pstng_date = ls_header-arrivaldate.
      ls_gm_head-doc_date   = ls_header-arrivaldate.
    ENDIF.

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>)
         WHERE lpid = ls_header-lpid
           AND approved = abap_true.

      CLEAR: <ls_item>-item_status,
             <ls_item>-item_message,
             <ls_item>-expectedquantity,
             <ls_item>-mblnr,
             <ls_item>-mjahr.

      CLEAR: ls_bapi_item, lv_ref_bwart.

      IF ls_gm_head-ref_doc_no IS INITIAL.
        ls_gm_head-ref_doc_no = <ls_item>-deliverynumber.
      ENDIF.

      SELECT bwart
        FROM ekbe
        WHERE ebeln = @<ls_item>-ebeln
          AND ebelp = @<ls_item>-ebelp
          AND vgabe = '6'
          AND bwart IN ( '901', '351' )
        ORDER BY gjahr DESCENDING,
                 belnr DESCENDING,
                 buzei DESCENDING
        INTO @lv_ref_bwart
        UP TO 1 ROWS.
      ENDSELECT.

      CASE lv_ref_bwart.
        WHEN '901'.
          ls_bapi_item-move_type = '101'.
        WHEN '351'.
          ls_bapi_item-move_type = '911'.
        WHEN OTHERS.
          lv_header_error = abap_true.
          <ls_item>-item_status = 'E'.
          lv_log_text = |LPID { ls_header-lpid }, SAS { <ls_item>-ebeln }/{ <ls_item>-ebelp }, parti { <ls_item>-charg }: EKBE'de VGABE 6 icin 901 veya 351 hareketi bulunamadi.|.
          <ls_item>-item_message = 'Referans mal hareketi bulunamadı.'.
          add_log_text 'E'.
          CONTINUE.
      ENDCASE.

      READ TABLE lt_ekpo INTO DATA(ls_ekpo)
        WITH KEY ebeln = <ls_item>-ebeln
                 ebelp = <ls_item>-ebelp
        BINARY SEARCH.

      IF sy-subrc <> 0.
        lv_header_error = abap_true.
        <ls_item>-item_status = 'E'.
        lv_log_text = |LPID { ls_header-lpid }, SAS { <ls_item>-ebeln }/{ <ls_item>-ebelp }, parti { <ls_item>-charg }: EKPO kalemi bulunamadi.|.
        <ls_item>-item_message = 'SAS kalemi bulunamadı.'.
        add_log_text 'E'.
        CONTINUE.
      ENDIF.

      " Gelen miktar RECEIVEDQUANTITY'de korunur. SAS miktari ise
      " EXPECTEDQUANTITY'ye yazilir ve mal hareketinde esas alinir.
      <ls_item>-expectedquantity = ls_ekpo-menge.

      IF ls_ekpo-lgort IS INITIAL.
        lv_header_error = abap_true.
        <ls_item>-item_status = 'E'.
        lv_log_text = |LPID { ls_header-lpid }, SAS { <ls_item>-ebeln }/{ <ls_item>-ebelp }, parti { <ls_item>-charg }: EKPO-LGORT bos; depo yeri belirlenemedi.|.
        <ls_item>-item_message = 'Depo yeri bulunamadı.'.
        add_log_text 'E'.
        CONTINUE.
      ENDIF.

      IF <ls_item>-uom IS INITIAL.
        lv_log_uom = ls_ekpo-meins.
      ELSE.
        lv_log_uom = <ls_item>-uom.
      ENDIF.

      ls_bapi_item-material  = <ls_item>-material.
      ls_bapi_item-plant     = ls_ekpo-werks.
      ls_bapi_item-stge_loc  = ls_ekpo-lgort.
      ls_bapi_item-batch     = <ls_item>-charg.
      ls_bapi_item-entry_qnt = <ls_item>-expectedquantity.

      <ls_item>-item_message =
        |Gelen { <ls_item>-receivedquantity } { lv_log_uom }, MG yapılan { <ls_item>-expectedquantity } { lv_log_uom }.|.
      lv_log_text = |LPID { ls_header-lpid }, SAS { <ls_item>-ebeln }/{ <ls_item>-ebelp }, parti { <ls_item>-charg }: { <ls_item>-item_message }|.
      IF <ls_item>-receivedquantity = <ls_item>-expectedquantity.
        add_log_text 'I'.
      ELSE.
        add_log_text 'W'.
      ENDIF.

      IF <ls_item>-uom IS INITIAL.
        ls_bapi_item-entry_uom = ls_ekpo-meins.
      ELSE.
        ls_bapi_item-entry_uom = <ls_item>-uom.
      ENDIF.

      ls_bapi_item-mvt_ind   = 'B'.
      ls_bapi_item-po_number = <ls_item>-ebeln.
      ls_bapi_item-po_item   = <ls_item>-ebelp.

      APPEND ls_bapi_item TO lt_bapi_item.
      APPEND <ls_item> TO lt_bapi_source.
    ENDLOOP.

    IF lv_header_error = abap_true OR lt_bapi_item IS INITIAL.
      ls_header-status = '3'.

      IF lt_bapi_item IS INITIAL AND lv_header_error = abap_false.
        lv_log_text = |LPID { ls_header-lpid }: BAPI'ye gonderilecek onayli kalem yok.|.
        add_log_text 'E'.
      ENDIF.

      MODIFY zsd_t_fdy_gr_h FROM ls_header.

      LOOP AT lt_items ASSIGNING <ls_item>
           WHERE lpid = ls_header-lpid.
        IF <ls_item>-approved = abap_true.
          <ls_item>-item_status = 'E'.
          IF <ls_item>-item_message IS INITIAL.
            <ls_item>-item_message =
              'Başka bir kalem hatalı olduğu için mal girişi yapılmadı.'.
          ENDIF.
        ENDIF.
        MODIFY zsd_t_fdy_gr_i FROM <ls_item>.
      ENDLOOP.

      save_application_log.
      COMMIT WORK AND WAIT.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
      EXPORTING
        goodsmvt_header  = ls_gm_head
        goodsmvt_code    = ls_gm_code
      IMPORTING
        goodsmvt_headret = ls_gm_headret
        materialdocument = lv_mblnr
        matdocumentyear  = lv_mjahr
      TABLES
        goodsmvt_item    = lt_bapi_item
        return           = lt_return.

    DATA(lv_bapi_error) = xsdbool(
      line_exists( lt_return[ type = 'E' ] ) OR
      line_exists( lt_return[ type = 'A' ] ) OR
      line_exists( lt_return[ type = 'X' ] ) ).

    " BAPI'nin dondugu tum mesajlari ayni loga ekle. E/A/X disindaki
    " uyari ve bilgi mesajlari da sonraki analiz icin degerlidir.
    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_return>).
      lv_bapi_message = <ls_return>-message.
      IF lv_bapi_message IS INITIAL
         AND <ls_return>-id IS NOT INITIAL
         AND <ls_return>-number IS NOT INITIAL.
        MESSAGE ID <ls_return>-id TYPE 'S' NUMBER <ls_return>-number
          WITH <ls_return>-message_v1 <ls_return>-message_v2
               <ls_return>-message_v3 <ls_return>-message_v4
          INTO lv_bapi_message.
      ENDIF.

      IF ( <ls_return>-type = 'E'
           OR <ls_return>-type = 'A'
           OR <ls_return>-type = 'X' )
         AND lv_first_error IS INITIAL.
        lv_first_error = lv_bapi_message.
      ENDIF.

      IF lv_log_ready = abap_true
         AND <ls_return>-id IS NOT INITIAL
         AND <ls_return>-number IS NOT INITIAL.
        CLEAR ls_bal_msg.
        ls_bal_msg-msgty = COND #( WHEN <ls_return>-type IS INITIAL
                                  THEN 'I'
                                  ELSE <ls_return>-type ).
        ls_bal_msg-msgid = <ls_return>-id.
        ls_bal_msg-msgno = <ls_return>-number.
        ls_bal_msg-msgv1 = <ls_return>-message_v1.
        ls_bal_msg-msgv2 = <ls_return>-message_v2.
        ls_bal_msg-msgv3 = <ls_return>-message_v3.
        ls_bal_msg-msgv4 = <ls_return>-message_v4.

        CALL FUNCTION 'BAL_LOG_MSG_ADD'
          EXPORTING
            i_log_handle = lv_log_handle
            i_s_msg      = ls_bal_msg
          EXCEPTIONS
            log_not_found    = 1
            msg_inconsistent = 2
            log_is_full      = 3
            OTHERS           = 4.
      ELSEIF lv_log_ready = abap_true.
        lv_log_text = |LPID { ls_header-lpid }, BAPI: { <ls_return>-message }|.
        lv_log_msgty = COND #( WHEN <ls_return>-type IS INITIAL
                              THEN 'I'
                              ELSE <ls_return>-type ).
        add_log_text lv_log_msgty.
      ENDIF.

      " BAPIRET2-ROW, GOODSMVT_ITEM satir numarasidir. Mesaji ilgili
      " ZSD_T_FDY_GR_I parti satirina yaz; ROW yoksa tum giden kalemlere yaz.
      CLEAR ls_bapi_source.
      IF <ls_return>-parameter = 'GOODSMVT_ITEM'
         AND <ls_return>-row IS NOT INITIAL.
        READ TABLE lt_bapi_source INTO ls_bapi_source
          INDEX <ls_return>-row.
      ENDIF.

      IF lv_bapi_message IS INITIAL
         OR ( <ls_return>-type <> 'E'
              AND <ls_return>-type <> 'A'
              AND <ls_return>-type <> 'X'
              AND <ls_return>-type <> 'W' ).
        CONTINUE.
      ELSEIF sy-subrc = 0 AND ls_bapi_source IS NOT INITIAL.
        LOOP AT lt_items ASSIGNING <ls_item>
             WHERE lpid           = ls_bapi_source-lpid
               AND deliverynumber = ls_bapi_source-deliverynumber
               AND ebeln          = ls_bapi_source-ebeln
               AND ebelp          = ls_bapi_source-ebelp
               AND material       = ls_bapi_source-material
               AND charg          = ls_bapi_source-charg.
          IF <ls_item>-item_message IS INITIAL.
            <ls_item>-item_message = lv_bapi_message.
          ELSE.
            CONCATENATE <ls_item>-item_message lv_bapi_message
              INTO <ls_item>-item_message SEPARATED BY ' | '.
          ENDIF.
        ENDLOOP.
      ELSE.
        LOOP AT lt_bapi_source INTO ls_bapi_source.
          LOOP AT lt_items ASSIGNING <ls_item>
               WHERE lpid           = ls_bapi_source-lpid
                 AND deliverynumber = ls_bapi_source-deliverynumber
                 AND ebeln          = ls_bapi_source-ebeln
                 AND ebelp          = ls_bapi_source-ebelp
                 AND material       = ls_bapi_source-material
                 AND charg          = ls_bapi_source-charg.
            IF <ls_item>-item_message IS INITIAL.
              <ls_item>-item_message = lv_bapi_message.
            ELSE.
              CONCATENATE <ls_item>-item_message lv_bapi_message
                INTO <ls_item>-item_message SEPARATED BY ' | '.
            ENDIF.
          ENDLOOP.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    IF lv_bapi_error = abap_false AND lv_mblnr IS NOT INITIAL.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      ls_header-status = '2'.

      lv_log_text = |LPID { ls_header-lpid }: malzeme belgesi { lv_mblnr }/{ lv_mjahr } basariyla olusturuldu.|.
      add_log_text 'S'.

      LOOP AT lt_items ASSIGNING <ls_item>
           WHERE lpid = ls_header-lpid
             AND approved = abap_true.
        <ls_item>-item_status = 'S'.

        READ TABLE lt_bapi_source TRANSPORTING NO FIELDS
          WITH KEY lpid           = <ls_item>-lpid
                   deliverynumber = <ls_item>-deliverynumber
                   ebeln          = <ls_item>-ebeln
                   ebelp          = <ls_item>-ebelp
                   material       = <ls_item>-material
                   charg          = <ls_item>-charg.
        IF sy-subrc = 0.
          <ls_item>-mblnr = lv_mblnr.
          <ls_item>-mjahr = lv_mjahr.
        ENDIF.

        MODIFY zsd_t_fdy_gr_i FROM <ls_item>.
      ENDLOOP.

    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

      ls_header-status = '3'.

      IF lt_return IS INITIAL.
        lv_log_text = |LPID { ls_header-lpid }: BAPI hata mesaji dondurmedi ve malzeme belgesi olusmadi.|.
        add_log_text 'E'.
      ELSEIF lv_bapi_error = abap_false AND lv_mblnr IS INITIAL.
        lv_log_text = |LPID { ls_header-lpid }: BAPI E/A/X mesaji dondurmedi ancak malzeme belge numarasi bos geldi.|.
        add_log_text 'E'.
      ENDIF.

      LOOP AT lt_items ASSIGNING <ls_item>
           WHERE lpid = ls_header-lpid
             AND approved = abap_true.
        <ls_item>-item_status = 'E'.
        IF <ls_item>-item_message IS INITIAL.
          IF lv_first_error IS NOT INITIAL.
            <ls_item>-item_message = lv_first_error.
          ELSE.
            <ls_item>-item_message =
              'Malzeme belgesi oluşturulamadı.'.
          ENDIF.
        ENDIF.
        MODIFY zsd_t_fdy_gr_i FROM <ls_item>.
      ENDLOOP.
    ENDIF.

    MODIFY zsd_t_fdy_gr_h FROM ls_header.
    save_application_log.
    COMMIT WORK AND WAIT.
  ENDLOOP.

ENDFUNCTION.
