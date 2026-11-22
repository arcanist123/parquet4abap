"! <p class="shorttext synchronized">Parquet: writer</p>
"! Writes an internal table as a Parquet file, in memory. The schema comes from
"! the line type, see ZPARQ2A_CL_SCHEMA: components typed as data references
"! are optional columns, and an unbound reference is null.
"! <p>The file has one row group with one data page (v1) per column. Values are
"! PLAIN, definition levels use the RLE / bit-packing hybrid. Each column is
"! compressed with the writer's compressor, or one set for that column.</p>
CLASS zparq2a_cl_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Name of the application in the footer (created_by)
    CONSTANTS created_by TYPE string VALUE `parquet4abap`.

    "! @parameter compressor | for every column; default: no compression
    METHODS constructor
      IMPORTING
        compressor TYPE REF TO zparq2a_if_compressor OPTIONAL.

    "! Compresses one column with another codec
    "! @parameter column | name of the ABAP component
    METHODS set_column_compressor
      IMPORTING
        column     TYPE csequence
        compressor TYPE REF TO zparq2a_if_compressor.

    "! @raising zparq2a_cx_error | unsupported line type or a value that does not fit its column
    METHODS write
      IMPORTING
        data          TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_column_compressor,
        column     TYPE string,
        compressor TYPE REF TO zparq2a_if_compressor,
      END OF ty_column_compressor,
      ty_column_compressors TYPE HASHED TABLE OF ty_column_compressor WITH UNIQUE KEY column.

    "! Unscaled value of a DECIMAL: up to 31 digits
    TYPES ty_unscaled TYPE p LENGTH 16 DECIMALS 0.

    DATA compressor TYPE REF TO zparq2a_if_compressor.
    DATA column_compressors TYPE ty_column_compressors.

    METHODS check_column_compressors
      IMPORTING
        columns TYPE zparq2a_cl_schema=>ty_columns
      RAISING
        zparq2a_cx_error.

    "! Column chunk of one column: the page header and the page
    METHODS write_column
      IMPORTING
        data   TYPE ANY TABLE
        column TYPE zparq2a_cl_schema=>ty_column
        offset TYPE int8
      EXPORTING
        bytes  TYPE xstring
        chunk  TYPE zparq2a_if_format=>ty_column_chunk
      RAISING
        zparq2a_cx_error.

    "! Uncompressed page body: definition levels, if any, and values
    METHODS encode_page
      IMPORTING
        data       TYPE ANY TABLE
        column     TYPE zparq2a_cl_schema=>ty_column
      EXPORTING
        body       TYPE xstring
        null_count TYPE int8
      RAISING
        zparq2a_cx_error.

    "! Converts an ABAP value to the column's physical type and adds it
    "! @parameter factor | 10^scale, for DECIMAL columns
    METHODS put_value
      IMPORTING
        column  TYPE zparq2a_cl_schema=>ty_column
        encoder TYPE REF TO zparq2a_if_encoder
        factor  TYPE ty_unscaled
        value   TYPE simple
      RAISING
        zparq2a_cx_error.

    "! Big-endian two's complement in LENGTH bytes
    CLASS-METHODS decimal_bytes
      IMPORTING
        value         TYPE ty_unscaled
        length        TYPE i
      RETURNING
        VALUE(result) TYPE xstring.

ENDCLASS.


