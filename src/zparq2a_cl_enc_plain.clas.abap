"! <p class="shorttext synchronized">Parquet: PLAIN encoder</p>
"! Encoding PLAIN for one physical type. PUT takes the value as
"! <ul>
"! <li>BOOLEAN: <em>abap_bool</em>, anything other than blank is true</li>
"! <li>INT32: <em>i</em>; INT64: <em>int8</em></li>
"! <li>FLOAT, DOUBLE: <em>f</em></li>
"! <li>BYTE_ARRAY, FIXED_LEN_BYTE_ARRAY: <em>xstring</em></li>
"! </ul>
"! or anything ABAP converts to that type.
CLASS zparq2a_cl_enc_plain DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_encoder.

    "! @parameter physical_type | one of ZPARQ2A_IF_FORMAT=>C_TYPE, except INT96
    "! @parameter type_length | bytes per value of FIXED_LEN_BYTE_ARRAY
    "! @raising zparq2a_cx_error | the type is not supported or the length is missing
    METHODS constructor
      IMPORTING
        physical_type TYPE i
        type_length   TYPE i OPTIONAL
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA physical_type TYPE i.
    DATA type_length TYPE i.
    DATA bytes TYPE REF TO zparq2a_cl_byte_writer.
    DATA bits TYPE REF TO zparq2a_cl_bit_writer.

ENDCLASS.


CLASS zparq2a_cl_enc_plain IMPLEMENTATION.

  METHOD constructor.
    CASE physical_type.
      WHEN zparq2a_if_format=>c_type-boolean
          OR zparq2a_if_format=>c_type-int32
          OR zparq2a_if_format=>c_type-int64
          OR zparq2a_if_format=>c_type-float
          OR zparq2a_if_format=>c_type-double
          OR zparq2a_if_format=>c_type-byte_array.
      WHEN zparq2a_if_format=>c_type-fixed_len_byte_array.
        IF type_length <= 0.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |FIXED_LEN_BYTE_ARRAY needs a positive length, got { type_length }|.
        ENDIF.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Physical type { physical_type } has no PLAIN encoder|.
    ENDCASE.
    me->physical_type = physical_type.
    me->type_length = type_length.
    bytes = NEW #( ).
    bits = NEW #( ).
  ENDMETHOD.

  METHOD zparq2a_if_encoder~get_encoding.
    result = zparq2a_if_format=>c_encoding-plain.
  ENDMETHOD.

  METHOD zparq2a_if_encoder~put.
    DATA binary TYPE xstring.

    CASE physical_type.
      WHEN zparq2a_if_format=>c_type-boolean.
        bits->write( value = COND #( WHEN value IS INITIAL THEN 0 ELSE 1 ) width = 1 ).
      WHEN zparq2a_if_format=>c_type-int32.
        bytes->write_int32_le( CONV #( value ) ).
      WHEN zparq2a_if_format=>c_type-int64.
        bytes->write_int64_le( CONV #( value ) ).
      WHEN zparq2a_if_format=>c_type-float.
        bytes->write_float( CONV #( value ) ).
      WHEN zparq2a_if_format=>c_type-double.
        bytes->write_double( CONV #( value ) ).
      WHEN zparq2a_if_format=>c_type-byte_array.
        binary = value.
        bytes->write_int32_le( xstrlen( binary ) ).
        bytes->write_bytes( binary ).
      WHEN zparq2a_if_format=>c_type-fixed_len_byte_array.
        binary = value.
        IF xstrlen( binary ) <> type_length.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |FIXED_LEN_BYTE_ARRAY({ type_length }) got { xstrlen( binary ) } bytes|.
        ENDIF.
        bytes->write_bytes( binary ).
    ENDCASE.
  ENDMETHOD.

  METHOD zparq2a_if_encoder~flush.
    IF physical_type = zparq2a_if_format=>c_type-boolean.
      result = bits->get_result( ).
      bits = NEW #( ).
    ELSE.
      result = bytes->get_result( ).
      bytes = NEW #( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
