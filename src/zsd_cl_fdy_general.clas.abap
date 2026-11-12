class ZSD_CL_FDY_GENERAL definition
  public
  final
  create public .

public section.

  types:
    BEGIN OF ty_ozk_raw,
        pckno           TYPE zsd_packhdr-pckno,
        vbeln           TYPE vbap-vbeln,
        item_posnr      TYPE vbap-posnr,
        inco1           TYPE vbkd-inco1,
        inco_list       TYPE zsd_t_inco2_list-inco_list,
        inco_secenek    TYPE zsd_t_inco2_list-inco_secenek,
        additional_text TYPE zsd_t_inco2_list-additional_text,
      END OF ty_ozk_raw .
  types:
    tt_ozk_raw TYPE STANDARD TABLE OF ty_ozk_raw WITH DEFAULT KEY .
  types:
    BEGIN OF ty_inco,
        inco1           TYPE zsd_t_inco2_main-inco1,
        inco_list       TYPE zsd_t_inco2_list-inco_list,
        inco_secenek    TYPE zsd_t_inco2_list-inco_secenek,
        additional_text TYPE zsd_t_inco2_list-additional_text,
      END OF ty_inco .
  types:
      " --- TİP TANIMLARI (Snippet 1'den alındı) ---
    BEGIN OF ty_context,
        username                     TYPE string,
        displayname                  TYPE string,
        warehousenum                 TYPE string,
        warehouse                    TYPE string,
        authtoken                    TYPE uid_acc_code,
        pendinggrcount               TYPE i,
        pendingshipassigncount       TYPE i,
        pendinggicount               TYPE i,
        pendinginvcount              TYPE i,
        pendingreturncount           TYPE i,
        pendingreturnfactoryshipment TYPE i,
      END OF ty_context .
  types:
    tt_context TYPE STANDARD TABLE OF ty_context WITH DEFAULT KEY .
  types:
    BEGIN OF ty_json_item,
        lpid             TYPE string,
        warehousenum     TYPE string,
        platenumber      TYPE string,
        arrivaldate      TYPE string,
        werks            TYPE string,
        deliveryitemid   TYPE string,
        deliverynumber   TYPE string,
        itemnumber       TYPE string,
        material         TYPE string,
        batch            TYPE string,
        expectedquantity TYPE string,
        receivedquantity TYPE string,
        uom              TYPE string,
        sm               TYPE string,
        ebeln            TYPE string,
        ebelp            TYPE string,
        approved         TYPE string,
        editreason       TYPE string,
        sicil            TYPE string,
        urunsicaklik     TYPE string,
        urnskt           TYPE string,
        sktmk            TYPE string,
      END OF ty_json_item .
  types:
    tty_json_item TYPE STANDARD TABLE OF ty_json_item WITH EMPTY KEY .
  types:
      " PUBLIC SECTION içine:
    BEGIN OF ty_photo,
        photoid    TYPE char32,
        lpid       TYPE string,
        filename   TYPE string,
        mimetype   TYPE string,
        uploadedby TYPE string,
*             content    TYPE xstring,
      END OF ty_photo .
  types:
    tt_photo TYPE STANDARD TABLE OF ty_photo WITH EMPTY KEY .

  TYPES: BEGIN OF ts_deep_deliverynote,
           deliverynumber    TYPE string,
           lpid              TYPE string,
           status            TYPE zsd_t_fdy_gr_h-status,
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
         END OF ts_deep_deliverynote.
  TYPES tt_deep_deliverynote
    TYPE STANDARD TABLE OF ts_deep_deliverynote WITH DEFAULT KEY.

  TYPES: BEGIN OF ts_deep_licenseplate,
           lpid            TYPE string,
           warehousenum    TYPE string,
           warehouse       TYPE string,
           platenumber     TYPE string,
           arrivaldate     TYPE zcl_zsd_fdy_gr_mpc_ext=>ts_licenseplate-arrivaldate," dats,
           photocount      TYPE string,
           werks           TYPE werks_d,
           werkstext       TYPE string,
           status          TYPE char1,
           aracsicaklik    TYPE p LENGTH 4 DECIMALS 2,
           todeliverynotes TYPE tt_deep_deliverynote,
         END OF ts_deep_licenseplate.
  TYPES tt_deep_licenseplate
    TYPE STANDARD TABLE OF ts_deep_licenseplate WITH DEFAULT KEY.

    " PUBLIC SECTION
*        !iv_lpid     TYPE string
  methods GET_PHOTO_BINARY
    importing
      !IV_DOCID type STRING
    exporting
      !EV_CONTENT type XSTRING
      !EV_MIMETYPE type STRING .
  methods GET_PHOTO_LIST
    importing
      !IV_LPID type STRING
    exporting
      !ET_PHOTOS type TT_PHOTO .
  methods POST_GOODS_RECEIPT
    importing
      !IT_PARAMETER type /IWBEP/T_MGW_NAME_VALUE_PAIR
    raising
      /IWBEP/CX_MGW_BUSI_EXCEPTION .
  methods SAVE_NOTE_GR
    importing
      !IT_PARAMETER type /IWBEP/T_MGW_NAME_VALUE_PAIR
    raising
      /IWBEP/CX_MGW_BUSI_EXCEPTION .
    " --- METHODS FOR ENTITY SETS (2. Başlık) ---
  methods GET_LICENSE_PLATE_SET
    importing
      !IT_FILTER_SELECT_OPTIONS type /IWBEP/T_MGW_SELECT_OPTION
    exporting
      !ET_DEEP_LICENCEPLATE type TT_DEEP_LICENSEPLATE
    raising
      /IWBEP/CX_MGW_BUSI_EXCEPTION .
  PROTECTED SECTION.
  PRIVATE SECTION.
    " Veri referansı ataması için yardımcı method
    METHODS set_data_to_ref
      IMPORTING
        !is_data TYPE any
      EXPORTING
        !cr_data TYPE REF TO data.

