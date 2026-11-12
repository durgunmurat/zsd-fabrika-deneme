class ZCL_ZSD_FDY_GR_DPC_EXT definition
  public
  inheriting from ZCL_ZSD_FDY_GR_DPC
  create public .

public section.

  types:
    BEGIN OF ts_deep_deliverynote,
         deliverynumber    TYPE string,
         lpid              TYPE string,
         status            TYPE zmm_t_bdy_gr_h-status,
         totalmaterialno   TYPE string,
         total1            TYPE /iwbep/sb_odata_ty_int2,
         total2            TYPE /iwbep/sb_odata_ty_int2,
         total3            TYPE /iwbep/sb_odata_ty_int2,
         total4            TYPE /iwbep/sb_odata_ty_int2,
         total5            TYPE /iwbep/sb_odata_ty_int2,
         total6            TYPE /iwbep/sb_odata_ty_int2,
         total7            TYPE /iwbep/sb_odata_ty_int2,
         total8            TYPE /iwbep/sb_odata_ty_int2,
         total9            TYPE /iwbep/sb_odata_ty_int2,
         totaldepozito     TYPE /iwbep/sb_odata_ty_int2,
         totalporsiyon     TYPE /iwbep/sb_odata_ty_int2,
         total1text        TYPE string,
         total2text        TYPE string,
         total3text        TYPE string,
         total4text        TYPE string,
         total5text        TYPE string,
         total6text        TYPE string,
         total7text        TYPE string,
         total8text        TYPE string,
         total9text        TYPE string,
         totaldepozitotext TYPE string,
         totalporsiyontext TYPE string,
         toitems           TYPE STANDARD TABLE OF
           zcl_zsd_fdy_gr_mpc_ext=>ts_deliveryitem WITH DEFAULT KEY,
       END OF ts_deep_deliverynote .
  types:
    tt_deep_deliverynote TYPE STANDARD TABLE OF ts_deep_deliverynote WITH DEFAULT KEY .
  types:
    BEGIN OF ts_deep_licenseplate,
         lpid            TYPE string,
         warehousenum    TYPE string,
         warehouse       TYPE string,
         platenumber     TYPE string,
         arrivaldate     TYPE zcl_zsd_fdy_gr_mpc_ext=>ts_licenseplate-arrivaldate,
         photocount      TYPE string,
         werks           TYPE werks_d,
         werkstext       TYPE string,
         status          TYPE char1,
         aracsicaklik    TYPE p LENGTH 4 DECIMALS 2,
         todeliverynotes TYPE tt_deep_deliverynote,
       END OF ts_deep_licenseplate .
  types:
    tt_deep_licenseplate TYPE STANDARD TABLE OF ts_deep_licenseplate WITH DEFAULT KEY .

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_STREAM
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITYSET
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_STREAM
    redefinition .
