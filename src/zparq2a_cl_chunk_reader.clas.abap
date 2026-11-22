"! <p class="shorttext synchronized">Parquet: column chunk reader</p>
"! Reads the values of one column chunk, one after another, page by page.
"! Data pages v1 and v2 are read, index pages are skipped. Values must be
"! PLAIN, or RLE for BOOLEAN; definition levels the RLE / bit-packing hybrid.
"! The column must be flat: required or optional, not repeated.
CLASS zparq2a_cl_chunk_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter file | the whole Parquet file
    "! @parameter chunk | the column chunk, from the footer
    "! @parameter element | the leaf of the schema the chunk belongs to
    "! @parameter compressor | for the codec of the chunk
    "! @raising zparq2a_cx_error | the chunk does not fit the file or is not supported
    METHODS constructor
      IMPORTING
        file       TYPE xstring
        chunk      TYPE zparq2a_if_format=>ty_column_chunk
        element    TYPE zparq2a_if_format=>ty_schema_element
        compressor TYPE REF TO zparq2a_if_compressor
      RAISING
        zparq2a_cx_error.

    "! Reads the next value of the column
    "! @parameter value | the value as ZPARQ2A_CL_DEC_PLAIN returns it; initial for a null
    "! @parameter null | the value is null
    "! @raising zparq2a_cx_error | no more values, or a page is not valid or not supported
    METHODS read
      EXPORTING
        value TYPE simple
        null  TYPE abap_bool
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA file TYPE xstring.
    DATA name TYPE string.
    DATA physical_type TYPE i.
    DATA type_length TYPE i.
    DATA optional TYPE abap_bool.
    DATA compressor TYPE REF TO zparq2a_if_compressor.
    "! Offset of the next page header
    DATA position TYPE int8.
    "! Offset after the last page of the chunk
    DATA chunk_end TYPE int8.
    "! Values of the chunk not read yet
    DATA chunk_left TYPE int8.
    "! Values of the current page not read yet
    DATA page_left TYPE i.
    DATA levels TYPE REF TO zparq2a_if_decoder.
    DATA values TYPE REF TO zparq2a_if_decoder.
    "! VALUES returns BOOLEAN values as 0 and 1, from encoding RLE
    DATA rle_booleans TYPE abap_bool.

    METHODS next_page
      RAISING
        zparq2a_cx_error.

    "! @parameter stored | the page as stored, after the header
    METHODS load_page_v1
      IMPORTING
        header TYPE zparq2a_if_format=>ty_page_header
        stored TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS load_page_v2
      IMPORTING
        header TYPE zparq2a_if_format=>ty_page_header
        stored TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! Sets VALUES for the values of a page
    "! @parameter data | the values, after the levels
    METHODS load_values
      IMPORTING
        encoding TYPE i
        data     TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS decompress
      IMPORTING
        stored        TYPE xstring
        expected      TYPE i
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS raise_error
      IMPORTING
        text TYPE string
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_chunk_reader IMPLEMENTATION.

  METHOD constructor.
    me->file = file.
    me->compressor = compressor.
    name = element-name.
    physical_type = element-type.
    type_length = element-type_length.

    IF chunk-has_meta_data = abap_false OR chunk-has_file_path = abap_true.
      raise_error( `the column chunk is in another file` ).
    ENDIF.
    DATA(meta_data) = chunk-meta_data.
    IF meta_data-type <> element-type.
      raise_error( |the chunk has physical type { meta_data-type }, the schema { element-type }| ).
    ENDIF.
    IF meta_data-codec <> compressor->get_codec( ).
      raise_error( |the chunk has codec { meta_data-codec }, the compressor { compressor->get_codec( ) }| ).
    ENDIF.
    CASE element-repetition_type.
      WHEN zparq2a_if_format=>c_repetition-required.
      WHEN zparq2a_if_format=>c_repetition-optional.
        optional = abap_true.
      WHEN OTHERS.
        raise_error( `repeated columns are not supported` ).
    ENDCASE.

    " a dictionary page, if any, comes first
    position = meta_data-data_page_offset.
    IF meta_data-has_dictionary_page_offset = abap_true AND meta_data-dictionary_page_offset > 0
        AND meta_data-dictionary_page_offset < position.
      position = meta_data-dictionary_page_offset.
    ENDIF.
    chunk_end = position + meta_data-total_compressed_size.
    IF position < 0 OR meta_data-total_compressed_size < 0 OR chunk_end > xstrlen( file ).
      raise_error( |the chunk at offset { position } with { meta_data-total_compressed_size } bytes | &&
                   |does not fit the file of { xstrlen( file ) } bytes| ).
    ENDIF.
    chunk_left = meta_data-num_values.
  ENDMETHOD.

  METHOD read.
    DATA level TYPE i.
    DATA bit TYPE i.

    CLEAR: value, null.
    IF chunk_left <= 0.
      raise_error( `no more values` ).
    ENDIF.
    WHILE page_left = 0.
      next_page( ).
    ENDWHILE.

    IF levels IS BOUND.
      levels->next( IMPORTING value = level ).
      IF level = 0.
        null = abap_true.
      ENDIF.
    ENDIF.
    IF null = abap_false AND rle_booleans = abap_true.
      values->next( IMPORTING value = bit ).
      value = xsdbool( bit = 1 ).
    ELSEIF null = abap_false.
      values->next( IMPORTING value = value ).
    ENDIF.
    page_left = page_left - 1.
    chunk_left = chunk_left - 1.
  ENDMETHOD.

  METHOD next_page.
    DATA offset TYPE i.
    DATA length TYPE i.
    DATA stored TYPE xstring.

    DO.
      IF position >= chunk_end.
        raise_error( |the pages end before the last { chunk_left } values| ).
      ENDIF.
      offset = position.
      zparq2a_cl_metadata=>decode_page_header(
        EXPORTING
          data   = file
          offset = offset
        IMPORTING
          header = DATA(header)
          length = length ).
      offset = offset + length.
      IF header-compressed_page_size < 0 OR offset + header-compressed_page_size > chunk_end.
        raise_error( |the page at offset { position } ends after the chunk| ).
      ENDIF.
      stored = file+offset(header-compressed_page_size).
      position = offset + header-compressed_page_size.

      CASE header-type.
        WHEN zparq2a_if_format=>c_page_type-data_page.
          load_page_v1( header = header stored = stored ).
          RETURN.
        WHEN zparq2a_if_format=>c_page_type-data_page_v2.
          load_page_v2( header = header stored = stored ).
          RETURN.
        WHEN zparq2a_if_format=>c_page_type-dictionary_page.
          raise_error( `dictionary encoding is not supported yet` ).
        WHEN OTHERS.
          " index pages and page types added later carry no values of the column
      ENDCASE.
    ENDDO.
  ENDMETHOD.

  METHOD load_page_v1.
    IF header-has_data_page_header = abap_false.
      raise_error( |the data page at offset { position } has no data page header| ).
    ENDIF.
    DATA(page) = header-data_page_header.
    IF page-num_values < 0.
      raise_error( |a data page has { page-num_values } values| ).
    ENDIF.

    DATA(body) = NEW zparq2a_cl_byte_reader( decompress( stored = stored expected = header-uncompressed_page_size ) ).
    " flat columns have no repetition levels
    CLEAR levels.
    IF optional = abap_true.
      IF page-definition_level_encoding <> zparq2a_if_format=>c_encoding-rle.
        raise_error( |definition levels in encoding { page-definition_level_encoding } are not supported| ).
      ENDIF.
      DATA(length) = body->read_int32_le( ).
      levels = NEW zparq2a_cl_dec_rle( bit_width = 1 data = body->read_bytes( length ) ).
    ENDIF.
    load_values( encoding = page-encoding data = body->read_bytes( body->get_remaining( ) ) ).
    page_left = page-num_values.
  ENDMETHOD.

  METHOD load_page_v2.
    DATA levels_part TYPE xstring.
    DATA values_part TYPE xstring.

    IF header-has_data_page_header_v2 = abap_false.
      raise_error( |the data page at offset { position } has no data page header| ).
    ENDIF.
    DATA(page) = header-data_page_header_v2.
    IF page-num_values < 0.
      raise_error( |a data page has { page-num_values } values| ).
    ENDIF.
    IF page-rep_levels_byte_length <> 0.
      raise_error( `a flat column has repetition levels` ).
    ENDIF.
    DATA(levels_length) = page-def_levels_byte_length.
    IF levels_length < 0 OR levels_length > xstrlen( stored ).
      raise_error( |the definition levels of { levels_length } bytes do not fit the page| ).
    ENDIF.

    " the levels come first and are never compressed
    levels_part = stored(levels_length).
    values_part = stored+levels_length.
    IF page-has_is_compressed = abap_false OR page-is_compressed = abap_true.
      values_part = decompress( stored = values_part expected = header-uncompressed_page_size - levels_length ).
    ENDIF.

    CLEAR levels.
    IF optional = abap_true.
      levels = NEW zparq2a_cl_dec_rle( bit_width = 1 data = levels_part ).
    ENDIF.
    load_values( encoding = page-encoding data = values_part ).
    page_left = page-num_values.
  ENDMETHOD.

  METHOD load_values.
    rle_booleans = abap_false.
    CASE encoding.
      WHEN zparq2a_if_format=>c_encoding-plain.
        values = NEW zparq2a_cl_dec_plain( data          = data
                                           physical_type = physical_type
                                           type_length   = type_length ).
      WHEN zparq2a_if_format=>c_encoding-rle.
        IF physical_type <> zparq2a_if_format=>c_type-boolean.
          raise_error( `encoding RLE is only supported for BOOLEAN values` ).
        ENDIF.
        " the runs come after their length, as for levels in data pages v1
        DATA(input) = NEW zparq2a_cl_byte_reader( data ).
        DATA(length) = input->read_int32_le( ).
        values = NEW zparq2a_cl_dec_rle( bit_width = 1 data = input->read_bytes( length ) ).
        rle_booleans = abap_true.
      WHEN zparq2a_if_format=>c_encoding-plain_dictionary OR zparq2a_if_format=>c_encoding-rle_dictionary.
        raise_error( `dictionary encoding is not supported yet` ).
      WHEN OTHERS.
        raise_error( |values in encoding { encoding } are not supported| ).
    ENDCASE.
  ENDMETHOD.

  METHOD decompress.
    result = compressor->decompress( stored ).
    IF xstrlen( result ) <> expected.
      raise_error( |a page has { xstrlen( result ) } bytes uncompressed, the header says { expected }| ).
    ENDIF.
  ENDMETHOD.

  METHOD raise_error.
    RAISE EXCEPTION TYPE zparq2a_cx_error
      EXPORTING
        text = |Column { name }: { text }|.
  ENDMETHOD.

ENDCLASS.
