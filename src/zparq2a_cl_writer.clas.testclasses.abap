CLASS ltcl_writer DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_page,
        header TYPE zparq2a_if_format=>ty_page_header,
        "! The page as stored, after the header
        body   TYPE xstring,
      END OF ty_page.

    METHODS footer_describes_table FOR TESTING RAISING zparq2a_cx_error.
    METHODS chunks_are_contiguous FOR TESTING RAISING zparq2a_cx_error.
    METHODS required_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS converted_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS optional_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS compressor_per_column FOR TESTING RAISING zparq2a_cx_error.
    METHODS unknown_column_compressor FOR TESTING.
    METHODS empty_table FOR TESTING RAISING zparq2a_cx_error.
    METHODS unsupported_table FOR TESTING.
    METHODS same_bytes_as_checked_files FOR TESTING RAISING zparq2a_cx_error.

    "! Page of the column COLUMN (from 1) in the only row group
    METHODS page
      IMPORTING
        file          TYPE xstring
        column        TYPE i
      RETURNING
        VALUE(result) TYPE ty_page
      RAISING
        zparq2a_cx_error.

    METHODS column_body
      IMPORTING
        file          TYPE xstring
        name          TYPE string
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_writer IMPLEMENTATION.

  METHOD page.
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    DATA(offset) = CONV i( metadata-row_groups[ 1 ]-columns[ column ]-meta_data-data_page_offset ).

    zparq2a_cl_metadata=>decode_page_header(
      EXPORTING
        data   = file
        offset = offset
      IMPORTING
        header = result-header
        length = DATA(length) ).
    offset = offset + length.
    result-body = file+offset(result-header-compressed_page_size).
  ENDMETHOD.

  METHOD column_body.
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    " the root comes first in the schema
    READ TABLE metadata-schema TRANSPORTING NO FIELDS WITH KEY name = name.
    result = page( file = file column = sy-tabix - 1 )-body.
  ENDMETHOD.

  METHOD footer_describes_table.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).

    cl_abap_unit_assert=>assert_equals( act = metadata-version exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = metadata-num_rows exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = metadata-created_by exp = zparq2a_cl_writer=>created_by ).
    cl_abap_unit_assert=>assert_equals( act = lines( metadata-schema ) exp = 17 ).
    cl_abap_unit_assert=>assert_equals(
      act = metadata-schema
      exp = zparq2a_cl_schema=>to_elements( zparq2a_cl_schema=>from_table( zparq2a_cl_samples=>flat_rows( ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( metadata-row_groups ) exp = 1 ).

    DATA(row_group) = metadata-row_groups[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = row_group-num_rows exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = lines( row_group-columns ) exp = 16 ).
    LOOP AT row_group-columns INTO DATA(chunk).
      DATA(element) = metadata-schema[ sy-tabix + 1 ].
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-path_in_schema
                                          exp = VALUE string_table( ( element-name ) ) ).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-type exp = element-type ).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-codec exp = zparq2a_if_format=>c_codec-uncompressed ).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-num_values exp = 4 ).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-encodings
                                          exp = VALUE zparq2a_if_format=>ty_ints(
                                                  ( zparq2a_if_format=>c_encoding-plain ) ) ).
      cl_abap_unit_assert=>assert_true( chunk-meta_data-statistics-has_null_count ).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-statistics-null_count exp = 0 ).
    ENDLOOP.
  ENDMETHOD.

  METHOD chunks_are_contiguous.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    DATA(row_group) = metadata-row_groups[ 1 ].
    DATA(offset) = CONV int8( 4 ).
    DATA total TYPE int8.

    LOOP AT row_group-columns INTO DATA(chunk).
      cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-data_page_offset exp = offset ).
      offset = offset + chunk-meta_data-total_compressed_size.
      total = total + chunk-meta_data-total_compressed_size.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = row_group-file_offset exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = row_group-total_compressed_size exp = total ).
    " uncompressed, both sizes match
    cl_abap_unit_assert=>assert_equals( act = row_group-total_byte_size exp = total ).

    DATA(footer_length) = xstrlen( zparq2a_cl_metadata=>encode_file_metadata( metadata ) ).
    cl_abap_unit_assert=>assert_equals( act = offset + footer_length + 8 exp = xstrlen( file ) ).
  ENDMETHOD.

  METHOD required_values.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    DATA(id) = page( file = file column = 1 ).

    cl_abap_unit_assert=>assert_equals( act = id-header-type exp = zparq2a_if_format=>c_page_type-data_page ).
    cl_abap_unit_assert=>assert_equals( act = id-header-data_page_header-num_values exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = id-header-data_page_header-encoding
                                        exp = zparq2a_if_format=>c_encoding-plain ).
    cl_abap_unit_assert=>assert_equals( act = id-header-uncompressed_page_size exp = 16 ).
    " no definition levels in a required column
    cl_abap_unit_assert=>assert_equals( act = id-body exp = CONV xstring( '010000000200000000000080FFFFFF7F' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `big` )
      exp = CONV xstring( '0000000000000080FFFFFFFFFFFFFF7FFFFFFFFFFFFFFFFF0000000000010000' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `tiny` )
      exp = CONV xstring( '00000000FF0000000700000080000000' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `flag` )
      exp = CONV xstring( '05' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `hash` )
      exp = CONV xstring( 'DEADBEEF0000000001020304FFFFFFFF' ) ).
  ENDMETHOD.

  METHOD converted_values.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).

    " days since 1970-01-01
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `day` )
      exp = CONV xstring( '464D000000000000219CFFFFA0C02C00' ) ).
    " milliseconds since midnight
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `time` )
      exp = CONV xstring( '1858260500000000002E9302E8030000' ) ).
    " unscaled: 1500, -9999999, 0, -1
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `price` )
      exp = CONV xstring( 'DC050000816967FF00000000FFFFFFFF' ) ).
    " 10^31 - 1, -(10^31 - 1), 1, -1 in 13 bytes, big-endian
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `total` )
      exp = CONV xstring( '7E37BE2022C0914B267FFFFFFF' && '81C841DFDD3F6EB4D980000001'
                       && '00000000000000000000000001' && 'FFFFFFFFFFFFFFFFFFFFFFFFFF' ) ).
    " UTF-8; trailing blanks of type c are not part of the value, leading ones are
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `code` )
      exp = CONV xstring( '03000000414243' && '0600000020206C656164' && '09000000C3A4C3B6C3BCE282AC'
                       && '0A00000066756C6C207769647468' ) ).
  ENDMETHOD.

  METHOD optional_values.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>optional_rows( ) ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    DATA(columns) = metadata-row_groups[ 1 ]-columns.

    cl_abap_unit_assert=>assert_equals( act = columns[ 2 ]-meta_data-num_values exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 2 ]-meta_data-statistics-null_count exp = 6 ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 3 ]-meta_data-statistics-null_count exp = 12 ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 4 ]-meta_data-statistics-null_count exp = 19 ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 5 ]-meta_data-statistics-null_count exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 2 ]-meta_data-encodings
                                        exp = VALUE zparq2a_if_format=>ty_ints(
                                                ( zparq2a_if_format=>c_encoding-plain )
                                                ( zparq2a_if_format=>c_encoding-rle ) ) ).

    " length of the levels, levels as one bit-packed run of 3 groups, then the 14 values
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `count` )
      exp = CONV xstring( '04000000' && '07DBB60D'
                       && '64000000C800000090010000F4010000BC02000020030000E80300004C040000'
                       && '140500007805000040060000A40600006C070000D0070000' ) ).
    " levels: a bit-packed group, an RLE run of 8 nulls and another bit-packed group
    cl_abap_unit_assert=>assert_equals(
      act = column_body( file = file name = `name` )
      exp = CONV xstring( '06000000' && '030F1000030F'
                       && '060000006E616D652031060000006E616D652032060000006E616D652033'
                       && '060000006E616D652034070000006E616D65203137070000006E616D65203138'
                       && '070000006E616D65203139070000006E616D65203230' ) ).
  ENDMETHOD.

  METHOD compressor_per_column.
    DATA gzip TYPE REF TO zparq2a_if_compressor.

    gzip = NEW zparq2a_cl_comp_gzip( ).
    DATA(writer) = NEW zparq2a_cl_writer( gzip ).
    writer->set_column_compressor( column = `id` compressor = NEW zparq2a_cl_comp_none( ) ).
    DATA(file) = writer->write( zparq2a_cl_samples=>optional_rows( ) ).
    DATA(plain_file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>optional_rows( ) ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).

    LOOP AT metadata-row_groups[ 1 ]-columns INTO DATA(chunk).
      DATA(column) = sy-tabix.
      DATA(compressed) = page( file = file column = column ).
      DATA(plain) = page( file = plain_file column = column ).
      IF column = 1.
        cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-codec
                                            exp = zparq2a_if_format=>c_codec-uncompressed ).
        cl_abap_unit_assert=>assert_equals( act = compressed-body exp = plain-body ).
      ELSE.
        cl_abap_unit_assert=>assert_equals( act = chunk-meta_data-codec exp = zparq2a_if_format=>c_codec-gzip ).
        cl_abap_unit_assert=>assert_equals( act = gzip->decompress( compressed-body ) exp = plain-body ).
      ENDIF.
      cl_abap_unit_assert=>assert_equals( act = compressed-header-uncompressed_page_size
                                          exp = xstrlen( plain-body ) ).
      cl_abap_unit_assert=>assert_equals( act = compressed-header-compressed_page_size
                                          exp = xstrlen( compressed-body ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD unknown_column_compressor.
    DATA(writer) = NEW zparq2a_cl_writer( ).
    writer->set_column_compressor( column = `missing` compressor = NEW zparq2a_cl_comp_none( ) ).

    TRY.
        writer->write( zparq2a_cl_samples=>optional_rows( ) ).
        cl_abap_unit_assert=>fail( `A compressor for a missing column was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_table.
    DATA rows TYPE zparq2a_cl_samples=>ty_flat_rows.

    DATA(file) = NEW zparq2a_cl_writer( )->write( rows ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).

    cl_abap_unit_assert=>assert_equals( act = metadata-num_rows exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lines( metadata-row_groups[ 1 ]-columns ) exp = 16 ).
    cl_abap_unit_assert=>assert_equals( act = page( file = file column = 1 )-header-data_page_header-num_values
                                        exp = 0 ).
    cl_abap_unit_assert=>assert_initial( page( file = file column = 1 )-body ).
  ENDMETHOD.

  METHOD same_bytes_as_checked_files.
    " pyarrow and DuckDB read these files with the expected values, see tools/writer/check.py
    DATA(samples) = zparq2a_cl_samples=>files( ).
    DATA(checked_files) = zparq2a_cl_written=>files( ).

    cl_abap_unit_assert=>assert_not_initial( checked_files ).
    LOOP AT checked_files INTO DATA(checked).
      cl_abap_unit_assert=>assert_equals( act = samples[ name = checked-name ]-data
                                          exp = checked-data
                                          msg = checked-name ).
    ENDLOOP.
  ENDMETHOD.

  METHOD unsupported_table.
    DATA numbers TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    TRY.
        NEW zparq2a_cl_writer( )->write( numbers ).
        cl_abap_unit_assert=>fail( `A table of integers was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
