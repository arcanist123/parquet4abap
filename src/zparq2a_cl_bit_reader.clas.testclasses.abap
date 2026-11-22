CLASS ltcl_bit_reader DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS spec_example FOR TESTING RAISING zparq2a_cx_error.
    METHODS alternating_booleans FOR TESTING RAISING zparq2a_cx_error.
    METHODS full_width FOR TESTING RAISING zparq2a_cx_error.
    METHODS round_trip_all_widths FOR TESTING RAISING zparq2a_cx_error.
    METHODS remaining_bits FOR TESTING RAISING zparq2a_cx_error.
    METHODS end_of_data FOR TESTING.
    METHODS width_out_of_range FOR TESTING.

ENDCLASS.


CLASS ltcl_bit_reader IMPLEMENTATION.

  METHOD spec_example.
    DATA(cut) = NEW zparq2a_cl_bit_reader( '88C6FA' ).

    DO 8 TIMES.
      DATA(expected) = sy-index - 1.
      cl_abap_unit_assert=>assert_equals(
        act = cut->read( 3 )
        exp = expected ).
    ENDDO.
  ENDMETHOD.

  METHOD alternating_booleans.
    " Same vector as TestAppendBoolean in parquet-go (Apache-2.0)
    DATA(cut) = NEW zparq2a_cl_bit_reader( 'AAAAAAAAAAAAAAAAAAAAAAAA0A' ).

    DO 100 TIMES.
      DATA(expected) = ( sy-index - 1 ) MOD 2.
      cl_abap_unit_assert=>assert_equals(
        act = cut->read( 1 )
        exp = expected ).
    ENDDO.
  ENDMETHOD.

  METHOD full_width.
    DATA(cut) = NEW zparq2a_cl_bit_reader( 'FFFFFFFF0906040200' ).

    cl_abap_unit_assert=>assert_equals( act = cut->read( 32 ) exp = 4294967295 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read( 1 ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read( 32 ) exp = 16909060 ).
  ENDMETHOD.

  METHOD round_trip_all_widths.
    DATA value TYPE int8.
    DATA width TYPE i.

    DATA(writer) = NEW zparq2a_cl_bit_writer( ).
    WHILE width < 32.
      width = width + 1.
      " the largest value of each width, then 1
      value = zparq2a_cl_bytes=>power_of_two( width ) - 1.
      writer->write( value = value width = width ).
      writer->write( value = 1 width = width ).
    ENDWHILE.

    DATA(cut) = NEW zparq2a_cl_bit_reader( writer->get_result( ) ).
    width = 0.
    WHILE width < 32.
      width = width + 1.
      value = zparq2a_cl_bytes=>power_of_two( width ) - 1.
      cl_abap_unit_assert=>assert_equals( act = cut->read( width ) exp = value msg = |width { width }| ).
      cl_abap_unit_assert=>assert_equals( act = cut->read( width ) exp = 1 msg = |width { width }| ).
    ENDWHILE.
  ENDMETHOD.

  METHOD remaining_bits.
    DATA(cut) = NEW zparq2a_cl_bit_reader( 'FFFF' ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_remaining_bits( ) exp = 16 ).
    cut->read( 3 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_remaining_bits( ) exp = 13 ).
    cut->read( 0 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_remaining_bits( ) exp = 13 ).
  ENDMETHOD.

  METHOD end_of_data.
    DATA(cut) = NEW zparq2a_cl_bit_reader( 'FF' ).

    TRY.
        cut->read( 5 ).
        cut->read( 4 ).
        cl_abap_unit_assert=>fail( `read 9 bits from 1 byte` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD width_out_of_range.
    TRY.
        NEW zparq2a_cl_bit_reader( 'FFFFFFFFFF' )->read( 33 ).
        cl_abap_unit_assert=>fail( `width 33 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
