"! <p class="shorttext synchronized">Parquet: GZIP compression</p>
"! Codec GZIP: page bodies in the gzip format of RFC 1952, through
"! <em>CL_ABAP_GZIP</em>.
CLASS zparq2a_cl_comp_gzip DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_compressor.

    "! @parameter level | 0 (store) .. 9 (smallest)
    "! @raising zparq2a_cx_error | level out of range
    METHODS constructor
      IMPORTING
        level TYPE i DEFAULT 6
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA level TYPE i.

ENDCLASS.


CLASS zparq2a_cl_comp_gzip IMPLEMENTATION.

  METHOD constructor.
    IF level < 0 OR level > 9.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |GZIP level { level } is outside 0..9|.
    ENDIF.
    me->level = level.
  ENDMETHOD.

  METHOD zparq2a_if_compressor~get_codec.
    result = zparq2a_if_compressor=>codecs-gzip.
  ENDMETHOD.

  METHOD zparq2a_if_compressor~compress.
    TRY.
        cl_abap_gzip=>compress_binary_with_header(
          EXPORTING
            raw_in         = input
            compress_level = level
          IMPORTING
            gzip_out       = result ).
      CATCH cx_parameter_invalid_range cx_sy_buffer_overflow cx_sy_compression_error INTO DATA(error).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text     = `GZIP compression failed`
            previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zparq2a_if_compressor~decompress.
    TRY.
        cl_abap_gzip=>decompress_binary_with_header(
          EXPORTING
            gzip_in = input
          IMPORTING
            raw_out = result ).
      CATCH cx_parameter_invalid cx_sy_buffer_overflow cx_sy_compression_error INTO DATA(error).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text     = `Data is not valid GZIP`
            previous = error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
