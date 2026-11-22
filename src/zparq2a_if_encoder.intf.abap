"! <p class="shorttext synchronized">Parquet: value encoder</p>
"! Encodes the values of one column, one value at a time, into the bytes of
"! a page. A writer picks one implementation per column, for example PLAIN for
"! the values and the RLE / bit-packing hybrid for definition levels.
INTERFACE zparq2a_if_encoder
  PUBLIC.

  "! Encoding this implementation writes, one of ZPARQ2A_IF_FORMAT=>C_ENCODING
  METHODS get_encoding
    RETURNING
      VALUE(result) TYPE i.

  "! Adds the next value
  "! @parameter value | a value the encoder accepts, see the implementation
  "! @raising zparq2a_cx_error | the value does not fit the encoder
  METHODS put
    IMPORTING
      value TYPE simple
    RAISING
      zparq2a_cx_error.

  "! Encoded values added since the last call; the encoder then starts over
  METHODS flush
    RETURNING
      VALUE(result) TYPE xstring
    RAISING
      zparq2a_cx_error.

ENDINTERFACE.
