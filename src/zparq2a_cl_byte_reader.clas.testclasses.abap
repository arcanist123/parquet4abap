CLASS ltcl_byte_reader DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS assert_varint
      IMPORTING
        bytes TYPE xstring
        value TYPE int8
      RAISING
        zparq2a_cx_error.

    METHODS assert_varint_error
      IMPORTING
        bytes TYPE xstring.

    METHODS bytes_and_position FOR TESTING RAISING zparq2a_cx_error.
    METHODS fixed_width_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS varints FOR TESTING RAISING zparq2a_cx_error.
    METHODS zigzag_varints FOR TESTING RAISING zparq2a_cx_error.
    METHODS invalid_varints FOR TESTING.
    METHODS end_of_data FOR TESTING.
    METHODS negative_length FOR TESTING.
    METHODS empty_input FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_byte_reader IMPLEMENTATION.

  METHOD assert_varint.
    DATA(cut) = NEW zparq2a_cl_byte_reader( bytes ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->read_varint( )
      exp = value
      msg = |decode { bytes }| ).
    cl_abap_unit_assert=>assert_true(
      act = cut->is_at_end( )
      msg = |all of { bytes } consumed| ).
  ENDMETHOD.

  METHOD assert_varint_error.
    TRY.
        NEW zparq2a_cl_byte_reader( bytes )->read_varint( ).
        cl_abap_unit_assert=>fail( |{ bytes } accepted as varint| ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD bytes_and_position.
    DATA(cut) = NEW zparq2a_cl_byte_reader( '0102030405FF' ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_remaining( ) exp = 6 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_byte( ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bytes( 2 ) exp = CONV xstring( '0203' ) ).
    cl_abap_unit_assert=>assert_initial( cut->read_bytes( 0 ) ).
    cut->skip( 2 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_position( ) exp = 5 ).
    cl_abap_unit_assert=>assert_false( cut->is_at_end( ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_byte( ) exp = 255 ).
    cl_abap_unit_assert=>assert_true( cut->is_at_end( ) ).
    cl_abap_unit_assert=>assert_initial( cut->read_bytes( 0 ) ).
  ENDMETHOD.

  METHOD fixed_width_values.
    DATA(cut) = NEW zparq2a_cl_byte_reader(
      CONV #( 'FEFFFFFF' && '0000000000000080' && '0000C0BF' && '0000000000D05EC0' ) ).

    cl_abap_unit_assert=>assert_equals( act = cut->read_int32_le( ) exp = -2 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_int64_le( ) exp = zparq2a_cl_bytes=>min_int8 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_float( ) exp = '-1.5' ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_double( ) exp = '-123.25' ).
    cl_abap_unit_assert=>assert_true( cut->is_at_end( ) ).
  ENDMETHOD.

  METHOD varints.
    assert_varint( bytes = '00' value = 0 ).
    assert_varint( bytes = '7F' value = 127 ).
    assert_varint( bytes = '8001' value = 128 ).
    assert_varint( bytes = 'AC02' value = 300 ).
    assert_varint( bytes = 'FFFFFFFF0F' value = 4294967295 ).
    assert_varint( bytes = 'FFFFFFFFFFFFFFFF7F' value = zparq2a_cl_bytes=>max_int8 ).
    assert_varint( bytes = '80808080808080808001' value = zparq2a_cl_bytes=>min_int8 ).
    assert_varint( bytes = 'FFFFFFFFFFFFFFFFFF01' value = -1 ).
    " a non-minimal encoding still decodes
    assert_varint( bytes = '8100' value = 1 ).
  ENDMETHOD.

  METHOD zigzag_varints.
    " zigzag(42) and zigzag(99), from TestSkipUUIDField in parquet-go (Apache-2.0),
    " encoding/thrift/decode_test.go
    DATA(cut) = NEW zparq2a_cl_byte_reader( '54C60101' ).

    cl_abap_unit_assert=>assert_equals( act = cut->read_zigzag_varint( ) exp = 42 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_zigzag_varint( ) exp = 99 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_zigzag_varint( ) exp = -1 ).
  ENDMETHOD.

  METHOD invalid_varints.
    " 10th group above 1: more than 64 bits
    assert_varint_error( 'FFFFFFFFFFFFFFFFFF02' ).
    " continuation bit set on the 10th byte
    assert_varint_error( 'FFFFFFFFFFFFFFFFFF8100' ).
    " data ends inside the varint
    assert_varint_error( 'FFFF' ).
  ENDMETHOD.

  METHOD end_of_data.
    DATA(cut) = NEW zparq2a_cl_byte_reader( '010203' ).

    TRY.
        cut->read_int32_le( ).
        cl_abap_unit_assert=>fail( `INT32 read from 3 bytes` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    " a failed read does not move the position
    cl_abap_unit_assert=>assert_equals( act = cut->get_position( ) exp = 0 ).
    TRY.
        cut->skip( 4 ).
        cl_abap_unit_assert=>fail( `skipped past the end` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD negative_length.
    TRY.
        NEW zparq2a_cl_byte_reader( '01' )->read_bytes( -1 ).
        cl_abap_unit_assert=>fail( `negative length accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_input.
    DATA nothing TYPE xstring.

    DATA(cut) = NEW zparq2a_cl_byte_reader( nothing ).
    cl_abap_unit_assert=>assert_true( cut->is_at_end( ) ).
    cl_abap_unit_assert=>assert_initial( cut->read_bytes( 0 ) ).
    TRY.
        cut->read_byte( ).
        cl_abap_unit_assert=>fail( `byte read from empty input` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
