class ZCL_SD_FDY_DELIVERY_REST definition
  public
  final
  create public .

public section.

  interfaces IF_HTTP_EXTENSION .
protected section.
private section.
ENDCLASS.



CLASS ZCL_SD_FDY_DELIVERY_REST IMPLEMENTATION.


METHOD if_http_extension~handle_request.
  DATA: lv_method   TYPE string,
        lv_json_req TYPE string,
        lv_json_res TYPE string.

  TYPES: BEGIN OF ty_urun,
           urun_kodu TYPE matnr,
           urun_adi  TYPE maktx,
           miktar    TYPE p LENGTH 13 DECIMALS 3,
         END OF ty_urun,
         tt_urun TYPE STANDARD TABLE OF ty_urun WITH DEFAULT KEY.

  TYPES: BEGIN OF ty_gorsel,
           gorsel_alani      TYPE char30,
           gorsel            TYPE string,
           irsaliye_tarihi   TYPE string,
           irsaliye_numarasi TYPE char16,
           ettn              TYPE char36,
           urunler           TYPE tt_urun,
         END OF ty_gorsel.

  TYPES: BEGIN OF ty_request,
           plaka                     TYPE char15,
           sefer_tarihi              TYPE dats,
           rota_no                   TYPE char20,
           teslimat_noktasi_kodu     TYPE kunnr,
           teslim_sonucu             TYPE char20,
           noktaya_varis_tarih_saat  TYPE string,
           teslimat_tamam_tarih_saat TYPE string,
           gorseller                 TYPE STANDARD TABLE OF ty_gorsel WITH DEFAULT KEY,
         END OF ty_request.

  TYPES: BEGIN OF ty_response,
           success TYPE abap_bool,
           message TYPE string,
           log_uid TYPE sysuuid_c32,
         END OF ty_response.

  DATA: ls_request  TYPE ty_request,
        ls_response TYPE ty_response,
        lt_gorsel   TYPE zsd_tt_fdy_gorsel, " (SE11'de güncellediğiniz yapı)
        ls_gorsel   TYPE zsd_s_fdy_gorsel,
        lv_success  TYPE flag,
        lv_message  TYPE string,
        lv_log_uid  TYPE sysuuid_c32,
        lv_sutas    TYPE abap_bool.

  lv_method = server->request->get_header_field( '~request_method' ).
  IF lv_method <> 'POST'.
    server->response->set_status( code = 405 reason = 'Method Not Allowed' ).
    RETURN.
  ENDIF.

  lv_json_req = server->request->get_cdata( ).

  /ui2/cl_json=>deserialize(
    EXPORTING json        = lv_json_req
              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
    CHANGING  data        = ls_request
  ).

  LOOP AT ls_request-gorseller INTO DATA(ls_req_img).
    CLEAR ls_gorsel.
    ls_gorsel-gorsel_alani      = ls_req_img-gorsel_alani.
    ls_gorsel-gorsel_base64     = ls_req_img-gorsel.

    REPLACE ALL OCCURRENCES OF '-' IN ls_req_img-irsaliye_tarihi WITH ''.
    ls_gorsel-irsaliye_tarihi   = ls_req_img-irsaliye_tarihi.
    ls_gorsel-irsaliye_numarasi = ls_req_img-irsaliye_numarasi.
    ls_gorsel-ettn              = ls_req_img-ettn.
    MOVE-CORRESPONDING ls_req_img-urunler TO ls_gorsel-urunler.

    APPEND ls_gorsel TO lt_gorsel.

    IF ls_gorsel-gorsel_alani EQ 'SutasIptalFaturaIrsaliye'.
      lv_sutas = abap_true.
    ENDIF.
  ENDLOOP.

  CALL FUNCTION 'ZSD_FM_FDY_LOG_TESLIMAT'
    EXPORTING
      iv_plaka           = ls_request-plaka
      iv_sefer_tarihi    = ls_request-sefer_tarihi
      iv_rota_no         = ls_request-rota_no
      iv_kunnr           = ls_request-teslimat_noktasi_kodu
      iv_sutas           = lv_sutas
      iv_teslim_sonucu   = ls_request-teslim_sonucu
      iv_varis_tarihsaat = ls_request-noktaya_varis_tarih_saat
      iv_tamam_tarihsaat = ls_request-teslimat_tamam_tarih_saat
    IMPORTING
      ev_success         = lv_success
      ev_message         = lv_message
      ev_log_uid         = lv_log_uid
    TABLES
      it_gorseller       = lt_gorsel.

  IF lv_success = abap_true.
    ls_response-success = abap_true.
    ls_response-message = lv_message.
    ls_response-log_uid = lv_log_uid.
    server->response->set_status( code = 200 reason = 'OK' ).
  ELSE.
    ls_response-success = abap_false.
    ls_response-message = lv_message.
    server->response->set_status( code = 400 reason = 'Bad Request' ).
  ENDIF.

  lv_json_res = /ui2/cl_json=>serialize( data = ls_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  server->response->set_header_field( name = 'Content-Type' value = 'application/json; charset=utf-8' ).
  server->response->set_cdata( lv_json_res ).
ENDMETHOD.
ENDCLASS.
