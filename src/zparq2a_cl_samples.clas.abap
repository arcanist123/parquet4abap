"! <p class="shorttext synchronized">Parquet: sample files of the writer</p>
"! Fixed datasets and the files ZPARQ2A_CL_WRITER makes of them. The tests use
"! them, and tools/writer/check.py has pyarrow and DuckDB read the files and
"! compare the values with its own description of the same datasets.
CLASS zparq2a_cl_samples DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  FOR TESTING.

  PUBLIC SECTION.
    TYPES:
      "! Every supported type, as a required column
      BEGIN OF ty_flat,
        id     TYPE i,
        tiny   TYPE int1,
        short  TYPE int2,
        big    TYPE int8,
        ratio  TYPE f,
        price  TYPE p LENGTH 4 DECIMALS 3,
        amount TYPE p LENGTH 8 DECIMALS 2,
        total  TYPE p LENGTH 16 DECIMALS 4,
        flag   TYPE abap_bool,
        code   TYPE c LENGTH 10,
        digits TYPE n LENGTH 6,
        text   TYPE string,
        raw    TYPE xstring,
        hash   TYPE x LENGTH 4,
        day    TYPE d,
        time   TYPE t,
      END OF ty_flat,
      ty_flat_rows TYPE STANDARD TABLE OF ty_flat WITH EMPTY KEY.

    TYPES ty_amount TYPE p LENGTH 6 DECIMALS 2.

    TYPES:
      "! Optional columns: an unbound reference is null
      BEGIN OF ty_optional,
        id     TYPE i,
        count  TYPE REF TO i,
        name   TYPE REF TO string,
        score  TYPE REF TO f,
        day    TYPE REF TO d,
        flag   TYPE REF TO abap_bool,
        amount TYPE REF TO ty_amount,
      END OF ty_optional,
      ty_optional_rows TYPE STANDARD TABLE OF ty_optional WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_sample,
        name TYPE string,
        data TYPE xstring,
      END OF ty_sample,
      ty_samples TYPE STANDARD TABLE OF ty_sample WITH EMPTY KEY.

    "! Every sample file. Samples whose name ends in _none are uncompressed,
    "! so every toolchain is expected to write the same bytes for them.
    CLASS-METHODS files
      RETURNING
        VALUE(result) TYPE ty_samples
      RAISING
        zparq2a_cx_error.

    "! 4 rows with edge values
    CLASS-METHODS flat_rows
      RETURNING
        VALUE(result) TYPE ty_flat_rows.

    "! 20 rows; nulls in patterns that give both kinds of RLE runs
    CLASS-METHODS optional_rows
      RETURNING
        VALUE(result) TYPE ty_optional_rows.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS zparq2a_cl_samples IMPLEMENTATION.

  METHOD files.
    DATA no_rows TYPE ty_flat_rows.

    DATA(plain) = NEW zparq2a_cl_writer( ).
    APPEND VALUE #( name = `flat_none` data = plain->write( flat_rows( ) ) ) TO result.
    APPEND VALUE #( name = `optional_none` data = plain->write( optional_rows( ) ) ) TO result.
    APPEND VALUE #( name = `empty_none` data = plain->write( no_rows ) ) TO result.

    " GZIP, except for one column
    DATA(gzip) = NEW zparq2a_cl_writer( NEW zparq2a_cl_comp_gzip( ) ).
    gzip->set_column_compressor( column = `ID` compressor = NEW zparq2a_cl_comp_none( ) ).
    APPEND VALUE #( name = `optional_gzip` data = gzip->write( optional_rows( ) ) ) TO result.
  ENDMETHOD.

  METHOD flat_rows.
    result = VALUE #(
      ( id     = 1
        tiny   = 0
        short  = -32768
        big    = zparq2a_cl_bytes=>min_int8
        ratio  = '0.5'
        price  = '1.5'
        amount = '-0.01'
        total  = '999999999999999999999999999.9999'
        flag   = abap_true
        code   = 'ABC'
        digits = '000042'
        text   = `alpha`
        raw    = '0001'
        hash   = 'DEADBEEF'
        day    = '20240229'
        time   = '235959' )
      ( id     = 2
        tiny   = 255
        short  = 32767
        big    = zparq2a_cl_bytes=>max_int8
        ratio  = '-1.25'
        price  = '-9999.999'
        amount = '9999999999999.99'
        total  = '-999999999999999999999999999.9999'
        flag   = abap_false
        code   = '  lead'
        digits = '999999'
        text   = ``
        day    = '19700101'
        time   = '000000' )
      ( id     = -2147483648
        tiny   = 7
        short  = -1
        big    = -1
        ratio  = '1E300'
        price  = 0
        amount = 0
        total  = '0.0001'
        flag   = abap_true
        code   = 'äöü€'
        digits = '000000'
        text   = `Grüße, 世界`
        raw    = 'FF'
        hash   = '01020304'
        day    = '19000101'
        time   = '120000' )
      ( id     = 2147483647
        tiny   = 128
        short  = 0
        big    = 1099511627776
        ratio  = 0
        price  = '-0.001'
        amount = '-9999999999999.99'
        total  = '-0.0001'
        flag   = abap_false
        code   = 'full width'
        digits = '123456'
        text   = |tab\tand "quotes"|
        raw    = '00FF00FF00FF'
        hash   = 'FFFFFFFF'
        day    = '99991231'
        time   = '000001' ) ).
  ENDMETHOD.

  METHOD optional_rows.
    CONSTANTS step TYPE ty_amount VALUE '1.25'.
    DATA row TYPE ty_optional.

    DO 20 TIMES.
      CLEAR row.
      row-id = sy-index.
      IF row-id MOD 3 <> 0.
        row-count = NEW #( row-id * 100 ).
      ENDIF.
      " a run of 12 nulls
      IF row-id < 5 OR row-id > 16.
        row-name = NEW #( |name { row-id }| ).
      ENDIF.
      IF row-id = 20.
        row-score = NEW #( '-0.75' ).
      ENDIF.
      row-day = NEW #( CONV d( '20240101' ) + row-id ).
      row-flag = NEW #( xsdbool( row-id MOD 2 = 0 ) ).
      IF row-id MOD 2 = 1.
        row-amount = NEW #( row-id * step ).
      ENDIF.
      APPEND row TO result.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
