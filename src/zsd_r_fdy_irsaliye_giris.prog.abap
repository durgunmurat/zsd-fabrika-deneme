*&---------------------------------------------------------------------*
*& Report ZSD_R_FDY_IRSALIYE_GIRIS
*&---------------------------------------------------------------------*
REPORT zsd_r_fdy_irsaliye_giris.

INCLUDE zsd_r_fdy_irsaliye_giris_top.
INCLUDE zsd_r_fdy_irsaliye_giris_cl.

START-OF-SELECTION.
  DATA lr_status TYPE RANGE OF zsd_t_fdy_h-status.

  IF p_giris <> abap_true.
    MESSAGE 'İade giriş işlemi seçilmelidir.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_gbek = abap_true.
    lr_status = VALUE #(
      ( sign = 'I' option = 'EQ' low = space )
      ( sign = 'I' option = 'EQ' low = 'N' )
      ( sign = 'I' option = 'EQ' low = 'E' ) ).
  ELSE.
    lr_status = VALUE #(
      ( sign = 'I' option = 'EQ' low = space )
      ( sign = 'I' option = 'EQ' low = 'N' )
      ( sign = 'I' option = 'EQ' low = 'E' )
      ( sign = 'I' option = 'EQ' low = 'C' ) ).
  ENDIF.

  SELECT *
    FROM zsd_t_fdy_h
    INTO CORRESPONDING FIELDS OF TABLE @gt_hdr_ext
    WHERE sefer_tarihi IN @s_tarih
      AND plaka        IN @s_plaka
      AND kunnr        IN @s_kunnr
      AND vbeln_zfis   IN @s_vbeln
      AND status       IN @lr_status.

  LOOP AT gt_hdr_ext ASSIGNING FIELD-SYMBOL(<ls_header>).
    PERFORM get_kunnr_name USING <ls_header>-kunnr
      CHANGING <ls_header>-kunnr_name.
    <ls_header>-is_error = xsdbool( <ls_header>-status = 'E' ).
  ENDLOOP.

  IF gt_hdr_ext IS INITIAL.
    MESSAGE 'Kriterlere uygun fabrika iade kaydı bulunamadı.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SORT gt_hdr_ext BY sefer_tarihi plaka kunnr log_uid.
  CALL SCREEN 0100.

MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'TITLE_0100'.

  IF go_custom_container IS BOUND.
    RETURN.
  ENDIF.

  CREATE OBJECT go_custom_container
    EXPORTING
      container_name = 'CC_MAIN'.

  CREATE OBJECT go_splitter_main
    EXPORTING
      parent        = go_custom_container
      orientation   = 1
      sash_position = 22.

  go_container_left = go_splitter_main->top_left_container.
  DATA(lo_container_right) = go_splitter_main->bottom_right_container.

  CREATE OBJECT go_splitter_right
    EXPORTING
      parent  = lo_container_right
      rows    = 3
      columns = 1.

  go_splitter_right->set_row_height( id = 1 height = 48 ).
  go_splitter_right->set_row_height( id = 2 height = 16 ).
  go_splitter_right->set_row_height( id = 3 height = 36 ).

  go_container_rtop = go_splitter_right->get_container( row = 1 column = 1 ).
  go_container_rmid = go_splitter_right->get_container( row = 2 column = 1 ).
  go_container_rbot = go_splitter_right->get_container( row = 3 column = 1 ).

  CREATE OBJECT go_alv_tree
    EXPORTING
      parent              = go_container_left
      node_selection_mode = cl_gui_column_tree=>node_sel_mode_single
      item_selection      = abap_true
      no_html_header      = abap_true.

  DATA: lt_events TYPE cntl_simple_events,
        ls_event  TYPE cntl_simple_event.

  ls_event-eventid = cl_gui_column_tree=>eventid_node_double_click.
  APPEND ls_event TO lt_events.
  ls_event-eventid = cl_gui_column_tree=>eventid_item_context_menu_req.
  APPEND ls_event TO lt_events.
  go_alv_tree->set_registered_events( events = lt_events ).

  CREATE OBJECT go_html_viewer EXPORTING parent = go_container_rtop.
  CREATE OBJECT go_grid_header EXPORTING i_parent = go_container_rmid.
  CREATE OBJECT go_grid_items EXPORTING i_parent = go_container_rbot.

  DATA lt_html_events TYPE cntl_simple_events.
  CLEAR ls_event.
  ls_event-eventid    = cl_gui_html_viewer=>m_id_sapevent.
  ls_event-appl_event = abap_true.
  APPEND ls_event TO lt_html_events.
  go_html_viewer->set_registered_events( events = lt_html_events ).

  CREATE OBJECT go_tree_event_receiver.
  SET HANDLER go_tree_event_receiver->handle_node_double_click FOR go_alv_tree.
  SET HANDLER go_tree_event_receiver->handle_item_context_menu FOR go_alv_tree.
  SET HANDLER go_tree_event_receiver->handle_item_menu_selected FOR go_alv_tree.

  CREATE OBJECT go_html_event_receiver.
  SET HANDLER go_html_event_receiver->on_sapevent FOR go_html_viewer.

  CREATE OBJECT go_grid_event_receiver.
  SET HANDLER go_grid_event_receiver->handle_toolbar FOR go_grid_header.
  SET HANDLER go_grid_event_receiver->handle_user_command FOR go_grid_header.
  SET HANDLER go_grid_event_receiver->handle_data_changed FOR go_grid_header.

  CREATE OBJECT go_item_event_receiver.
  SET HANDLER go_item_event_receiver->handle_on_f4 FOR go_grid_items.
  SET HANDLER go_item_event_receiver->handle_data_changed FOR go_grid_items.

  go_grid_header->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  go_grid_header->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).
  go_grid_items->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_modified ).
  go_grid_items->register_edit_event( i_event_id = cl_gui_alv_grid=>mc_evt_enter ).

  PERFORM build_alv_tree.
  PERFORM setup_alv_grids.
ENDMODULE.

MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      IF gv_locked_uid IS NOT INITIAL.
        CALL FUNCTION 'DEQUEUE_E_TABLE'
          EXPORTING
            tabname = 'ZSD_T_FDY_H'
            varkey  = CONV rstable-varkey( gv_locked_uid ).
      ENDIF.
      CLEAR gv_locked_uid.
      SET SCREEN 0.
      LEAVE SCREEN.
  ENDCASE.
ENDMODULE.

FORM get_kunnr_name USING    pv_kunnr TYPE kunnr
                    CHANGING cv_name  TYPE name1_gp.
  DATA lv_lgort TYPE lgort_d.

  DATA lv_kunnr TYPE kunnr.

  lv_kunnr = |{ pv_kunnr ALPHA = OUT }|.
  IF strlen( lv_kunnr ) EQ 4.
    pv_kunnr = |{ pv_kunnr ALPHA = OUT }|.
    lv_lgort = CONV lgort_d( lv_kunnr ).
    SELECT SINGLE lgobe FROM t001l
      INTO @cv_name
      WHERE werks = '1900'
        AND lgort = @lv_lgort.
  ELSE.
    CLEAR cv_name.
    SELECT SINGLE name1 FROM kna1
      INTO @cv_name
      WHERE kunnr = @pv_kunnr.
  ENDIF.




