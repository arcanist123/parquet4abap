CLASS ltcl_comp_none DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zparq2a_if_compressor.

    METHODS setup.
    METHODS codec_is_uncompressed FOR TESTING.
    METHODS compress_keeps_bytes FOR TESTING RAISING zparq2a_cx_error.
    METHODS decompress_keeps_bytes FOR TESTING RAISING zparq2a_cx_error.
    METHODS empty_input FOR TESTING RAISING zparq2a_cx_error.

ENDCLASS.


CLASS ltcl_comp_none IMPLEMENTATION.

  METHOD setup.
    cut = NEW zparq2a_cl_comp_none( ).
  ENDMETHOD.

  METHOD codec_is_uncompressed.
    cl_abap_unit_assert=>assert_equals(
      act = cut->get_codec( )
      exp = 0 ).
  ENDMETHOD.

  METHOD compress_keeps_bytes.
    DATA(input) = CONV xstring( '50415231000102FF' ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->compress( input )
      exp = input ).
  ENDMETHOD.

  METHOD decompress_keeps_bytes.
    DATA(input) = CONV xstring( '50415231000102FF' ).

    cl_abap_unit_assert=>assert_equals(
      act = cut->decompress( input )
      exp = input ).
  ENDMETHOD.

  METHOD empty_input.
    DATA empty TYPE xstring.

    cl_abap_unit_assert=>assert_initial( cut->compress( empty ) ).
    cl_abap_unit_assert=>assert_initial( cut->decompress( empty ) ).
  ENDMETHOD.

ENDCLASS.
