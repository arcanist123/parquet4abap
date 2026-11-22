"! <p class="shorttext synchronized">Parquet: binary codec helpers</p>
"! Conversions between ABAP values and the byte layouts Parquet and Thrift use:
"! little-endian INT32/INT64, IEEE-754 FLOAT/DOUBLE, ZigZag, unsigned varints
"! (ULEB128) and UTF-8.
"!
"! Unsigned 64-bit values travel in <em>int8</em> as their two's complement bit pattern,
"! so values of 2^63 and above appear as negative numbers.
CLASS zparq2a_cl_bytes DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      "! Classification of an IEEE-754 bit pattern
      BEGIN OF float_kinds,
        finite            TYPE i VALUE 0,
        nan               TYPE i VALUE 1,
        positive_infinity TYPE i VALUE 2,
        negative_infinity TYPE i VALUE 3,
      END OF float_kinds.

    CONSTANTS min_int8 TYPE int8 VALUE -9223372036854775808.
    CONSTANTS max_int8 TYPE int8 VALUE 9223372036854775807.

    CLASS-METHODS class_constructor.

    "! 2^exponent for exponent 0..62
    CLASS-METHODS power_of_two
      IMPORTING
        exponent      TYPE i
      RETURNING
        VALUE(result) TYPE int8.

    "! Reverses the byte order
    CLASS-METHODS reverse
      IMPORTING
        bytes         TYPE xsequence
      RETURNING
        VALUE(result) TYPE xstring.

    CLASS-METHODS int32_to_le
      IMPORTING
        value         TYPE i
      RETURNING
        VALUE(result) TYPE xstring.

    "! @parameter bytes | exactly 4 bytes
    CLASS-METHODS int32_from_le
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS int64_to_le
      IMPORTING
        value         TYPE int8
      RETURNING
        VALUE(result) TYPE xstring.

    "! @parameter bytes | exactly 8 bytes
    CLASS-METHODS int64_from_le
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    "! IEEE-754 binary32, rounded to nearest, ties to even
    "! @raising zparq2a_cx_error | value is too large for binary32
    CLASS-METHODS float_to_le
      IMPORTING
        value         TYPE f
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! Reads IEEE-754 binary32. Negative zero reads as zero.
    "! @raising zparq2a_cx_error | wrong length, NaN or infinity (see FLOAT_KIND)
    CLASS-METHODS float_from_le
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE f
      RAISING
        zparq2a_cx_error.

    "! @parameter result | one of the values in FLOAT_KINDS
    CLASS-METHODS float_kind
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    "! IEEE-754 binary64; exact for every value of type F
    CLASS-METHODS double_to_le
      IMPORTING
        value         TYPE f
      RETURNING
        VALUE(result) TYPE xstring.

    "! Reads IEEE-754 binary64. Negative zero reads as zero.
    "! @raising zparq2a_cx_error | wrong length, NaN or infinity (see DOUBLE_KIND)
    CLASS-METHODS double_from_le
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE f
      RAISING
        zparq2a_cx_error.

    "! @parameter result | one of the values in FLOAT_KINDS
    CLASS-METHODS double_kind
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    "! ZigZag encoding: 0, -1, 1, -2, ... become 0, 1, 2, 3, ...
    "! @parameter result | unsigned 64-bit bit pattern
    CLASS-METHODS zigzag_encode
      IMPORTING
        value         TYPE int8
      RETURNING
        VALUE(result) TYPE int8.

    "! @parameter value | unsigned 64-bit bit pattern
    CLASS-METHODS zigzag_decode
      IMPORTING
        value         TYPE int8
      RETURNING
        VALUE(result) TYPE int8.

    "! Unsigned LEB128 varint, 1 to 10 bytes
    "! @parameter value | unsigned 64-bit bit pattern
    CLASS-METHODS varint_encode
      IMPORTING
        value         TYPE int8
      RETURNING
        VALUE(result) TYPE xstring.

    CLASS-METHODS utf8_encode
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! @raising zparq2a_cx_error | bytes are not valid UTF-8
    CLASS-METHODS utf8_decode
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      "! Layout of an IEEE-754 binary interchange format
      BEGIN OF ty_format,
        name           TYPE string,
        length         TYPE i,
        mantissa_bits  TYPE i,
        bias           TYPE i,
        max_exponent   TYPE i,
        mantissa_scale TYPE int8,
      END OF ty_format.

    TYPES ty_powers TYPE STANDARD TABLE OF int8 WITH EMPTY KEY.

    CONSTANTS two_pow_62 TYPE int8 VALUE 4611686018427387904.
    CONSTANTS two_pow_31 TYPE int8 VALUE 2147483648.

    CLASS-DATA powers TYPE ty_powers.
    CLASS-DATA binary32 TYPE ty_format.
    CLASS-DATA binary64 TYPE ty_format.

    CLASS-METHODS check_length
      IMPORTING
        bytes  TYPE xstring
        length TYPE i
        what   TYPE string
      RAISING
        zparq2a_cx_error.

    "! 2^exponent as F, for exponent -1074..1023
    CLASS-METHODS float_power_of_two
      IMPORTING
        exponent      TYPE i
      RETURNING
        VALUE(result) TYPE f.

    "! Largest e with 2^e <= magnitude
    CLASS-METHODS binary_exponent
      IMPORTING
        magnitude     TYPE f
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS round_half_even
      IMPORTING
        value         TYPE f
      RETURNING
        VALUE(result) TYPE int8.

    "! Bit pattern without the sign bit
    CLASS-METHODS encode_ieee
      IMPORTING
        magnitude     TYPE f
        format        TYPE ty_format
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    "! Unsigned bit pattern of a binary32 or binary64 value; NEGATIVE is set from the sign bit
    CLASS-METHODS ieee_bits
      IMPORTING
        bytes    TYPE xstring
        format   TYPE ty_format
      EXPORTING
        bits     TYPE int8
        negative TYPE abap_bool
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS ieee_kind
      IMPORTING
        bytes         TYPE xstring
        format        TYPE ty_format
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS decode_ieee
      IMPORTING
        bytes         TYPE xstring
        format        TYPE ty_format
      RETURNING
        VALUE(result) TYPE f
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_bytes IMPLEMENTATION.

  METHOD class_constructor.
    DATA power TYPE int8 VALUE 1.

    DO 63 TIMES.
      APPEND power TO powers.
      IF sy-index < 63.
        power = power * 2.
      ENDIF.
    ENDDO.

    binary32 = VALUE #(
      name           = `FLOAT`
      length         = 4
      mantissa_bits  = 23
      bias           = 127
      max_exponent   = 255
      mantissa_scale = power_of_two( 23 ) ).
    binary64 = VALUE #(
      name           = `DOUBLE`
      length         = 8
      mantissa_bits  = 52
      bias           = 1023
      max_exponent   = 2047
      mantissa_scale = power_of_two( 52 ) ).
  ENDMETHOD.

  METHOD power_of_two.
    result = powers[ exponent + 1 ].
  ENDMETHOD.

  METHOD reverse.
    DATA(offset) = xstrlen( bytes ).
    WHILE offset > 0.
      offset = offset - 1.
      CONCATENATE result bytes+offset(1) INTO result IN BYTE MODE.
    ENDWHILE.
  ENDMETHOD.

  METHOD check_length.
    IF xstrlen( bytes ) <> length.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |{ what } needs { length } bytes, got { xstrlen( bytes ) }|.
    ENDIF.
  ENDMETHOD.

  METHOD int32_to_le.
    DATA big_endian TYPE x LENGTH 4.

    big_endian = value.
    result = reverse( big_endian ).
  ENDMETHOD.

  METHOD int32_from_le.
    DATA big_endian TYPE x LENGTH 4.

    check_length( bytes = bytes length = 4 what = `INT32` ).
    big_endian = reverse( bytes ).
    result = big_endian.
  ENDMETHOD.

  METHOD int64_to_le.
    DATA big_endian TYPE x LENGTH 8.

    big_endian = value.
    result = reverse( big_endian ).
  ENDMETHOD.

  METHOD int64_from_le.
    DATA big_endian TYPE x LENGTH 8.

    check_length( bytes = bytes length = 8 what = `INT64` ).
    big_endian = reverse( bytes ).
    result = big_endian.
  ENDMETHOD.

  METHOD float_power_of_two.
    DATA two TYPE f VALUE 2.

    result = two ** exponent.
  ENDMETHOD.

  METHOD binary_exponent.
    DATA estimate TYPE f.

    estimate = floor( log( magnitude ) / log( 2 ) ).
    IF estimate > 1023.
      estimate = 1023.
    ELSEIF estimate < -1074.
      estimate = -1074.
    ENDIF.
    result = estimate.

    " the logarithm can be off by one near powers of two
    WHILE result > -1074 AND float_power_of_two( result ) > magnitude.
      result = result - 1.
    ENDWHILE.
    WHILE result < 1023 AND float_power_of_two( result + 1 ) <= magnitude.
      result = result + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD round_half_even.
    CONSTANTS half TYPE f VALUE '0.5'.
    DATA whole TYPE f.

    whole = trunc( value ).
    result = whole.
    DATA(fraction) = value - whole.
    IF fraction > half OR ( fraction = half AND result MOD 2 = 1 ).
      result = result + 1.
    ENDIF.
  ENDMETHOD.

  METHOD encode_ieee.
    DATA scaled TYPE f.
    DATA exponent_field TYPE int8.

    IF magnitude = 0.
      RETURN.
    ENDIF.

    DATA(exponent) = binary_exponent( magnitude ).
    IF exponent < 1 - format-bias.
      " subnormal: magnitude / 2^(1 - bias - mantissa_bits), in two exact steps
      scaled = magnitude * float_power_of_two( format-bias - 1 )
                         * float_power_of_two( format-mantissa_bits ).
    ELSE.
      exponent_field = exponent + format-bias.
      scaled = ( magnitude / float_power_of_two( exponent ) - 1 )
             * float_power_of_two( format-mantissa_bits ).
    ENDIF.

    " a mantissa that rounds up to 2^mantissa_bits carries into the exponent field
    result = exponent_field * format-mantissa_scale + round_half_even( scaled ).
    IF result >= format-max_exponent * format-mantissa_scale.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { magnitude } is too large for { format-name }|.
    ENDIF.
  ENDMETHOD.

  METHOD ieee_bits.
    CONSTANTS zero_word TYPE x LENGTH 4 VALUE '00000000'.
    DATA big_endian TYPE x LENGTH 8.

    check_length( bytes = bytes length = format-length what = format-name ).
    IF format-length = 4.
      DATA(reversed) = reverse( bytes ).
      CONCATENATE zero_word reversed INTO big_endian IN BYTE MODE.
      bits = big_endian.
      negative = xsdbool( bits >= two_pow_31 ).
      IF negative = abap_true.
        bits = bits - two_pow_31.
      ENDIF.
    ELSE.
      big_endian = reverse( bytes ).
      bits = big_endian.
      negative = xsdbool( bits < 0 ).
      IF negative = abap_true.
        bits = bits - min_int8.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD ieee_kind.
    ieee_bits(
      EXPORTING
        bytes    = bytes
        format   = format
      IMPORTING
        bits     = DATA(bits)
        negative = DATA(negative) ).

    IF bits DIV format-mantissa_scale <> format-max_exponent.
      result = float_kinds-finite.
    ELSEIF bits MOD format-mantissa_scale <> 0.
      result = float_kinds-nan.
    ELSEIF negative = abap_true.
      result = float_kinds-negative_infinity.
    ELSE.
      result = float_kinds-positive_infinity.
    ENDIF.
  ENDMETHOD.

  METHOD decode_ieee.
    ieee_bits(
      EXPORTING
        bytes    = bytes
        format   = format
      IMPORTING
        bits     = DATA(bits)
        negative = DATA(negative) ).

    DATA(exponent_field) = bits DIV format-mantissa_scale.
    DATA(mantissa) = bits MOD format-mantissa_scale.

    IF exponent_field = format-max_exponent.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |{ format-name } { bytes } is NaN or infinite, which type F cannot hold|.
    ELSEIF exponent_field = 0.
      result = mantissa * float_power_of_two( 1 - format-bias )
                        / float_power_of_two( format-mantissa_bits ).
    ELSE.
      result = ( format-mantissa_scale + mantissa ) / float_power_of_two( format-mantissa_bits )
             * float_power_of_two( exponent_field - format-bias ).
    ENDIF.

    IF negative = abap_true.
      result = - result.
    ENDIF.
  ENDMETHOD.

  METHOD float_to_le.
    DATA big_endian TYPE x LENGTH 4.

    DATA(bits) = encode_ieee( magnitude = abs( value ) format = binary32 ).
    IF value < 0.
      bits = bits + two_pow_31.
    ENDIF.
    big_endian = bits.
    result = reverse( big_endian ).
  ENDMETHOD.

  METHOD float_from_le.
    result = decode_ieee( bytes = bytes format = binary32 ).
  ENDMETHOD.

  METHOD float_kind.
    result = ieee_kind( bytes = bytes format = binary32 ).
  ENDMETHOD.

  METHOD double_to_le.
    DATA big_endian TYPE x LENGTH 8.
    DATA bits TYPE int8.

    TRY.
        bits = encode_ieee( magnitude = abs( value ) format = binary64 ).
      CATCH zparq2a_cx_error.
        " every finite value of type F fits binary64
        ASSERT 1 = 0.
    ENDTRY.
    IF value < 0.
      bits = bits + min_int8.
    ENDIF.
    big_endian = bits.
    result = reverse( big_endian ).
  ENDMETHOD.

  METHOD double_from_le.
    result = decode_ieee( bytes = bytes format = binary64 ).
  ENDMETHOD.

  METHOD double_kind.
    result = ieee_kind( bytes = bytes format = binary64 ).
  ENDMETHOD.

  METHOD zigzag_encode.
    DATA magnitude TYPE int8.
    DATA low_bit TYPE int8.

    " (value << 1) XOR (value >> 63), in arithmetic that stays inside int8
    IF value >= 0.
      magnitude = value.
    ELSE.
      magnitude = - ( value + 1 ).
      low_bit = 1.
    ENDIF.

    IF magnitude < two_pow_62.
      result = magnitude * 2 + low_bit.
    ELSE.
      result = ( magnitude - two_pow_62 ) * 2 + low_bit + min_int8.
    ENDIF.
  ENDMETHOD.

  METHOD zigzag_decode.
    DATA half TYPE int8.
    DATA low_bit TYPE int8.

    IF value >= 0.
      half = value DIV 2.
      low_bit = value MOD 2.
    ELSE.
      DATA(without_top_bit) = value - min_int8.
      half = without_top_bit DIV 2 + two_pow_62.
      low_bit = without_top_bit MOD 2.
    ENDIF.

    IF low_bit = 1.
      result = - half - 1.
    ELSE.
      result = half.
    ENDIF.
  ENDMETHOD.

  METHOD varint_encode.
    DATA rest TYPE int8.
    DATA top_bit TYPE int8.
    DATA group TYPE int8.
    DATA byte TYPE x LENGTH 1.

    IF value < 0.
      rest = value - min_int8.
      top_bit = 1.
    ELSE.
      rest = value.
    ENDIF.

    " 9 groups of 7 bits hold the low 63 bits; bit 63 is the 10th group
    DO.
      group = rest MOD 128.
      rest = rest DIV 128.
      IF sy-index = 9.
        rest = rest + top_bit.
        top_bit = 0.
      ENDIF.
      IF rest = 0 AND top_bit = 0.
        byte = group.
        CONCATENATE result byte INTO result IN BYTE MODE.
        RETURN.
      ENDIF.
      byte = group + 128.
      CONCATENATE result byte INTO result IN BYTE MODE.
    ENDDO.
  ENDMETHOD.

  METHOD utf8_encode.
    TRY.
        result = cl_abap_conv_codepage=>create_out( codepage = `UTF-8` )->convert( source = text ).
      CATCH cx_sy_conversion_codepage INTO DATA(error).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text     = `Text cannot be encoded as UTF-8`
            previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD utf8_decode.
    TRY.
        result = cl_abap_conv_codepage=>create_in( codepage = `UTF-8` )->convert( source = bytes ).
      CATCH cx_sy_conversion_codepage INTO DATA(error).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text     = `Bytes are not valid UTF-8`
            previous = error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