*  IF sy-subrc = 4.
*    pv_kunnr = |{ pv_kunnr ALPHA = OUT }|.
*    lv_lgort = CONV lgort_d( pv_kunnr ).
*    SELECT SINGLE lgobe FROM t001l
*      INTO @cv_name
*      WHERE werks = '1900'
*        AND lgort = @lv_lgort.
*  ENDIF.
ENDFORM.

FORM build_alv_tree.
  DATA: lt_fcat       TYPE lvc_t_fcat,
        ls_fcat       TYPE lvc_s_fcat,
        ls_out        TYPE ty_tree_out,
        ls_layout     TYPE lvc_s_layn,
        lv_date_key   TYPE lvc_nkey,
        lv_plaka_key  TYPE lvc_nkey,
        lv_leaf_key   TYPE lvc_nkey,
        lv_last_date  TYPE dats,
        lv_last_plaka TYPE zsd_t_fdy_h-plaka,
        lv_node_text  TYPE lvc_value.

  ls_fcat-fieldname = 'NODE_TEXT'.
  ls_fcat-coltext   = 'Fabrika İade Kayıtları'.
  ls_fcat-outputlen = 55.
  APPEND ls_fcat TO lt_fcat.

  go_alv_tree->set_table_for_first_display(
    EXPORTING is_hierarchy_header = VALUE #( heading = 'Tarih / Plaka / Müşteri' width = 48 )
    CHANGING  it_outtab           = gt_tree_out
              it_fieldcatalog     = lt_fcat ).

  LOOP AT gt_hdr_ext INTO DATA(ls_header).
    IF ls_header-sefer_tarihi <> lv_last_date.
      CLEAR ls_out.
      lv_node_text = |Tarih: { ls_header-sefer_tarihi DATE = USER }|.
      ls_out-node_text = lv_node_text.
      go_alv_tree->add_node(
        EXPORTING
          i_relat_node_key = space
          i_relationship   = cl_gui_column_tree=>relat_last_child
          is_outtab_line   = ls_out
          i_node_text      = lv_node_text
        IMPORTING e_new_node_key = lv_date_key ).
      lv_last_date = ls_header-sefer_tarihi.
      CLEAR lv_last_plaka.
    ENDIF.

    IF ls_header-plaka <> lv_last_plaka.
      CLEAR ls_out.
      lv_node_text = |Plaka: { ls_header-plaka }|.
      ls_out-node_text = lv_node_text.
      go_alv_tree->add_node(
        EXPORTING
          i_relat_node_key = lv_date_key
          i_relationship   = cl_gui_column_tree=>relat_last_child
          is_outtab_line   = ls_out
          i_node_text      = lv_node_text
        IMPORTING e_new_node_key = lv_plaka_key ).
      lv_last_plaka = ls_header-plaka.
    ENDIF.

    CLEAR: ls_out, ls_layout.
    lv_node_text = |Müşteri: { ls_header-kunnr ALPHA = OUT } - { ls_header-kunnr_name }|.
    IF ls_header-vbeln_zfis IS NOT INITIAL.
      lv_node_text = |{ lv_node_text } - ZFIS: { ls_header-vbeln_zfis }|.
    ENDIF.
    ls_out-node_text = lv_node_text.
    ls_out-log_uid   = ls_header-log_uid.

    CASE ls_header-status.
      WHEN 'C'.
        ls_layout-n_image = icon_green_light.
      WHEN 'E'.
        ls_layout-n_image = icon_red_light.
      WHEN OTHERS.
        ls_layout-n_image = icon_yellow_light.
    ENDCASE.
    ls_layout-exp_image = ls_layout-n_image.

    go_alv_tree->add_node(
      EXPORTING
        i_relat_node_key = lv_plaka_key
        i_relationship   = cl_gui_column_tree=>relat_last_child
        is_outtab_line   = ls_out
        is_node_layout   = ls_layout
        i_node_text      = lv_node_text
      IMPORTING e_new_node_key = lv_leaf_key ).
  ENDLOOP.

  go_alv_tree->frontend_update( ).
ENDFORM.

FORM append_fcat USING    pv_fieldname TYPE lvc_fname
                          pv_text      TYPE string
                          pv_outputlen TYPE i
                          pv_edit      TYPE abap_bool
                 CHANGING ct_fcat      TYPE lvc_t_fcat.
  DATA ls_fcat TYPE lvc_s_fcat.

  ls_fcat-fieldname = pv_fieldname.
  ls_fcat-coltext   = pv_text.
  ls_fcat-scrtext_s = pv_text.
  ls_fcat-scrtext_m = pv_text.
  ls_fcat-scrtext_l = pv_text.
  ls_fcat-outputlen = pv_outputlen.
  ls_fcat-edit      = pv_edit.
  APPEND ls_fcat TO ct_fcat.
ENDFORM.

FORM setup_alv_grids.
  DATA: lt_fcat_h    TYPE lvc_t_fcat,
        lt_fcat_i    TYPE lvc_t_fcat,
        ls_layout    TYPE lvc_s_layo,
        lt_excluding TYPE ui_functions,
        lt_f4_reg    TYPE lvc_t_f4.

  ls_layout-cwidth_opt = abap_false.
  ls_layout-zebra      = abap_true.

  PERFORM append_fcat USING 'SEFER_TARIHI'  'Sefer tarihi'       12 abap_false CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'PLAKA'          'Plaka'              18 abap_true  CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'KUNNR'          'Müşteri'            12 abap_true  CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'KUNNR_NAME'     'Müşteri adı'        28 abap_false CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'TESLIM_SONUCU'  'Teslim sonucu'      16 abap_true  CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'SUTAS'           'Sütaş'               6 abap_false CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'STATUS'          'Durum'               6 abap_false CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'VBELN_ZFIS'      'ZFIS siparişi'      14 abap_false CHANGING lt_fcat_h.
*  PERFORM append_fcat USING 'VBELN_LF'        'Teslimat'           14 abap_false CHANGING lt_fcat_h.
*  PERFORM append_fcat USING 'MBLNR'           'Malzeme belgesi'    14 abap_false CHANGING lt_fcat_h.
  PERFORM append_fcat USING 'MESSAGE'         'İşlem sonucu'       50 abap_false CHANGING lt_fcat_h.

  READ TABLE lt_fcat_h ASSIGNING FIELD-SYMBOL(<ls_fcat>) WITH KEY fieldname = 'SUTAS'.
  IF sy-subrc = 0.
    <ls_fcat>-checkbox = abap_true.
  ENDIF.

  APPEND cl_gui_alv_grid=>mc_fc_excl_all TO lt_excluding.

  go_grid_header->set_table_for_first_display(
    EXPORTING is_layout            = ls_layout
              it_toolbar_excluding = lt_excluding
    CHANGING  it_outtab       = gt_grid_header
              it_fieldcatalog = lt_fcat_h ).

  PERFORM append_fcat USING 'POSNR'       'Kalem'             8 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'IMG_POSNR' 'Görsel Ref (No)' 15 abap_true CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'MATNR'       'Malzeme'          18 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'MAKTX'       'Malzeme kısa metni' 30 abap_false CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'CHARG'       'Parti'             12 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'MENGE'       'Miktar'            12 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'MEINS'       'Birim'              6 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'ZZGRUND'     'İade nedeni'       15 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'ZZGRUND_TXT' 'İade nedeni text'  22 abap_false CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'ZZALTNDN'    'İade alt nedeni'   12 abap_true  CHANGING lt_fcat_i.
  PERFORM append_fcat USING 'ZZALTNDN_TXT' 'İade alt nedeni text' 22 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'VBELN_ZFIS'  'ZFIS siparişi'     14 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'POSNR_ZFIS'  'ZFIS kalemi'        8 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'VBELN_LF'    'Teslimat'          14 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'POSNR_LF'    'Teslimat kalemi'    8 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'MBLNR'       'Malzeme belgesi'   14 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'MJAHR'       'Belge yılı'         6 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'STATUS'      'Durum'              6 abap_false CHANGING lt_fcat_i.