protected section.

  methods EDITREASONSET_GET_ENTITYSET
    redefinition .
  methods PERSONNELSET_GET_ENTITY
    redefinition .
  methods PERSONNELSET_GET_ENTITYSET
    redefinition .
  methods PLATEPHOTOSET_DELETE_ENTITY
    redefinition .
  methods PLATEPHOTOSET_GET_ENTITYSET
    redefinition .
  methods NOTEGRSET_GET_ENTITYSET
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZSD_FDY_GR_DPC_EXT IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_stream.
    DATA: ls_photo       TYPE zsd_t_fdy_photo,
          ls_entity      TYPE zcl_zsd_fdy_gr_mpc=>ts_platephoto,
          lv_lpid        TYPE string,
          lv_filename    TYPE string,
          lv_photo_count TYPE i.

    IF iv_entity_set_name <> 'PlatePhotoSet' OR iv_slug IS INITIAL.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Fotoğraf yükleme bilgisi okunamadı.'.
    ENDIF.

    SPLIT iv_slug AT '|' INTO lv_lpid lv_filename.
    IF lv_lpid IS INITIAL OR lv_filename IS INITIAL.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Slug formatı LpId|FileName olmalıdır.'.
    ENDIF.

    IF is_media_resource-mime_type <> 'image/jpeg'
       AND is_media_resource-mime_type <> 'image/png'.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Yalnızca JPG ve PNG yüklenebilir.'.
    ENDIF.

    IF xstrlen( is_media_resource-value ) > 5 * 1024 * 1024.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Fotoğraf boyutu en fazla 5 MB olabilir.'.
    ENDIF.

    SELECT COUNT(*) FROM zsd_t_fdy_photo
      WHERE lpid = @lv_lpid
      INTO @lv_photo_count.
    IF lv_photo_count >= 5.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Bir plaka için en fazla 5 fotoğraf yüklenebilir.'.
    ENDIF.

    ls_photo-photo_id   = cl_system_uuid=>create_uuid_c32_static( ).
    ls_photo-lpid       = lv_lpid.
    ls_photo-filename   = lv_filename.
    ls_photo-mimetype   = is_media_resource-mime_type.
    ls_photo-content    = is_media_resource-value.
    ls_photo-uploaded_by = sy-uname.
    ls_photo-erdat      = sy-datum.
    ls_photo-erzet      = sy-uzeit.

    INSERT zsd_t_fdy_photo FROM @ls_photo.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Fotoğraf kaydedilemedi.'.
    ENDIF.

    ls_entity-photoid   = ls_photo-photo_id.
    ls_entity-lpid      = ls_photo-lpid.
    ls_entity-filename  = ls_photo-filename.
    ls_entity-mimetype  = ls_photo-mimetype.
    ls_entity-uploadedby = ls_photo-uploaded_by.

        CONVERT DATE ls_photo-erdat
                TIME ls_photo-erzet
                INTO TIME STAMP ls_entity-uploaddate
                TIME ZONE 'UTC'.
