CLASS ltcl_bit_writer DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS spec_example FOR TESTING RAISING zparq2a_cx_error.
    METHODS alternating_booleans FOR TESTING RAISING zparq2a_cx_error.
    METHODS full_width FOR TESTING RAISING zparq2a_cx_error.
    METHODS padding FOR TESTING RAISING zparq2a_cx_error.
    METHODS zero_width FOR TESTING RAISING zparq2a_cx_error.
    METHODS value_too_large FOR TESTING.
    METHODS negative_value FOR TESTING.
    METHODS width_out_of_range FOR TESTING.

ENDCLASS.


CLASS ltcl_bit_writer IMPLEMENTATION.

  METHOD spec_example.
    " Parquet encodings spec, bit-packed run: 0..7 with bit width 3
    DATA(cut) = NEW zparq2a_cl_bit_writer( ).

    DO 8 TIMES.
      DATA(value) = CONV int8( sy-index - 1 ).
      cut->write( value = value width = 3 ).
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '88C6FA' ) ).
  ENDMETHOD.

  METHOD alternating_booleans.
    " Same vector as TestAppendBoolean in parquet-go (Apache-2.0),
    " encoding/plain/plain_test.go: false, true, false, ... for 100 values
    DATA(cut) = NEW zparq2a_cl_bit_writer( ).

    DO 100 TIMES.
      DATA(value) = CONV int8( ( sy-index - 1 ) MOD 2 ).
      cut->write( value = value width = 1 ).
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( 'AAAAAAAAAAAAAAAAAAAAAAAA0A' ) ).
  ENDMETHOD.

  METHOD full_width.
    DATA(cut) = NEW zparq2a_cl_bit_writer( ).

    cut->write( value = 4294967295 width = 32 ).
    cut->write( value = 1 width = 1 ).
    cut->write( value = 16909060 width = 32 ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( 'FFFFFFFF0906040200' ) ).
  ENDMETHOD.

  METHOD padding.
    DATA(cut) = NEW zparq2a_cl_bit_writer( ).

    cut->write( value = 5 width = 3 ).
    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '05' ) ).

    " reading the result does not end the stream
    cut->write( value = 31 width = 5 ).
    cut->write( value = 1 width = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( 'FD01' ) ).
  ENDMETHOD.

  METHOD zero_width.
    DATA(cut) = NEW zparq2a_cl_bit_writer( ).

    cut->write( value = 0 width = 0 ).
    cl_abap_unit_assert=>assert_initial( cut->get_result( ) ).
  ENDMETHOD.

  METHOD value_too_large.
    TRY.
        NEW zparq2a_cl_bit_writer( )->write( value = 8 width = 3 ).
        cl_abap_unit_assert=>fail( `8 accepted in 3 bits` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD negative_value.
    TRY.
        NEW zparq2a_cl_bit_writer( )->write( value = -1 width = 32 ).
        cl_abap_unit_assert=>fail( `-1 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD width_out_of_range.
    TRY.
        NEW zparq2a_cl_bit_writer( )->write( value = 0 width = 33 ).
        cl_abap_unit_assert=>fail( `width 33 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