ENDCLASS.



CLASS ZSD_CL_FDY_GENERAL IMPLEMENTATION.


  METHOD get_license_plate_set.
    " --- TİP TANIMLAMALARI (PERFORMANS İÇİN) ---
    TYPES: BEGIN OF ty_photo_count,
             lpid  TYPE zmm_de_bdy_gr_lpid,
             count TYPE int4,
           END OF ty_photo_count.

    TYPES: BEGIN OF ty_t179t,
             prodh TYPE prodh_d,
             vtext TYPE vtext,
           END OF ty_t179t.

    " Yeni Tablo İçin Tip Tanımı (Sadece varlık kontrolü yapacağımız için key yeterli)
    TYPES: BEGIN OF ty_gr_h_check,
             lpid   TYPE zmm_de_bdy_gr_lpid, "ZMM_T_BDY_GR_H key alanı tipiyle aynı olmalı
             status TYPE char1,
           END OF ty_gr_h_check.

    DATA: lt_deep_licenceplate TYPE tt_deep_licenseplate,
          ls_deep_licenceplate TYPE ts_deep_licenseplate,
          lt_deep_deliverynote TYPE tt_deep_deliverynote,
          ls_deep_deliverynote TYPE ts_deep_deliverynote,
          ls_deliveryitem      TYPE zcl_zsd_fdy_gr_mpc_ext=>ts_deliveryitem,
          lt_deliveryitem      TYPE STANDARD TABLE OF
            zcl_zsd_fdy_gr_mpc_ext=>ts_deliveryitem WITH DEFAULT KEY.

    " Hashed Tables (Performansın Kalbi)
    DATA: lt_photo_counts TYPE HASHED TABLE OF ty_photo_count  WITH UNIQUE KEY lpid,
          ls_photo_count  TYPE ty_photo_count,
          lt_t179t        TYPE HASHED TABLE OF ty_t179t        WITH UNIQUE KEY prodh,
          lt_gr_h_cache   TYPE HASHED TABLE OF ty_gr_h_check   WITH UNIQUE KEY lpid. " YENİ EKLENDİ

    DATA: lv_werks       TYPE werks_d,
          lv_eindt       TYPE datum,
          lv_lpid        TYPE zmm_de_bdy_gr_lpid,
          lv_item        TYPE posnr,
          lv_total_matnr TYPE i.

    " --- FİLTRE PARSE ---
    LOOP AT it_filter_select_options INTO DATA(ls_filter).
      CASE ls_filter-property.
        WHEN 'LpId'.
          READ TABLE ls_filter-select_options INTO DATA(ls_so_lp) INDEX 1.
          IF sy-subrc EQ 0.
            lv_lpid = ls_so_lp-low.
          ENDIF.
        WHEN 'Werks'.
          READ TABLE ls_filter-select_options INTO DATA(ls_so_wh) INDEX 1.
          IF sy-subrc EQ 0.
            lv_werks = ls_so_wh-low.
          ENDIF.
        WHEN 'ArrivalDate'.
          READ TABLE ls_filter-select_options INTO DATA(ls_so_ad) INDEX 1.
          IF sy-subrc EQ 0.
            lv_eindt = ls_so_ad-low.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_werks IS INITIAL OR lv_eindt IS INITIAL OR lv_eindt EQ '00000000'.
      RETURN.
    ENDIF.

    " --- 1. REFERANS DATALARI (HASHED TABLE - HIZLI ERİŞİM) ---
    SELECT DISTINCT b~prodh, b~vtext
      FROM t179 AS a
      INNER JOIN t179t AS b ON a~prodh EQ b~prodh
      INTO TABLE @lt_t179t
      WHERE a~stufe EQ '1'
        AND b~spras EQ @sy-langu.

    " --- 2. ANA VERİ ÇEKME (SQL OPTİMİZASYONU) ---
    " 1. ADIM: Tablo yapımızı açıkça tanımlıyoruz (CAST kullanmamak için)
    TYPES: BEGIN OF ty_data,
             ebeln            TYPE ekpo-ebeln,
             ebelp            TYPE ekpo-ebelp,
             mtart            TYPE ekpo-mtart,
             matnr            TYPE ekpo-matnr,
             maktx            TYPE makt-maktx,
             gjahr            TYPE ekbe-gjahr,
             belnr            TYPE ekbe-belnr,
             buzei            TYPE ekbe-buzei,
             menge            TYPE ekbe-menge,
             charg            TYPE ekbe-charg,
             meins            TYPE ekpo-meins,
             prdha            TYPE mara-prdha,
             reswk            TYPE ekko-reswk,
             werks            TYPE ekpo-werks,
             lgort            TYPE ekpo-lgort,
             eindt            TYPE eket-eindt,
             xblnr            TYPE mkpf-xblnr,
             plaka_no         TYPE zflo_m_sefer-plaka_no, " (Kendi veri tipine göre kontrol et)
             lgobe            TYPE t001l-lgobe,
             name1            TYPE t001w-name1,
             sep_adt          TYPE zsdb11-sep_adt,        " <-- Asıl tip
             urn_bar          TYPE zsdb11-urn_bar,        " <-- Asıl tip
             status_completed TYPE char1,
           END OF ty_data.

    DATA: lt_data TYPE TABLE OF ty_data.

    SELECT DISTINCT
              ekpo~ebeln, ekpo~ebelp, ekpo~mtart, ekpo~matnr, makt~maktx,
              ekbe~gjahr, ekbe~belnr, ekbe~buzei, ekbe~menge, ekbe~charg,
              ekpo~meins, mara~prdha, ekko~reswk, ekpo~werks, ekpo~lgort,
              eket~eindt, mkpf~xblnr, sefer~plaka_no, t001l~lgobe, t001w~name1
              " sep_adt ve urn_bar seçilmediği için tablomuzda otomatik boş kalacak
              FROM ekko
              INNER JOIN ekpo ON ekpo~ebeln EQ ekko~ebeln
              INNER JOIN eket ON eket~ebeln EQ ekpo~ebeln AND eket~ebelp EQ ekpo~ebelp
              INNER JOIN ekbe ON ekbe~ebeln EQ eket~ebeln AND ekbe~ebelp EQ eket~ebelp
              INNER JOIN mkpf ON mkpf~mblnr EQ ekbe~belnr AND mkpf~mjahr EQ ekbe~gjahr
              LEFT JOIN mara  ON mara~matnr  EQ ekpo~matnr
              LEFT JOIN makt  ON makt~matnr  EQ mara~matnr  AND makt~spras  EQ @sy-langu
              LEFT JOIN zflo_m_sefer AS sefer ON sefer~sefer_no EQ mkpf~bktxt
              INNER JOIN t001l ON ekpo~werks EQ t001l~werks AND ekpo~lgort EQ t001l~lgort
              INNER JOIN t001w ON ekko~reswk EQ t001w~werks
              INTO CORRESPONDING FIELDS OF TABLE @lt_data
              WHERE ekko~reswk IN ('1100', '1200', '1300', '1400')
                AND ekko~ekorg IN ('1000', '2000', '3000')
                AND ekko~bstyp EQ 'F'
                AND ekpo~werks EQ @lv_werks
                AND ekpo~loekz EQ @space
                AND eket~eindt EQ @lv_eindt
                AND ekbe~bwart IN ('901', '351')
                AND ekbe~vgabe EQ '6'
                AND NOT EXISTS ( SELECT 1 FROM mseg AS ms
                                 WHERE ms~sjahr EQ ekbe~gjahr
                                   AND ms~smbln EQ ekbe~belnr
                                   AND ms~smblp EQ ekbe~buzei
                                   AND ms~bwart IN ( '902', '352' ) )
              %_HINTS MSSQLNT 'TABLE EKKO INDEX([EKKO~W])'.
    IF lt_data IS NOT INITIAL.
      SELECT werks, urun_kod, sepet_ici_adt
        FROM zppb01
        INTO TABLE @DATA(lt_zppb01)
        FOR ALL ENTRIES IN @lt_data
        WHERE werks         EQ @lt_data-werks
          AND urun_kod      EQ @lt_data-matnr
          AND gec_basl      LE @sy-datum
          AND sevk_standart EQ @abap_true.

      " Çekilen palet_urun_adt bilgisini tablomuzdaki sep_adt alanına yazıyoruz
      LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_boral>).
        READ TABLE lt_zppb01 INTO DATA(ls_zppb01)
             WITH KEY werks    = <fs_boral>-werks
                      urun_kod = <fs_boral>-matnr.
        IF sy-subrc EQ 0.
          <fs_boral>-sep_adt = ceil( <fs_boral>-menge / ls_zppb01-sepet_ici_adt ).
        ENDIF.
      ENDLOOP.
    ENDIF.
