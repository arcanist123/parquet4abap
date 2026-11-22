CLASS ltcl_enc_rle DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_values TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    METHODS encoding_is_rle FOR TESTING RAISING zparq2a_cx_error.
    METHODS repeated_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS bit_packed_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS short_input_is_padded FOR TESTING RAISING zparq2a_cx_error.
    METHODS short_repeat_stays_packed FOR TESTING RAISING zparq2a_cx_error.
    METHODS repeat_fills_last_group FOR TESTING RAISING zparq2a_cx_error.
    METHODS wide_repeated_value FOR TESTING RAISING zparq2a_cx_error.
    METHODS zero_width FOR TESTING RAISING zparq2a_cx_error.
    METHODS long_packed_run FOR TESTING RAISING zparq2a_cx_error.
    METHODS empty FOR TESTING RAISING zparq2a_cx_error.
    METHODS out_of_range FOR TESTING.

    METHODS encode
      IMPORTING
        bit_width     TYPE i
        values        TYPE ty_values
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_enc_rle IMPLEMENTATION.

  METHOD encode.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_rle( bit_width ).
    LOOP AT values INTO DATA(value).
      cut->put( value ).
    ENDLOOP.
    result = cut->flush( ).
  ENDMETHOD.

  METHOD encoding_is_rle.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    cut = NEW zparq2a_cl_enc_rle( 1 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_encoding( ) exp = zparq2a_if_format=>c_encoding-rle ).
  ENDMETHOD.

  METHOD repeated_run.
    " header 10 << 1, then the value in one byte
    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 1 values = VALUE #( ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ) )
      exp = CONV xstring( '1401' ) ).
  ENDMETHOD.

  METHOD bit_packed_run.
    " header 1 group << 1 | 1, then 0..7 packed with 3 bits each
    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 3 values = VALUE #( ( 0 ) ( 1 ) ( 2 ) ( 3 ) ( 4 ) ( 5 ) ( 6 ) ( 7 ) ) )
      exp = CONV xstring( '0388C6FA' ) ).
  ENDMETHOD.

  METHOD short_input_is_padded.
    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 1 values = VALUE #( ( 1 ) ( 0 ) ( 1 ) ) )
      exp = CONV xstring( '0305' ) ).
  ENDMETHOD.

  METHOD short_repeat_stays_packed.
    " 1, 0, 1 and ten 0: filling the group leaves only 5 repeats, too few for an RLE run
    DATA(values) = VALUE ty_values( ( 1 ) ( 0 ) ( 1 ) ).
    DO 10 TIMES.
      APPEND 0 TO values.
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 1 values = values )
      exp = CONV xstring( '050500' ) ).
  ENDMETHOD.

  METHOD repeat_fills_last_group.
    " 1, 0, 1 and thirteen 0: 5 of them fill the group, 8 make an RLE run
    DATA(values) = VALUE ty_values( ( 1 ) ( 0 ) ( 1 ) ).
    DO 13 TIMES.
      APPEND 0 TO values.
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 1 values = values )
      exp = CONV xstring( '03051000' ) ).
  ENDMETHOD.

  METHOD wide_repeated_value.
    " the value of an RLE run takes ceil(9 / 8) = 2 bytes, little-endian
    DATA values TYPE ty_values.
    DO 8 TIMES.
      APPEND 300 TO values.
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 9 values = values )
      exp = CONV xstring( '102C01' ) ).
  ENDMETHOD.

  METHOD zero_width.
    DATA values TYPE ty_values.
    DO 5 TIMES.
      APPEND 0 TO values.
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 0 values = values )
      exp = CONV xstring( '03' ) ).

    DO 5 TIMES.
      APPEND 0 TO values.
    ENDDO.
    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 0 values = values )
      exp = CONV xstring( '14' ) ).
  ENDMETHOD.

  METHOD long_packed_run.
    " 1000 alternating values: 125 groups, header 251 as a two-byte varint
    DATA values TYPE ty_values.
    DATA expected TYPE xstring.
    DATA pattern TYPE x LENGTH 1 VALUE 'AA'.

    DO 1000 TIMES.
      APPEND ( sy-index - 1 ) MOD 2 TO values.
    ENDDO.
    expected = 'FB01'.
    DO 125 TIMES.
      CONCATENATE expected pattern INTO expected IN BYTE MODE.
    ENDDO.

    cl_abap_unit_assert=>assert_equals(
      act = encode( bit_width = 1 values = values )
      exp = expected ).
  ENDMETHOD.

  METHOD empty.
    DATA nothing TYPE ty_values.

    cl_abap_unit_assert=>assert_initial( encode( bit_width = 1 values = nothing ) ).
  ENDMETHOD.

  METHOD out_of_range.
    DATA cut TYPE REF TO zparq2a_if_encoder.

    TRY.
        cut = NEW zparq2a_cl_enc_rle( 2 ).
        cut->put( 4 ).
        cl_abap_unit_assert=>fail( `4 was accepted for 2 bits` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut->put( -1 ).
        cl_abap_unit_assert=>fail( `-1 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        cut = NEW zparq2a_cl_enc_rle( 33 ).
        cl_abap_unit_assert=>fail( `Bit width 33 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
