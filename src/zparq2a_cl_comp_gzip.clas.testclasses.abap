CLASS ltcl_comp_gzip DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zparq2a_if_compressor.

    METHODS setup RAISING zparq2a_cx_error.
    METHODS codec_is_gzip FOR TESTING.
    METHODS round_trip FOR TESTING RAISING zparq2a_cx_error.
    METHODS gzip_header FOR TESTING RAISING zparq2a_cx_error.
    METHODS empty_input FOR TESTING RAISING zparq2a_cx_error.
    METHODS invalid_input FOR TESTING.
    METHODS level_out_of_range FOR TESTING.

ENDCLASS.


CLASS ltcl_comp_gzip IMPLEMENTATION.

  METHOD setup.
    cut = NEW zparq2a_cl_comp_gzip( ).
  ENDMETHOD.

  METHOD codec_is_gzip.
    cl_abap_unit_assert=>assert_equals( act = cut->get_codec( ) exp = zparq2a_if_format=>c_codec-gzip ).
  ENDMETHOD.

  METHOD round_trip.
    DATA input TYPE xstring.
    DATA chunk TYPE x LENGTH 8 VALUE '0001020304050607'.

    DO 100 TIMES.
      CONCATENATE input chunk INTO input IN BYTE MODE.
    ENDDO.

    DATA(compressed) = cut->compress( input ).
    cl_abap_unit_assert=>assert_true( xsdbool( xstrlen( compressed ) < xstrlen( input ) ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->decompress( compressed ) exp = input ).
  ENDMETHOD.

  METHOD gzip_header.
    DATA magic TYPE x LENGTH 3.

    " RFC 1952: ID1 ID2 and CM = 8 (deflate)
    DATA(compressed) = cut->compress( CONV xstring( '50415231' ) ).
    magic = compressed.
    cl_abap_unit_assert=>assert_equals( act = magic exp = '1F8B08' ).
  ENDMETHOD.

  METHOD empty_input.
    DATA empty TYPE xstring.

    DATA(compressed) = cut->compress( empty ).
    cl_abap_unit_assert=>assert_initial( cut->decompress( compressed ) ).
  ENDMETHOD.

  METHOD invalid_input.
    TRY.
        cut->decompress( CONV xstring( '0102030405060708090A0B0C' ) ).
        cl_abap_unit_assert=>fail( `Invalid GZIP data was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD level_out_of_range.
    TRY.
        NEW zparq2a_cl_comp_gzip( 10 ).
        cl_abap_unit_assert=>fail( `Level 10 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