*    ENDIF.

    SORT lt_data BY ebeln ebelp matnr charg .
    DELETE ADJACENT DUPLICATES FROM lt_data COMPARING ebeln ebelp matnr charg belnr buzei.
    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    SELECT werks,
           urun_kod,
           sepet_ici_adt,
           palet_urun_adt
      FROM zppb01
      INTO TABLE @DATA(lt_standard)
      FOR ALL ENTRIES IN @lt_data
      WHERE werks         EQ @lt_data-werks
        AND urun_kod      EQ @lt_data-matnr
        AND gec_basl      LE @sy-datum
        AND sevk_standart EQ @abap_true.

    " --- 3. STATÜ HESAPLAMA (PARALLEL CURSOR) ---
    SELECT ebeln, ebelp, bwart, menge, charg
      FROM ekbe
      FOR ALL ENTRIES IN @lt_data
      WHERE ebeln EQ @lt_data-ebeln
        AND ebelp EQ @lt_data-ebelp
        AND vgabe EQ '1'
        AND bwart IN ( '101', '102', '911', '912' )
      INTO TABLE @DATA(lt_gr_history).

    SORT lt_data       BY ebeln ebelp charg.
    SORT lt_gr_history BY ebeln ebelp charg.

    DATA: lv_tabix   TYPE sy-tabix,
          lv_net_qty TYPE ekbe-menge.

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      CLEAR lv_net_qty.
      READ TABLE lt_gr_history WITH KEY ebeln = <ls_data>-ebeln
                                        ebelp = <ls_data>-ebelp
                                        charg = <ls_data>-charg
                               TRANSPORTING NO FIELDS
                               BINARY SEARCH.
      IF sy-subrc EQ 0.
        lv_tabix = sy-tabix.
        LOOP AT lt_gr_history INTO DATA(ls_gr) FROM lv_tabix.
          IF ls_gr-ebeln NE <ls_data>-ebeln
             OR ls_gr-ebelp NE <ls_data>-ebelp
             OR ls_gr-charg NE <ls_data>-charg.
            EXIT.
          ENDIF.
          IF ls_gr-bwart EQ '101' OR ls_gr-bwart EQ '911'.
            ADD ls_gr-menge TO lv_net_qty.
          ELSEIF ls_gr-bwart EQ '102' OR ls_gr-bwart EQ '912'.
            SUBTRACT ls_gr-menge FROM lv_net_qty.
          ENDIF.
        ENDLOOP.
        IF lv_net_qty > 0.
          <ls_data>-status_completed = 'X'.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " --- 4. PLAKA DOLDURMA MANTIĞI ---
    SORT lt_data BY eindt xblnr plaka_no DESCENDING.

    DATA: lv_prev_xblnr TYPE mkpf-xblnr,
          lv_curr_plaka TYPE zflo_m_sefer-plaka_no.

    LOOP AT lt_data ASSIGNING <ls_data>.
      IF <ls_data>-xblnr NE lv_prev_xblnr.
        lv_prev_xblnr = <ls_data>-xblnr.
        lv_curr_plaka = <ls_data>-plaka_no.
      ELSE.
        IF <ls_data>-plaka_no IS INITIAL.
          <ls_data>-plaka_no = lv_curr_plaka.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " --- 5. EK DATA TOPLAMA (FOTOĞRAF ve ZMM_T_BDY_GR_H) ---
    TYPES: BEGIN OF ty_lpid,
             lpid TYPE zmm_de_bdy_gr_lpid,
           END OF ty_lpid.
    DATA: lt_lpid_list TYPE STANDARD TABLE OF ty_lpid,
          ls_lpid_item TYPE ty_lpid.