*    ls_entity-uploaddate = ls_photo-erdat.
    ls_entity-uploadtime = ls_photo-erzet.

    copy_data_to_ref(
      EXPORTING is_data = ls_entity
      CHANGING  cr_data = er_entity ).
  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
    DATA lo_general TYPE REF TO zsd_cl_fdy_general.
    DATA ls_result  TYPE zcl_zsd_fdy_gr_mpc=>actionresult.

    CREATE OBJECT lo_general.

    CASE iv_action_name.
      WHEN 'PostGoodsReceipt'.
        lo_general->post_goods_receipt( it_parameter = it_parameter ).
        ls_result-success = abap_true.
        ls_result-message = 'İşlem tamamlandı'.

      WHEN 'SaveNoteGR'.
        lo_general->save_note_gr( it_parameter = it_parameter ).
        ls_result-success = abap_true.
        ls_result-message = 'Not kaydedildi'.

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~execute_action(
          EXPORTING
            iv_action_name          = iv_action_name
            it_parameter            = it_parameter
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_data                 = er_data ).
        RETURN.
    ENDCASE.

    copy_data_to_ref(
      EXPORTING is_data = ls_result
      CHANGING  cr_data = er_data ).
  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset.
    IF iv_entity_set_name = 'LicensePlateSet'.
      DATA(lo_general) = NEW zsd_cl_fdy_general( ).
      DATA lt_license_plates TYPE zsd_cl_fdy_general=>tt_deep_licenseplate.

      lo_general->get_license_plate_set(
        EXPORTING
          it_filter_select_options = it_filter_select_options
        IMPORTING
          et_deep_licenceplate     = lt_license_plates ).

      copy_data_to_ref(
        EXPORTING
          is_data = lt_license_plates
        CHANGING
          cr_data = er_entityset ).

      APPEND 'TODELIVERYNOTES'
        TO et_expanded_tech_clauses.

      APPEND 'TODELIVERYNOTES/TOITEMS'
        TO et_expanded_tech_clauses.

      RETURN.
    ENDIF.

    super->/iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset(
      EXPORTING
        iv_entity_name           = iv_entity_name
        iv_entity_set_name       = iv_entity_set_name
        iv_source_name           = iv_source_name
        it_filter_select_options = it_filter_select_options
        it_order                 = it_order
        is_paging                = is_paging
        it_navigation_path       = it_navigation_path
        it_key_tab               = it_key_tab
        iv_filter_string         = iv_filter_string
        iv_search_string         = iv_search_string
        io_expand                = io_expand
        io_tech_request_context  = io_tech_request_context
      IMPORTING
        er_entityset             = er_entityset
        et_expanded_clauses      = et_expanded_clauses
        et_expanded_tech_clauses = et_expanded_tech_clauses
        es_response_context      = es_response_context ).
  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_stream.
    DATA: ls_stream  TYPE ty_s_media_resource,
          lo_general TYPE REF TO zsd_cl_fdy_general,
          lv_photoid TYPE string.

    READ TABLE it_key_tab INTO DATA(ls_key)
      WITH KEY name = 'PhotoId'.
    IF sy-subrc <> 0.
      READ TABLE it_key_tab INTO ls_key
        WITH KEY name = 'PHOTOID'.
    ENDIF.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'PhotoId anahtarı bulunamadı.'.
    ENDIF.
    lv_photoid = ls_key-value.

    CREATE OBJECT lo_general.
    lo_general->get_photo_binary(
      EXPORTING iv_docid    = lv_photoid
      IMPORTING ev_content  = ls_stream-value
                ev_mimetype = ls_stream-mime_type ).

    IF ls_stream-value IS INITIAL.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Fotoğraf bulunamadı.'.
    ENDIF.

    copy_data_to_ref(
      EXPORTING is_data = ls_stream
      CHANGING  cr_data = er_stream ).
  ENDMETHOD.


  METHOD editreasonset_get_entityset.
    CONSTANTS lc_domain_name TYPE domname
        VALUE 'ZMM_DO_BDY_GR_EDIT_REASON'.

    SELECT domvalue_l AS key,
           ddtext     AS text
      FROM dd07t
      WHERE domname    = @lc_domain_name
        AND ddlanguage = @sy-langu
        AND as4local   = 'A'
      ORDER BY valpos
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
  ENDMETHOD.


  METHOD notegrset_get_entityset.
    DATA lv_lpid TYPE zsd_t_fdy_note-lpid.
    DATA ls_entity TYPE zcl_zsd_fdy_gr_mpc=>ts_notegr.

    LOOP AT it_filter_select_options INTO DATA(ls_filter)
         WHERE property = 'LpId'.
      READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
      IF sy-subrc = 0.
        lv_lpid = ls_option-low.
      ENDIF.
      EXIT.
    ENDLOOP.

    IF lv_lpid IS INITIAL.
      RETURN.
    ENDIF.

    SELECT lpid,
           note,
           sicil,
           aedat AS changedat,
           aezet AS changedtime
      FROM zsd_t_fdy_note
      WHERE lpid = @lv_lpid
      INTO TABLE @DATA(lt_data).


    LOOP AT lt_data INTO DATA(ls_data).
      CLEAR ls_entity.
      MOVE-CORRESPONDING ls_data TO ls_entity.

      IF ls_data-changedat IS NOT INITIAL.
        CONVERT DATE ls_data-changedat
                TIME ls_data-changedtime
                INTO TIME STAMP ls_entity-changedat
                TIME ZONE 'UTC'.
      ENDIF.
      ls_entity-changedtime = ls_data-changedtime.

      APPEND ls_entity TO et_entityset.
    ENDLOOP.
  ENDMETHOD.


  METHOD personnelset_get_entity.
    DATA: lv_tabname TYPE tabname VALUE 'ZPPB05',
          lr_rows    TYPE REF TO data.

    FIELD-SYMBOLS: <lt_rows>  TYPE STANDARD TABLE,
                   <ls_row>   TYPE any,
                   <lv_no>    TYPE any,
                   <lv_name>  TYPE any,
                   <lv_werks> TYPE any.

    DATA(lv_personnel_no) = VALUE pernr_d(
      it_key_tab[ name = 'PersonnelNo' ]-value OPTIONAL ).
    lv_personnel_no = |{ lv_personnel_no ALPHA = IN }|.

    CREATE DATA lr_rows TYPE TABLE OF (lv_tabname).
    ASSIGN lr_rows->* TO <lt_rows>.
    SELECT * FROM (lv_tabname) INTO TABLE <lt_rows>.

    LOOP AT <lt_rows> ASSIGNING <ls_row>.
      UNASSIGN: <lv_no>, <lv_name>, <lv_werks>.

      ASSIGN COMPONENT 'PERS_NO' OF STRUCTURE <ls_row> TO <lv_no>.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'PERNR' OF STRUCTURE <ls_row> TO <lv_no>. ENDIF.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'SICILNO' OF STRUCTURE <ls_row> TO <lv_no>. ENDIF.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'PERSONNELNO' OF STRUCTURE <ls_row> TO <lv_no>. ENDIF.
      IF <lv_no> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      DATA(lv_candidate) = CONV pernr_d( <lv_no> ).
      lv_candidate = |{ lv_candidate ALPHA = IN }|.
      IF lv_candidate <> lv_personnel_no.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT 'PERS_ADI' OF STRUCTURE <ls_row> TO <lv_name>.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'ENAME' OF STRUCTURE <ls_row> TO <lv_name>. ENDIF.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'SICILNAME' OF STRUCTURE <ls_row> TO <lv_name>. ENDIF.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'PERSONNELNAME' OF STRUCTURE <ls_row> TO <lv_name>. ENDIF.

      ASSIGN COMPONENT 'WERKS' OF STRUCTURE <ls_row> TO <lv_werks>.
      IF sy-subrc <> 0. ASSIGN COMPONENT 'PLANT' OF STRUCTURE <ls_row> TO <lv_werks>. ENDIF.

      er_entity-personnelno = <lv_no>.
      IF <lv_name> IS ASSIGNED. er_entity-personnelname = <lv_name>. ENDIF.
      IF <lv_werks> IS ASSIGNED. er_entity-plant = <lv_werks>. ENDIF.

      SELECT SINGLE name1 FROM t001w
        WHERE werks = @er_entity-plant
        INTO @er_entity-plantname.
      RETURN.
    ENDLOOP.

    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        message = 'Personel numarası bulunamadı.'.
  ENDMETHOD.


  METHOD personnelset_get_entityset.
    DATA: lr_per_adi TYPE RANGE OF zppb05-pers_adi,
          lr_per_no  TYPE RANGE OF zppb05-pers_no.

    LOOP AT it_filter_select_options INTO DATA(ls_filter).
      CASE ls_filter-property.
        WHEN 'PersonnelName'.
          LOOP AT ls_filter-select_options INTO DATA(ls_name_option).
            APPEND VALUE #(
              sign   = ls_name_option-sign
              option = ls_name_option-option
              low    = ls_name_option-low
              high   = ls_name_option-high ) TO lr_per_adi.
          ENDLOOP.
        WHEN 'PersonnelNo'.
          LOOP AT ls_filter-select_options INTO DATA(ls_no_option).
            DATA(lv_low)  = CONV zppb05-pers_no( ls_no_option-low ).
            DATA(lv_high) = CONV zppb05-pers_no( ls_no_option-high ).
            IF ls_no_option-option = 'EQ'.
              lv_low = |{ lv_low ALPHA = IN }|.
            ENDIF.
            APPEND VALUE #(
              sign   = ls_no_option-sign
              option = ls_no_option-option
              low    = lv_low
              high   = lv_high ) TO lr_per_no.
          ENDLOOP.
      ENDCASE.
    ENDLOOP.

    IF lr_per_adi IS NOT INITIAL.
      SELECT z~pers_no,
             z~pers_adi,
             z~kullanici,
             z~werks,
             t~name1
        FROM zppb05 AS z
        INNER JOIN t001w AS t
          ON t~werks = z~werks
        WHERE z~pers_adi IN @lr_per_adi
        INTO TABLE @DATA(lt_personnel).
    ENDIF.

    IF lt_personnel IS INITIAL AND lr_per_no IS NOT INITIAL.
      SELECT z~pers_no,
             z~pers_adi,
             z~kullanici,
             z~werks,
             t~name1
        FROM zppb05 AS z
        INNER JOIN t001w AS t
          ON t~werks = z~werks
        WHERE z~pers_no IN @lr_per_no
        INTO TABLE @lt_personnel.
    ENDIF.

    IF lr_per_adi IS INITIAL AND lr_per_no IS INITIAL.
      SELECT z~pers_no,
             z~pers_adi,
             z~kullanici,
             z~werks,
             t~name1
        FROM zppb05 AS z
        INNER JOIN t001w AS t
          ON t~werks = z~werks
        INTO TABLE @lt_personnel.
    ENDIF.

    LOOP AT lt_personnel ASSIGNING FIELD-SYMBOL(<personnel>).
      APPEND VALUE #(
        personnelno   = <personnel>-pers_no
        personnelname = <personnel>-pers_adi
        plant         = <personnel>-werks
        plantname     = <personnel>-name1 ) TO et_entityset.
    ENDLOOP.

    SORT et_entityset BY personnelname personnelno.
  ENDMETHOD.


  method PLATEPHOTOSET_DELETE_ENTITY.
   DATA(lv_photoid) = VALUE zsd_t_fdy_photo-photo_id(
      it_key_tab[ name = 'PhotoId' ]-value OPTIONAL ).
    IF lv_photoid IS INITIAL.
      lv_photoid = VALUE #(
        it_key_tab[ name = 'PHOTOID' ]-value OPTIONAL ).
    ENDIF.

    DELETE FROM zsd_t_fdy_photo WHERE photo_id = @lv_photoid.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING message = 'Silinecek fotoğraf bulunamadı.'.
    ENDIF.
  endmethod.


  METHOD platephotoset_get_entityset.
    DATA lv_lpid TYPE zsd_t_fdy_photo-lpid.

    TYPES: BEGIN OF ty_photo_db,
             photoid    TYPE zsd_t_fdy_photo-photo_id,
             lpid       TYPE zsd_t_fdy_photo-lpid,
             filename   TYPE zsd_t_fdy_photo-filename,
             mimetype   TYPE zsd_t_fdy_photo-mimetype,
             uploadedby TYPE zsd_t_fdy_photo-uploaded_by,
             erdat      TYPE zsd_t_fdy_photo-erdat,
             erzet      TYPE zsd_t_fdy_photo-erzet,
           END OF ty_photo_db.
    DATA: lt_photos TYPE STANDARD TABLE OF ty_photo_db WITH DEFAULT KEY,
          ls_entity LIKE LINE OF et_entityset.

    LOOP AT it_filter_select_options INTO DATA(ls_filter)
         WHERE property = 'LpId'.
      READ TABLE ls_filter-select_options INTO DATA(ls_option) INDEX 1.
      IF sy-subrc = 0.
        lv_lpid = ls_option-low.
      ENDIF.
      EXIT.
    ENDLOOP.

    IF lv_lpid IS INITIAL.
      RETURN.
    ENDIF.

    SELECT photo_id   AS photoid,
           lpid,
           filename,
           mimetype,
           uploaded_by AS uploadedby,
           erdat,
           erzet
      FROM zsd_t_fdy_photo
      WHERE lpid = @lv_lpid
      ORDER BY erdat DESCENDING, erzet DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_photos.

    LOOP AT lt_photos INTO DATA(ls_photo).
      CLEAR ls_entity.
      MOVE-CORRESPONDING ls_photo TO ls_entity.

      IF ls_photo-erdat IS NOT INITIAL.
        CONVERT DATE ls_photo-erdat
                TIME ls_photo-erzet
                INTO TIME STAMP ls_entity-uploaddate
                TIME ZONE 'UTC'.
      ENDIF.
      ls_entity-uploadtime = ls_photo-erzet.

      APPEND ls_entity TO et_entityset.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
