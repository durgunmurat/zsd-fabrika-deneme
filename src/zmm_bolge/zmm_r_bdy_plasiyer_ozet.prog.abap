*&---------------------------------------------------------------------*
*& Report ZMM_R_BDY_PLASIYER_OZET
*&---------------------------------------------------------------------*
*& SMT-262 Plasiyer sevkiyat özeti raporu (İşlem kodu: ZBDY11)
*& Seçilen sevkiyat noktası / mal çıkış tarihi için plasiyer bazında
*& toplam, normal ve depozito teslimat sayıları.
*& Seçim mantığı BDY kokpit (ZMM_BDY_KOKPIT, FORM show_plasiyer_f4)
*& ile aynıdır: ZSD_PACKHDR / ZSD_PACKITM, VBUK-WBSTK = 'C'.
*&---------------------------------------------------------------------*
REPORT zmm_r_bdy_plasiyer_ozet.

*----------------------------------------------------------------------*
* Veri tanımları
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_raw,
         kunnr TYPE zsd_packhdr-kunnr,
         name1 TYPE kna1-name1,
         vbeln TYPE zsd_packitm-vbeln,
         delty TYPE zsd_packitm-delty,
       END OF ty_raw,
       tt_raw TYPE STANDARD TABLE OF ty_raw WITH DEFAULT KEY.

TYPES: BEGIN OF ty_out,
         kunnr    TYPE zsd_packhdr-kunnr,
         name1    TYPE kna1-name1,
         toplam   TYPE i,
         normal   TYPE i,
         depozito TYPE i,
       END OF ty_out,
       tt_out TYPE STANDARD TABLE OF ty_out WITH DEFAULT KEY.

CONSTANTS: gc_delty_depozito TYPE zsd_packitm-delty VALUE 'D',
           gc_wbstk_tamam    TYPE vbuk-wbstk        VALUE 'C'.

DATA: gv_vstel TYPE vstel.

*----------------------------------------------------------------------*
* Seçim ekranı
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-b01.
SELECT-OPTIONS: s_vstel FOR gv_vstel OBLIGATORY.
PARAMETERS:     p_datum TYPE sy-datum DEFAULT sy-datum OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.

*----------------------------------------------------------------------*
* Rapor sınıfı
*----------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.
  PRIVATE SECTION.
    DATA: mt_raw TYPE tt_raw,
          mt_out TYPE tt_out.
    METHODS: get_data,
             build_output,
             display.
ENDCLASS.

CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    get_data( ).
    IF mt_raw IS INITIAL.
      MESSAGE 'Seçim kriterlerine uygun mal çıkışı yapılmış teslimat bulunamadı'(m01)
        TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    build_output( ).
    display( ).
  ENDMETHOD.

  METHOD get_data.
    " Kokpit F4 (show_plasiyer_f4) ile aynı kaynak ve filtre:
    " sevkiyat noktası, fiili mal çıkış tarihi, mal çıkışı tamam (WBSTK = C).
    " Depozito ayrımı için DELTY de okunur; filtre uygulanmaz.
    " Klasik Open SQL söz dizimi: yeni programda sabit nokta aritmetiği
    " bayrağına bağlı kalmamak için host değişkeni (@) kullanılmadı.
    SELECT DISTINCT h~kunnr a~name1 i~vbeln i~delty
      INTO TABLE mt_raw
      FROM zsd_packhdr AS h
      INNER JOIN zsd_packitm AS i ON i~pckno = h~pckno
      INNER JOIN vbuk AS v ON v~vbeln = i~vbeln
      LEFT OUTER JOIN kna1 AS a ON a~kunnr = h~kunnr
      WHERE h~vstel     IN s_vstel
        AND h~wadat_ist =  p_datum
        AND v~wbstk     =  gc_wbstk_tamam.
  ENDMETHOD.

  METHOD build_output.
    DATA: lt_dep   TYPE SORTED TABLE OF zsd_packitm-vbeln WITH UNIQUE KEY table_line,
          lt_teslm TYPE tt_raw,
          ls_out   TYPE ty_out.
    FIELD-SYMBOLS: <ls_raw> TYPE ty_raw,
                   <ls_out> TYPE ty_out.

    " 1. En az bir kalemi depozito olan teslimatlar
    LOOP AT mt_raw ASSIGNING <ls_raw> WHERE delty = gc_delty_depozito.
      INSERT <ls_raw>-vbeln INTO TABLE lt_dep.
    ENDLOOP.

    " 2. Plasiyer + teslimat bazında tekilleştir
    lt_teslm = mt_raw.
    SORT lt_teslm BY kunnr vbeln.
    DELETE ADJACENT DUPLICATES FROM lt_teslm COMPARING kunnr vbeln.

    " 3. Plasiyer bazında say (Toplam = Normal + Depozito)
    LOOP AT lt_teslm ASSIGNING <ls_raw>.
      READ TABLE mt_out ASSIGNING <ls_out> WITH KEY kunnr = <ls_raw>-kunnr.
      IF sy-subrc <> 0.
        CLEAR ls_out.
        ls_out-kunnr = <ls_raw>-kunnr.
        ls_out-name1 = <ls_raw>-name1.
        IF ls_out-kunnr IS INITIAL.
          ls_out-name1 = 'Plasiyer atanmamış'(t01).
        ENDIF.
        APPEND ls_out TO mt_out ASSIGNING <ls_out>.
      ENDIF.

      READ TABLE lt_dep TRANSPORTING NO FIELDS WITH TABLE KEY table_line = <ls_raw>-vbeln.
      IF sy-subrc = 0.
        <ls_out>-depozito = <ls_out>-depozito + 1.
      ELSE.
        <ls_out>-normal = <ls_out>-normal + 1.
      ENDIF.
      <ls_out>-toplam = <ls_out>-toplam + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD display.
    DATA: lo_alv     TYPE REF TO cl_salv_table,
          lo_columns TYPE REF TO cl_salv_columns_table,
          lo_column  TYPE REF TO cl_salv_column,
          lo_agg     TYPE REF TO cl_salv_aggregations,
          lx_msg     TYPE REF TO cx_salv_msg,
          lx_nf      TYPE REF TO cx_salv_not_found,
          lx_data    TYPE REF TO cx_salv_data_error,
          lx_exist   TYPE REF TO cx_salv_existing.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = mt_out ).
      CATCH cx_salv_msg INTO lx_msg.
        MESSAGE lx_msg TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " Standart araç çubuğu (Excel'e aktarım dahil)
    lo_alv->get_functions( )->set_all( abap_true ).
    lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

    lo_columns = lo_alv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    TRY.
        lo_column = lo_columns->get_column( 'KUNNR' ).
        lo_column->set_short_text( 'Plasiyer'(c01) ).
        lo_column->set_medium_text( 'Plasiyer'(c01) ).
        lo_column->set_long_text( 'Plasiyer'(c01) ).

        lo_column = lo_columns->get_column( 'NAME1' ).
        lo_column->set_short_text( 'Adı'(c02) ).
        lo_column->set_medium_text( 'Plasiyer adı'(c03) ).
        lo_column->set_long_text( 'Plasiyer adı'(c03) ).

        lo_column = lo_columns->get_column( 'TOPLAM' ).
        lo_column->set_short_text( 'Toplam'(c04) ).
        lo_column->set_medium_text( 'Toplam teslimat'(c05) ).
        lo_column->set_long_text( 'Toplam teslimat'(c05) ).

        lo_column = lo_columns->get_column( 'NORMAL' ).
        lo_column->set_short_text( 'Normal'(c06) ).
        lo_column->set_medium_text( 'Normal teslimat'(c07) ).
        lo_column->set_long_text( 'Normal teslimat'(c07) ).

        lo_column = lo_columns->get_column( 'DEPOZITO' ).
        lo_column->set_short_text( 'Depozito'(c08) ).
        lo_column->set_medium_text( 'Depozito teslimat'(c09) ).
        lo_column->set_long_text( 'Depozito teslimatı'(c10) ).
      CATCH cx_salv_not_found INTO lx_nf.
        MESSAGE lx_nf TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    " Sayı sütunlarında genel toplam
    lo_agg = lo_alv->get_aggregations( ).
    TRY.
        lo_agg->add_aggregation( columnname = 'TOPLAM' ).
        lo_agg->add_aggregation( columnname = 'NORMAL' ).
        lo_agg->add_aggregation( columnname = 'DEPOZITO' ).
      CATCH cx_salv_data_error INTO lx_data.
        MESSAGE lx_data TYPE 'S' DISPLAY LIKE 'E'.
      CATCH cx_salv_not_found INTO lx_nf.
        MESSAGE lx_nf TYPE 'S' DISPLAY LIKE 'E'.
      CATCH cx_salv_existing INTO lx_exist.
        MESSAGE lx_exist TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

    lo_alv->display( ).
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* Ana akış
*----------------------------------------------------------------------*
START-OF-SELECTION.
  DATA(go_report) = NEW lcl_report( ).
  go_report->run( ).
