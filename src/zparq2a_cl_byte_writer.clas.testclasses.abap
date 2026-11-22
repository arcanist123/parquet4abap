CLASS ltcl_byte_writer DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zparq2a_cl_byte_writer.

    METHODS setup.
    METHODS assert_round_trip
      IMPORTING
        value TYPE int8
      RAISING
        zparq2a_cx_error.
    METHODS bytes FOR TESTING RAISING zparq2a_cx_error.
    METHODS fixed_width_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS varints FOR TESTING.
    METHODS byte_out_of_range FOR TESTING.
    METHODS float_overflow FOR TESTING.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_byte_writer IMPLEMENTATION.

  METHOD setup.
    cut = NEW zparq2a_cl_byte_writer( ).
  ENDMETHOD.

  METHOD bytes.
    cl_abap_unit_assert=>assert_initial( cut->get_result( ) ).
    cut->write_byte( 0 ).
    cut->write_byte( 255 ).
    cut->write_bytes( '50415231' ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_result( ) exp = CONV xstring( '00FF50415231' ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_length( ) exp = 6 ).
  ENDMETHOD.

  METHOD fixed_width_values.
    cut->write_int32_le( -2 ).
    cut->write_int64_le( zparq2a_cl_bytes=>min_int8 ).
    cut->write_float( '-1.5' ).
    cut->write_double( '-123.25' ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( 'FEFFFFFF' && '0000000000000080' && '0000C0BF' && '0000000000D05EC0' ) ).
  ENDMETHOD.

  METHOD varints.
    cut->write_varint( 300 ).
    cut->write_varint( -1 ).
    cut->write_zigzag_varint( 42 ).
    cut->write_zigzag_varint( 99 ).
    cut->write_zigzag_varint( -1 ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( 'AC02' && 'FFFFFFFFFFFFFFFFFF01' && '54' && 'C601' && '01' ) ).
  ENDMETHOD.

  METHOD byte_out_of_range.
    TRY.
        cut->write_byte( 256 ).
        cl_abap_unit_assert=>fail( `256 accepted as byte` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_byte( -1 ).
        cl_abap_unit_assert=>fail( `-1 accepted as byte` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( cut->get_result( ) ).
  ENDMETHOD.

  METHOD float_overflow.
    TRY.
        cut->write_float( '1E39' ).
        cl_abap_unit_assert=>fail( `1E39 accepted as FLOAT` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( cut->get_result( ) ).
  ENDMETHOD.

  METHOD round_trip.
    assert_round_trip( 0 ).
    assert_round_trip( 1 ).
    assert_round_trip( -1 ).
    assert_round_trip( 63 ).
    assert_round_trip( -64 ).
    assert_round_trip( 64 ).
    assert_round_trip( 8191 ).
    assert_round_trip( -8192 ).
    assert_round_trip( 2147483647 ).
    assert_round_trip( -2147483648 ).
    assert_round_trip( zparq2a_cl_bytes=>max_int8 ).
    assert_round_trip( zparq2a_cl_bytes=>min_int8 ).
  ENDMETHOD.

  METHOD assert_round_trip.
    DATA(writer) = NEW zparq2a_cl_byte_writer( ).
    writer->write_zigzag_varint( value ).
    writer->write_varint( value ).

    DATA(reader) = NEW zparq2a_cl_byte_reader( writer->get_result( ) ).
    cl_abap_unit_assert=>assert_equals( act = reader->read_zigzag_varint( ) exp = value msg = |zigzag { value }| ).
    cl_abap_unit_assert=>assert_equals( act = reader->read_varint( ) exp = value msg = |varint { value }| ).
    cl_abap_unit_assert=>assert_true( reader->is_at_end( ) ).
  ENDMETHOD.

ENDCLASS.
