*&---------------------------------------------------------------------*
*& Include ZSD_R_FDY_IRSALIYE_GIRIS_CL
*&---------------------------------------------------------------------*

CLASS lcl_dialog_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_close FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.
ENDCLASS.

CLASS lcl_dialog_handler IMPLEMENTATION.
  METHOD on_close.
    sender->free( ).
    CLEAR: go_image_popup, go_image_dialog.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_tree_event_receiver DEFINITION.
  PUBLIC SECTION.
    METHODS handle_node_double_click
                FOR EVENT node_double_click OF cl_gui_alv_tree
      IMPORTING node_key sender.
    METHODS handle_item_context_menu
                FOR EVENT item_context_menu_request OF cl_gui_alv_tree
      IMPORTING node_key menu fieldname.
    METHODS handle_item_menu_selected
                FOR EVENT item_context_menu_selected OF cl_gui_alv_tree
      IMPORTING fcode node_key fieldname.
ENDCLASS.

CLASS lcl_tree_event_receiver IMPLEMENTATION.
  METHOD handle_node_double_click.
    DATA: ls_out      TYPE ty_tree_out,
          lt_node_key TYPE lvc_t_nkey.

    gv_current_node_key = node_key.
    APPEND node_key TO lt_node_key.
    go_alv_tree->set_selected_nodes( it_selected_nodes = lt_node_key ).
    go_alv_tree->get_outtab_line(
      EXPORTING i_node_key    = node_key
      IMPORTING e_outtab_line = ls_out ).

    IF ls_out-log_uid IS INITIAL.
      MESSAGE 'Lütfen bir müşteri kaydı seçiniz.' TYPE 'S'.
      RETURN.
    ENDIF.

    PERFORM update_right_screen USING node_key.
  ENDMETHOD.

  METHOD handle_item_context_menu.
    menu->add_function( fcode = 'DELETE_ENTRY' text = 'Sil' ).
  ENDMETHOD.

  METHOD handle_item_menu_selected.
    DATA: ls_out    TYPE ty_tree_out,
          ls_header TYPE zsd_t_fdy_h,
          lv_answer TYPE c.

    CHECK fcode = 'DELETE_ENTRY' AND node_key IS NOT INITIAL.

    go_alv_tree->get_outtab_line(
      EXPORTING i_node_key    = node_key
      IMPORTING e_outtab_line = ls_out ).
    CHECK ls_out-log_uid IS NOT INITIAL.

    SELECT SINGLE * FROM zsd_t_fdy_h
      INTO @ls_header
      WHERE log_uid = @ls_out-log_uid.
    IF sy-subrc <> 0.
      MESSAGE 'Kayıt bulunamadı.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF ls_header-vbeln_zfis IS NOT INITIAL OR
       ls_header-vbeln_lf   IS NOT INITIAL OR
       ls_header-mblnr      IS NOT INITIAL.
      MESSAGE 'SAP belgesi oluşmuş kayıt silinemez.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Kayıt Silme'
        text_question         = 'Seçilen fabrika iade kaydı silinsin mi?'
        text_button_1         = 'Evet'
        text_button_2         = 'Hayır'
        default_button        = '2'
        display_cancel_button = space
      IMPORTING
        answer                = lv_answer.
    CHECK lv_answer = '1'.

    DELETE FROM zsd_t_fdy_img WHERE log_uid = @ls_out-log_uid.
    DELETE FROM zsd_t_fdy_i   WHERE log_uid = @ls_out-log_uid.
    DELETE FROM zsd_t_fdy_h   WHERE log_uid = @ls_out-log_uid.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE 'Kayıt silinemedi.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.
    go_alv_tree->delete_subtree( i_node_key = node_key ).
    go_alv_tree->frontend_update( ).
    MESSAGE 'Kayıt silindi.' TYPE 'S'.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_html_event_receiver DEFINITION.
  PUBLIC SECTION.
    METHODS on_sapevent FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action.
ENDCLASS.

CLASS lcl_html_event_receiver IMPLEMENTATION.
  METHOD on_sapevent.
    DATA lv_posnr TYPE posnr.

    IF action CP 'IMG_*'.
      lv_posnr = action+4.
      gv_current_image = lv_posnr.
      PERFORM show_images_on_viewer.
    ELSEIF action CP 'FULLSCREEN_*'.
      lv_posnr = action+11.
      PERFORM show_fullscreen_popup USING lv_posnr.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_grid_event_receiver DEFINITION.
  PUBLIC SECTION.
    METHODS handle_toolbar
                FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.
    METHODS handle_user_command
                FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_data_changed
                FOR EVENT data_changed OF cl_gui_alv_grid
      IMPORTING er_data_changed.
ENDCLASS.

