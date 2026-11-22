CLASS ltcl_dec_plain DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS integers FOR TESTING RAISING zparq2a_cx_error.
    METHODS floats FOR TESTING RAISING zparq2a_cx_error.
    METHODS booleans FOR TESTING RAISING zparq2a_cx_error.
    METHODS byte_arrays FOR TESTING RAISING zparq2a_cx_error.
    METHODS fixed_length FOR TESTING RAISING zparq2a_cx_error.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS past_the_end FOR TESTING RAISING zparq2a_cx_error.
    METHODS unsupported_types FOR TESTING.

ENDCLASS.


CLASS ltcl_dec_plain IMPLEMENTATION.

  METHOD integers.
    DATA int32 TYPE i.
    DATA int64 TYPE int8.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = CONV xstring( '01000000FFFFFFFF00000080' )
                                               physical_type = zparq2a_if_format=>c_type-int32 ) ).
    cl_abap_unit_assert=>assert_equals( act = decoder->get_encoding( ) exp = zparq2a_if_format=>c_encoding-plain ).
    decoder->next( IMPORTING value = int32 ).
    cl_abap_unit_assert=>assert_equals( act = int32 exp = 1 ).
    decoder->next( IMPORTING value = int32 ).
    cl_abap_unit_assert=>assert_equals( act = int32 exp = -1 ).
    decoder->next( IMPORTING value = int32 ).
    cl_abap_unit_assert=>assert_equals( act = int32 exp = -2147483648 ).

    decoder = NEW zparq2a_cl_dec_plain( data          = CONV xstring( 'FFFFFFFFFFFFFF7F0000000000010000' )
                                        physical_type = zparq2a_if_format=>c_type-int64 ).
    decoder->next( IMPORTING value = int64 ).
    cl_abap_unit_assert=>assert_equals( act = int64 exp = zparq2a_cl_bytes=>max_int8 ).
    decoder->next( IMPORTING value = int64 ).
    cl_abap_unit_assert=>assert_equals( act = int64 exp = 1099511627776 ).
  ENDMETHOD.

  METHOD floats.
    DATA real TYPE f.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = CONV xstring( '0000C03F000020C1' )
                                               physical_type = zparq2a_if_format=>c_type-float ) ).
    decoder->next( IMPORTING value = real ).
    cl_abap_unit_assert=>assert_equals( act = real exp = '1.5' ).
    decoder->next( IMPORTING value = real ).
    cl_abap_unit_assert=>assert_equals( act = real exp = -10 ).

    decoder = NEW zparq2a_cl_dec_plain( data          = CONV xstring( '000000000000F4BF' )
                                        physical_type = zparq2a_if_format=>c_type-double ).
    decoder->next( IMPORTING value = real ).
    cl_abap_unit_assert=>assert_equals( act = real exp = '-1.25' ).
  ENDMETHOD.

  METHOD booleans.
    DATA flag TYPE abap_bool.
    DATA flags TYPE string.

    " 1, 0, 1, 1, 0, 0, 0, 0, then 1: least significant bit first
    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = CONV xstring( '0D01' )
                                               physical_type = zparq2a_if_format=>c_type-boolean ) ).
    DO 9 TIMES.
      decoder->next( IMPORTING value = flag ).
      flags = flags && COND string( WHEN flag = abap_true THEN `1` ELSE `0` ).
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = flags exp = `101100001` ).
  ENDMETHOD.

  METHOD byte_arrays.
    DATA bytes TYPE xstring.

    DATA(data) = CONV xstring( '020000000001' && '00000000' && '01000000FF' ).
    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = data
                                               physical_type = zparq2a_if_format=>c_type-byte_array ) ).
    decoder->next( IMPORTING value = bytes ).
    cl_abap_unit_assert=>assert_equals( act = bytes exp = CONV xstring( '0001' ) ).
    decoder->next( IMPORTING value = bytes ).
    cl_abap_unit_assert=>assert_initial( bytes ).
    decoder->next( IMPORTING value = bytes ).
    cl_abap_unit_assert=>assert_equals( act = bytes exp = CONV xstring( 'FF' ) ).
  ENDMETHOD.

  METHOD fixed_length.
    DATA bytes TYPE xstring.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = CONV xstring( 'DEADBEEF01020304' )
                                               physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array
                                               type_length   = 4 ) ).
    decoder->next( IMPORTING value = bytes ).
    cl_abap_unit_assert=>assert_equals( act = bytes exp = CONV xstring( 'DEADBEEF' ) ).
    decoder->next( IMPORTING value = bytes ).
    cl_abap_unit_assert=>assert_equals( act = bytes exp = CONV xstring( '01020304' ) ).
  ENDMETHOD.

  METHOD round_trip.
    DATA text TYPE xstring.
    DATA int64 TYPE int8.

    DATA(encoder) = CAST zparq2a_if_encoder( NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-byte_array ) ).
    encoder->put( zparq2a_cl_bytes=>utf8_encode( `Grüße` ) ).
    encoder->put( zparq2a_cl_bytes=>utf8_encode( `` ) ).
    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = encoder->flush( )
                                               physical_type = zparq2a_if_format=>c_type-byte_array ) ).
    decoder->next( IMPORTING value = text ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_bytes=>utf8_decode( text ) exp = `Grüße` ).
    decoder->next( IMPORTING value = text ).
    cl_abap_unit_assert=>assert_initial( text ).

    encoder = NEW zparq2a_cl_enc_plain( zparq2a_if_format=>c_type-int64 ).
    encoder->put( zparq2a_cl_bytes=>min_int8 ).
    encoder->put( -1 ).
    decoder = NEW zparq2a_cl_dec_plain( data          = encoder->flush( )
                                        physical_type = zparq2a_if_format=>c_type-int64 ).
    decoder->next( IMPORTING value = int64 ).
    cl_abap_unit_assert=>assert_equals( act = int64 exp = zparq2a_cl_bytes=>min_int8 ).
    decoder->next( IMPORTING value = int64 ).
    cl_abap_unit_assert=>assert_equals( act = int64 exp = -1 ).
  ENDMETHOD.

  METHOD past_the_end.
    DATA int32 TYPE i.
    DATA bytes TYPE xstring.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_plain(
                                               data          = CONV xstring( '010000' )
                                               physical_type = zparq2a_if_format=>c_type-int32 ) ).
    TRY.
        decoder->next( IMPORTING value = int32 ).
        cl_abap_unit_assert=>fail( `3 bytes were read as INT32` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.

    " the length says 5 bytes, 1 follows
    decoder = NEW zparq2a_cl_dec_plain( data          = CONV xstring( '05000000FF' )
                                        physical_type = zparq2a_if_format=>c_type-byte_array ).
    TRY.
        decoder->next( IMPORTING value = bytes ).
        cl_abap_unit_assert=>fail( `A byte array longer than the data was read` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unsupported_types.
    TRY.
        NEW zparq2a_cl_dec_plain( data = CONV xstring( '00' ) physical_type = zparq2a_if_format=>c_type-int96 ).
        cl_abap_unit_assert=>fail( `INT96 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        NEW zparq2a_cl_dec_plain( data          = CONV xstring( '00' )
                                  physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array ).
        cl_abap_unit_assert=>fail( `FIXED_LEN_BYTE_ARRAY without a length was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
