CLASS ltcl_reader DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_amount TYPE p LENGTH 5 DECIMALS 2.

    TYPES:
      "! The table of FLAT_TABLE( ) in tools/golden/generate.py; every column is optional
      BEGIN OF ty_golden,
        id     TYPE i,
        big    TYPE int8,
        ratio  TYPE REF TO f,
        small  TYPE REF TO f,
        flag   TYPE REF TO abap_bool,
        name   TYPE REF TO string,
        raw    TYPE REF TO xstring,
        day    TYPE REF TO d,
        ts     TYPE REF TO int8,
        amount TYPE REF TO ty_amount,
      END OF ty_golden,
      ty_golden_rows TYPE STANDARD TABLE OF ty_golden WITH EMPTY KEY.

    TYPES:
      "! Columns of LOGICAL_TABLE( ) in tools/golden/generate.py
      BEGIN OF ty_logical,
        i8    TYPE i,
        u16   TYPE i,
        ts_ns TYPE int8,
        fixed TYPE x LENGTH 4,
        dec38 TYPE p LENGTH 16 DECIMALS 10,
      END OF ty_logical,
      ty_logical_rows TYPE STANDARD TABLE OF ty_logical WITH EMPTY KEY.

    METHODS flat_round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS optional_round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS gzip_round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS empty_file FOR TESTING RAISING zparq2a_cx_error.
    METHODS golden_plain FOR TESTING RAISING zparq2a_cx_error.
    METHODS golden_gzip FOR TESTING RAISING zparq2a_cx_error.
    METHODS golden_pages_v2 FOR TESTING RAISING zparq2a_cx_error.
    METHODS golden_logical_types FOR TESTING RAISING zparq2a_cx_error.
    METHODS checked_files FOR TESTING RAISING zparq2a_cx_error.
    METHODS some_columns FOR TESTING RAISING zparq2a_cx_error.
    METHODS other_types FOR TESTING RAISING zparq2a_cx_error.
    METHODS sorted_table FOR TESTING RAISING zparq2a_cx_error.
    METHODS duplicate_key FOR TESTING RAISING zparq2a_cx_error.
    METHODS own_compressor FOR TESTING RAISING zparq2a_cx_error.
    METHODS null_in_required FOR TESTING.
    METHODS missing_column FOR TESTING.
    METHODS incompatible_types FOR TESTING.
    METHODS values_out_of_range FOR TESTING RAISING zparq2a_cx_error.
    METHODS unsupported_files FOR TESTING.

    CLASS-METHODS golden
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

    CLASS-METHODS golden_rows
      RETURNING
        VALUE(result) TYPE ty_golden_rows.

    "! Compares two tables of the same line type; data references by the values they point to
    CLASS-METHODS assert_rows
      IMPORTING
        act TYPE STANDARD TABLE
        exp TYPE STANDARD TABLE.

    "! Reading FILE into DATA raises an error whose text matches PATTERN
    CLASS-METHODS assert_fails
      IMPORTING
        file    TYPE xstring
        pattern TYPE csequence
      CHANGING
        data    TYPE ANY TABLE.

ENDCLASS.