*  DELETE lt_data WHERE plaka_no IS INITIAL.

    " LPID Listesini Hazırla
    LOOP AT lt_data INTO DATA(ls_data_for_lpid).
      ls_lpid_item-lpid = ls_data_for_lpid-plaka_no && ls_data_for_lpid-lgort && ls_data_for_lpid-eindt.
      COLLECT ls_lpid_item INTO lt_lpid_list.
    ENDLOOP.

    IF lt_lpid_list IS NOT INITIAL.

      " A) FOTOĞRAF SAYILARI
      SELECT photo_id, lpid
        FROM zsd_t_fdy_photo
        FOR ALL ENTRIES IN @lt_lpid_list
        WHERE lpid EQ @lt_lpid_list-lpid
        INTO TABLE @DATA(lt_raw_photos).

      LOOP AT lt_raw_photos INTO DATA(ls_raw_photo).
        ls_photo_count-lpid  = ls_raw_photo-lpid.
        ls_photo_count-count = 1.
        COLLECT ls_photo_count INTO lt_photo_counts.
      ENDLOOP.

      " B) GR HEADER TABLOSU KONTROLÜ (YENİ EKLENDİ)
      " Sadece lpid'si eşleşen kayıtları çekip Hashed Table'a atıyoruz.
      SELECT DISTINCT lpid,
                      status
        FROM zsd_t_fdy_gr_h
        FOR ALL ENTRIES IN @lt_lpid_list
        WHERE lpid EQ @lt_lpid_list-lpid
        INTO TABLE @lt_gr_h_cache.
      IF sy-subrc EQ 0.
        SELECT lpid,
               deliverynumber,
               itemnumber,
               material,
               charg,
               expectedquantity,
               receivedquantity,
               uom,
               ebeln,
               ebelp,
               item_status,
               approved,
               editreason,
               urun_sicaklik,
               urnskt,
               sktmk
          FROM zsd_t_fdy_gr_i
          INTO TABLE @DATA(lt_gr_i_cache)
          FOR ALL ENTRIES IN @lt_gr_h_cache
          WHERE lpid EQ @lt_gr_h_cache-lpid.
*        SORT lt_gr_i_cache BY ebeln ebelp.
      ENDIF.

    ENDIF.

    SELECT matnr
      FROM zmm_t_bdy_0002
      INTO TABLE @DATA(lt_porsiyon)
      FOR ALL ENTRIES IN @lt_data
      WHERE matnr EQ @lt_data-matnr.

    " --- 6. DEEP STRUCTURE OLUŞTURMA (GROUPING) ---
    SORT lt_data BY eindt plaka_no xblnr ebeln ebelp.

    LOOP AT lt_data INTO DATA(lgr_data) GROUP BY ( eindt    = lgr_data-eindt
                                                   plaka_no = lgr_data-plaka_no
                                                   lgort    = lgr_data-lgort
                                                   lgobe    = lgr_data-lgobe
                                                   werks    = lgr_data-werks
                                                   name1    = lgr_data-name1 ) ASCENDING.

      CLEAR ls_deep_licenceplate.
      ls_deep_licenceplate-lpid          = lgr_data-plaka_no && lgr_data-lgort && lgr_data-eindt.
      ls_deep_licenceplate-warehousenum  = lgr_data-lgort.
      ls_deep_licenceplate-warehouse     = lgr_data-lgobe.
      ls_deep_licenceplate-platenumber   = lgr_data-plaka_no.