CLASS lcl_grid_event_receiver IMPLEMENTATION.
  METHOD handle_toolbar.
    DATA ls_toolbar TYPE stb_button.

    CLEAR e_object->mt_toolbar.

    ls_toolbar-function  = 'COMPLETE_PROCESS'.
    ls_toolbar-icon      = icon_execute_object.
    ls_toolbar-text      = 'Süreci Tamamla'.
    ls_toolbar-quickinfo = 'İade siparişi adımını tamamla'.
    ls_toolbar-disabled  = COND #( WHEN gv_is_readonly = abap_true THEN 'X' ELSE space ).
    APPEND ls_toolbar TO e_object->mt_toolbar.

    CLEAR ls_toolbar.
    ls_toolbar-butn_type = 3.
    APPEND ls_toolbar TO e_object->mt_toolbar.

    CLEAR ls_toolbar.
    ls_toolbar-function  = 'REFRESH_GIRIS'.
    ls_toolbar-icon      = icon_refresh.
    ls_toolbar-text      = 'Yenile'.
    APPEND ls_toolbar TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'COMPLETE_PROCESS'.
        PERFORM complete_process.
      WHEN 'REFRESH_GIRIS'.
        PERFORM refresh_giris_screen.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_data_changed.
    DATA: ls_mod_cell TYPE lvc_s_modi,
          ls_header   TYPE ty_hdr_grid.

    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cell.
      READ TABLE gt_grid_header INTO ls_header INDEX ls_mod_cell-row_id.
      IF sy-subrc <> 0 OR gv_is_readonly = abap_true.
        CONTINUE.
      ENDIF.

      CASE ls_mod_cell-fieldname.
        WHEN 'PLAKA'.
          ls_header-plaka = to_upper( ls_mod_cell-value ).
          er_data_changed->modify_cell(
            i_row_id    = ls_mod_cell-row_id
            i_fieldname = 'PLAKA'
            i_value     = ls_header-plaka ).
        WHEN 'KUNNR'.
          ls_header-kunnr = |{ ls_mod_cell-value ALPHA = IN }|.
          PERFORM get_kunnr_name USING ls_header-kunnr
            CHANGING ls_header-kunnr_name.
          er_data_changed->modify_cell(
            i_row_id    = ls_mod_cell-row_id
            i_fieldname = 'KUNNR'
            i_value     = ls_header-kunnr ).
          er_data_changed->modify_cell(
            i_row_id    = ls_mod_cell-row_id
            i_fieldname = 'KUNNR_NAME'
            i_value     = ls_header-kunnr_name ).
        WHEN 'TESLIM_SONUCU'.
          ls_header-teslim_sonucu = ls_mod_cell-value.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      MODIFY gt_grid_header FROM ls_header INDEX ls_mod_cell-row_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_item_event_receiver DEFINITION.
  PUBLIC SECTION.
    METHODS handle_on_f4
                FOR EVENT onf4 OF cl_gui_alv_grid
      IMPORTING e_fieldname es_row_no er_event_data.
    METHODS handle_data_changed
                FOR EVENT data_changed OF cl_gui_alv_grid
      IMPORTING er_data_changed.
ENDCLASS.