*  PERFORM append_fcat USING 'MESSAGE'     'İşlem sonucu'      45 abap_false CHANGING lt_fcat_i.

  READ TABLE lt_fcat_i ASSIGNING <ls_fcat> WITH KEY fieldname = 'MENGE'.
  IF sy-subrc = 0.
    <ls_fcat>-ref_table = 'ZSD_T_FDY_I'.
    <ls_fcat>-ref_field = 'MENGE'.
    <ls_fcat>-qfieldname = 'MEINS'.
  ENDIF.

  LOOP AT lt_fcat_i ASSIGNING <ls_fcat>
    WHERE fieldname = 'ZZGRUND' OR fieldname = 'ZZALTNDN'.
    <ls_fcat>-f4availabl = abap_true.
  ENDLOOP.

  lt_f4_reg = VALUE #(
    ( fieldname = 'ZZGRUND'  register = abap_true getbefore = abap_true chngeafter = abap_true )
    ( fieldname = 'ZZALTNDN' register = abap_true getbefore = abap_true chngeafter = abap_true ) ).
  go_grid_items->register_f4_for_fields( it_f4 = lt_f4_reg ).

  go_grid_items->set_table_for_first_display(
    EXPORTING is_layout       = ls_layout
    CHANGING  it_outtab       = gt_grid_items
              it_fieldcatalog = lt_fcat_i ).
ENDFORM.

FORM update_right_screen USING pv_node_key TYPE lvc_nkey.
  DATA: ls_tree_line TYPE ty_tree_out,
        ls_header    TYPE zsd_t_fdy_h,
        ls_hdr_grid  TYPE ty_hdr_grid,
        lt_fcat      TYPE lvc_t_fcat,
        ls_stable    TYPE lvc_s_stbl.

  go_alv_tree->get_outtab_line(
    EXPORTING i_node_key    = pv_node_key
    IMPORTING e_outtab_line = ls_tree_line ).
  CHECK ls_tree_line-log_uid IS NOT INITIAL.

  IF gv_locked_uid IS NOT INITIAL.
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZSD_T_FDY_H'
        varkey  = CONV rstable-varkey( gv_locked_uid ).
  ENDIF.

  gv_locked_uid = ls_tree_line-log_uid.
  CALL FUNCTION 'ENQUEUE_E_TABLE'
    EXPORTING
      tabname      = 'ZSD_T_FDY_H'
      varkey       = CONV rstable-varkey( gv_locked_uid )
    EXCEPTIONS
      foreign_lock = 1
      OTHERS       = 2.
  gv_is_readonly = xsdbool( sy-subrc <> 0 ).

  SELECT SINGLE * FROM zsd_t_fdy_h
    INTO @ls_header
    WHERE log_uid = @ls_tree_line-log_uid.
  IF sy-subrc <> 0.
    MESSAGE 'Başlık kaydı bulunamadı.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF ls_header-status = 'C'.
    gv_is_readonly = abap_true.
  ENDIF.
  gv_is_sutas = xsdbool( ls_header-sutas = abap_true ).

  CLEAR gt_grid_header.
  ls_hdr_grid = CORRESPONDING #( ls_header ).
  PERFORM get_kunnr_name USING ls_header-kunnr
    CHANGING ls_hdr_grid-kunnr_name.
  APPEND ls_hdr_grid TO gt_grid_header.

  SELECT * FROM zsd_t_fdy_i
    INTO CORRESPONDING FIELDS OF TABLE @gt_grid_items
    WHERE log_uid = @ls_header-log_uid
    ORDER BY posnr.

  LOOP AT gt_grid_items ASSIGNING FIELD-SYMBOL(<ls_item_text>).
    PERFORM get_zzgrund_text USING <ls_item_text>-zzgrund
      CHANGING <ls_item_text>-zzgrund_txt.
    PERFORM get_zzaltndn_text USING <ls_item_text>-zzaltndn
      CHANGING <ls_item_text>-zzaltndn_txt.
  ENDLOOP.

  IF gv_is_readonly = abap_false.
    PERFORM ensure_empty_item_rows USING ls_header-log_uid.
  ENDIF.

  CLEAR gv_current_image.
  SELECT posnr, gorsel_alani, image_b64, irsaliye_numarasi, irsaliye_tarihi, ettn
    FROM zsd_t_fdy_img
    INTO CORRESPONDING FIELDS OF TABLE @gt_images
    WHERE log_uid = @ls_header-log_uid
    ORDER BY posnr.

  PERFORM show_images_on_viewer.

  ls_stable-row = abap_true.
  ls_stable-col = abap_true.

  go_grid_header->get_frontend_fieldcatalog( IMPORTING et_fieldcatalog = lt_fcat ).
  LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
    IF <ls_fcat>-fieldname = 'PLAKA' OR
       <ls_fcat>-fieldname = 'KUNNR' OR
       <ls_fcat>-fieldname = 'TESLIM_SONUCU'.
      <ls_fcat>-edit = xsdbool( gv_is_readonly = abap_false ).
    ELSEIF <ls_fcat>-fieldname = 'VBELN_LF' AND
           gv_is_sutas = abap_true AND
           ls_header-status <> 'C'.
      <ls_fcat>-edit = abap_true.
    ELSE.
      <ls_fcat>-edit = abap_false.
    ENDIF.
  ENDLOOP.
  go_grid_header->set_frontend_fieldcatalog( lt_fcat ).
  go_grid_header->refresh_table_display( EXPORTING is_stable = ls_stable ).
  go_grid_header->set_toolbar_interactive( ).

  go_grid_items->get_frontend_fieldcatalog( IMPORTING et_fieldcatalog = lt_fcat ).
  LOOP AT lt_fcat ASSIGNING <ls_fcat>.
    IF <ls_fcat>-fieldname = 'MATNR' OR
       <ls_fcat>-fieldname = 'CHARG' OR
       <ls_fcat>-fieldname = 'MENGE' OR
       <ls_fcat>-fieldname = 'MEINS' OR
       <ls_fcat>-fieldname = 'ZZGRUND' OR
       <ls_fcat>-fieldname = 'ZZALTNDN'.
      IF gv_is_sutas = abap_true AND
         ( <ls_fcat>-fieldname = 'ZZGRUND' OR
           <ls_fcat>-fieldname = 'ZZALTNDN' ).
        <ls_fcat>-edit = abap_false.
      ELSE.
        <ls_fcat>-edit = xsdbool( gv_is_readonly = abap_false ).
      ENDIF.
    ELSE.
      <ls_fcat>-edit = abap_false.
    ENDIF.
  ENDLOOP.
  go_grid_items->set_frontend_fieldcatalog( lt_fcat ).
  go_grid_items->refresh_table_display( EXPORTING is_stable = ls_stable ).
ENDFORM.