*      ls_deep_licenceplate-arrivaldate   = lgr_data-eindt.
      IF lgr_data-eindt IS NOT INITIAL.
        CONVERT DATE lgr_data-eindt
                TIME '000000'
                INTO TIME STAMP ls_deep_licenceplate-arrivaldate
                TIME ZONE 'UTC'.
      ENDIF.
      ls_deep_licenceplate-werks         = lgr_data-werks.
      ls_deep_licenceplate-werkstext     = lgr_data-name1.
      ls_deep_licenceplate-status        = lgr_data-status_completed.
*    ls_deep_licenceplate-status        = space. "Default boş

      " 1. Kontrol: Fotoğraf Sayısı
      READ TABLE lt_photo_counts INTO ls_photo_count WITH TABLE KEY lpid = ls_deep_licenceplate-lpid.
      IF sy-subrc EQ 0.
        ls_deep_licenceplate-photocount = ls_photo_count-count.
      ENDIF.

      " 2. Kontrol: ZMM_T_BDY_GR_H Tablosunda Var mı? (YENİ)
      READ TABLE lt_gr_h_cache INTO DATA(ls_gr_cache) WITH TABLE KEY lpid = ls_deep_licenceplate-lpid.
      IF sy-subrc EQ 0." AND ls_gr_cache-status NE '1'.
        IF NOT ls_gr_cache-status EQ '0'.
          ls_deep_licenceplate-status = 'X'.
        ENDIF.

      ENDIF.

      REFRESH lt_deep_deliverynote.

      LOOP AT GROUP lgr_data INTO DATA(ls_data_del) GROUP BY ( xblnr = ls_data_del-xblnr ).
        CLEAR ls_deep_deliverynote.
        ls_deep_deliverynote-deliverynumber  = ls_data_del-xblnr.
        ls_deep_deliverynote-lpid            = ls_deep_licenceplate-lpid.
        REFRESH lt_deliveryitem.
        CLEAR lv_item.
        CLEAR lv_total_matnr.

        LOOP AT GROUP ls_data_del INTO DATA(ls_item_data).
          READ TABLE lt_deliveryitem
          ASSIGNING FIELD-SYMBOL(<fs_dlvitem>)
          WITH KEY deliverynumber = ls_data_del-xblnr
                   material       = ls_item_data-matnr
                   ebeln          = ls_item_data-ebeln
                   ebelp          = ls_item_data-ebelp
                   batch          = ls_item_data-charg.
          IF sy-subrc EQ 0.
            ADD ls_item_data-menge   TO <fs_dlvitem>-expectedquantity.
            ADD ls_item_data-sep_adt TO <fs_dlvitem>-sm.
            CONTINUE.
          ELSE.
            ADD 1 TO lv_item.
            CLEAR ls_deliveryitem.
          ENDIF.


          ls_deliveryitem-lpid             = ls_deep_licenceplate-lpid.
          ls_deliveryitem-deliveryitemid   = |{ ls_data_del-xblnr }-{ ls_item_data-ebeln }-{ ls_item_data-ebelp }-{ ls_item_data-charg }|.
          ls_deliveryitem-deliverynumber   = ls_data_del-xblnr.
          ls_deliveryitem-itemnumber       = lv_item.
          ls_deliveryitem-material         = ls_item_data-matnr.
          ls_deliveryitem-batch            = ls_item_data-charg.
          ls_deliveryitem-materialtext     = ls_item_data-maktx.
          ls_deliveryitem-sm               = ls_item_data-sep_adt.
          READ TABLE lt_gr_i_cache INTO DATA(ls_gr_i_cache)
          WITH KEY lpid           = ls_deep_licenceplate-lpid
                   deliverynumber = ls_deliveryitem-deliverynumber
                   material       = ls_deliveryitem-material
                   ebeln          = ls_item_data-ebeln
                   ebelp          = ls_item_data-ebelp
                   charg          = ls_item_data-charg.
          IF sy-subrc EQ 0.
            ls_deliveryitem-approved         = ls_gr_i_cache-approved.
            ls_deliveryitem-editreason       = ls_gr_i_cache-editreason.
            ls_deliveryitem-receivedquantity = ls_gr_i_cache-receivedquantity.
            ls_deliveryitem-urunsicaklik     = ls_gr_i_cache-urun_sicaklik.