CLASS lcl_item_event_receiver IMPLEMENTATION.
  METHOD handle_on_f4.
    DATA: lt_return  TYPE STANDARD TABLE OF ddshretval,
          lt_f4      TYPE STANDARD TABLE OF ty_value_text,
          ls_f4      TYPE ty_value_text,
          lv_zzgrund TYPE zsd_t_fdy_i-zzgrund.
    FIELD-SYMBOLS: <lt_modi> TYPE lvc_t_modi,
                   <ls_item> TYPE ty_itm_grid.

    CHECK e_fieldname = 'ZZGRUND' OR e_fieldname = 'ZZALTNDN'.

    IF e_fieldname = 'ZZGRUND'.
      SELECT tvlvt~abrvw AS value, tvlvt~bezei AS text
        FROM tvlvt
        INTO CORRESPONDING FIELDS OF TABLE @lt_f4
        WHERE spras = 'T'.
      DELETE lt_f4 WHERE value = '3'
                     OR value = '4'
                     OR value = '6'
                     OR value = '7'
                     OR value = '8'
                     OR value = '9'
                     OR value = '10'
                     OR value = '90'.
    ELSE.
      READ TABLE gt_grid_items ASSIGNING <ls_item> INDEX es_row_no-row_id.
      IF sy-subrc = 0.
        lv_zzgrund = <ls_item>-zzgrund.
      ENDIF.
      IF lv_zzgrund IS INITIAL.
        MESSAGE 'Önce iade nedeni seçiniz.' TYPE 'S' DISPLAY LIKE 'E'.
        er_event_data->m_event_handled = abap_true.
        RETURN.
      ENDIF.

      SELECT t605t~exart AS value, t605t~bezei AS text
        FROM t605t
        INTO CORRESPONDING FIELDS OF TABLE @lt_f4
        WHERE t605t~spras = 'T'
          AND t605t~land1 = 'TR'
          AND t605t~exart IN ( SELECT altnd
                                 FROM zsd_t_refund_007
                                WHERE vkaus = @lv_zzgrund
                                  AND altnd <> @space ).
      IF lt_f4 IS INITIAL.
        MESSAGE |İade nedeni { lv_zzgrund } için alt neden tanımlı değildir.| TYPE 'S' DISPLAY LIKE 'E'.
        er_event_data->m_event_handled = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield   = 'VALUE'
        value_org  = 'S'
      TABLES
        value_tab  = lt_f4
        return_tab = lt_return
      EXCEPTIONS
        OTHERS     = 3.
    IF sy-subrc = 0 AND lt_return IS NOT INITIAL.
      ASSIGN er_event_data->m_data->* TO <lt_modi>.
      READ TABLE lt_return INTO DATA(ls_return) INDEX 1.
      READ TABLE lt_f4 INTO ls_f4 WITH KEY value = ls_return-fieldval.

      APPEND VALUE #( row_id = es_row_no-row_id
                      fieldname = e_fieldname
                      value = ls_return-fieldval ) TO <lt_modi>.
      APPEND VALUE #( row_id = es_row_no-row_id
                      fieldname = COND #( WHEN e_fieldname = 'ZZGRUND'
                                          THEN 'ZZGRUND_TXT'
                                          ELSE 'ZZALTNDN_TXT' )
                      value = ls_f4-text ) TO <lt_modi>.

      READ TABLE gt_grid_items ASSIGNING <ls_item> INDEX es_row_no-row_id.
      IF sy-subrc = 0.
        IF e_fieldname = 'ZZGRUND'.
          <ls_item>-zzgrund = ls_return-fieldval.
          <ls_item>-zzgrund_txt = ls_f4-text.
          CLEAR: <ls_item>-zzaltndn, <ls_item>-zzaltndn_txt.
        ELSE.
          <ls_item>-zzaltndn = ls_return-fieldval.
          <ls_item>-zzaltndn_txt = ls_f4-text.
        ENDIF.
      ENDIF.
    ENDIF.
    er_event_data->m_event_handled = abap_true.
  ENDMETHOD.

  METHOD handle_data_changed.
    DATA: ls_mod_cell TYPE lvc_s_modi,
          ls_item     TYPE ty_itm_grid,
          lv_matnr    TYPE matnr,
          lv_maktx    TYPE maktx,
          lv_meins    TYPE meins,
          lv_text     TYPE text60.

    CHECK gv_is_readonly = abap_false.

    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cell.
      READ TABLE gt_grid_items INTO ls_item INDEX ls_mod_cell-row_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      CASE ls_mod_cell-fieldname.
        WHEN 'MATNR'.
          lv_matnr = |{ ls_mod_cell-value ALPHA = IN }|.
          CLEAR: lv_maktx, lv_meins.
          SELECT SINGLE a~meins, b~maktx
            FROM mara AS a
            LEFT OUTER JOIN makt AS b
              ON b~matnr = a~matnr
             AND b~spras = @sy-langu
            INTO (@lv_meins, @lv_maktx)
            WHERE a~matnr = @lv_matnr.
          IF sy-subrc <> 0.
            MESSAGE 'Malzeme bulunamadı.' TYPE 'S' DISPLAY LIKE 'E'.
            CONTINUE.
          ENDIF.

          CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
            EXPORTING
              input          = lv_meins
            IMPORTING
              output         = lv_meins
            EXCEPTIONS
              unit_not_found = 1.

          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'MATNR' i_value = lv_matnr ).
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'MAKTX' i_value = lv_maktx ).
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'MEINS' i_value = lv_meins ).
          ls_item-matnr = lv_matnr.
          ls_item-maktx = lv_maktx.
          ls_item-meins = lv_meins.
        WHEN 'CHARG'.
          ls_item-charg = to_upper( ls_mod_cell-value ).
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id
            i_fieldname = 'CHARG'
            i_value = ls_item-charg ).
        WHEN 'MENGE'.
          ls_item-menge = ls_mod_cell-value.
        WHEN 'MEINS'.
          ls_item-meins = to_upper( ls_mod_cell-value ).
        WHEN 'ZZGRUND'.
          ls_item-zzgrund = ls_mod_cell-value.
          CLEAR: ls_item-zzaltndn, ls_item-zzaltndn_txt, lv_text.
          PERFORM get_zzgrund_text USING ls_item-zzgrund CHANGING lv_text.
          ls_item-zzgrund_txt = lv_text.
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'ZZGRUND_TXT' i_value = lv_text ).
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'ZZALTNDN' i_value = space ).
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'ZZALTNDN_TXT' i_value = space ).
        WHEN 'ZZALTNDN'.
          ls_item-zzaltndn = ls_mod_cell-value.
          CLEAR lv_text.
          PERFORM get_zzaltndn_text USING ls_item-zzaltndn CHANGING lv_text.
          ls_item-zzaltndn_txt = lv_text.
          er_data_changed->modify_cell(
            i_row_id = ls_mod_cell-row_id i_fieldname = 'ZZALTNDN_TXT' i_value = lv_text ).
      ENDCASE.

      MODIFY gt_grid_items FROM ls_item INDEX ls_mod_cell-row_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
