"! <p class="shorttext synchronized">Parquet: value decoder</p>
"! Decodes the values of one column from the bytes of a page, one value at a
"! time, the counterpart of ZPARQ2A_IF_ENCODER. A reader picks one
"! implementation per page, for example PLAIN for the values and the RLE /
"! bit-packing hybrid for definition levels.
INTERFACE zparq2a_if_decoder
  PUBLIC.

  "! Encoding this implementation reads, one of ZPARQ2A_IF_FORMAT=>C_ENCODING
  METHODS get_encoding
    RETURNING
      VALUE(result) TYPE i.

  "! Reads the next value
  "! @parameter value | the value, in a type the decoder fills, see the implementation
  "! @raising zparq2a_cx_error | no more values, or the data is not valid
  METHODS next
    EXPORTING
      value TYPE simple
    RAISING
      zparq2a_cx_error.

ENDINTERFACE.
