"! <p class="shorttext synchronized">Parquet: RLE / bit-packing hybrid decoder</p>
"! Encoding RLE of the Parquet spec, the counterpart of ZPARQ2A_CL_ENC_RLE:
"! a sequence of RLE runs and bit-packed runs, without a length prefix. NEXT
"! returns unsigned integers of up to BIT_WIDTH bits, as <em>int8</em> or
"! converted to the type of the actual parameter.
"! <p>The last bit-packed run may be cut short, as some writers leave out the
"! padding: values past the end of the data then raise an error.</p>
CLASS zparq2a_cl_dec_rle DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_decoder.

    "! @parameter bit_width | 0..32
    "! @raising zparq2a_cx_error | bit width out of range
    METHODS constructor
      IMPORTING
        bit_width TYPE i
        data      TYPE xstring
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    "! Values in a group of a bit-packed run
    CONSTANTS group_size TYPE i VALUE 8.
    "! Largest count in a run header
    CONSTANTS max_run TYPE int8 VALUE 2147483647.

    DATA bit_width TYPE i.
    DATA input TYPE REF TO zparq2a_cl_byte_reader.
    "! Values left in the current run
    DATA run_left TYPE int8.
    "! The current run is bit-packed and its values come from PACKED
    DATA literal TYPE abap_bool.
    DATA packed TYPE REF TO zparq2a_cl_bit_reader.
    "! The value of the current RLE run
    DATA repeated TYPE int8.

    METHODS read_run
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_dec_rle IMPLEMENTATION.

  METHOD constructor.
    IF bit_width < 0 OR bit_width > 32.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Bit width { bit_width } is outside 0..32|.
    ENDIF.
    me->bit_width = bit_width.
    input = NEW #( data ).
  ENDMETHOD.

  METHOD zparq2a_if_decoder~get_encoding.
    result = zparq2a_if_format=>c_encoding-rle.
  ENDMETHOD.

  METHOD zparq2a_if_decoder~next.
    WHILE run_left = 0.
      read_run( ).
    ENDWHILE.
    IF literal = abap_true.
      value = packed->read( bit_width ).
    ELSE.
      value = repeated.
    ENDIF.
    run_left = run_left - 1.
  ENDMETHOD.

  METHOD read_run.
    DATA multiplier TYPE int8 VALUE 1.
    DATA length TYPE int8.

    IF input->is_at_end( ) = abap_true.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `No more values in RLE / bit-packed data`.
    ENDIF.
    DATA(header) = input->read_varint( ).
    " a page holds fewer than 2^31 values
    IF header < 0 OR header DIV 2 > max_run.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `Run header of RLE / bit-packed data is out of range`.
    ENDIF.

    IF header MOD 2 = 1.
      " bit-packed: header = groups << 1 | 1
      literal = abap_true.
      run_left = header DIV 2 * group_size.
      length = nmin( val1 = header DIV 2 * bit_width
                     val2 = CONV int8( input->get_remaining( ) ) ).
      packed = NEW #( input->read_bytes( CONV #( length ) ) ).
    ELSE.
      " RLE: header = count << 1, then the value in ceil(bit_width / 8) bytes, little-endian
      literal = abap_false.
      run_left = header DIV 2.
      repeated = 0.
      DO ( bit_width + 7 ) DIV 8 TIMES.
        repeated = repeated + input->read_byte( ) * multiplier.
        multiplier = multiplier * 256.
      ENDDO.
      IF repeated >= zparq2a_cl_bytes=>power_of_two( bit_width ).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |RLE run value { repeated } does not fit { bit_width } bits|.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