FORM ensure_empty_item_rows USING pv_log_uid TYPE sysuuid_c32.
  DATA: lv_empty_count TYPE i,
        lv_posnr       TYPE posnr,
        ls_item        TYPE ty_itm_grid.

  LOOP AT gt_grid_items INTO ls_item.
    IF ls_item-posnr > lv_posnr.
      lv_posnr = ls_item-posnr.
    ENDIF.
    IF ls_item-matnr   IS INITIAL AND
       ls_item-charg   IS INITIAL AND
       ls_item-menge   IS INITIAL AND
       ls_item-meins   IS INITIAL AND
       ls_item-zzgrund IS INITIAL AND
       ls_item-zzaltndn IS INITIAL.
      lv_empty_count = lv_empty_count + 1.
    ENDIF.
  ENDLOOP.

  SELECT MAX( posnr ) FROM zsd_t_fdy_i
    INTO @DATA(lv_db_posnr)
    WHERE log_uid = @pv_log_uid.
  IF lv_db_posnr > lv_posnr.
    lv_posnr = lv_db_posnr.
  ENDIF.

  WHILE lv_empty_count < 20.
    CLEAR ls_item.
    lv_posnr = lv_posnr + 10.
    ls_item-log_uid = pv_log_uid.
    ls_item-posnr   = lv_posnr.
    APPEND ls_item TO gt_grid_items.
    lv_empty_count = lv_empty_count + 1.
  ENDWHILE.
ENDFORM.

FORM get_zzgrund_text USING    pv_zzgrund TYPE zsd_t_fdy_i-zzgrund
                      CHANGING cv_text     TYPE text60.
  CLEAR cv_text.
  CHECK pv_zzgrund IS NOT INITIAL.

  SELECT SINGLE bezei FROM tvlvt
    INTO @cv_text
    WHERE spras = @sy-langu
      AND abrvw = @pv_zzgrund.
  IF sy-subrc <> 0.
    SELECT SINGLE bezei FROM tvlvt
      INTO @cv_text
      WHERE spras = 'T'
        AND abrvw = @pv_zzgrund.
  ENDIF.
ENDFORM.

FORM get_zzaltndn_text USING    pv_zzaltndn TYPE zsd_t_fdy_i-zzaltndn
                       CHANGING cv_text      TYPE text60.
  DATA: lt_dd07v   TYPE STANDARD TABLE OF dd07v,
        lv_domname TYPE dd04l-domname.

  CLEAR cv_text.
  CHECK pv_zzaltndn IS NOT INITIAL.

  SELECT SINGLE bezei FROM t605t
    INTO @cv_text
    WHERE spras = 'T'
      AND land1 = 'TR'
      AND exart = @pv_zzaltndn.
  IF sy-subrc = 0.
    RETURN.
  ENDIF.

  SELECT SINGLE domname FROM dd04l
    INTO @lv_domname
    WHERE rollname = 'EXART'
      AND as4local = 'A'.
  IF lv_domname IS INITIAL.
    lv_domname = 'EXART'.
  ENDIF.

  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      domname   = lv_domname
      text      = abap_true
      langu     = sy-langu
    TABLES
      dd07v_tab = lt_dd07v
    EXCEPTIONS
      OTHERS    = 1.
  READ TABLE lt_dd07v INTO DATA(ls_dd07v)
    WITH KEY domvalue_l = pv_zzaltndn.
  IF sy-subrc = 0.
    cv_text = ls_dd07v-ddtext.
  ENDIF.
ENDFORM.

FORM get_image_mime USING    pv_image TYPE xstring
                    CHANGING cv_mime  TYPE string.
  DATA lv_head TYPE x LENGTH 4.

  cv_mime = 'image/jpeg'.
  IF xstrlen( pv_image ) < 4.
    RETURN.
  ENDIF.

  lv_head = pv_image+0(4).
  IF lv_head = '89504E47'.
    cv_mime = 'image/png'.
  ELSEIF lv_head+0(2) = 'FFD8'.
    cv_mime = 'image/jpeg'.
  ELSEIF lv_head = '47494638'.
    cv_mime = 'image/gif'.
  ELSEIF lv_head+0(2) = '424D'.
    cv_mime = 'image/bmp'.
  ENDIF.
ENDFORM.

FORM load_image_url USING    po_viewer TYPE REF TO cl_gui_html_viewer
                             pv_image  TYPE xstring
                    CHANGING cv_url    TYPE cndp_url.
  DATA: lt_binary TYPE STANDARD TABLE OF x255,
        lv_length TYPE i,
        lv_mime   TYPE string.

  CLEAR cv_url.
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = pv_image
    IMPORTING
      output_length = lv_length
    TABLES
      binary_tab    = lt_binary.

  PERFORM get_image_mime USING pv_image CHANGING lv_mime.
  CASE lv_mime.
    WHEN 'image/png'.
      po_viewer->load_data(
        EXPORTING type = 'image' subtype = 'png' size = lv_length
        IMPORTING assigned_url = cv_url
        CHANGING data_table = lt_binary ).
    WHEN 'image/gif'.
      po_viewer->load_data(
        EXPORTING type = 'image' subtype = 'gif' size = lv_length
        IMPORTING assigned_url = cv_url
        CHANGING data_table = lt_binary ).
    WHEN 'image/bmp'.
      po_viewer->load_data(
        EXPORTING type = 'image' subtype = 'bmp' size = lv_length
        IMPORTING assigned_url = cv_url
        CHANGING data_table = lt_binary ).
    WHEN OTHERS.
      po_viewer->load_data(
        EXPORTING type = 'image' subtype = 'jpeg' size = lv_length
        IMPORTING assigned_url = cv_url
        CHANGING data_table = lt_binary ).
  ENDCASE.
ENDFORM.

