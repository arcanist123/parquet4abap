CLASS ltcl_enc_plain DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS encoding_is_plain FOR TESTING RAISING zparq2a_cx_error.
    METHODS int32 FOR TESTING RAISING zparq2a_cx_error.
    METHODS int64 FOR TESTING RAISING zparq2a_cx_error.
    METHODS float_and_double FOR TESTING RAISING zparq2a_cx_error.
    METHODS booleans FOR TESTING RAISING zparq2a_cx_error.
    METHODS byte_arrays FOR TESTING RAISING zparq2a_cx_error.
    METHODS fixed_length FOR TESTING RAISING zparq2a_cx_error.
    METHODS flush_starts_over FOR TESTING RAISING zparq2a_cx_error.
    METHODS unsupported_types FOR TESTING.

ENDCLASS.


CLASS ltcl_enc_plain IMPLEMENTATION.

  METHOD encoding_is_plain.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int32 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_encoding( ) exp = zparq2a_if_format=>c_encoding-plain ).
  ENDMETHOD.

  METHOD int32.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int32 ).
    cut->put( 1 ).
    cut->put( -1 ).
    cut->put( 2147483647 ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->flush( )
      exp = CONV xstring( '01000000FFFFFFFFFFFFFF7F' ) ).
  ENDMETHOD.

  METHOD int64.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int64 ).
    cut->put( zparq2a_cl_bytes=>min_int8 ).
    cut->put( 1 ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->flush( )
      exp = CONV xstring( '00000000000000800100000000000000' ) ).
  ENDMETHOD.

  METHOD float_and_double.
    DATA cut TYPE REF TO zparq2a_if_encoder.
    DATA one TYPE f VALUE 1.

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-double ).
    cut->put( one ).
    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( '000000000000F03F' ) ).

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-float ).
    cut->put( one ).
    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( '0000803F' ) ).
  ENDMETHOD.

  METHOD booleans.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    " bit-packed, first value in the lowest bit: 1, 0, 1, 1
    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-boolean ).
    cut->put( abap_true ).
    cut->put( abap_false ).
    cut->put( abap_true ).
    cut->put( abap_true ).

    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( '0D' ) ).
  ENDMETHOD.

  METHOD byte_arrays.
    DATA cut TYPE REF TO zparq2a_if_encoder.
    DATA empty TYPE xstring.

    " 4-byte little-endian length, then the bytes
    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-byte_array ).
    cut->put( CONV xstring( 'ABCD' ) ).
    cut->put( empty ).

    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( '02000000ABCD00000000' ) ).
  ENDMETHOD.

  METHOD fixed_length.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_plain( physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array
                                    type_length   = 2 ).
    cut->put( CONV xstring( 'ABCD' ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( 'ABCD' ) ).

    TRY.
        cut->put( CONV xstring( 'AB' ) ).
        cl_abap_unit_assert=>fail( `A value of the wrong length was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD flush_starts_over.
    DATA cut TYPE REF TO zparq2a_if_encoder.
    DATA empty TYPE xstring.

    cut = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int32 ).
    cut->put( 7 ).
    cut->flush( ).
    cut->put( 5 ).

    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = CONV xstring( '05000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->flush( ) exp = empty ).
  ENDMETHOD.

  METHOD unsupported_types.
    TRY.
        NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int96 ).
        cl_abap_unit_assert=>fail( `INT96 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-fixed_len_byte_array ).
        cl_abap_unit_assert=>fail( `FIXED_LEN_BYTE_ARRAY without a length was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
