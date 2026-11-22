"! <p class="shorttext synchronized">Parquet: benchmark</p>
"! Generates a table from a seed, writes it with ZPARQ2A_CL_WRITER and reads
"! the file back with ZPARQ2A_CL_READER, and times both. The report
"! ZPARQ2A_BENCHMARK runs it; tools/run-bench.mjs runs it on the toolchains.
"! <p>The same seed gives the same rows on every toolchain, so an uncompressed
"! file is expected to have the same bytes everywhere.</p>
CLASS zparq2a_cl_benchmark DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_price TYPE p LENGTH 8 DECIMALS 2.

    TYPES:
      "! One row: a column of each common kind, and one optional column
      BEGIN OF ty_row,
        id       TYPE i,
        quantity TYPE int8,
        price    TYPE ty_price,
        ratio    TYPE f,
        flag     TYPE abap_bool,
        name     TYPE string,
        day      TYPE d,
        note     TYPE REF TO string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES:
      "! One write and read; times in microseconds
      BEGIN OF ty_run,
        rows     TYPE i,
        bytes    TYPE i,
        write_us TYPE i,
        read_us  TYPE i,
        file     TYPE xstring,
      END OF ty_run.

    "! @parameter seed | any integer; seeds that differ modulo 2^31 - 2 give other rows
    METHODS constructor
      IMPORTING
        seed TYPE i.

    "! The next COUNT rows of the seed: every fourth row has no note
    METHODS rows
      IMPORTING
        count         TYPE i
      RETURNING
        VALUE(result) TYPE ty_rows.

    "! Writes ROWS with COMPRESSOR, reads the file back and compares the rows
    "! @raising zparq2a_cx_error | the writer or reader failed, or the rows read differ from ROWS
    METHODS run
      IMPORTING
        rows          TYPE ty_rows
        compressor    TYPE REF TO zparq2a_if_compressor
      RETURNING
        VALUE(result) TYPE ty_run
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    "! Last value of the random generator, 1 .. 2^31 - 2
    DATA state TYPE int8.

    "! Park and Miller's minimal standard generator: 16807 * state modulo 2^31 - 1
    METHODS next
      RETURNING
        VALUE(result) TYPE int8.

    CLASS-METHODS compare
      IMPORTING
        expected TYPE ty_rows
        actual   TYPE ty_rows
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_benchmark IMPLEMENTATION.

  METHOD constructor.
    state = abs( seed ) MOD 2147483646 + 1.
  ENDMETHOD.

  METHOD next.
    state = state * 16807 MOD 2147483647.
    result = state.
  ENDMETHOD.

  METHOD rows.
    DATA row TYPE ty_row.
    DATA days TYPE i.
    DATA epoch TYPE d VALUE '19700101'.

    DO count TIMES.
      CLEAR row.
      row-id = lines( result ) + 1.
      row-quantity = next( ) * 4096.
      row-price = next( ) MOD 100000000 / 100.
      row-ratio = next( ) / 2147483647.
      row-flag = xsdbool( next( ) MOD 2 = 0 ).
      row-name = |item { next( ) MOD 1000 }|.
      days = next( ) MOD 25000.
      row-day = epoch + days.
      IF row-id MOD 4 <> 0.
        row-note = NEW #( |note { row-id }| ).
      ENDIF.
      APPEND row TO result.
    ENDDO.
  ENDMETHOD.

  METHOD run.
    DATA started TYPE i.
    DATA finished TYPE i.
    DATA read TYPE ty_rows.

    DATA(writer) = NEW zparq2a_cl_writer( compressor ).
    DATA(reader) = NEW zparq2a_cl_reader( ).
    reader->set_compressor( compressor ).

    GET RUN TIME FIELD started.
    result-file = writer->write( rows ).
    GET RUN TIME FIELD finished.
    result-write_us = finished - started.

    GET RUN TIME FIELD started.
    reader->read( EXPORTING file = result-file IMPORTING data = read ).
    GET RUN TIME FIELD finished.
    result-read_us = finished - started.

    result-rows = lines( rows ).
    result-bytes = xstrlen( result-file ).
    compare( expected = rows actual = read ).
  ENDMETHOD.

  METHOD compare.
    DATA left TYPE ty_row.
    DATA right TYPE ty_row.
    DATA same_note TYPE abap_bool.

    IF lines( actual ) <> lines( expected ).
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |{ lines( actual ) } rows read, { lines( expected ) } written|.
    ENDIF.

    LOOP AT expected INTO left.
      right = actual[ sy-tabix ].
      IF left-note IS BOUND AND right-note IS BOUND.
        same_note = xsdbool( left-note->* = right-note->* ).
      ELSE.
        same_note = xsdbool( left-note IS NOT BOUND AND right-note IS NOT BOUND ).
      ENDIF.
      CLEAR: left-note, right-note.
      IF same_note = abap_false OR left <> right.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Row { left-id } read back with other values|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
