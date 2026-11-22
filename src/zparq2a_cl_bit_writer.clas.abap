"! <p class="shorttext synchronized">Parquet: bit-packing writer</p>
"! Packs unsigned values of 0 to 32 bits each, least significant bit first,
"! as Parquet's bit-packed encoding does: the first value starts at bit 0 of
"! the first byte.
CLASS zparq2a_cl_bit_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter value | 0 .. 2^width - 1
    "! @parameter width | 0..32
    METHODS write
      IMPORTING
        value TYPE int8
        width TYPE i
      RAISING
        zparq2a_cx_error.

    "! Bytes written so far; a partly used last byte is padded with zero bits
    METHODS get_result
      RETURNING
        VALUE(result) TYPE xstring.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA buffer TYPE xstring.
    "! Bits not yet written to BUFFER, the oldest in the lowest position
    DATA pending TYPE int8.
    DATA pending_bits TYPE i.

ENDCLASS.


CLASS zparq2a_cl_bit_writer IMPLEMENTATION.

  METHOD write.
    DATA byte TYPE x LENGTH 1.

    IF width < 0 OR width > 32.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Bit width { width } is outside 0..32|.
    ENDIF.
    IF value < 0 OR value >= zparq2a_cl_bytes=>power_of_two( width ).
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { value } does not fit { width } bits|.
    ENDIF.

    pending = pending + value * zparq2a_cl_bytes=>power_of_two( pending_bits ).
    pending_bits = pending_bits + width.
    WHILE pending_bits >= 8.
      byte = pending MOD 256.
      CONCATENATE buffer byte INTO buffer IN BYTE MODE.
      pending = pending DIV 256.
      pending_bits = pending_bits - 8.
    ENDWHILE.
  ENDMETHOD.

  METHOD get_result.
    DATA byte TYPE x LENGTH 1.

    result = buffer.
    IF pending_bits > 0.
      byte = pending.
      CONCATENATE result byte INTO result IN BYTE MODE.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
