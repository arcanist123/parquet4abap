CLASS ltcl_dec_rle DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_values TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    METHODS rle_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS bit_packed_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS mixed_runs FOR TESTING RAISING zparq2a_cx_error.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS short_last_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS past_the_end FOR TESTING RAISING zparq2a_cx_error.
    METHODS invalid_input FOR TESTING.

    "! The first COUNT values
    METHODS decode
      IMPORTING
        bit_width     TYPE i
        data          TYPE xstring
        count         TYPE i
      RETURNING
        VALUE(result) TYPE ty_values
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_dec_rle IMPLEMENTATION.

  METHOD decode.
    DATA value TYPE i.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_rle( bit_width = bit_width data = data ) ).
    DO count TIMES.
      decoder->next( IMPORTING value = value ).
      APPEND value TO result.
    ENDDO.
  ENDMETHOD.

  METHOD rle_run.
    " 10 times 1 with width 1; 3 times 300 with width 9 (2 bytes)
    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 1 data = CONV #( '1401' ) count = 10 )
                                        exp = VALUE ty_values( ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 )
                                                               ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 9 data = CONV #( '062C01' ) count = 3 )
                                        exp = VALUE ty_values( ( 300 ) ( 300 ) ( 300 ) ) ).
    " width 0: the run has no value bytes
    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 0 data = CONV #( '04' ) count = 2 )
                                        exp = VALUE ty_values( ( 0 ) ( 0 ) ) ).
    cl_abap_unit_assert=>assert_equals(
      act = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_rle( bit_width = 1 data = CONV #( '' ) ) )->get_encoding( )
      exp = zparq2a_if_format=>c_encoding-rle ).
  ENDMETHOD.

  METHOD bit_packed_run.
    " one group of 0..7 with width 3: 0b10001000 0b11000110 0b11111010
    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 3 data = CONV #( '0388C6FA' ) count = 8 )
                                        exp = VALUE ty_values( ( 0 ) ( 1 ) ( 2 ) ( 3 ) ( 4 ) ( 5 ) ( 6 ) ( 7 ) ) ).
  ENDMETHOD.

  METHOD mixed_runs.
    " the definition levels of the column name in ZPARQ2A_CL_SAMPLES=>OPTIONAL_ROWS:
    " a bit-packed group, an RLE run of 8 nulls and another bit-packed group
    cl_abap_unit_assert=>assert_equals(
      act = decode( bit_width = 1 data = CONV #( '030F1000030F' ) count = 20 )
      exp = VALUE ty_values( ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 0 ) ( 0 ) ( 0 ) ( 0 ) ( 0 ) ( 0 )
                             ( 0 ) ( 0 ) ( 0 ) ( 0 ) ( 0 ) ( 0 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ) ).
  ENDMETHOD.

  METHOD round_trip.
    DATA values TYPE ty_values.

    DO 100 TIMES.
      " runs of different lengths, and values that change every time
      APPEND COND i( WHEN sy-index < 40 THEN 5
                        WHEN sy-index < 60 THEN sy-index MOD 7
                        ELSE 2 ) TO values.
    ENDDO.
    DATA(encoder) = CAST zparq2a_if_encoder( NEW zparq2a_cl_enc_rle( 3 ) ).
    LOOP AT values INTO DATA(value).
      encoder->put( value ).
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 3 data = encoder->flush( ) count = 100 )
                                        exp = values ).
  ENDMETHOD.

  METHOD short_last_run.
    " two groups announced, but only the bytes of the values written: 1, 1, 0 with width 2
    cl_abap_unit_assert=>assert_equals( act = decode( bit_width = 2 data = CONV #( '0505' ) count = 3 )
                                        exp = VALUE ty_values( ( 1 ) ( 1 ) ( 0 ) ) ).
  ENDMETHOD.

  METHOD past_the_end.
    DATA value TYPE i.

    DATA(decoder) = CAST zparq2a_if_decoder( NEW zparq2a_cl_dec_rle( bit_width = 1 data = CONV #( '0401' ) ) ).
    decoder->next( IMPORTING value = value ).
    decoder->next( IMPORTING value = value ).
    TRY.
        decoder->next( IMPORTING value = value ).
        cl_abap_unit_assert=>fail( `A third value was read from a run of 2` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_input.
    TRY.
        NEW zparq2a_cl_dec_rle( bit_width = 33 data = CONV #( '' ) ).
        cl_abap_unit_assert=>fail( `Bit width 33 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    " RLE run value 2 with width 1
    TRY.
        decode( bit_width = 1 data = CONV #( '0202' ) count = 1 ).
        cl_abap_unit_assert=>fail( `Value 2 was read with width 1` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    " a run of 2^40 values
    TRY.
        decode( bit_width = 1 data = CONV #( '808080808040' ) count = 1 ).
        cl_abap_unit_assert=>fail( `A run of 2^40 values was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