FORM build_image_html USING    po_viewer  TYPE REF TO cl_gui_html_viewer
                               pv_selected TYPE posnr
                               pv_popup    TYPE abap_bool
                      CHANGING ct_html     TYPE ty_t_html.
  DATA: ls_selected  TYPE ty_image,
        ls_html      TYPE w3html,
        lv_main_url  TYPE cndp_url,
        lv_thumb_url TYPE cndp_url,
        lv_class     TYPE string.

  CLEAR ct_html.
  READ TABLE gt_images INTO ls_selected WITH KEY posnr = pv_selected.
  IF sy-subrc <> 0.
    READ TABLE gt_images INTO ls_selected INDEX 1.
  ENDIF.

  APPEND VALUE #( line = '<html><head>' ) TO ct_html.
  APPEND VALUE #( line = '<meta http-equiv="X-UA-Compatible" content="IE=edge">' ) TO ct_html.
  APPEND VALUE #( line = '<style>' ) TO ct_html.
  APPEND VALUE #( line = 'html,body{height:100%;margin:0;overflow:hidden;font-family:Arial;background:#eef1f4;}' ) TO ct_html.
  APPEND VALUE #( line = '.bar{height:38px;padding:5px 8px;box-sizing:border-box;background:#d9e4ec;border-bottom:1px solid #9eacb7;}' ) TO ct_html.
  APPEND VALUE #( line = 'button{font-size:12px;margin-right:5px;padding:3px 12px;}' ) TO ct_html.
  APPEND VALUE #( line = '.title{float:right;padding:5px 8px;font-size:12px;font-weight:bold;}' ) TO ct_html.
  APPEND VALUE #( line = '.thumbs{height:78px;white-space:nowrap;overflow-x:auto;background:#e7ecef;padding:4px;box-sizing:border-box;}' ) TO ct_html.
  APPEND VALUE #( line = '.thumb{display:inline-block;height:64px;margin-right:6px;padding:2px;border:2px solid transparent;background:#fff;vertical-align:top;}' ) TO ct_html.
  APPEND VALUE #( line = '.selected{border-color:#0064b0;}' ) TO ct_html.
  APPEND VALUE #( line = '.thumb img{width:88px;height:42px;display:block;}' ) TO ct_html.
  APPEND VALUE #( line = '.thumb span{display:block;width:88px;overflow:hidden;font-size:10px;text-align:center;color:#111;}' ) TO ct_html.
  IF pv_popup = abap_true.
    APPEND VALUE #( line = '#wrap{height:calc(100% - 38px);overflow:auto;text-align:center;background:#cbd2d8;}' ) TO ct_html.
  ELSE.
    APPEND VALUE #( line = '#wrap{height:calc(100% - 116px);overflow:auto;text-align:center;background:#cbd2d8;}' ) TO ct_html.
  ENDIF.
  APPEND VALUE #( line = '#irsimg{width:100%;height:auto;transform-origin:center center;}' ) TO ct_html.
  APPEND VALUE #( line = '</style>' ) TO ct_html.
  APPEND VALUE #( line = '<script type="text/javascript">var z=100,r=0;' ) TO ct_html.
  APPEND VALUE #( line = 'function setz(v){z=v;document.getElementById("irsimg").style.width=z+"%";}' ) TO ct_html.
  APPEND VALUE #( line = 'function zin(){setz(Math.min(z+25,300));}' ) TO ct_html.
  APPEND VALUE #( line = 'function zout(){setz(Math.max(z-25,40));}' ) TO ct_html.
  APPEND VALUE #( line = 'function fit(){r=0;setz(100);rotset();}' ) TO ct_html.
  APPEND VALUE #( line = 'function rotset(){var i=document.getElementById("irsimg");var t="rotate("+r+"deg)";i.style.transform=t;i.style.msTransform=t;i.style.webkitTransform=t;}' ) TO ct_html.
  APPEND VALUE #( line = 'function rot(){r=(r+90)%360;rotset();}' ) TO ct_html.
  IF pv_popup = abap_false AND ls_selected-posnr IS NOT INITIAL.
    ls_html-line = 'function full(){window.location.href="sapevent:FULLSCREEN_'
                && ls_selected-posnr && '";}'.
    APPEND ls_html TO ct_html.
  ENDIF.
  APPEND VALUE #( line = '</script></head><body>' ) TO ct_html.

  IF gt_images IS INITIAL.
    APPEND VALUE #( line = '<div class="bar"></div><div style="padding:20px">Bu kayıt için görsel bulunmuyor.</div>' ) TO ct_html.
    APPEND VALUE #( line = '</body></html>' ) TO ct_html.
    RETURN.
  ENDIF.

  PERFORM load_image_url USING po_viewer ls_selected-image_b64 CHANGING lv_main_url.
  APPEND VALUE #( line = '<div class="bar">' ) TO ct_html.
  APPEND VALUE #( line = '<button onclick="zin()">Yakınlaştır +</button>' ) TO ct_html.
  APPEND VALUE #( line = '<button onclick="zout()">Uzaklaştır -</button>' ) TO ct_html.
  APPEND VALUE #( line = '<button onclick="fit()">Sığdır</button>' ) TO ct_html.
  APPEND VALUE #( line = '<button onclick="rot()">Döndür</button>' ) TO ct_html.
  IF pv_popup = abap_false.
    APPEND VALUE #( line = '<button onclick="full()">Tam ekran</button>' ) TO ct_html.
  ENDIF.
  ls_html-line = |<span class="title">{ ls_selected-gorsel_alani } (No:{ ls_selected-posnr }) - İrsaliye: { ls_selected-irsaliye_numarasi }</span></div>|.
*  ls_html-line = |<span class="title">{ ls_selected-gorsel_alani } ({ ls_selected-posnr })</span></div>|.
  APPEND ls_html TO ct_html.

  IF pv_popup = abap_false.
    APPEND VALUE #( line = '<div class="thumbs">' ) TO ct_html.
    LOOP AT gt_images INTO DATA(ls_image).
      PERFORM load_image_url USING po_viewer ls_image-image_b64 CHANGING lv_thumb_url.
      lv_class = COND #( WHEN ls_image-posnr = ls_selected-posnr
                         THEN 'thumb selected'
                         ELSE 'thumb' ).
      ls_html-line = |<a class="{ lv_class }" href="sapevent:IMG_{ ls_image-posnr }">|.
      APPEND ls_html TO ct_html.
      ls_html-line = |<img src="{ lv_thumb_url }"><span>{ ls_image-gorsel_alani }</span></a>|.
      APPEND ls_html TO ct_html.
    ENDLOOP.
    APPEND VALUE #( line = '</div>' ) TO ct_html.
  ENDIF.

  ls_html-line = |<div id="wrap"><img id="irsimg" src="{ lv_main_url }"></div>|.
  APPEND ls_html TO ct_html.
  APPEND VALUE #( line = '</body></html>' ) TO ct_html.
ENDFORM.

FORM show_images_on_viewer.
  DATA: lv_url  TYPE c LENGTH 255,
        lt_html TYPE ty_t_html.

  IF gt_images IS NOT INITIAL AND
     NOT line_exists( gt_images[ posnr = gv_current_image ] ).
    gv_current_image = gt_images[ 1 ]-posnr.
  ENDIF.

  PERFORM build_image_html USING go_html_viewer gv_current_image abap_false CHANGING lt_html.
  go_html_viewer->load_data(
    EXPORTING type = 'text' subtype = 'html'
    IMPORTING assigned_url = lv_url
    CHANGING  data_table = lt_html ).
  go_html_viewer->show_url( url = lv_url ).
ENDFORM.

FORM show_fullscreen_popup USING pv_posnr TYPE posnr.
  DATA: ls_image TYPE ty_image,
        lv_url   TYPE c LENGTH 255,
        lt_html  TYPE ty_t_html.

  READ TABLE gt_images INTO ls_image WITH KEY posnr = pv_posnr.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.
  gv_current_image = pv_posnr.

  IF go_image_dialog IS BOUND.
    go_image_dialog->free( ).
    CLEAR: go_image_popup, go_image_dialog.
  ENDIF.

  CREATE OBJECT go_image_dialog
    EXPORTING
      width   = 1200
      height  = 820
      caption = ls_image-gorsel_alani.
  SET HANDLER lcl_dialog_handler=>on_close FOR go_image_dialog.
  CREATE OBJECT go_image_popup EXPORTING parent = go_image_dialog.

  PERFORM build_image_html USING go_image_popup pv_posnr abap_true CHANGING lt_html.
  go_image_popup->load_data(
    EXPORTING type = 'text' subtype = 'html'
    IMPORTING assigned_url = lv_url
    CHANGING  data_table = lt_html ).
  go_image_popup->show_url( url = lv_url ).
ENDFORM.

FORM refresh_giris_screen.
  IF gv_current_node_key IS INITIAL.
    MESSAGE 'Önce bir müşteri kaydı seçiniz.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  PERFORM update_right_screen USING gv_current_node_key.
ENDFORM.

