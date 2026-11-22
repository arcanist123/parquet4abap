CLASS ltcl_thrift_writer DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS field_headers FOR TESTING RAISING zparq2a_cx_error.
    METHODS scalar_fields FOR TESTING RAISING zparq2a_cx_error.
    METHODS list_headers FOR TESTING RAISING zparq2a_cx_error.
    METHODS unions FOR TESTING RAISING zparq2a_cx_error.
    METHODS unknown_fields_in_order FOR TESTING RAISING zparq2a_cx_error.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS out_of_range FOR TESTING.

ENDCLASS.


CLASS ltcl_thrift_writer IMPLEMENTATION.

  METHOD field_headers.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    cut->write_struct_begin( ).
    cut->write_i32_field( id = 1 value = 150 ).
    cut->write_i64_field( id = 100 value = -1 ).
    cut->write_i32_field( id = 101 value = 0 ).
    cut->write_i32_field( id = 3 value = 1 ).
    cut->write_i32_field( id = 18 value = 1 ).
    cut->write_struct_end( ).

    " ids up to 15 above the previous one use the short form
    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '15AC02' && '06C80101' && '1500' && '050602' && 'F502' && '00' ) ).
  ENDMETHOD.

  METHOD scalar_fields.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    cut->write_struct_begin( ).
    cut->write_bool_field( id = 1 value = abap_true ).
    cut->write_bool_field( id = 2 value = abap_false ).
    cut->write_i8_field( id = 3 value = -128 ).
    cut->write_i16_field( id = 4 value = -32768 ).
    cut->write_binary_field( id = 5 value = '00FF' ).
    cut->write_string_field( id = 6 value = `abc` ).
    cut->write_struct_end( ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '11' && '12' && '1380' && '14FFFF03' && '180200FF' && '1803616263' && '00' ) ).
  ENDMETHOD.

  METHOD list_headers.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-i32 size = 0 ).
    cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-i32 size = 14 ).
    cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-binary size = 15 ).
    cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-bool_true size = 300 ).
    cut->write_bool( abap_true ).
    cut->write_bool( abap_false ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '05' && 'E5' && 'F80F' && 'F1AC02' && '0102' ) ).
  ENDMETHOD.

  METHOD unions.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    cut->write_union( VALUE #( member = 2 ) ).
    cut->write_union( VALUE #( member = 1 value = '150000' ) ).
    cut->write_union( VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '2C0000' && '1C15000000' && '00' ) ).
  ENDMETHOD.

  METHOD unknown_fields_in_order.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    " unknown fields 2, 5 and 40 around the known fields 1, 3 and 30
    cut->write_struct_begin( VALUE #(
      ( id = 40 type = zparq2a_if_thrift=>c_type-bool_false )
      ( id = 2 type = zparq2a_if_thrift=>c_type-binary value = '0161' )
      ( id = 5 type = zparq2a_if_thrift=>c_type-struct value = '1100' ) ) ).
    cut->write_i32_field( id = 1 value = 1 ).
    cut->write_i32_field( id = 3 value = 3 ).
    cut->write_i32_field( id = 30 value = 30 ).
    cut->write_struct_end( ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->get_result( )
      exp = CONV xstring( '1502' && '180161' && '1506' && '2C1100' && '053C3C' && 'A2' && '00' ) ).
  ENDMETHOD.

  METHOD round_trip.
    DATA unknown TYPE zparq2a_if_thrift=>ty_fields.
    DATA(data) = CONV xstring(
      '11' && '1380' && '14FFFF03' && '17000000000000F03F' && '1D00112233445566778899AABBCCDDEEFF' &&
      '1B0258' && '0201AA0401BB' && '1A250204' && '192C15000000' && '1C1100' && '0CFE01' && '1100' && '00' ).
    DATA(reader) = NEW zparq2a_cl_thrift_reader( data ).

    reader->read_struct_begin( `Test` ).
    WHILE reader->next_field( ).
      APPEND reader->read_unknown( ) TO unknown.
    ENDWHILE.
    reader->read_struct_end( ).

    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).
    cut->write_struct_begin( unknown ).
    cut->write_struct_end( ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_result( ) exp = data ).
  ENDMETHOD.

  METHOD out_of_range.
    DATA(cut) = NEW zparq2a_cl_thrift_writer( ).

    TRY.
        cut->write_i32_field( id = 1 value = 1 ).
        cl_abap_unit_assert=>fail( `field outside a struct accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    cut->write_struct_begin( ).
    TRY.
        cut->write_i32_field( id = 0 value = 1 ).
        cl_abap_unit_assert=>fail( `field id 0 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_i32_field( id = 32768 value = 1 ).
        cl_abap_unit_assert=>fail( `field id 32768 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_i8( 128 ).
        cl_abap_unit_assert=>fail( `128 accepted as i8` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_i16( -32769 ).
        cl_abap_unit_assert=>fail( `-32769 accepted as i16` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-stop size = 1 ).
        cl_abap_unit_assert=>fail( `list of stop elements accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->write_list_begin( element_type = zparq2a_if_thrift=>c_type-i32 size = -1 ).
        cl_abap_unit_assert=>fail( `negative list size accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
