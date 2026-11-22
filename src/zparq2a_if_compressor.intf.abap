"! <p class="shorttext synchronized">Parquet: page compression codec</p>
"! Compresses and decompresses the body of a Parquet page.
"! Platform-specific codecs (for example GZIP) sit behind this interface,
"! so each toolchain can plug in what it supports.
INTERFACE zparq2a_if_compressor
  PUBLIC.

  CONSTANTS:
    "! Values of the Thrift enum CompressionCodec in parquet.thrift
    BEGIN OF codecs,
      uncompressed TYPE i VALUE 0,
      snappy       TYPE i VALUE 1,
      gzip         TYPE i VALUE 2,
      lzo          TYPE i VALUE 3,
      brotli       TYPE i VALUE 4,
      lz4          TYPE i VALUE 5,
      zstd         TYPE i VALUE 6,
      lz4_raw      TYPE i VALUE 7,
    END OF codecs.

  "! Codec this implementation handles, one of the values in CODECS
  METHODS get_codec
    RETURNING
      VALUE(result) TYPE i.

  METHODS compress
    IMPORTING
      input         TYPE xstring
    RETURNING
      VALUE(result) TYPE xstring
    RAISING
      zparq2a_cx_error.

  METHODS decompress
    IMPORTING
      input         TYPE xstring
    RETURNING
      VALUE(result) TYPE xstring
    RAISING
      zparq2a_cx_error.

ENDINTERFACE.