*            ls_deliveryitem-urnskt           = ls_gr_i_cache-urnskt.

            IF ls_gr_i_cache-urnskt IS NOT INITIAL AND ls_gr_i_cache-urnskt NE '00000000'.
              CONVERT DATE ls_gr_i_cache-urnskt TIME '000000'
                      INTO TIME STAMP ls_deliveryitem-urnskt
                      TIME ZONE 'UTC'.
            ELSE.
              CLEAR ls_deliveryitem-urnskt.
            ENDIF.


            ls_deliveryitem-sktmk            = ls_gr_i_cache-sktmk.
            IF ls_gr_i_cache-approved = abap_true.
              ls_deliveryitem-localstatus = 'COMPLETED'.
            ELSEIF ls_gr_i_cache-receivedquantity > 0.
              ls_deliveryitem-localstatus = 'IP'.
            ENDIF.
          ELSE.
            ls_deliveryitem-receivedquantity = 0.
          ENDIF.

          ls_deliveryitem-expectedquantity = ls_item_data-menge.
          ls_deliveryitem-ebeln            = ls_item_data-ebeln.
          ls_deliveryitem-ebelp            = ls_item_data-ebelp.
          ls_deliveryitem-status           = ls_deep_licenceplate-status.

          READ TABLE lt_standard
          INTO DATA(ls_standard)
          WITH KEY werks = lgr_data-werks
                   urun_kod = ls_deliveryitem-material.
          IF sy-subrc EQ 0.
            ls_deliveryitem-palet = ls_standard-palet_urun_adt.
            ls_deliveryitem-sepet = ls_standard-sepet_ici_adt.
          ENDIF.

          " EKBE hesaplamasından gelen statüyü burada kullanmak isterseniz:
          " Eğer satır bazlı statü 'X' ise burada bir mantık kurulabilir.
          " Şimdilik Header statüsü önceliklendirildi.

          CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
            EXPORTING
              input          = ls_item_data-meins
              language       = sy-langu
            IMPORTING
              output         = ls_deliveryitem-uom
            EXCEPTIONS
              unit_not_found = 1
              OTHERS         = 2.

          ls_deliveryitem-kategori = ls_item_data-prdha(2).

          READ TABLE lt_t179t INTO DATA(ls_t179) WITH TABLE KEY prodh = ls_deliveryitem-kategori.
          IF sy-subrc EQ 0.
            ls_deliveryitem-kategoritext = ls_t179-vtext.
          ENDIF.

          READ TABLE lt_deliveryitem TRANSPORTING NO FIELDS
          WITH KEY deliverynumber  = ls_deliveryitem-deliverynumber
                   material        = ls_deliveryitem-material.
          IF sy-subrc NE 0.
            ADD 1 TO lv_total_matnr.

            IF ls_item_data-mtart EQ 'ZSTK'.
              ls_deliveryitem-kategori     = '99'.
              ADD 1 TO ls_deep_deliverynote-totaldepozito.
              ls_deliveryitem-kategoritext = 'Depozito'.
              ls_deep_deliverynote-totaldepozitotext = ls_deliveryitem-kategoritext.
              IF ls_deliveryitem-receivedquantity = 0.
                ls_deliveryitem-receivedquantity = ls_deliveryitem-expectedquantity.
              ENDIF.
            ELSE.
              READ TABLE lt_porsiyon
              INTO DATA(ls_porsiyon)
              WITH KEY matnr = ls_deliveryitem-material.
              IF sy-subrc EQ 0.
                ls_deliveryitem-kategori     = '98'.
                ADD 1 TO ls_deep_deliverynote-totalporsiyon.
                ls_deliveryitem-kategoritext = 'Porsiyon'.
                ls_deep_deliverynote-totalporsiyontext = ls_deliveryitem-kategoritext.
              ELSE.
                CASE ls_item_data-prdha(2).
                  WHEN '01'. ADD 1 TO ls_deep_deliverynote-total1. ls_deep_deliverynote-total1text = ls_deliveryitem-kategoritext.
                  WHEN '02'. ADD 1 TO ls_deep_deliverynote-total2. ls_deep_deliverynote-total2text = ls_deliveryitem-kategoritext.
                  WHEN '03'. ADD 1 TO ls_deep_deliverynote-total3. ls_deep_deliverynote-total3text = ls_deliveryitem-kategoritext.
                  WHEN '04'. ADD 1 TO ls_deep_deliverynote-total4. ls_deep_deliverynote-total4text = ls_deliveryitem-kategoritext.
                  WHEN '05'. ADD 1 TO ls_deep_deliverynote-total5. ls_deep_deliverynote-total5text = ls_deliveryitem-kategoritext.
                  WHEN '06'. ADD 1 TO ls_deep_deliverynote-total6. ls_deep_deliverynote-total6text = ls_deliveryitem-kategoritext.
                  WHEN '07'. ADD 1 TO ls_deep_deliverynote-total7. ls_deep_deliverynote-total7text = ls_deliveryitem-kategoritext.
                  WHEN '08'. ADD 1 TO ls_deep_deliverynote-total8. ls_deep_deliverynote-total8text = ls_deliveryitem-kategoritext.
                  WHEN '09'. ADD 1 TO ls_deep_deliverynote-total9. ls_deep_deliverynote-total9text = ls_deliveryitem-kategoritext.
                ENDCASE.
              ENDIF.

            ENDIF.
          ENDIF.
          APPEND ls_deliveryitem TO lt_deliveryitem.
        ENDLOOP.
        SORT lt_deliveryitem BY kategori.
        ls_deep_deliverynote-totalmaterialno = lv_total_matnr.
        ls_deep_deliverynote-toitems         = lt_deliveryitem.
        IF ls_deep_licenceplate-status = 'X'.
          ls_deep_deliverynote-status = 'X'.
        ELSE.
          ls_deep_deliverynote-status = 'X'.
          LOOP AT lt_deliveryitem TRANSPORTING NO FIELDS
               WHERE approved <> abap_true.
            CLEAR ls_deep_deliverynote-status.
            EXIT.
          ENDLOOP.
        ENDIF.
        APPEND ls_deep_deliverynote TO lt_deep_deliverynote.
      ENDLOOP.

      ls_deep_licenceplate-todeliverynotes = lt_deep_deliverynote.
      APPEND ls_deep_licenceplate TO lt_deep_licenceplate.
    ENDLOOP.
    IF lv_lpid NE space.
      DELETE lt_deep_licenceplate WHERE lpid NE lv_lpid.
    ENDIF.
    et_deep_licenceplate = lt_deep_licenceplate.

  ENDMETHOD.


  METHOD GET_PHOTO_BINARY.
    DATA lv_photoid TYPE zsd_t_fdy_photo-photo_id.
    lv_photoid = iv_docid.
    SELECT SINGLE content, mimetype
      FROM zsd_t_fdy_photo
      INTO (@ev_content, @ev_mimetype)
      WHERE photo_id EQ @lv_photoid.
