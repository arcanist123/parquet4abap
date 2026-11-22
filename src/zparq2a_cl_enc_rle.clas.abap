"! <p class="shorttext synchronized">Parquet: RLE / bit-packing hybrid encoder</p>
"! Encoding RLE of the Parquet spec, as used for definition and repetition
"! levels and dictionary indices: runs of 8 or more equal values become RLE
"! runs, everything else becomes bit-packed runs of groups of 8 values. The
"! result has no length prefix; data pages v1 put one in front of the levels.
"! PUT takes unsigned integers of up to BIT_WIDTH bits.
CLASS zparq2a_cl_enc_rle DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_encoder.

    "! @parameter bit_width | 0..32
    "! @raising zparq2a_cx_error | bit width out of range
    METHODS constructor
      IMPORTING
        bit_width TYPE i
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES ty_values TYPE STANDARD TABLE OF int8 WITH EMPTY KEY.

    "! Shortest run that is written as an RLE run
    CONSTANTS min_repeat TYPE i VALUE 8.

    DATA bit_width TYPE i.
    DATA limit TYPE int8.
    DATA values TYPE ty_values.
    DATA output TYPE REF TO zparq2a_cl_byte_writer.

    "! Number of values from START on that equal the value at START
    METHODS run_length
      IMPORTING
        start         TYPE i
      RETURNING
        VALUE(result) TYPE i.

    METHODS write_repeated
      IMPORTING
        value TYPE int8
        count TYPE i
      RAISING
        zparq2a_cx_error.

    "! Bit-packed run of the values FIRST to LAST, padded to whole groups of 8
    METHODS write_literals
      IMPORTING
        first TYPE i
        last  TYPE i
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_enc_rle IMPLEMENTATION.

  METHOD constructor.
    IF bit_width < 0 OR bit_width > 32.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Bit width { bit_width } is outside 0..32|.
    ENDIF.
    me->bit_width = bit_width.
    limit = zparq2a_cl_bytes=>power_of_two( bit_width ).
  ENDMETHOD.

  METHOD zparq2a_if_encoder~get_encoding.
    result = zparq2a_if_format=>c_encoding-rle.
  ENDMETHOD.

  METHOD zparq2a_if_encoder~put.
    DATA number TYPE int8.

    number = value.
    IF number < 0 OR number >= limit.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { number } does not fit { bit_width } bits|.
    ENDIF.
    APPEND number TO values.
  ENDMETHOD.

  METHOD zparq2a_if_encoder~flush.
    DATA(count) = lines( values ).
    DATA(position) = 1.
    " values from LITERAL_START on wait for a bit-packed run
    DATA(literal_start) = 1.

    output = NEW #( ).
    WHILE position <= count.
      DATA(run) = run_length( position ).
      IF run >= min_repeat.
        " a bit-packed run holds whole groups of 8: fill the last group from this run
        DATA(fill) = ( min_repeat - ( position - literal_start ) MOD min_repeat ) MOD min_repeat.
        IF run - fill >= min_repeat.
          position = position + fill.
          IF position > literal_start.
            write_literals( first = literal_start last = position - 1 ).
          ENDIF.
          write_repeated( value = values[ position ] count = run - fill ).
          position = position + run - fill.
          literal_start = position.
          CONTINUE.
        ENDIF.
      ENDIF.
      position = position + run.
    ENDWHILE.
    IF count >= literal_start.
      write_literals( first = literal_start last = count ).
    ENDIF.

    result = output->get_result( ).
    CLEAR values.
  ENDMETHOD.

  METHOD run_length.
    DATA(value) = values[ start ].
    result = 1.
    LOOP AT values FROM start + 1 INTO DATA(next).
      IF next <> value.
        RETURN.
      ENDIF.
      result = result + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD write_repeated.
    " header: count << 1; then the value in ceil(bit_width / 8) bytes, little-endian
    output->write_varint( CONV #( count * 2 ) ).
    DATA(rest) = value.
    DO ( bit_width + 7 ) DIV 8 TIMES.
      output->write_byte( CONV #( rest MOD 256 ) ).
      rest = rest DIV 256.
    ENDDO.
  ENDMETHOD.

  METHOD write_literals.
    DATA(groups) = ( last - first + min_repeat ) DIV min_repeat.
    DATA(packer) = NEW zparq2a_cl_bit_writer( ).

    " header: groups << 1 | 1
    output->write_varint( CONV #( groups * 2 + 1 ) ).
    LOOP AT values FROM first TO last INTO DATA(value).
      packer->write( value = value width = bit_width ).
    ENDLOOP.
    DO groups * min_repeat - ( last - first + 1 ) TIMES.
      packer->write( value = 0 width = bit_width ).
    ENDDO.
    output->write_bytes( packer->get_result( ) ).
  ENDMETHOD.

ENDCLASS.