CLASS zparq2a_cl_writer IMPLEMENTATION.

  METHOD constructor.
    IF compressor IS BOUND.
      me->compressor = compressor.
    ELSE.
      me->compressor = NEW zparq2a_cl_comp_none( ).
    ENDIF.
  ENDMETHOD.

  METHOD set_column_compressor.
    DATA(name) = to_upper( column ).

    DELETE TABLE column_compressors WITH TABLE KEY column = name.
    INSERT VALUE #( column = name compressor = compressor ) INTO TABLE column_compressors.
  ENDMETHOD.

  METHOD check_column_compressors.
    LOOP AT column_compressors INTO DATA(entry).
      IF NOT line_exists( columns[ component = entry-column ] ).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |A compressor is set for column { entry-column }, which the table does not have|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD write.
    DATA metadata TYPE zparq2a_if_format=>ty_file_metadata.
    DATA row_group TYPE zparq2a_if_format=>ty_row_group.

    DATA(columns) = zparq2a_cl_schema=>from_table( data ).
    check_column_compressors( columns ).

    DATA(file) = NEW zparq2a_cl_byte_writer( ).
    file->write_bytes( CONV #( zparq2a_cl_metadata=>magic ) ).
    row_group-has_file_offset = abap_true.
    row_group-file_offset = file->get_length( ).
    row_group-has_total_compressed_size = abap_true.
    LOOP AT columns INTO DATA(column).
      write_column(
        EXPORTING
          data   = data
          column = column
          offset = file->get_length( )
        IMPORTING
          bytes  = DATA(bytes)
          chunk  = DATA(chunk) ).
      file->write_bytes( bytes ).
      row_group-total_byte_size = row_group-total_byte_size + chunk-meta_data-total_uncompressed_size.
      row_group-total_compressed_size = row_group-total_compressed_size + chunk-meta_data-total_compressed_size.
      APPEND chunk TO row_group-columns.
    ENDLOOP.
    row_group-num_rows = lines( data ).

    metadata-version = 1.
    metadata-schema = zparq2a_cl_schema=>to_elements( columns ).
    metadata-num_rows = lines( data ).
    APPEND row_group TO metadata-row_groups.
    metadata-has_created_by = abap_true.
    metadata-created_by = created_by.

    DATA(footer) = zparq2a_cl_metadata=>encode_file_metadata( metadata ).
    file->write_bytes( footer ).
    file->write_int32_le( xstrlen( footer ) ).
    file->write_bytes( CONV #( zparq2a_cl_metadata=>magic ) ).
    result = file->get_result( ).
  ENDMETHOD.

  METHOD write_column.
    DATA header TYPE zparq2a_if_format=>ty_page_header.

    DATA(codec) = VALUE #( column_compressors[ column = column-component ]-compressor DEFAULT compressor ).
    encode_page(
      EXPORTING
        data       = data
        column     = column
      IMPORTING
        body       = DATA(body)
        null_count = DATA(null_count) ).
    DATA(compressed) = codec->compress( body ).

    header-type = zparq2a_if_format=>c_page_type-data_page.
    header-uncompressed_page_size = xstrlen( body ).
    header-compressed_page_size = xstrlen( compressed ).
    header-has_data_page_header = abap_true.
    header-data_page_header = VALUE #( num_values                = lines( data )
                                       encoding                  = zparq2a_if_format=>c_encoding-plain
                                       definition_level_encoding = zparq2a_if_format=>c_encoding-rle
                                       repetition_level_encoding = zparq2a_if_format=>c_encoding-rle ).
    DATA(header_bytes) = zparq2a_cl_metadata=>encode_page_header( header ).
    CONCATENATE header_bytes compressed INTO bytes IN BYTE MODE.

    chunk-has_meta_data = abap_true.
    chunk-meta_data = VALUE #( type                    = column-element-type
                               path_in_schema          = VALUE #( ( column-element-name ) )
                               codec                   = codec->get_codec( )
                               num_values              = lines( data )
                               total_uncompressed_size = xstrlen( header_bytes ) + xstrlen( body )
                               total_compressed_size   = xstrlen( bytes )
                               data_page_offset        = offset
                               has_statistics          = abap_true
                               statistics              = VALUE #( has_null_count = abap_true
                                                                  null_count     = null_count ) ).
    APPEND zparq2a_if_format=>c_encoding-plain TO chunk-meta_data-encodings.
    IF column-optional = abap_true.
      APPEND zparq2a_if_format=>c_encoding-rle TO chunk-meta_data-encodings.
    ENDIF.
  ENDMETHOD.

  METHOD encode_page.
    DATA values TYPE REF TO zparq2a_if_encoder.
    DATA levels TYPE REF TO zparq2a_if_encoder.
    DATA reference TYPE REF TO data.
    DATA factor TYPE ty_unscaled VALUE 1.
    FIELD-SYMBOLS <row> TYPE any.
    FIELD-SYMBOLS <component> TYPE any.
    FIELD-SYMBOLS <value> TYPE simple.

    CLEAR: body, null_count.
    values = NEW zparq2a_cl_enc_plain( physical_type = column-element-type
                                       type_length   = column-element-type_length ).
    IF column-optional = abap_true.
      levels = NEW zparq2a_cl_enc_rle( 1 ).
    ENDIF.
    DO column-element-scale TIMES.
      factor = factor * 10.
    ENDDO.

    LOOP AT data ASSIGNING <row>.
      ASSIGN COMPONENT column-component OF STRUCTURE <row> TO <component>.
      IF column-optional = abap_true.
        reference = <component>.
        IF reference IS NOT BOUND.
          levels->put( 0 ).
          null_count = null_count + 1.
          CONTINUE.
        ENDIF.
        levels->put( 1 ).
        ASSIGN reference->* TO <value>.
      ELSE.
        ASSIGN <component> TO <value>.
      ENDIF.
      put_value( column  = column
                 encoder = values
                 factor  = factor
                 value   = <value> ).
    ENDLOOP.

    IF levels IS BOUND.
      DATA(level_bytes) = levels->flush( ).
      DATA(level_length) = zparq2a_cl_bytes=>int32_to_le( xstrlen( level_bytes ) ).
      CONCATENATE level_length level_bytes INTO body IN BYTE MODE.
    ENDIF.
    DATA(value_bytes) = values->flush( ).
    CONCATENATE body value_bytes INTO body IN BYTE MODE.
  ENDMETHOD.

  METHOD put_value.
    CONSTANTS midnight TYPE t VALUE '000000'.
    DATA text TYPE string.
    DATA date TYPE d.
    DATA time TYPE t.
    DATA unscaled TYPE ty_unscaled.

    CASE column-type_kind.
      WHEN cl_abap_typedescr=>typekind_string.
        text = value.
        encoder->put( zparq2a_cl_bytes=>utf8_encode( text ) ).
      WHEN cl_abap_typedescr=>typekind_date.
        date = value.
        encoder->put( zparq2a_cl_schema=>days_from_date( date ) ).
      WHEN cl_abap_typedescr=>typekind_time.
        time = value.
        encoder->put( ( time - midnight ) * 1000 ).
      WHEN cl_abap_typedescr=>typekind_packed.
        unscaled = value * factor.
        IF column-element-type = zparq2a_if_format=>c_type-fixed_len_byte_array.
          encoder->put( decimal_bytes( value = unscaled length = column-element-type_length ) ).
        ELSE.
          encoder->put( unscaled ).
        ENDIF.
      WHEN OTHERS.
        encoder->put( value ).
    ENDCASE.
  ENDMETHOD.

  METHOD decimal_bytes.
    CONSTANTS all_bits TYPE x LENGTH 1 VALUE 'FF'.
    DATA rest TYPE ty_unscaled.
    DATA byte TYPE x LENGTH 1.

    " a negative value is the bitwise complement of abs( value ) - 1
    DATA(negative) = xsdbool( value < 0 ).
    IF negative = abap_true.
      rest = abs( value ) - 1.
    ELSE.
      rest = value.
    ENDIF.
    DO length TIMES.
      byte = rest MOD 256.
      IF negative = abap_true.
        byte = byte BIT-XOR all_bits.
      ENDIF.
      CONCATENATE byte result INTO result IN BYTE MODE.
      rest = rest DIV 256.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