*      WHERE lpid  EQ @iv_lpid
*        AND photo_id EQ @iv_docid.
  ENDMETHOD.


  METHOD GET_PHOTO_LIST.
    " DB tablonun zmm_t_bdy_gr_ph olduğunu varsayıyorum
    SELECT photo_id AS photoid,
           lpid,
           filename,
           mimetype,
           uploaded_by AS uploadedby
      FROM zsd_t_fdy_photo
      WHERE lpid = @iv_lpid
      INTO CORRESPONDING FIELDS OF TABLE @et_photos.
  ENDMETHOD.


  METHOD POST_GOODS_RECEIPT.
    DATA: lt_json_items TYPE tty_json_item,
          ls_head       TYPE zsd_t_fdy_gr_h,
          ls_item       TYPE zsd_t_fdy_gr_i,
          lt_item       TYPE STANDARD TABLE OF zsd_t_fdy_gr_i WITH DEFAULT KEY,
          lv_auto_gr_fm TYPE rs38l_fnam.

    TRY.
        DATA(lv_lpid)        = it_parameter[ name = 'LpId' ]-value.
        DATA(lv_json_string) = it_parameter[ name = 'PendingItemsJson' ]-value.
        DATA(lv_sicil)       = it_parameter[ name = 'UserID' ]-value.
        DATA(lv_status)       = it_parameter[ name = 'Status' ]-value.
        lv_sicil = |{ lv_sicil ALPHA = IN }|.
      CATCH cx_sy_itab_line_not_found.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message = 'Gerekli parametreler eksik.'.
    ENDTRY.

    IF lv_status EQ '0'.
      IF lv_json_string IS INITIAL.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message = 'Gönderilecek kalem bulunamadı.'.
      ENDIF.

      TRY.
          /ui2/cl_json=>deserialize(
            EXPORTING
              json = lv_json_string
            CHANGING
              data = lt_json_items
          ).
        CATCH cx_root.

          RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
            EXPORTING
              message = 'Gönderilecek kalem bulunamadı.'.
      ENDTRY.

      IF lt_json_items IS INITIAL.

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message = 'Gönderilecek kalem bulunamadı.'.

        RETURN.
      ENDIF.


*    DATA(lv_queue_guid) = cl_system_uuid=>create_uuid_x16_static( ).

      LOOP AT lt_json_items ASSIGNING FIELD-SYMBOL(<fs_json_item>).
        IF ls_head IS INITIAL.
          IF strlen( <fs_json_item>-arrivaldate ) < 10.
            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING message = 'ArrivalDate formatı geçersiz.'.
          ENDIF.
          ls_head-arrivaldate = <fs_json_item>-arrivaldate(4)   &&
                                <fs_json_item>-arrivaldate+5(2) &&
                                <fs_json_item>-arrivaldate+8(2).
          ls_head-lpid        = lv_lpid.
          ls_head-werks       = <fs_json_item>-werks.
          ls_head-platenumber = <fs_json_item>-platenumber.
          ls_head-status      = lv_status.
          ls_head-sicil       = lv_sicil.
          ls_head-ernam       = sy-uname.
          ls_head-erdat       = sy-datum.
          ls_head-erzet       = sy-uzeit.
        ENDIF.
        CLEAR ls_item.
        ls_item-lpid             = lv_lpid.
        ls_item-deliverynumber   = <fs_json_item>-deliverynumber.
        ls_item-ebeln            = <fs_json_item>-ebeln.
        ls_item-ebelp            = <fs_json_item>-ebelp.
        ls_item-material         = <fs_json_item>-material.
        ls_item-charg            = <fs_json_item>-batch.
        ls_item-itemnumber       = <fs_json_item>-itemnumber.
        ls_item-expectedquantity = <fs_json_item>-expectedquantity.
        ls_item-receivedquantity = <fs_json_item>-receivedquantity.
        ls_item-sm               = <fs_json_item>-sm.
        ls_item-approved         = <fs_json_item>-approved.
        ls_item-editreason       = <fs_json_item>-editreason.
        ls_item-urun_sicaklik = <fs_json_item>-urunsicaklik.
        ls_item-sktmk          = <fs_json_item>-sktmk.
        IF <fs_json_item>-urnskt IS NOT INITIAL
           AND strlen( <fs_json_item>-urnskt ) >= 10.
          ls_item-urnskt = <fs_json_item>-urnskt(4) && <fs_json_item>-urnskt+5(2) && <fs_json_item>-urnskt+8(2).
        ENDIF.

        ls_item-item_status = lv_status.
        ls_item-ernam       = sy-uname.
        ls_item-erdat       = sy-datum.
        ls_item-erzet       = sy-uzeit.
        CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
          EXPORTING
            input          = <fs_json_item>-uom
          IMPORTING
            output         = ls_item-uom
          EXCEPTIONS
            unit_not_found = 1.
        APPEND ls_item TO lt_item.
      ENDLOOP.
    ELSE.

      SELECT SINGLE * FROM zsd_t_fdy_gr_h
        INTO ls_head
        WHERE lpid = lv_lpid
          AND status = '0'.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message = 'Gönderilecek kalem bulunamadı.'.
        RETURN.
      ELSE.

        ls_head-status = lv_status.

        " Mal Kabul öncesinde kaydedilen araç içi sıcaklığı nota bakarak header'a taşı
        IF lv_status = '1'.

          SELECT SINGLE note
            FROM zsd_t_fdy_note
            INTO @DATA(lv_gr_note)
            WHERE lpid = @lv_lpid.

          IF sy-subrc = 0
             AND lv_gr_note CS '[AIS:'
             AND lv_gr_note CS ']'.

            DATA(lv_ais_value) =
              substring_before(
                val = substring_after(
                        val = lv_gr_note
                        sub = '[AIS:' )
                sub = ']' ).

            CONDENSE lv_ais_value NO-GAPS.
            REPLACE ALL OCCURRENCES OF ',' IN lv_ais_value WITH '.'.

            IF lv_ais_value IS NOT INITIAL.
              TRY.
                  ls_head-arac_ici_derece = CONV #( lv_ais_value ).
                CATCH cx_sy_conversion_no_number
                      cx_sy_conversion_overflow.
                  " Geçersiz sıcaklık nedeniyle Mal Kabul işlemini durdurmuyoruz
              ENDTRY.
            ENDIF.

          ENDIF.

        ENDIF.


      ENDIF.

      SELECT * FROM zsd_t_fdy_gr_i
        INTO TABLE lt_item
        WHERE lpid = lv_lpid
        AND item_status = '0'.
      IF sy-subrc NE 0.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message = 'Gönderilecek kalem bulunamadı.'.
        RETURN.
      ELSE.

        LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_it>).
          <fs_it>-item_status = lv_status.
        ENDLOOP.
      ENDIF.


    ENDIF.




