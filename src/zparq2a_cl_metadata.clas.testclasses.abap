"! Footers and page headers of the golden files in testdata/golden
CLASS ltcl_golden_files DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! Footer bytes of a file
    METHODS footer_of
      IMPORTING
        file          TYPE zparq2a_cl_golden=>ty_file
      RETURNING
        VALUE(result) TYPE xstring.

    "! Dotted paths of the leaf columns, depth first
    METHODS leaf_paths
      IMPORTING
        schema        TYPE zparq2a_if_format=>ty_schema_elements
      RETURNING
        VALUE(result) TYPE string_table
      RAISING
        zparq2a_cx_error.

    "! Adds the leaves below schema[ index ] and moves index past them
    METHODS collect_leaves
      IMPORTING
        schema TYPE zparq2a_if_format=>ty_schema_elements
        prefix TYPE string
      CHANGING
        index  TYPE i
        paths  TYPE string_table
      RAISING
        zparq2a_cx_error.

    METHODS footers_decode FOR TESTING RAISING zparq2a_cx_error.
    METHODS footers_round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS page_headers_round_trip FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_golden_files IMPLEMENTATION.

  METHOD footer_of.
    DATA(start) = xstrlen( file-data ) - 8 - file-footer_length.
    result = file-data+start(file-footer_length).
  ENDMETHOD.

  METHOD leaf_paths.
    DATA(index) = 2.

    WHILE index <= lines( schema ).
      collect_leaves( EXPORTING schema = schema prefix = ``
                      CHANGING  index  = index paths = result ).
    ENDWHILE.
  ENDMETHOD.

  METHOD collect_leaves.
    DATA(element) = REF #( schema[ index ] ).
    DATA(path) = COND string( WHEN prefix IS INITIAL THEN element->name ELSE |{ prefix }.{ element->name }| ).

    index = index + 1.
    IF element->num_children = 0.
      APPEND path TO paths.
      RETURN.
    ENDIF.
    DO element->num_children TIMES.
      IF index > lines( schema ).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Schema ends inside { path }|.
      ENDIF.
      collect_leaves( EXPORTING schema = schema prefix = path
                      CHANGING  index  = index paths = paths ).
    ENDDO.
  ENDMETHOD.

  METHOD footers_decode.
    DATA keys TYPE string_table.

    LOOP AT zparq2a_cl_golden=>files( ) INTO DATA(file).
      DATA(metadata) = zparq2a_cl_metadata=>read_footer( file-data ).

      cl_abap_unit_assert=>assert_equals( act = metadata-num_rows exp = file-num_rows msg = file-name ).
      cl_abap_unit_assert=>assert_equals( act = metadata-created_by exp = file-created_by msg = file-name ).
      cl_abap_unit_assert=>assert_equals( act = lines( metadata-row_groups )
                                          exp = file-num_row_groups
                                          msg = file-name ).
      cl_abap_unit_assert=>assert_equals( act = leaf_paths( metadata-schema )
                                          exp = file-leaf_columns
                                          msg = file-name ).
      CLEAR keys.
      LOOP AT metadata-key_value_metadata INTO DATA(key_value).
        APPEND key_value-key TO keys.
      ENDLOOP.
      SORT keys.
      cl_abap_unit_assert=>assert_equals( act = keys exp = file-key_value_keys msg = file-name ).

      LOOP AT file-columns INTO DATA(expected).
        DATA(group) = REF #( metadata-row_groups[ expected-row_group + 1 ] ).
        DATA(column) = REF #( group->columns[ expected-column + 1 ] ).
        DATA(meta) = REF #( column->meta_data ).
        DATA(msg) = |{ file-name } { expected-row_group } { expected-path }|.

        cl_abap_unit_assert=>assert_true( act = column->has_meta_data msg = msg ).
        cl_abap_unit_assert=>assert_equals(
          act = concat_lines_of( table = meta->path_in_schema sep = `.` )
          exp = expected-path
          msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->type exp = expected-physical_type msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->codec exp = expected-codec msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->num_values exp = expected-num_values msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->data_page_offset exp = expected-data_page_offset msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->dictionary_page_offset
                                            exp = expected-dictionary_page_offset
                                            msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->total_compressed_size
                                            exp = expected-total_compressed_size
                                            msg = msg ).
        cl_abap_unit_assert=>assert_equals( act = meta->has_statistics exp = expected-has_statistics msg = msg ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD footers_round_trip.
    LOOP AT zparq2a_cl_golden=>files( ) INTO DATA(file).
      DATA(footer) = footer_of( file ).
      DATA(metadata) = zparq2a_cl_metadata=>decode_file_metadata( footer ).

      cl_abap_unit_assert=>assert_equals(
        act = zparq2a_cl_metadata=>encode_file_metadata( metadata )
        exp = footer
        msg = |{ file-name }: re-encoded footer differs| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD page_headers_round_trip.
    DATA header TYPE zparq2a_if_format=>ty_page_header.
    DATA length TYPE i.
    DATA original TYPE xstring.
    DATA values TYPE int8.
    DATA pages TYPE i.

    LOOP AT zparq2a_cl_golden=>files( ) INTO DATA(file).
      DATA(metadata) = zparq2a_cl_metadata=>read_footer( file-data ).
      LOOP AT metadata-row_groups INTO DATA(group).
        LOOP AT group-columns INTO DATA(column).
          DATA(meta) = column-meta_data.
          DATA(msg) = |{ file-name } { concat_lines_of( table = meta-path_in_schema sep = `.` ) }|.
          DATA(position) = CONV i( meta-data_page_offset ).
          IF meta-has_dictionary_page_offset = abap_true.
            position = meta-dictionary_page_offset.
          ENDIF.
          DATA(end) = position + CONV i( meta-total_compressed_size ).
          values = 0.

          WHILE position < end.
            zparq2a_cl_metadata=>decode_page_header( EXPORTING data   = file-data
                                                               offset = position
                                                     IMPORTING header = header
                                                               length = length ).
            original = file-data+position(length).
            cl_abap_unit_assert=>assert_equals(
              act = zparq2a_cl_metadata=>encode_page_header( header )
              exp = original
              msg = |{ msg } at { position }: re-encoded page header differs| ).
            IF header-has_data_page_header = abap_true.
              values = values + header-data_page_header-num_values.
            ELSEIF header-has_data_page_header_v2 = abap_true.
              values = values + header-data_page_header_v2-num_values.
            ENDIF.
            position = position + length + header-compressed_page_size.
            pages = pages + 1.
          ENDWHILE.

          cl_abap_unit_assert=>assert_equals( act = position exp = end msg = |{ msg }: pages end| ).
          cl_abap_unit_assert=>assert_equals( act = values exp = meta-num_values msg = |{ msg }: values| ).
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
    cl_abap_unit_assert=>assert_differs( act = pages exp = 0 ).
  ENDMETHOD.

ENDCLASS.


"! Struct details that the golden files do not cover
CLASS ltcl_metadata DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS minimal_file_metadata
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_file_metadata.

    METHODS assert_footer_error
      IMPORTING
        file TYPE xstring
        msg  TYPE string.

    "! Value of a struct field that holds structs nested this deep
    METHODS nested_structs
      IMPORTING
        structs       TYPE i
      RETURNING
        VALUE(result) TYPE xstring.

    METHODS minimal_footer FOR TESTING RAISING zparq2a_cx_error.
    METHODS unknown_fields_kept FOR TESTING RAISING zparq2a_cx_error.
    METHODS logical_types FOR TESTING RAISING zparq2a_cx_error.
    METHODS page_header_defaults FOR TESTING RAISING zparq2a_cx_error.
    METHODS invalid_files FOR TESTING RAISING zparq2a_cx_error.
    METHODS missing_required_field FOR TESTING.
    METHODS deep_unknown_field FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_metadata IMPLEMENTATION.

  METHOD minimal_file_metadata.
    result = VALUE #(
      version  = 2
      num_rows = 0
      schema   = VALUE #( ( name = `schema` num_children = 1 has_num_children = abap_true )
                          ( name = `id` type = zparq2a_if_format=>c_type-int32 has_type = abap_true
                            repetition_type = zparq2a_if_format=>c_repetition-required
                            has_repetition_type = abap_true ) ) ).
  ENDMETHOD.

  METHOD assert_footer_error.
    TRY.
        zparq2a_cl_metadata=>read_footer( file ).
        cl_abap_unit_assert=>fail( |{ msg }: accepted| ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD nested_structs.
    DATA(open) = CONV xstring( '1C' ).
    DATA(stop) = CONV xstring( '00' ).

    DO structs TIMES.
      CONCATENATE result open INTO result IN BYTE MODE.
    ENDDO.
    DO structs + 1 TIMES.
      CONCATENATE result stop INTO result IN BYTE MODE.
    ENDDO.
  ENDMETHOD.

  METHOD deep_unknown_field.
    " FileMetaData is level 1 and the struct in field 8 level 2, so that
    " struct may hold max_depth - 2 nested structs
    DATA(metadata) = minimal_file_metadata( ).
    metadata-unknown = VALUE #( ( id    = 8
                                  type  = zparq2a_if_thrift=>c_type-struct
                                  value = nested_structs( zparq2a_cl_thrift_reader=>max_depth - 2 ) ) ).

    DATA(encoded) = zparq2a_cl_metadata=>encode_file_metadata( metadata ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_metadata=>decode_file_metadata( encoded ) exp = metadata ).

    metadata-unknown[ 1 ]-value = nested_structs( zparq2a_cl_thrift_reader=>max_depth - 1 ).
    encoded = zparq2a_cl_metadata=>encode_file_metadata( metadata ).
    TRY.
        zparq2a_cl_metadata=>decode_file_metadata( encoded ).
        cl_abap_unit_assert=>fail( `unknown field nested too deep: accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD minimal_footer.
    DATA(encoded) = zparq2a_cl_metadata=>encode_file_metadata( minimal_file_metadata( ) ).

    " version 2, schema [ {name schema, num_children 1}, {type INT32, repetition REQUIRED, name id} ],
    " num_rows 0, row_groups []
    cl_abap_unit_assert=>assert_equals(
      act = encoded
      exp = CONV xstring( '1504' && '192C' && '4806736368656D611502' && '00' &&
                          '1502' && '2500' && '18026964' && '00' && '1600' && '190C' && '00' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_metadata=>decode_file_metadata( encoded )
      exp = minimal_file_metadata( ) ).
  ENDMETHOD.

  METHOD unknown_fields_kept.
    DATA(metadata) = minimal_file_metadata( ).

    " an encryption_algorithm (field 8, not modelled) between known fields,
    " and a field from a later format version in a schema element
    metadata-created_by = `test`.
    metadata-has_created_by = abap_true.
    metadata-unknown = VALUE #( ( id = 8 type = zparq2a_if_thrift=>c_type-struct value = '1C0000' )
                                ( id = 9 type = zparq2a_if_thrift=>c_type-binary value = '0101' ) ).
    metadata-schema[ 2 ]-unknown = VALUE #( ( id = 30 type = zparq2a_if_thrift=>c_type-i32 value = '02' ) ).

    DATA(encoded) = zparq2a_cl_metadata=>encode_file_metadata( metadata ).
    DATA(decoded) = zparq2a_cl_metadata=>decode_file_metadata( encoded ).

    cl_abap_unit_assert=>assert_equals( act = decoded exp = metadata ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_metadata=>encode_file_metadata( decoded ) exp = encoded ).
    " created_by (6), then field 8 two ids later, then field 9
    cl_abap_unit_assert=>assert_char_cp( act = |{ encoded }| exp = '*280474657374' && '2C1C0000' && '18010100' ).
  ENDMETHOD.

  METHOD logical_types.
    DATA metadata TYPE zparq2a_if_format=>ty_file_metadata.
    DATA(types) = VALUE zparq2a_if_format=>ty_schema_elements(
      ( name = `s` logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-string ) )
      ( name = `d` logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-decimal scale = 2 precision = 9 ) )
      ( name = `t` logical_type = VALUE #( kind               = zparq2a_if_format=>c_logical_type-time
                                           is_adjusted_to_utc = abap_true
                                           unit = VALUE #( member = zparq2a_if_format=>c_time_unit-nanos ) ) )
      ( name = `ts` logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-timestamp
                                            unit = VALUE #( member = zparq2a_if_format=>c_time_unit-millis ) ) )
      ( name = `i` logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-integer bit_width = 64 ) )
      ( name = `v` logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-variant value = '130100' ) )
      ( name = `n` logical_type = VALUE #( kind = 99 ) ) ).

    LOOP AT types REFERENCE INTO DATA(element).
      element->has_logical_type = abap_true.
    ENDLOOP.
    metadata = minimal_file_metadata( ).
    metadata-schema = types.

    DATA(encoded) = zparq2a_cl_metadata=>encode_file_metadata( metadata ).
    DATA(decoded) = zparq2a_cl_metadata=>decode_file_metadata( encoded ).

    cl_abap_unit_assert=>assert_equals( act = decoded-schema exp = types ).
    " DECIMAL(9, 2): LogicalType { 5: DecimalType { 1: 2, 2: 9 } }
    cl_abap_unit_assert=>assert_char_cp( act = |{ encoded }|
                                         exp = '*0164' && '6C' && '5C' && '1504' && '1512' && '0000*' ).
  ENDMETHOD.

  METHOD page_header_defaults.
    DATA header TYPE zparq2a_if_format=>ty_page_header.
    DATA length TYPE i.

    " DATA_PAGE_V2 without is_compressed, which then defaults to true
    DATA(encoded) = CONV xstring( '1506' && '1514' && '1514' && '5C' && '1502' && '1500' && '1502' && '1500' &&
                                  '1500' && '1500' && '00' && '00' ).

    zparq2a_cl_metadata=>decode_page_header( EXPORTING data   = encoded
                                             IMPORTING header = header
                                                       length = length ).

    cl_abap_unit_assert=>assert_equals( act = length exp = xstrlen( encoded ) ).
    cl_abap_unit_assert=>assert_equals( act = header-type exp = zparq2a_if_format=>c_page_type-data_page_v2 ).
    cl_abap_unit_assert=>assert_equals( act = header-compressed_page_size exp = 10 ).
    cl_abap_unit_assert=>assert_true( header-has_data_page_header_v2 ).
    cl_abap_unit_assert=>assert_equals( act = header-data_page_header_v2-num_values exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = header-data_page_header_v2-num_rows exp = 1 ).
    cl_abap_unit_assert=>assert_true( header-data_page_header_v2-is_compressed ).
    cl_abap_unit_assert=>assert_false( header-data_page_header_v2-has_is_compressed ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_metadata=>encode_page_header( header ) exp = encoded ).
  ENDMETHOD.

  METHOD invalid_files.
    DATA(footer) = zparq2a_cl_metadata=>encode_file_metadata( minimal_file_metadata( ) ).
    DATA(length) = zparq2a_cl_bytes=>int32_to_le( xstrlen( footer ) ).
    DATA(too_long) = zparq2a_cl_bytes=>int32_to_le( xstrlen( footer ) + 1 ).
    DATA(after_footer) = zparq2a_cl_bytes=>int32_to_le( xstrlen( footer ) + 1 ).
    DATA(magic) = CONV xstring( zparq2a_cl_metadata=>magic ).
    DATA file TYPE xstring.
    DATA pare TYPE x LENGTH 4 VALUE '50415245'.
    DATA zeros TYPE x LENGTH 4 VALUE '00000000'.
    DATA zero TYPE x LENGTH 1 VALUE '00'.

    CONCATENATE magic footer length magic INTO file IN BYTE MODE.
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_metadata=>read_footer( file )
                                        exp = minimal_file_metadata( ) ).

    assert_footer_error( file = magic msg = `magic bytes only` ).
    CONCATENATE magic footer length pare INTO file IN BYTE MODE.
    assert_footer_error( file = file msg = `encrypted footer` ).
    CONCATENATE zeros footer length magic INTO file IN BYTE MODE.
    assert_footer_error( file = file msg = `no magic bytes at the start` ).
    CONCATENATE magic footer too_long magic INTO file IN BYTE MODE.
    assert_footer_error( file = file msg = `footer length too large` ).
    CONCATENATE magic footer zeros magic INTO file IN BYTE MODE.
    assert_footer_error( file = file msg = `footer length 0` ).
    CONCATENATE magic footer zero after_footer magic INTO file IN BYTE MODE.
    assert_footer_error( file = file msg = `byte after the file metadata` ).
  ENDMETHOD.

  METHOD missing_required_field.
    " FileMetaData with version and schema only
    TRY.
        zparq2a_cl_metadata=>decode_file_metadata( CONV #( '1504' && '190C' && '00' ) ).
        cl_abap_unit_assert=>fail( `FileMetaData without num_rows accepted` ).
      CATCH zparq2a_cx_error INTO DATA(error).
        cl_abap_unit_assert=>assert_char_cp( act = error->get_text( ) exp = '*field 3 of FileMetaData*' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
