"! <p class="shorttext synchronized">Parquet: PLAIN decoder</p>
"! Encoding PLAIN for one physical type, the counterpart of
"! ZPARQ2A_CL_ENC_PLAIN. NEXT returns the value as
"! <ul>
"! <li>BOOLEAN: <em>abap_bool</em></li>
"! <li>INT32: <em>i</em>; INT64: <em>int8</em></li>
"! <li>FLOAT, DOUBLE: <em>f</em></li>
"! <li>BYTE_ARRAY, FIXED_LEN_BYTE_ARRAY: <em>xstring</em></li>
"! </ul>
"! or converted to the type of the actual parameter, as ABAP assigns it.
CLASS zparq2a_cl_dec_plain DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_decoder.

    "! @parameter data | the encoded values, nothing else
    "! @parameter physical_type | one of ZPARQ2A_IF_FORMAT=>C_TYPE, except INT96
    "! @parameter type_length | bytes per value of FIXED_LEN_BYTE_ARRAY
    "! @raising zparq2a_cx_error | the type is not supported or the length is missing
    METHODS constructor
      IMPORTING
        data          TYPE xstring
        physical_type TYPE i
        type_length   TYPE i OPTIONAL
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA physical_type TYPE i.
    DATA type_length TYPE i.
    DATA bytes TYPE REF TO zparq2a_cl_byte_reader.
    DATA bits TYPE REF TO zparq2a_cl_bit_reader.

ENDCLASS.


CLASS zparq2a_cl_dec_plain IMPLEMENTATION.

  METHOD constructor.
    CASE physical_type.
      WHEN zparq2a_if_format=>c_type-boolean.
        " booleans are bit-packed, one bit each
        bits = NEW #( data ).
      WHEN zparq2a_if_format=>c_type-int32
          OR zparq2a_if_format=>c_type-int64
          OR zparq2a_if_format=>c_type-float
          OR zparq2a_if_format=>c_type-double
          OR zparq2a_if_format=>c_type-byte_array.
        bytes = NEW #( data ).
      WHEN zparq2a_if_format=>c_type-fixed_len_byte_array.
        IF type_length <= 0.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |FIXED_LEN_BYTE_ARRAY needs a positive length, got { type_length }|.
        ENDIF.
        bytes = NEW #( data ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Physical type { physical_type } has no PLAIN decoder|.
    ENDCASE.
    me->physical_type = physical_type.
    me->type_length = type_length.
  ENDMETHOD.

  METHOD zparq2a_if_decoder~get_encoding.
    result = zparq2a_if_format=>c_encoding-plain.
  ENDMETHOD.

  METHOD zparq2a_if_decoder~next.
    DATA length TYPE i.

    CASE physical_type.
      WHEN zparq2a_if_format=>c_type-boolean.
        value = COND abap_bool( WHEN bits->read( 1 ) = 1 THEN abap_true ELSE abap_false ).
      WHEN zparq2a_if_format=>c_type-int32.
        value = bytes->read_int32_le( ).
      WHEN zparq2a_if_format=>c_type-int64.
        value = bytes->read_int64_le( ).
      WHEN zparq2a_if_format=>c_type-float.
        value = bytes->read_float( ).
      WHEN zparq2a_if_format=>c_type-double.
        value = bytes->read_double( ).
      WHEN zparq2a_if_format=>c_type-byte_array.
        length = bytes->read_int32_le( ).
        value = bytes->read_bytes( length ).
      WHEN zparq2a_if_format=>c_type-fixed_len_byte_array.
        value = bytes->read_bytes( type_length ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