FORM save_screen_data CHANGING cv_error TYPE abap_bool
                               cv_msg   TYPE string.
  DATA: ls_header        TYPE ty_hdr_grid,
        lt_process_items TYPE ty_t_itm_grid,
        lt_db_items      TYPE STANDARD TABLE OF zsd_t_fdy_i,
        lv_target_img    TYPE posnr.

  CLEAR: cv_error, cv_msg.
  go_grid_header->check_changed_data( ).
  go_grid_items->check_changed_data( ).

  READ TABLE gt_grid_header INTO ls_header INDEX 1.
  IF sy-subrc <> 0.
    cv_error = abap_true.
    cv_msg   = 'Başlık kaydı seçilmedi.'.
    RETURN.
  ENDIF.

  IF ls_header-plaka IS INITIAL OR ls_header-kunnr IS INITIAL.
    cv_error = abap_true.
    cv_msg   = 'Plaka ve müşteri alanları zorunludur.'.
    RETURN.
  ENDIF.

  IF ls_header-teslim_sonucu <> 'TamTeslim' AND
     ls_header-teslim_sonucu <> 'EksikTeslim'.
    cv_error = abap_true.
    cv_msg   = 'Teslim sonucu TamTeslim veya EksikTeslim olmalıdır.'.
    RETURN.
  ENDIF.

  lt_process_items = gt_grid_items.
  DELETE lt_process_items
    WHERE matnr    IS INITIAL
      AND charg    IS INITIAL
      AND menge    IS INITIAL
      AND meins    IS INITIAL
      AND zzgrund  IS INITIAL
      AND zzaltndn IS INITIAL.

  IF lt_process_items IS INITIAL.
    cv_error = abap_true.
    cv_msg   = 'Malzeme kalemi bulunamadı.'.
    RETURN.
  ENDIF.

  LOOP AT gt_images INTO DATA(ls_target_img)
         WHERE gorsel_alani EQ 'UrunIadeGorseli'
            OR gorsel_alani EQ 'DepozitoIadeGorseli'
            OR gorsel_alani EQ 'SutasIptalFaturaIrsaliye'
            OR gorsel_alani EQ 'IadeIrsaliyesiTutanak'.
    lv_target_img = ls_target_img-posnr.
    EXIT. " İlk geçerli işlem belgesini bulduğunda çık
  ENDLOOP.


  LOOP AT lt_process_items ASSIGNING FIELD-SYMBOL(<ls_item>).
    IF <ls_item>-matnr IS INITIAL OR
       <ls_item>-menge <= 0 OR
       <ls_item>-meins IS INITIAL.
      cv_error = abap_true.
      cv_msg   = |{ <ls_item>-posnr } numaralı kalemde malzeme, miktar ve birim zorunludur.|.
      RETURN.
    ENDIF.
    IF gv_is_sutas = abap_false AND <ls_item>-zzgrund IS INITIAL.
      cv_error = abap_true.
      cv_msg = |{ <ls_item>-posnr } numaralı kalemde iade nedeni zorunludur.|.
      RETURN.
    ENDIF.
    <ls_item>-log_uid = ls_header-log_uid.
    <ls_item>-img_posnr = lv_target_img.
  ENDLOOP.

  gt_grid_items = lt_process_items.

  UPDATE zsd_t_fdy_h
     SET plaka          = @ls_header-plaka,
         kunnr          = @ls_header-kunnr,
         teslim_sonucu  = @ls_header-teslim_sonucu,
         vbeln_lf       = @ls_header-vbeln_lf,
         aedat          = @sy-datum,
         aezet          = @sy-uzeit,
         aenam          = @sy-uname
   WHERE log_uid        = @ls_header-log_uid.
  IF sy-subrc <> 0.
    cv_error = abap_true.
    cv_msg   = 'Başlık kaydı güncellenemedi.'.
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  lt_db_items = CORRESPONDING #( gt_grid_items ).
  MODIFY zsd_t_fdy_i FROM TABLE @lt_db_items.
  IF sy-subrc <> 0.
    cv_error = abap_true.
    cv_msg   = 'Malzeme kalemleri güncellenemedi.'.
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.
ENDFORM.

FORM create_zfis_order USING    ps_header TYPE ty_hdr_grid
                                pt_items  TYPE ty_t_itm_grid
                       CHANGING cv_vbeln  TYPE vbeln_va
                                cv_error  TYPE abap_bool
                                cv_msg    TYPE string.
  DATA: ls_sales_header TYPE bapisdhd1,
        lt_sales_items  TYPE STANDARD TABLE OF bapisditm,
        lt_partners     TYPE STANDARD TABLE OF bapiparnr,
        lt_schedules    TYPE STANDARD TABLE OF bapischdl,
        lt_return       TYPE STANDARD TABLE OF bapiret2.

  CLEAR: cv_error, cv_msg.
  cv_vbeln = ps_header-vbeln_zfis.
  IF cv_vbeln IS NOT INITIAL.
    RETURN.
  ENDIF.
  IF ps_header-iade_tipi EQ 'D'.
    ls_sales_header-doc_type   = 'ZDAI'.
  ELSE.
    ls_sales_header-doc_type   = 'ZFIS'.
  ENDIF.

  ls_sales_header-sales_org  = '1000'.
  ls_sales_header-distr_chan = '10'.
  ls_sales_header-division   = '00'.
  ls_sales_header-doc_date   = sy-datum.
  ls_sales_header-req_date_h = sy-datum.
  ls_sales_header-price_date = sy-datum.
  ls_sales_header-purch_date = ps_header-sefer_tarihi.
  ls_sales_header-purch_no_c = ps_header-plaka.
  ls_sales_header-collect_no = ps_header-plaka.

  APPEND VALUE #( partn_role = 'AG' partn_numb = ps_header-kunnr ) TO lt_partners.
  APPEND VALUE #( partn_role = 'WE' partn_numb = ps_header-kunnr ) TO lt_partners.

  LOOP AT pt_items INTO DATA(ls_item).

    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = ls_item-meins
      IMPORTING
        output         = ls_item-meins
      EXCEPTIONS
        unit_not_found = 1.


    APPEND VALUE #(
      itm_number = ls_item-posnr
      material   = ls_item-matnr
      batch      = ls_item-charg
      target_qty = ls_item-menge
      target_qu  = ls_item-meins
      sales_unit = ls_item-meins
      bus_transt  = ls_item-zzaltndn
      dlvschduse  = ls_item-zzgrund ) TO lt_sales_items.
    APPEND VALUE #(
      itm_number = ls_item-posnr
      req_qty    = ls_item-menge
      req_date   = sy-datum ) TO lt_schedules.
  ENDLOOP.

  CALL FUNCTION 'SD_SALESDOCUMENT_CREATE' DESTINATION 'NONE'
    EXPORTING
      sales_header_in    = ls_sales_header
      business_object    = 'BUS2102'
    IMPORTING
      salesdocument_ex   = cv_vbeln
    TABLES
      return             = lt_return
      sales_items_in     = lt_sales_items
      sales_partners     = lt_partners
      sales_schedules_in = lt_schedules.

  READ TABLE lt_return INTO DATA(ls_return) WITH KEY type = 'A'.
  IF sy-subrc <> 0.
    READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
  ENDIF.
  IF sy-subrc = 0 OR cv_vbeln IS INITIAL.
    cv_error = abap_true.
    cv_msg   = COND #( WHEN ls_return-message IS NOT INITIAL
                       THEN ls_return-message
                       ELSE 'ZFIS siparişi oluşturulamadı.' ).
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK' DESTINATION 'NONE'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' DESTINATION 'NONE'
    EXPORTING
      wait = abap_true.