CLASS ltcl_reader IMPLEMENTATION.

  METHOD golden.
    DATA(files) = zparq2a_cl_golden=>files( ).
    result = files[ name = name ]-data.
  ENDMETHOD.

  METHOD golden_rows.
    result = VALUE #(
      ( id     = 1
        big    = -1
        ratio  = NEW #( '0.5' )
        small  = NEW #( '1.5' )
        flag   = NEW #( abap_true )
        name   = NEW #( `alpha` )
        raw    = NEW #( CONV xstring( '0001' ) )
        day    = NEW #( '20240229' )
        ts     = NEW #( 0 )
        amount = NEW #( '12.34' ) )
      ( id     = 2
        big    = 0
        small  = NEW #( 2 )
        flag   = NEW #( abap_false )
        name   = NEW #( `beta` )
        raw    = NEW #( )
        ts     = NEW #( 1700000000000000 )
        amount = NEW #( '-0.01' ) )
      ( id     = 3
        big    = 1099511627776
        ratio  = NEW #( '-1.25' )
        day    = NEW #( '19700101' ) )
      ( id     = 4
        big    = zparq2a_cl_bytes=>min_int8
        ratio  = NEW #( '1E300' )
        small  = NEW #( 0 )
        flag   = NEW #( abap_true )
        name   = NEW #( `ä€` )
        raw    = NEW #( CONV xstring( 'FF' ) )
        day    = NEW #( '00010101' )
        ts     = NEW #( -1 )
        amount = NEW #( '9999999.99' ) ) ).
  ENDMETHOD.

  METHOD assert_rows.
    FIELD-SYMBOLS <act> TYPE any.
    FIELD-SYMBOLS <exp> TYPE any.
    FIELD-SYMBOLS <act_value> TYPE any.
    FIELD-SYMBOLS <exp_value> TYPE any.
    DATA act_reference TYPE REF TO data.
    DATA exp_reference TYPE REF TO data.

    cl_abap_unit_assert=>assert_equals( act = lines( act ) exp = lines( exp ) msg = `Number of rows` ).
    DATA(line_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( act ) )->get_table_line_type( ).
    DATA(components) = CAST cl_abap_structdescr( line_type )->get_components( ).
    LOOP AT exp ASSIGNING <exp>.
      DATA(row) = sy-tabix.
      READ TABLE act INDEX row ASSIGNING <act>.
      LOOP AT components INTO DATA(component).
        DATA(where) = |Row { row }, { component-name }|.
        ASSIGN COMPONENT component-name OF STRUCTURE <act> TO <act_value>.
        ASSIGN COMPONENT component-name OF STRUCTURE <exp> TO <exp_value>.
        IF component-type->kind = cl_abap_typedescr=>kind_ref.
          act_reference = <act_value>.
          exp_reference = <exp_value>.
          IF exp_reference IS NOT BOUND.
            cl_abap_unit_assert=>assert_not_bound( act = act_reference msg = |{ where } is not null| ).
            CONTINUE.
          ENDIF.
          cl_abap_unit_assert=>assert_bound( act = act_reference msg = |{ where } is null| ).
          ASSIGN act_reference->* TO <act_value>.
          ASSIGN exp_reference->* TO <exp_value>.
        ENDIF.
        cl_abap_unit_assert=>assert_equals( act = <act_value> exp = <exp_value> msg = where ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD assert_fails.
    TRY.
        NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = data ).
        cl_abap_unit_assert=>fail( |No error, expected { pattern }| ).
      CATCH zparq2a_cx_error INTO DATA(error).
        cl_abap_unit_assert=>assert_char_cp( act = error->get_text( ) exp = pattern ).
    ENDTRY.
  ENDMETHOD.

  METHOD flat_round_trip.
    DATA rows TYPE zparq2a_cl_samples=>ty_flat_rows.

    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = rows ).

    cl_abap_unit_assert=>assert_equals( act = rows exp = zparq2a_cl_samples=>flat_rows( ) ).
  ENDMETHOD.

  METHOD optional_round_trip.
    DATA rows TYPE zparq2a_cl_samples=>ty_optional_rows.

    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>optional_rows( ) ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = rows ).

    assert_rows( act = rows exp = zparq2a_cl_samples=>optional_rows( ) ).
  ENDMETHOD.

  METHOD gzip_round_trip.
    DATA rows TYPE zparq2a_cl_samples=>ty_optional_rows.

    DATA(samples) = zparq2a_cl_samples=>files( ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = samples[ name = `optional_gzip` ]-data IMPORTING data = rows ).

    assert_rows( act = rows exp = zparq2a_cl_samples=>optional_rows( ) ).
  ENDMETHOD.

  METHOD empty_file.
    DATA rows TYPE zparq2a_cl_samples=>ty_flat_rows.

    DATA(file) = NEW zparq2a_cl_writer( )->write( rows ).
    rows = zparq2a_cl_samples=>flat_rows( ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = rows ).

    " the rows that were there before are gone
    cl_abap_unit_assert=>assert_initial( rows ).
  ENDMETHOD.

  METHOD golden_plain.
    DATA rows TYPE ty_golden_rows.

    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_plain_none` ) IMPORTING data = rows ).

    assert_rows( act = rows exp = golden_rows( ) ).
  ENDMETHOD.

  METHOD golden_gzip.
    DATA rows TYPE ty_golden_rows.

    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_plain_gzip` ) IMPORTING data = rows ).

    assert_rows( act = rows exp = golden_rows( ) ).
  ENDMETHOD.

  METHOD golden_pages_v2.
    DATA rows TYPE ty_golden_rows.

    " two row groups, data pages v2 with one value each, GZIP
    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_v2_plain_pages` ) IMPORTING data = rows ).

    assert_rows( act = rows exp = golden_rows( ) ).
  ENDMETHOD.

  METHOD golden_logical_types.
    DATA rows TYPE ty_logical_rows.

    " INTEGER(8, signed), INTEGER(16, unsigned), TIMESTAMP(NANOS), FIXED_LEN_BYTE_ARRAY(4), DECIMAL(38, 10)
    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_logical_plain` ) IMPORTING data = rows ).

    cl_abap_unit_assert=>assert_equals(
      act = rows
      exp = VALUE ty_logical_rows( ( i8 = -128 u16 = 0 ts_ns = 0 fixed = '61626364' dec38 = '1.5' )
                                   ( i8 = 127 u16 = 65535 ts_ns = 1 fixed = '7778797A' dec38 = '-2.25' ) ) ).
  ENDMETHOD.

  METHOD checked_files.
    DATA rows TYPE zparq2a_cl_samples=>ty_optional_rows.

    " pyarrow and DuckDB read these files with the expected values, see tools/writer/check.py
    DATA(checked) = zparq2a_cl_written=>files( ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = checked[ name = `optional_none` ]-data IMPORTING data = rows ).

    assert_rows( act = rows exp = zparq2a_cl_samples=>optional_rows( ) ).
  ENDMETHOD.

  METHOD some_columns.
    TYPES:
      BEGIN OF ty_row,
        name TYPE REF TO string,
        id   TYPE int8,
      END OF ty_row.
    DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    DATA expected LIKE rows.

    " other order, other case, fewer columns
    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_plain_none` ) IMPORTING data = rows ).

    expected = VALUE #( ( name = NEW #( `alpha` ) id = 1 ) ( name = NEW #( `beta` ) id = 2 )
                        ( id = 3 ) ( name = NEW #( `ä€` ) id = 4 ) ).
    assert_rows( act = rows exp = expected ).
  ENDMETHOD.

  METHOD other_types.
    TYPES:
      BEGIN OF ty_row,
        id    TYPE f,
        tiny  TYPE i,
        short TYPE p LENGTH 3 DECIMALS 0,
        price TYPE p LENGTH 4 DECIMALS 1,
        code  TYPE string,
        text  TYPE c LENGTH 16,
        hash  TYPE xstring,
        raw   TYPE x LENGTH 6,
      END OF ty_row.
    DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    " the columns of ZPARQ2A_CL_SAMPLES=>FLAT_ROWS, in other types; RAW only in the last row
    DATA(flat) = zparq2a_cl_samples=>flat_rows( ).
    DATA(file) = NEW zparq2a_cl_writer( )->write( VALUE zparq2a_cl_samples=>ty_flat_rows( ( flat[ 4 ] ) ) ).
    NEW zparq2a_cl_reader( )->read( EXPORTING file = file IMPORTING data = rows ).

    " DECIMAL(7, 3) -0.001 is rounded to one decimal
    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = rows[ 1 ]
      exp = VALUE ty_row( id    = 2147483647
                          tiny  = 128
                          short = 0
                          price = 0
                          code  = `full width`
                          text  = |tab\tand "quotes"|
                          hash  = CONV xstring( 'FFFFFFFF' )
                          raw   = '00FF00FF00FF' ) ).
  ENDMETHOD.

  METHOD sorted_table.
    TYPES:
      BEGIN OF ty_row,
        day TYPE REF TO d,
        big TYPE int8,
      END OF ty_row.
    DATA rows TYPE SORTED TABLE OF ty_row WITH UNIQUE KEY big.
    DATA bigs TYPE string.

    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_plain_none` ) IMPORTING data = rows ).

    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 4 ).
    LOOP AT rows INTO DATA(row).
      bigs = COND #( WHEN sy-tabix = 1 THEN |{ row-big }| ELSE |{ bigs } { row-big }| ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = bigs exp = `-9223372036854775808 -1 0 1099511627776` ).
  ENDMETHOD.

  METHOD duplicate_key.
    TYPES:
      BEGIN OF ty_row,
        flag TYPE REF TO abap_bool,
        id   TYPE i,
      END OF ty_row.
    DATA rows TYPE HASHED TABLE OF ty_row WITH UNIQUE KEY id.
    DATA keyed TYPE HASHED TABLE OF zparq2a_cl_samples=>ty_flat WITH UNIQUE KEY flag.
    NEW zparq2a_cl_reader( )->read( EXPORTING file = golden( `pa_plain_none` ) IMPORTING data = rows ).
    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 4 ).

    " rows 1 and 3 both have flag = abap_true
    assert_fails( EXPORTING file    = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) )
                            pattern = '*same key*'
                  CHANGING  data    = keyed ).
  ENDMETHOD.

  METHOD own_compressor.
    DATA rows TYPE zparq2a_cl_samples=>ty_optional_rows.

    DATA(reader) = NEW zparq2a_cl_reader( ).
    reader->set_compressor( NEW zparq2a_cl_comp_gzip( 9 ) ).
    DATA(samples) = zparq2a_cl_samples=>files( ).
    reader->read( EXPORTING file = samples[ name = `optional_gzip` ]-data IMPORTING data = rows ).

    cl_abap_unit_assert=>assert_equals( act = lines( rows ) exp = 20 ).
  ENDMETHOD.

  METHOD null_in_required.
    TYPES:
      BEGIN OF ty_row,
        ratio TYPE f,
      END OF ty_row.
    DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    assert_fails( EXPORTING file    = golden( `pa_plain_none` )
                            pattern = '*null in row 2*'
                  CHANGING  data    = rows ).
  ENDMETHOD.

  METHOD missing_column.
    TYPES:
      BEGIN OF ty_row,
        id      TYPE i,
        missing TYPE i,
      END OF ty_row.
    DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    assert_fails( EXPORTING file    = golden( `pa_plain_none` )
                            pattern = '*no column missing*'
                  CHANGING  data    = rows ).
  ENDMETHOD.

  METHOD incompatible_types.
    TYPES:
      BEGIN OF ty_text_as_number,
        name TYPE REF TO i,
      END OF ty_text_as_number,
      BEGIN OF ty_binary_as_text,
        raw TYPE REF TO string,
      END OF ty_binary_as_text,
      BEGIN OF ty_decimal_as_integer,
        amount TYPE REF TO int8,
      END OF ty_decimal_as_integer,
      BEGIN OF ty_timestamp_as_date,
        ts TYPE REF TO d,
      END OF ty_timestamp_as_date.
    DATA text_as_number TYPE STANDARD TABLE OF ty_text_as_number WITH EMPTY KEY.
    DATA binary_as_text TYPE STANDARD TABLE OF ty_binary_as_text WITH EMPTY KEY.
    DATA decimal_as_integer TYPE STANDARD TABLE OF ty_decimal_as_integer WITH EMPTY KEY.
    DATA timestamp_as_date TYPE STANDARD TABLE OF ty_timestamp_as_date WITH EMPTY KEY.
    DATA integers TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    DATA(file) = golden( `pa_plain_none` ).
    assert_fails( EXPORTING file = file pattern = '*cannot be read into component NAME*'
                  CHANGING  data = text_as_number ).
    assert_fails( EXPORTING file = file pattern = '*cannot be read into component RAW*'
                  CHANGING  data = binary_as_text ).
    assert_fails( EXPORTING file = file pattern = '*cannot be read into component AMOUNT*'
                  CHANGING  data = decimal_as_integer ).
    assert_fails( EXPORTING file = file pattern = '*cannot be read into component TS*'
                  CHANGING  data = timestamp_as_date ).
    assert_fails( EXPORTING file = file pattern = '*structured line type*'
                  CHANGING  data = integers ).
  ENDMETHOD.

  METHOD values_out_of_range.
    TYPES:
      BEGIN OF ty_short_text,
        code TYPE c LENGTH 3,
      END OF ty_short_text,
      BEGIN OF ty_digits,
        text TYPE n LENGTH 10,
      END OF ty_digits,
      BEGIN OF ty_short_bytes,
        raw TYPE x LENGTH 2,
      END OF ty_short_bytes,
      BEGIN OF ty_small_integer,
        id TYPE int2,
      END OF ty_small_integer,
      BEGIN OF ty_unsigned_64,
        u64 TYPE int8,
      END OF ty_unsigned_64,
      BEGIN OF ty_millis,
        t_ms TYPE t,
      END OF ty_millis.
    DATA short_text TYPE STANDARD TABLE OF ty_short_text WITH EMPTY KEY.
    DATA digits TYPE STANDARD TABLE OF ty_digits WITH EMPTY KEY.
    DATA short_bytes TYPE STANDARD TABLE OF ty_short_bytes WITH EMPTY KEY.
    DATA small_integer TYPE STANDARD TABLE OF ty_small_integer WITH EMPTY KEY.
    DATA unsigned_64 TYPE STANDARD TABLE OF ty_unsigned_64 WITH EMPTY KEY.
    DATA millis TYPE STANDARD TABLE OF ty_millis WITH EMPTY KEY.

    DATA(flat) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    " row 2: '  lead'
    assert_fails( EXPORTING file = flat pattern = '*does not fit component CODE*'
                  CHANGING  data = short_text ).
    assert_fails( EXPORTING file = flat pattern = '*"alpha" does not fit component TEXT*'
                  CHANGING  data = digits ).
    " row 2: no bytes
    assert_fails( EXPORTING file = flat pattern = '*0 bytes do not fit component RAW*'
                  CHANGING  data = short_bytes ).
    " row 3: -2^31
    assert_fails( EXPORTING file = flat pattern = '*row 3: the value does not fit component ID*'
                  CHANGING  data = small_integer ).

    DATA(logical) = golden( `pa_logical_plain` ).
    " 2^64 - 1
    assert_fails( EXPORTING file = logical pattern = '*unsigned 64-bit*'
                  CHANGING  data = unsigned_64 ).
    " 23:59:59.999
    assert_fails( EXPORTING file = logical pattern = '*not a whole second*'
                  CHANGING  data = millis ).
  ENDMETHOD.

  METHOD unsupported_files.
    DATA rows TYPE ty_golden_rows.

    assert_fails( EXPORTING file = golden( `pa_index_crc_bloom` ) pattern = '*dictionary*'
                  CHANGING  data = rows ).
    " Snappy is not built in
    assert_fails( EXPORTING file = golden( `pa_dict_snappy` ) pattern = '*Codec 1*'
                  CHANGING  data = rows ).
    assert_fails( EXPORTING file = golden( `pa_nested` ) pattern = '*Nested*'
                  CHANGING  data = rows ).
    assert_fails( EXPORTING file = CONV #( '0102030405060708' ) pattern = '*'
                  CHANGING  data = rows ).
  ENDMETHOD.

ENDCLASS.
