"! <p class="shorttext synchronized">Parquet: bit-packing reader</p>
"! Reads unsigned values of 0 to 32 bits each, least significant bit first,
"! the counterpart of ZPARQ2A_CL_BIT_WRITER.
CLASS zparq2a_cl_bit_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        data TYPE xstring.

    "! @parameter width | 0..32
    METHODS read
      IMPORTING
        width         TYPE i
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    "! Bits not read yet, including the padding bits of the last byte
    METHODS get_remaining_bits
      RETURNING
        VALUE(result) TYPE int8.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA bytes TYPE xstring.
    DATA length TYPE i.
    "! Offset of the next byte to load into PENDING
    DATA position TYPE i.
    "! Loaded bits not returned yet, the oldest in the lowest position
    DATA pending TYPE int8.
    DATA pending_bits TYPE i.

ENDCLASS.


CLASS zparq2a_cl_bit_reader IMPLEMENTATION.

  METHOD constructor.
    bytes = data.
    length = xstrlen( data ).
  ENDMETHOD.

  METHOD read.
    DATA byte TYPE x LENGTH 1.
    DATA byte_value TYPE int8.

    IF width < 0 OR width > 32.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Bit width { width } is outside 0..32|.
    ENDIF.

    WHILE pending_bits < width.
      IF position >= length.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Unexpected end of bit-packed data: { width } bits needed, { pending_bits } left|.
      ENDIF.
      byte = bytes+position(1).
      byte_value = byte.
      pending = pending + byte_value * zparq2a_cl_bytes=>power_of_two( pending_bits ).
      pending_bits = pending_bits + 8.
      position = position + 1.
    ENDWHILE.

    DATA(divisor) = zparq2a_cl_bytes=>power_of_two( width ).
    result = pending MOD divisor.
    pending = pending DIV divisor.
    pending_bits = pending_bits - width.
  ENDMETHOD.

  METHOD get_remaining_bits.
    result = ( length - position ) * 8 + pending_bits.
  ENDMETHOD.

ENDCLASS.