*    DELETE FROM zmm_t_bdy_gr_h WHERE lpid = ls_head-lpid.
*    DELETE FROM zmm_t_bdy_gr_i WHERE lpid = ls_head-lpid.

    MODIFY zsd_t_fdy_gr_h FROM ls_head.
    IF sy-subrc <> 0.
      ROLLBACK WORK.

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Mal girişi yapılamadı sayfaya tekrar giriş yapın!'.
    ENDIF.

    MODIFY zsd_t_fdy_gr_i FROM TABLE @lt_item.
    IF sy-subrc <> 0.
      ROLLBACK WORK.

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message = 'Mal girişi yapılamadı sayfaya tekrar giriş yapın!'.
    ENDIF.

    COMMIT WORK AND WAIT.

    IF lv_status EQ '1'.
      lv_auto_gr_fm = 'ZSD_FM_FDY_AUTO_GR'.
      SELECT SINGLE funcname FROM tfdir
        WHERE funcname = @lv_auto_gr_fm
        INTO @DATA(lv_existing_fm).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING message = 'ZSD_FM_FDY_AUTO_GR fonksiyon modülü bulunamadı.'.
      ENDIF.
      CALL FUNCTION 'ZSD_FM_FDY_AUTO_GR'
        IN BACKGROUND TASK
        AS SEPARATE UNIT
        EXPORTING
          iv_lpid = ls_head-lpid.

      COMMIT WORK. " Background Task'ın tetiklenmesi için commit şarttır.
    ENDIF.
  ENDMETHOD.


  METHOD SAVE_NOTE_GR.


    DATA: lv_lpid  TYPE zsd_t_fdy_note-lpid,
          lv_note  TYPE zsd_t_fdy_note-note,
          lt_notes TYPE STANDARD TABLE OF zsd_t_fdy_note WITH DEFAULT KEY.

    " 1. Parametreleri Al
    " -------------------------------------------------------------
    READ TABLE it_parameter INTO DATA(ls_param) WITH KEY name = 'LpId'.
    IF sy-subrc = 0.
      lv_lpid = ls_param-value.
    ENDIF.

    READ TABLE it_parameter INTO ls_param WITH KEY name = 'Note'.
    IF sy-subrc = 0.
      lv_note = ls_param-value.
    ENDIF.

    IF lv_lpid IS INITIAL.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING message = 'LpId parametresi zorunludur.'.
    ENDIF.

    IF lv_note IS NOT INITIAL.

      DATA: lv_ais_value TYPE string,
            lv_text      TYPE string.

      IF lv_note CA '[' AND lv_note CS ']'.
        lv_ais_value = substring_before( val = substring_after( val = lv_note sub = '[AIS:' ) sub = ']' ).

        lv_text = substring_after( val = lv_note sub = ']' ).
      ELSE.
        CLEAR lv_ais_value.
        lv_text = lv_note.
      ENDIF.

      lv_text = condense( lv_text ).

      APPEND VALUE #(
        lpid  = lv_lpid
        note  = lv_note
        ernam = sy-uname
        erdat = sy-datum
        erzet = sy-uzeit
        aenam = sy-uname
        aedat = sy-datum
        aezet = sy-uzeit
      ) TO lt_notes.
*          " 4. Yeni Listeyi Kaydet
      " -------------------------------------------------------------
      IF lt_notes IS NOT INITIAL.
        MODIFY zsd_t_fdy_note FROM TABLE lt_notes.
        IF sy-subrc <> 0.
          " DB hatası durumunda opsiyonel exception fırlatılabilir
        ENDIF.
      ENDIF.

      IF lv_ais_value IS NOT INITIAL.
        UPDATE zsd_t_fdy_gr_h SET arac_ici_derece = lv_ais_value
        WHERE lpid = lv_lpid.
      ENDIF.
      COMMIT WORK AND WAIT.
    ENDIF.

    " Not: Gateway COMMIT işlemini genellikle otomatik yapar.
    " Gerekirse: COMMIT WORK.

  ENDMETHOD.


  METHOD SET_DATA_TO_REF.
    " Standart copy_data_to_ref mantığının basitleştirilmiş hali
    GET REFERENCE OF is_data INTO cr_data.
  ENDMETHOD.
ENDCLASS.
