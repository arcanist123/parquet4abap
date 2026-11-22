CLASS ltcl_integers DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS assert_int32
      IMPORTING
        value TYPE i
        bytes TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS assert_int64
      IMPORTING
        value TYPE int8
        bytes TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS int32_edge_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS int32_wrong_length FOR TESTING.
    METHODS int64_edge_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS int64_wrong_length FOR TESTING.
    METHODS reverse_bytes FOR TESTING.
    METHODS powers_of_two FOR TESTING.

ENDCLASS.


CLASS ltcl_integers IMPLEMENTATION.

  METHOD assert_int32.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>int32_to_le( value )
      exp = bytes
      msg = |encode { value }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>int32_from_le( bytes )
      exp = value
      msg = |decode { bytes }| ).
  ENDMETHOD.

  METHOD assert_int64.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>int64_to_le( value )
      exp = bytes
      msg = |encode { value }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>int64_from_le( bytes )
      exp = value
      msg = |decode { bytes }| ).
  ENDMETHOD.

  METHOD int32_edge_values.
    assert_int32( value = 0 bytes = '00000000' ).
    assert_int32( value = 1 bytes = '01000000' ).
    assert_int32( value = -1 bytes = 'FFFFFFFF' ).
    assert_int32( value = 16909060 bytes = '04030201' ).
    assert_int32( value = 2147483647 bytes = 'FFFFFF7F' ).
    assert_int32( value = -2147483648 bytes = '00000080' ).
  ENDMETHOD.

  METHOD int32_wrong_length.
    TRY.
        zparq2a_cl_bytes=>int32_from_le( '010203' ).
        cl_abap_unit_assert=>fail( `3 bytes accepted as INT32` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD int64_edge_values.
    assert_int64( value = 0 bytes = '0000000000000000' ).
    assert_int64( value = 1 bytes = '0100000000000000' ).
    assert_int64( value = -1 bytes = 'FFFFFFFFFFFFFFFF' ).
    assert_int64( value = 72623859790382856 bytes = '0807060504030201' ).
    assert_int64( value = 2147483648 bytes = '0000008000000000' ).
    assert_int64( value = -2147483649 bytes = 'FFFFFF7FFFFFFFFF' ).
    assert_int64( value = zparq2a_cl_bytes=>max_int8 bytes = 'FFFFFFFFFFFFFF7F' ).
    assert_int64( value = zparq2a_cl_bytes=>min_int8 bytes = '0000000000000080' ).
  ENDMETHOD.

  METHOD int64_wrong_length.
    TRY.
        zparq2a_cl_bytes=>int64_from_le( '01020304050607080900' ).
        cl_abap_unit_assert=>fail( `10 bytes accepted as INT64` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD reverse_bytes.
    DATA empty TYPE xstring.

    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>reverse( '010203' )
      exp = CONV xstring( '030201' ) ).
    cl_abap_unit_assert=>assert_initial( zparq2a_cl_bytes=>reverse( empty ) ).
  ENDMETHOD.

  METHOD powers_of_two.
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_bytes=>power_of_two( 0 ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_bytes=>power_of_two( 32 ) exp = 4294967296 ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>power_of_two( 62 )
      exp = 4611686018427387904 ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_floats DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! 2^exponent
    METHODS power
      IMPORTING
        exponent      TYPE i
      RETURNING
        VALUE(result) TYPE f.

    "! Decoding gives VALUE and encoding VALUE gives BYTES back
    METHODS assert_double
      IMPORTING
        value TYPE f
        bytes TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS assert_float
      IMPORTING
        value TYPE f
        bytes TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS assert_double_special
      IMPORTING
        bytes TYPE xstring
        kind  TYPE i.

    METHODS assert_float_special
      IMPORTING
        bytes TYPE xstring
        kind  TYPE i.

    METHODS double_normal_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS double_limits FOR TESTING RAISING zparq2a_cx_error.
    METHODS double_subnormals FOR TESTING RAISING zparq2a_cx_error.
    METHODS double_negative_zero FOR TESTING RAISING zparq2a_cx_error.
    METHODS double_nan_and_infinity FOR TESTING.
    METHODS double_wrong_length FOR TESTING.
    METHODS float_normal_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS float_limits FOR TESTING RAISING zparq2a_cx_error.
    METHODS float_subnormals FOR TESTING RAISING zparq2a_cx_error.
    METHODS float_rounding FOR TESTING RAISING zparq2a_cx_error.
    METHODS float_overflow FOR TESTING.
    METHODS float_nan_and_infinity FOR TESTING.

ENDCLASS.


CLASS ltcl_floats IMPLEMENTATION.

  METHOD power.
    DATA two TYPE f VALUE 2.

    result = two ** exponent.
  ENDMETHOD.

  METHOD assert_double.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>double_to_le( value )
      exp = bytes
      msg = |encode { value }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>double_from_le( bytes )
      exp = value
      msg = |decode { bytes }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>double_kind( bytes )
      exp = zparq2a_cl_bytes=>float_kinds-finite
      msg = |kind { bytes }| ).
  ENDMETHOD.

  METHOD assert_float.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( value )
      exp = bytes
      msg = |encode { value }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_from_le( bytes )
      exp = value
      msg = |decode { bytes }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_kind( bytes )
      exp = zparq2a_cl_bytes=>float_kinds-finite
      msg = |kind { bytes }| ).
  ENDMETHOD.

  METHOD assert_double_special.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zparq2a_cl_bytes=>double_kind( bytes )
          exp = kind
          msg = |kind { bytes }| ).
      CATCH zparq2a_cx_error.
        cl_abap_unit_assert=>fail( |kind { bytes } raised| ).
    ENDTRY.
    TRY.
        zparq2a_cl_bytes=>double_from_le( bytes ).
        cl_abap_unit_assert=>fail( |{ bytes } decoded to type F| ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD assert_float_special.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zparq2a_cl_bytes=>float_kind( bytes )
          exp = kind
          msg = |kind { bytes }| ).
      CATCH zparq2a_cx_error.
        cl_abap_unit_assert=>fail( |kind { bytes } raised| ).
    ENDTRY.
    TRY.
        zparq2a_cl_bytes=>float_from_le( bytes ).
        cl_abap_unit_assert=>fail( |{ bytes } decoded to type F| ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD double_normal_values.
    assert_double( value = 0 bytes = '0000000000000000' ).
    assert_double( value = 1 bytes = '000000000000F03F' ).
    assert_double( value = -2 bytes = '00000000000000C0' ).
    assert_double( value = '0.5' bytes = '000000000000E03F' ).
    assert_double( value = '0.1' bytes = '9A9999999999B93F' ).
    assert_double( value = '-123.25' bytes = '0000000000D05EC0' ).
    " 1 + 2^-52, the smallest step above 1
    assert_double( value = 1 + power( -52 ) bytes = '010000000000F03F' ).
  ENDMETHOD.

  METHOD double_limits.
    " largest finite value: (2 - 2^-52) * 2^1023
    assert_double( value = ( 2 - power( -52 ) ) * power( 1023 ) bytes = 'FFFFFFFFFFFFEF7F' ).
    assert_double( value = - ( 2 - power( -52 ) ) * power( 1023 ) bytes = 'FFFFFFFFFFFFEFFF' ).
    " smallest normal value 2^-1022
    assert_double( value = power( -1022 ) bytes = '0000000000001000' ).
  ENDMETHOD.

  METHOD double_subnormals.
    " smallest subnormal 2^-1074
    assert_double( value = power( -1074 ) bytes = '0100000000000000' ).
    assert_double( value = - power( -1074 ) bytes = '0100000000000080' ).
    " largest subnormal 2^-1022 - 2^-1074
    assert_double( value = power( -1022 ) - power( -1074 ) bytes = 'FFFFFFFFFFFF0F00' ).
    assert_double( value = 3 * power( -1074 ) bytes = '0300000000000000' ).
  ENDMETHOD.

  METHOD double_negative_zero.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>double_from_le( '0000000000000080' )
      exp = 0 ).
  ENDMETHOD.

  METHOD double_nan_and_infinity.
    assert_double_special( bytes = '000000000000F87F' kind = zparq2a_cl_bytes=>float_kinds-nan ).
    assert_double_special( bytes = '010000000000F0FF' kind = zparq2a_cl_bytes=>float_kinds-nan ).
    assert_double_special( bytes = '000000000000F07F' kind = zparq2a_cl_bytes=>float_kinds-positive_infinity ).
    assert_double_special( bytes = '000000000000F0FF' kind = zparq2a_cl_bytes=>float_kinds-negative_infinity ).
  ENDMETHOD.

  METHOD double_wrong_length.
    TRY.
        zparq2a_cl_bytes=>double_from_le( '0000803F' ).
        cl_abap_unit_assert=>fail( `4 bytes accepted as DOUBLE` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD float_normal_values.
    assert_float( value = 0 bytes = '00000000' ).
    assert_float( value = 1 bytes = '0000803F' ).
    assert_float( value = -2 bytes = '000000C0' ).
    assert_float( value = '0.5' bytes = '0000003F' ).
    assert_float( value = '-123.25' bytes = '0080F6C2' ).
    assert_float( value = 1 + power( -23 ) bytes = '0100803F' ).
  ENDMETHOD.

  METHOD float_limits.
    " largest finite value: (2 - 2^-23) * 2^127
    assert_float( value = ( 2 - power( -23 ) ) * power( 127 ) bytes = 'FFFF7F7F' ).
    assert_float( value = - ( 2 - power( -23 ) ) * power( 127 ) bytes = 'FFFF7FFF' ).
    assert_float( value = power( -126 ) bytes = '00008000' ).
  ENDMETHOD.

  METHOD float_subnormals.
    assert_float( value = power( -149 ) bytes = '01000000' ).
    assert_float( value = - power( -149 ) bytes = '01000080' ).
    assert_float( value = power( -126 ) - power( -149 ) bytes = 'FFFF7F00' ).
  ENDMETHOD.

  METHOD float_rounding.
    " 0.1 is not exact in binary32; the nearest value is 0x3DCCCCCD
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( '0.1' )
      exp = CONV xstring( 'CDCCCC3D' ) ).
    " ties go to the even mantissa
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( 1 + power( -24 ) )
      exp = CONV xstring( '0000803F' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( 1 + 3 * power( -24 ) )
      exp = CONV xstring( '0200803F' ) ).
    " a mantissa that rounds up carries into the exponent: 2 - 2^-25 becomes 2
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( 2 - power( -25 ) )
      exp = CONV xstring( '00000040' ) ).
    " below half of the smallest subnormal rounds to zero
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( power( -151 ) )
      exp = CONV xstring( '00000000' ) ).
    " subnormal rounding up into the smallest normal value
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>float_to_le( power( -126 ) - power( -151 ) )
      exp = CONV xstring( '00008000' ) ).
  ENDMETHOD.

  METHOD float_overflow.
    TRY.
        zparq2a_cl_bytes=>float_to_le( power( 128 ) ).
        cl_abap_unit_assert=>fail( `2^128 accepted as FLOAT` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        " halfway between the largest value and 2^128 rounds up to infinity
        zparq2a_cl_bytes=>float_to_le( - ( power( 128 ) - power( 103 ) ) ).
        cl_abap_unit_assert=>fail( `-(2^128 - 2^103) accepted as FLOAT` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        zparq2a_cl_bytes=>float_to_le( '1E300' ).
        cl_abap_unit_assert=>fail( `1E300 accepted as FLOAT` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD float_nan_and_infinity.
    assert_float_special( bytes = '0000C07F' kind = zparq2a_cl_bytes=>float_kinds-nan ).
    assert_float_special( bytes = '0100C0FF' kind = zparq2a_cl_bytes=>float_kinds-nan ).
    assert_float_special( bytes = '0000807F' kind = zparq2a_cl_bytes=>float_kinds-positive_infinity ).
    assert_float_special( bytes = '000080FF' kind = zparq2a_cl_bytes=>float_kinds-negative_infinity ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_varints DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS assert_zigzag
      IMPORTING
        value   TYPE int8
        encoded TYPE int8.

    METHODS assert_varint
      IMPORTING
        value TYPE int8
        bytes TYPE xstring.

    METHODS zigzag_edge_values FOR TESTING.
    METHODS varint_edge_values FOR TESTING.

ENDCLASS.


CLASS ltcl_varints IMPLEMENTATION.

  METHOD assert_zigzag.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>zigzag_encode( value )
      exp = encoded
      msg = |encode { value }| ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>zigzag_decode( encoded )
      exp = value
      msg = |decode { encoded }| ).
  ENDMETHOD.

  METHOD assert_varint.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>varint_encode( value )
      exp = bytes
      msg = |encode { value }| ).
  ENDMETHOD.

  METHOD zigzag_edge_values.
    assert_zigzag( value = 0 encoded = 0 ).
    assert_zigzag( value = -1 encoded = 1 ).
    assert_zigzag( value = 1 encoded = 2 ).
    assert_zigzag( value = -2 encoded = 3 ).
    assert_zigzag( value = 2147483647 encoded = 4294967294 ).
    assert_zigzag( value = -2147483648 encoded = 4294967295 ).
    assert_zigzag( value = 4611686018427387903 encoded = 9223372036854775806 ).
    assert_zigzag( value = -4611686018427387904 encoded = 9223372036854775807 ).
    " results of 2^63 and above appear as negative bit patterns
    assert_zigzag( value = 4611686018427387904 encoded = zparq2a_cl_bytes=>min_int8 ).
    assert_zigzag( value = zparq2a_cl_bytes=>max_int8 encoded = -2 ).
    assert_zigzag( value = zparq2a_cl_bytes=>min_int8 encoded = -1 ).
  ENDMETHOD.

  METHOD varint_edge_values.
    assert_varint( value = 0 bytes = '00' ).
    assert_varint( value = 1 bytes = '01' ).
    assert_varint( value = 127 bytes = '7F' ).
    assert_varint( value = 128 bytes = '8001' ).
    assert_varint( value = 300 bytes = 'AC02' ).
    assert_varint( value = 16384 bytes = '808001' ).
    assert_varint( value = 4294967295 bytes = 'FFFFFFFF0F' ).
    assert_varint( value = zparq2a_cl_bytes=>max_int8 bytes = 'FFFFFFFFFFFFFFFF7F' ).
    " 2^63 and 2^64 - 1
    assert_varint( value = zparq2a_cl_bytes=>min_int8 bytes = '80808080808080808001' ).
    assert_varint( value = -1 bytes = 'FFFFFFFFFFFFFFFFFF01' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_utf8 DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS ascii FOR TESTING RAISING zparq2a_cx_error.
    METHODS multi_byte FOR TESTING RAISING zparq2a_cx_error.
    METHODS empty FOR TESTING RAISING zparq2a_cx_error.
    METHODS invalid_bytes FOR TESTING.

ENDCLASS.


CLASS ltcl_utf8 IMPLEMENTATION.

  METHOD ascii.
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>utf8_encode( `PAR1` )
      exp = CONV xstring( '50415231' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>utf8_decode( '50415231' )
      exp = `PAR1` ).
  ENDMETHOD.

  METHOD multi_byte.
    " U+00E4 and U+20AC: two and three bytes in UTF-8
    DATA(text) = zparq2a_cl_bytes=>utf8_decode( 'C3A4E282AC' ).

    cl_abap_unit_assert=>assert_equals( act = strlen( text ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = zparq2a_cl_bytes=>utf8_encode( text )
      exp = CONV xstring( 'C3A4E282AC' ) ).
  ENDMETHOD.

  METHOD empty.
    DATA nothing TYPE xstring.

    cl_abap_unit_assert=>assert_initial( zparq2a_cl_bytes=>utf8_encode( `` ) ).
    cl_abap_unit_assert=>assert_initial( zparq2a_cl_bytes=>utf8_decode( nothing ) ).
  ENDMETHOD.

  METHOD invalid_bytes.
    TRY.
        " a lead byte without its continuation byte
        zparq2a_cl_bytes=>utf8_decode( '41C3' ).
        cl_abap_unit_assert=>fail( `truncated UTF-8 accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
