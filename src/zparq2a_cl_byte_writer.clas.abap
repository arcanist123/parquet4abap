"! <p class="shorttext synchronized">Parquet: sequential byte writer</p>
"! Appends values to a growing <em>xstring</em>.
CLASS zparq2a_cl_byte_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter value | 0..255
    METHODS write_byte
      IMPORTING
        value TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS write_bytes
      IMPORTING
        value TYPE xstring.

    METHODS write_int32_le
      IMPORTING
        value TYPE i.

    METHODS write_int64_le
      IMPORTING
        value TYPE int8.

    "! @raising zparq2a_cx_error | value is too large for FLOAT
    METHODS write_float
      IMPORTING
        value TYPE f
      RAISING
        zparq2a_cx_error.

    METHODS write_double
      IMPORTING
        value TYPE f.

    "! Unsigned LEB128 varint
    "! @parameter value | unsigned 64-bit bit pattern
    METHODS write_varint
      IMPORTING
        value TYPE int8.

    METHODS write_zigzag_varint
      IMPORTING
        value TYPE int8.

    METHODS get_result
      RETURNING
        VALUE(result) TYPE xstring.

    METHODS get_length
      RETURNING
        VALUE(result) TYPE i.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA buffer TYPE xstring.

ENDCLASS.


CLASS zparq2a_cl_byte_writer IMPLEMENTATION.

  METHOD write_byte.
    DATA byte TYPE x LENGTH 1.

    IF value < 0 OR value > 255.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Byte value { value } is outside 0..255|.
    ENDIF.
    byte = value.
    CONCATENATE buffer byte INTO buffer IN BYTE MODE.
  ENDMETHOD.

  METHOD write_bytes.
    CONCATENATE buffer value INTO buffer IN BYTE MODE.
  ENDMETHOD.

  METHOD write_int32_le.
    write_bytes( zparq2a_cl_bytes=>int32_to_le( value ) ).
  ENDMETHOD.

  METHOD write_int64_le.
    write_bytes( zparq2a_cl_bytes=>int64_to_le( value ) ).
  ENDMETHOD.

  METHOD write_float.
    write_bytes( zparq2a_cl_bytes=>float_to_le( value ) ).
  ENDMETHOD.

  METHOD write_double.
    write_bytes( zparq2a_cl_bytes=>double_to_le( value ) ).
  ENDMETHOD.

  METHOD write_varint.
    write_bytes( zparq2a_cl_bytes=>varint_encode( value ) ).
  ENDMETHOD.

  METHOD write_zigzag_varint.
    write_varint( zparq2a_cl_bytes=>zigzag_encode( value ) ).
  ENDMETHOD.

  METHOD get_result.
    result = buffer.
  ENDMETHOD.

  METHOD get_length.
    result = xstrlen( buffer ).
  ENDMETHOD.

ENDCLASS.