ENDFORM.

FORM get_follow_on_documents USING    pv_vbeln   TYPE vbeln_va
                             CHANGING cv_delivery TYPE vbeln_vl
                                      cv_mblnr    TYPE mblnr
                                      cv_mjahr    TYPE mjahr.
  CLEAR: cv_delivery, cv_mblnr, cv_mjahr.

  SELECT SINGLE vbeln
    FROM vbfa
    INTO @cv_delivery
    WHERE vbelv = @pv_vbeln
      AND vbtyp_n = 'J'.

  IF cv_delivery IS NOT INITIAL.
    SELECT SINGLE vbeln, mjahr
      FROM vbfa
      INTO (@cv_mblnr, @cv_mjahr)
      WHERE vbelv = @cv_delivery
        AND vbtyp_n = 'R'.
  ENDIF.
ENDFORM.

FORM create_delivery_and_goods_mvt
  USING    pv_vbeln    TYPE vbeln_va
  CHANGING cv_delivery TYPE vbeln_vl
           cv_mblnr    TYPE mblnr
           cv_mjahr    TYPE mjahr
           cv_error    TYPE abap_bool
           cv_msg      TYPE string.

  DATA: lt_return      TYPE STANDARD TABLE OF bapiret2,
        lt_order_items TYPE STANDARD TABLE OF bapidlvreftosalesorder,
        lt_deliveries  TYPE STANDARD TABLE OF bapishpdelivnumb,
        lt_created     TYPE STANDARD TABLE OF bapidlvitemcreated.

  CLEAR: cv_error, cv_msg.
  PERFORM get_follow_on_documents USING pv_vbeln
    CHANGING cv_delivery cv_mblnr cv_mjahr.
  IF cv_mblnr IS NOT INITIAL.
    RETURN.
  ENDIF.

  IF cv_delivery IS INITIAL.
    SELECT vbeln, posnr, vstel
      FROM vbap
      INTO TABLE @DATA(lt_vbap)
      WHERE vbeln = @pv_vbeln
        AND kwmeng > 0.
    IF lt_vbap IS INITIAL.
      cv_error = abap_true.
      cv_msg   = |ZFIS kalemi bulunamadı: { pv_vbeln }|.
      RETURN.
    ENDIF.

    LOOP AT lt_vbap INTO DATA(ls_vbap).
      APPEND VALUE #(
        ref_doc  = ls_vbap-vbeln
        ref_item = ls_vbap-posnr ) TO lt_order_items.
    ENDLOOP.

    CALL FUNCTION 'ZSD_CREDIT_CHECK_TURN_OFF'.
    CALL FUNCTION 'BAPI_OUTB_DELIVERY_CREATE_SLS'
      EXPORTING
        ship_point        = ls_vbap-vstel
        due_date          = '99991231'
      TABLES
        sales_order_items = lt_order_items
        deliveries        = lt_deliveries
        created_items     = lt_created
        return            = lt_return.
    CALL FUNCTION 'ZSD_CREDIT_CHECK_TURN_ON'.

    READ TABLE lt_return INTO DATA(ls_return) WITH KEY type = 'A'.
    IF sy-subrc <> 0.
      READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
    ENDIF.
    IF sy-subrc = 0.
      cv_error = abap_true.
      cv_msg   = ls_return-message.
      ROLLBACK WORK.
      RETURN.
    ENDIF.

    READ TABLE lt_deliveries INTO DATA(ls_delivery) INDEX 1.
    IF sy-subrc = 0.
      cv_delivery = ls_delivery-deliv_numb.
    ENDIF.
    IF cv_delivery IS INITIAL.
      cv_error = abap_true.
      cv_msg   = |Teslimat oluşturulamadı. ZFIS: { pv_vbeln }|.
      ROLLBACK WORK.
      RETURN.
    ENDIF.
    COMMIT WORK AND WAIT.
  ENDIF.

  DATA: ls_vbkok TYPE vbkok,
        lt_vbpok TYPE STANDARD TABLE OF vbpok.
  SELECT vbeln, posnr, lfimg
    FROM lips
    INTO TABLE @DATA(lt_lips)
    WHERE vbeln = @cv_delivery.

  LOOP AT lt_lips INTO DATA(ls_lips).
    APPEND VALUE #(
      vbeln_vl = ls_lips-vbeln
      posnr_vl = ls_lips-posnr
      vbeln    = ls_lips-vbeln
      posnn    = ls_lips-posnr
      pikmg    = ls_lips-lfimg
      ndifm    = ls_lips-lfimg ) TO lt_vbpok.
  ENDLOOP.

  ls_vbkok-vbeln_vl = cv_delivery.
  ls_vbkok-wabuc    = abap_true.
  CALL FUNCTION 'WS_DELIVERY_UPDATE'
    EXPORTING
      vbkok_wa       = ls_vbkok
      delivery       = cv_delivery
      commit         = abap_true
      update_picking = abap_true
    TABLES
      vbpok_tab      = lt_vbpok
    EXCEPTIONS
      OTHERS         = 1.
  IF sy-subrc <> 0.
    cv_error = abap_true.
    cv_msg   = |Mal hareketi oluşturulamadı. Teslimat: { cv_delivery }|.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.

  FIELD-SYMBOLS: <ls_emkpf> TYPE emkpf.
  " Programın global yapısına dinamik erişim
  ASSIGN ('(SAPLV50S)EMKPF') TO <ls_emkpf>.

  IF <ls_emkpf> IS ASSIGNED AND <ls_emkpf>-mblnr IS NOT INITIAL.
    cv_mblnr = <ls_emkpf>-mblnr.
    cv_mjahr = <ls_emkpf>-mjahr.
  ELSE.
    DO 1000 TIMES.
      SELECT SINGLE vbeln AS mblnr,
                    mjahr
        FROM vbfa
        INTO @DATA(ls_vbfa)
        WHERE vbelv   = @cv_delivery
          AND vbtyp_v = 'J'
          AND vbtyp_n = 'R'.
      IF sy-subrc EQ 0.
        EXIT.
      ELSE.
        SELECT SINGLE vbeln AS mblnr,
                      mjahr
          FROM vbfa
          INTO @ls_vbfa
          WHERE vbelv   = @cv_delivery
            AND vbtyp_v = 'T'
            AND vbtyp_n = 'R'.
        IF sy-subrc EQ 0.
          EXIT.
        ENDIF.
      ENDIF.
    ENDDO.
    cv_mblnr = ls_vbfa-mblnr.
    cv_mjahr = ls_vbfa-mjahr.
  ENDIF.


*  PERFORM get_follow_on_documents USING pv_vbeln
*    CHANGING cv_delivery cv_mblnr cv_mjahr.
  IF cv_mblnr IS INITIAL.
    cv_error = abap_true.
    cv_msg   = |Malzeme belgesi bulunamadı. Teslimat: { cv_delivery }|.
  ENDIF.
ENDFORM.

