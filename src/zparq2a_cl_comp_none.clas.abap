"! <p class="shorttext synchronized">Parquet: no compression</p>
"! Codec UNCOMPRESSED: passes page bodies through unchanged.
CLASS zparq2a_cl_comp_none DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zparq2a_if_compressor.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS zparq2a_cl_comp_none IMPLEMENTATION.

  METHOD zparq2a_if_compressor~get_codec.
    result = zparq2a_if_compressor=>codecs-uncompressed.
  ENDMETHOD.

  METHOD zparq2a_if_compressor~compress.
    result = input.
  ENDMETHOD.

  METHOD zparq2a_if_compressor~decompress.
    result = input.
  ENDMETHOD.

ENDCLASS.
