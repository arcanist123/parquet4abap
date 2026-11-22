"! <p class="shorttext synchronized">Parquet: sequential byte reader</p>
"! Reads values one after another from an <em>xstring</em>. Every read past the
"! end of the data raises ZPARQ2A_CX_ERROR.
CLASS zparq2a_cl_byte_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        data TYPE xstring.

    "! @parameter result | 0..255
    METHODS read_byte
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_bytes
      IMPORTING
        length        TYPE i
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS skip
      IMPORTING
        length TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_int32_le
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_int64_le
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    METHODS read_float
      RETURNING
        VALUE(result) TYPE f
      RAISING
        zparq2a_cx_error.

    METHODS read_double
      RETURNING
        VALUE(result) TYPE f
      RAISING
        zparq2a_cx_error.

    "! Unsigned LEB128 varint of up to 10 bytes
    "! @parameter result | unsigned 64-bit bit pattern
    METHODS read_varint
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    "! ZigZag-encoded varint
    METHODS read_zigzag_varint
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    "! Offset of the next byte to read
    METHODS get_position
      RETURNING
        VALUE(result) TYPE i.

    METHODS get_remaining
      RETURNING
        VALUE(result) TYPE i.

    METHODS is_at_end
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA bytes TYPE xstring.
    DATA length TYPE i.
    DATA position TYPE i.

    METHODS ensure
      IMPORTING
        count TYPE i
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_byte_reader IMPLEMENTATION.

  METHOD constructor.
    bytes = data.
    length = xstrlen( data ).
  ENDMETHOD.

  METHOD ensure.
    IF count < 0.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Negative length { count }|.
    ENDIF.
    IF count > length - position.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Unexpected end of data: { count } bytes needed at offset { position }, { length - position } left|.
    ENDIF.
  ENDMETHOD.

  METHOD read_byte.
    DATA byte TYPE x LENGTH 1.

    ensure( 1 ).
    byte = bytes+position(1).
    result = byte.
    position = position + 1.
  ENDMETHOD.

  METHOD read_bytes.
    ensure( length ).
    IF length > 0.
      result = bytes+position(length).
      position = position + length.
    ENDIF.
  ENDMETHOD.

  METHOD skip.
    ensure( length ).
    position = position + length.
  ENDMETHOD.

  METHOD read_int32_le.
    result = zparq2a_cl_bytes=>int32_from_le( read_bytes( 4 ) ).
  ENDMETHOD.

  METHOD read_int64_le.
    result = zparq2a_cl_bytes=>int64_from_le( read_bytes( 8 ) ).
  ENDMETHOD.

  METHOD read_float.
    result = zparq2a_cl_bytes=>float_from_le( read_bytes( 4 ) ).
  ENDMETHOD.

  METHOD read_double.
    result = zparq2a_cl_bytes=>double_from_le( read_bytes( 8 ) ).
  ENDMETHOD.

  METHOD read_varint.
    DATA multiplier TYPE int8 VALUE 1.
    DATA group TYPE int8.
    DATA count TYPE i.

    DATA(start) = position.
    DO.
      count = count + 1.
      DATA(byte) = read_byte( ).
      group = byte MOD 128.

      IF count < 10.
        result = result + group * multiplier.
      ELSEIF group <= 1.
        " the 10th group carries bit 63 only
        result = result + group * zparq2a_cl_bytes=>min_int8.
      ELSE.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Varint at offset { start } does not fit 64 bits|.
      ENDIF.

      IF byte < 128.
        RETURN.
      ELSEIF count = 10.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Varint at offset { start } is longer than 10 bytes|.
      ELSEIF count < 9.
        multiplier = multiplier * 128.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD read_zigzag_varint.
    result = zparq2a_cl_bytes=>zigzag_decode( read_varint( ) ).
  ENDMETHOD.

  METHOD get_position.
    result = position.
  ENDMETHOD.

  METHOD get_remaining.
    result = length - position.
  ENDMETHOD.

  METHOD is_at_end.
    result = xsdbool( position >= length ).
  ENDMETHOD.

ENDCLASS.