FORM persist_process_result
  USING ps_header   TYPE ty_hdr_grid
        pv_status   TYPE char1
        pv_vbeln    TYPE vbeln_va
        pv_delivery TYPE vbeln_vl
        pv_mblnr    TYPE mblnr
        pv_mjahr    TYPE mjahr
        pv_message  TYPE string.

  UPDATE zsd_t_fdy_h
     SET status     = @pv_status,
         message    = @pv_message,
         vbeln_zfis = @pv_vbeln,
         vbeln_lf   = @pv_delivery,
         mblnr      = @pv_mblnr,
         mjahr      = @pv_mjahr,
         aedat      = @sy-datum,
         aezet      = @sy-uzeit,
         aenam      = @sy-uname
   WHERE log_uid    = @ps_header-log_uid.

  SELECT vbeln, posnr, vgpos
    FROM lips
    INTO TABLE @DATA(lt_lips)
    WHERE vbeln = @pv_delivery
      AND vgbel = @pv_vbeln.

  LOOP AT gt_grid_items INTO DATA(ls_item).
    DATA(lv_posnr_lf) = VALUE posnr_vl( ).
    READ TABLE lt_lips INTO DATA(ls_lips) WITH KEY vgpos = ls_item-posnr.
    IF sy-subrc = 0.
      lv_posnr_lf = ls_lips-posnr.
    ENDIF.

    UPDATE zsd_t_fdy_i
       SET status     = @pv_status,
           message    = @pv_message,
           vbeln_zfis = @pv_vbeln,
           posnr_zfis = @ls_item-posnr,
           vbeln_lf   = @pv_delivery,
           posnr_lf   = @lv_posnr_lf,
           mblnr      = @pv_mblnr,
           mjahr      = @pv_mjahr
     WHERE log_uid    = @ps_header-log_uid
       AND posnr      = @ls_item-posnr.
  ENDLOOP.

  COMMIT WORK AND WAIT.
ENDFORM.

FORM reverse_sutas_goods_issue
  USING    pv_delivery TYPE vbeln_vl
  CHANGING cv_mblnr    TYPE mblnr
           cv_mjahr    TYPE mjahr
           cv_error    TYPE abap_bool
           cv_msg      TYPE string.

  DATA lt_messages TYPE STANDARD TABLE OF mesg.
  CLEAR: cv_mblnr, cv_mjahr, cv_error, cv_msg.

  SELECT SINGLE f~vbeln, f~mjahr, m~budat
    FROM vbfa AS f
    INNER JOIN mkpf AS m
      ON m~mblnr = f~vbeln
     AND m~mjahr = f~mjahr
    INTO @DATA(ls_document)
    WHERE f~vbelv   = @pv_delivery
      AND f~vbtyp_n = 'R'
      AND NOT EXISTS ( SELECT * FROM mseg AS s
                        WHERE s~smbln = f~vbeln
                          AND s~sjahr = f~mjahr ).
  IF sy-subrc <> 0.
    cv_error = abap_true.
    cv_msg   = |Ters kaydı yapılacak malzeme belgesi bulunamadı: { pv_delivery }|.
    RETURN.
  ENDIF.

  cv_mblnr = ls_document-vbeln.
  cv_mjahr = ls_document-mjahr.
  CALL FUNCTION 'WS_REVERSE_GOODS_ISSUE'
    EXPORTING
      i_vbeln                   = pv_delivery
      i_budat                   = ls_document-budat
      i_tcode                   = 'VL09'
      i_vbtyp                   = 'J'
      i_mblnr                   = cv_mblnr
      i_mjahr                   = cv_mjahr
    TABLES
      t_mesg                    = lt_messages
    EXCEPTIONS
      error_reverse_goods_issue = 1
      OTHERS                    = 2.

  IF sy-subrc <> 0 OR
     line_exists( lt_messages[ msgty = 'E' ] ) OR
     line_exists( lt_messages[ msgty = 'A' ] ).
    cv_error = abap_true.
    cv_msg   = |Sütaş ters kaydı başarısız. Teslimat: { pv_delivery }|.
    ROLLBACK WORK.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.
ENDFORM.

FORM complete_process.
  DATA: ls_header   TYPE ty_hdr_grid,
        lv_vbeln    TYPE vbeln_va,
        lv_delivery TYPE vbeln_vl,
        lv_mblnr    TYPE mblnr,
        lv_mjahr    TYPE mjahr,
        lv_error    TYPE abap_bool,
        lv_status   TYPE char1,
        lv_msg      TYPE string.

  IF gv_is_readonly = abap_true.
    MESSAGE 'Kayıt salt okunur durumda.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM save_screen_data CHANGING lv_error lv_msg.
  IF lv_error = abap_true.
    MESSAGE lv_msg TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  READ TABLE gt_grid_header INTO ls_header INDEX 1.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  IF ls_header-sutas = abap_true.
    lv_delivery = ls_header-vbeln_lf.
    IF lv_delivery IS INITIAL AND ls_header-vbeln_zfis IS NOT INITIAL.
      PERFORM get_follow_on_documents USING ls_header-vbeln_zfis
        CHANGING lv_delivery lv_mblnr lv_mjahr.
    ENDIF.
    IF lv_delivery IS INITIAL.
      lv_error = abap_true.
      lv_msg = 'Sütaş iptali için kaynak teslimat numarası gereklidir.'.
    ELSE.
      PERFORM reverse_sutas_goods_issue USING lv_delivery
        CHANGING lv_mblnr lv_mjahr lv_error lv_msg.
      IF lv_error = abap_false.
        lv_msg = |Sütaş teslimat mal hareketi ters kaydedildi: { lv_delivery }|.
      ENDIF.
    ENDIF.

    lv_status = COND #( WHEN lv_error = abap_true THEN 'E' ELSE 'C' ).
    PERFORM persist_process_result USING ls_header lv_status
      ls_header-vbeln_zfis lv_delivery lv_mblnr lv_mjahr lv_msg.
  ELSE.

    PERFORM create_zfis_order USING ls_header gt_grid_items
      CHANGING lv_vbeln lv_error lv_msg.

    IF lv_error = abap_true.
      PERFORM persist_process_result USING ls_header 'E' lv_vbeln
        lv_delivery lv_mblnr lv_mjahr lv_msg.
    ELSE.
      lv_msg = |Süreç tamamlandı. ZFIS:{ lv_vbeln }|.
      PERFORM persist_process_result USING ls_header 'C' lv_vbeln
        lv_delivery lv_mblnr lv_mjahr lv_msg.

*      PERFORM persist_process_result USING ls_header 'N' lv_vbeln
*        lv_delivery lv_mblnr lv_mjahr 'ZFIS siparişi oluşturuldu.'.

*      PERFORM create_delivery_and_goods_mvt USING lv_vbeln
*        CHANGING lv_delivery lv_mblnr lv_mjahr lv_error lv_msg.
*      IF lv_error = abap_true.
*        PERFORM persist_process_result USING ls_header 'E' lv_vbeln
*          lv_delivery lv_mblnr lv_mjahr lv_msg.
*      ELSE.
*        lv_msg = |Süreç tamamlandı. ZFIS:{ lv_vbeln } Teslimat:{ lv_delivery } Malzeme belgesi:{ lv_mblnr }|.
*        PERFORM persist_process_result USING ls_header 'C' lv_vbeln
*          lv_delivery lv_mblnr lv_mjahr lv_msg.
*      ENDIF.
    ENDIF.
  ENDIF.

  IF lv_error = abap_true.
    MESSAGE lv_msg TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    gv_is_readonly = abap_true.
    MESSAGE lv_msg TYPE 'S'.
  ENDIF.
  PERFORM refresh_giris_screen.
ENDFORM.
