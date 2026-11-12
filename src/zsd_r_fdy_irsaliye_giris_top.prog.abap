*&---------------------------------------------------------------------*
*& Include ZSD_R_FDY_IRSALIYE_GIRIS_TOP
*&---------------------------------------------------------------------*
TYPE-POOLS: icon.

TABLES: zsd_t_fdy_h.

TYPES: BEGIN OF ty_hdr_ext.
         INCLUDE TYPE zsd_t_fdy_h.
         TYPES:   kunnr_name TYPE name1_gp,
         is_error   TYPE abap_bool,
       END OF ty_hdr_ext.

TYPES: BEGIN OF ty_hdr_grid.
         INCLUDE TYPE zsd_t_fdy_h.
         TYPES:   kunnr_name TYPE name1_gp,
       END OF ty_hdr_grid.

TYPES: BEGIN OF ty_itm_grid.
         INCLUDE TYPE zsd_t_fdy_i.
         TYPES:   zzgrund_txt  TYPE text60,
         zzaltndn_txt TYPE text60,
       END OF ty_itm_grid.

TYPES ty_t_itm_grid TYPE STANDARD TABLE OF ty_itm_grid WITH DEFAULT KEY.

TYPES: BEGIN OF ty_value_text,
         value TYPE char20,
         text  TYPE text60,
       END OF ty_value_text.

TYPES: BEGIN OF ty_tree_out,
         node_text TYPE lvc_value,
         log_uid   TYPE sysuuid_c32,
       END OF ty_tree_out.

TYPES: BEGIN OF ty_image,
         posnr             TYPE zsd_t_fdy_img-posnr,
         gorsel_alani      TYPE zsd_t_fdy_img-gorsel_alani,
         image_b64         TYPE zsd_t_fdy_img-image_b64,
         irsaliye_numarasi TYPE zsd_t_fdy_img-irsaliye_numarasi,
         irsaliye_tarihi   TYPE zsd_t_fdy_img-irsaliye_tarihi,
         ettn              TYPE zsd_t_fdy_img-ettn,
       END OF ty_image.

TYPES ty_t_image TYPE STANDARD TABLE OF ty_image WITH DEFAULT KEY.
TYPES ty_t_html  TYPE STANDARD TABLE OF w3html WITH DEFAULT KEY.

DATA: go_custom_container TYPE REF TO cl_gui_custom_container,
      go_splitter_main    TYPE REF TO cl_gui_easy_splitter_container,
      go_splitter_right   TYPE REF TO cl_gui_splitter_container,
      go_container_left   TYPE REF TO cl_gui_container,
      go_container_rtop   TYPE REF TO cl_gui_container,
      go_container_rmid   TYPE REF TO cl_gui_container,
      go_container_rbot   TYPE REF TO cl_gui_container,
      go_alv_tree         TYPE REF TO cl_gui_alv_tree,
      go_html_viewer      TYPE REF TO cl_gui_html_viewer,
      go_grid_header      TYPE REF TO cl_gui_alv_grid,
      go_grid_items       TYPE REF TO cl_gui_alv_grid,
      go_image_dialog     TYPE REF TO cl_gui_dialogbox_container,
      go_image_popup      TYPE REF TO cl_gui_html_viewer.

DATA: gt_hdr_ext     TYPE STANDARD TABLE OF ty_hdr_ext,
      gt_grid_header TYPE STANDARD TABLE OF ty_hdr_grid,
      gt_grid_items  TYPE STANDARD TABLE OF ty_itm_grid,
      gt_tree_out    TYPE STANDARD TABLE OF ty_tree_out,
      gt_images      TYPE ty_t_image.

DATA: gv_locked_uid       TYPE sysuuid_c32,
      gv_is_readonly      TYPE abap_bool,
      gv_is_sutas         TYPE abap_bool,
      gv_current_image    TYPE zsd_t_fdy_img-posnr,
      gv_current_node_key TYPE lvc_nkey.

CLASS lcl_dialog_handler DEFINITION DEFERRED.
CLASS lcl_html_event_receiver DEFINITION DEFERRED.
CLASS lcl_tree_event_receiver DEFINITION DEFERRED.
CLASS lcl_grid_event_receiver DEFINITION DEFERRED.
CLASS lcl_item_event_receiver DEFINITION DEFERRED.

DATA: go_html_event_receiver TYPE REF TO lcl_html_event_receiver,
      go_tree_event_receiver TYPE REF TO lcl_tree_event_receiver,
      go_grid_event_receiver TYPE REF TO lcl_grid_event_receiver,
      go_item_event_receiver TYPE REF TO lcl_item_event_receiver.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
SELECT-OPTIONS: s_tarih FOR zsd_t_fdy_h-sefer_tarihi DEFAULT sy-datum,
                s_plaka FOR zsd_t_fdy_h-plaka,
                s_kunnr FOR zsd_t_fdy_h-kunnr,
                s_vbeln FOR zsd_t_fdy_h-vbeln_zfis.
SELECTION-SCREEN END OF BLOCK b1.

PARAMETERS p_giris TYPE abap_bool NO-DISPLAY DEFAULT abap_true.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-010.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_gbek RADIOBUTTON GROUP gr1 DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(25) text-011.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_gtum RADIOBUTTON GROUP gr1.
SELECTION-SCREEN COMMENT 4(25) text-012.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b2.
