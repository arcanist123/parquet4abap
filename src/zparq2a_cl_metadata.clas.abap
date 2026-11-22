"! <p class="shorttext synchronized">Parquet: metadata codec</p>
"! Decodes and encodes the Thrift structs of parquet.thrift: the file footer
"! (FileMetaData) and page headers. Fields that ZPARQ2A_IF_FORMAT does not
"! model are kept, so decoding and re-encoding gives the original bytes, as
"! long as the writer put the fields of each struct in ascending id order.
CLASS zparq2a_cl_metadata DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! "PAR1", at the start and the end of a Parquet file
    CONSTANTS magic TYPE x LENGTH 4 VALUE '50415231'.

    "! Decodes the footer of a complete Parquet file
    "! @raising zparq2a_cx_error | not a Parquet file, encrypted footer or invalid metadata
    CLASS-METHODS read_footer
      IMPORTING
        file          TYPE xstring
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_file_metadata
      RAISING
        zparq2a_cx_error.

    "! @parameter data | exactly one encoded FileMetaData
    CLASS-METHODS decode_file_metadata
      IMPORTING
        data          TYPE xstring
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_file_metadata
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS encode_file_metadata
      IMPORTING
        metadata      TYPE zparq2a_if_format=>ty_file_metadata
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! @parameter offset | offset of the page header in data
    "! @parameter length | length of the encoded page header
    CLASS-METHODS decode_page_header
      IMPORTING
        data   TYPE xstring
        offset TYPE i DEFAULT 0
      EXPORTING
        header TYPE zparq2a_if_format=>ty_page_header
        length TYPE i
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS encode_page_header
      IMPORTING
        header        TYPE zparq2a_if_format=>ty_page_header
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    "! "PARE", the end of a file with an encrypted footer
    CONSTANTS magic_encrypted TYPE x LENGTH 4 VALUE '50415245'.

    TYPES ty_reader TYPE REF TO zparq2a_cl_thrift_reader.
    TYPES ty_writer TYPE REF TO zparq2a_cl_thrift_writer.

    CLASS-METHODS read_file_metadata
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_file_metadata
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_schema_element
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_schema_element
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_logical_type
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_logical_type
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_decimal_type
      IMPORTING
        reader TYPE ty_reader
      CHANGING
        value  TYPE zparq2a_if_format=>ty_logical_type
      RAISING
        zparq2a_cx_error.

    "! TimeType or TimestampType
    CLASS-METHODS read_time_type
      IMPORTING
        reader TYPE ty_reader
      CHANGING
        value  TYPE zparq2a_if_format=>ty_logical_type
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_int_type
      IMPORTING
        reader TYPE ty_reader
      CHANGING
        value  TYPE zparq2a_if_format=>ty_logical_type
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_key_values
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_key_values
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_row_group
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_row_group
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_sorting_column
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_sorting_column
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_column_chunk
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_column_chunk
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_column_metadata
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_column_metadata
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_page_encoding_stats
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_page_encoding_stats
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_statistics
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_statistics
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_size_statistics
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_size_statistics
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_int8s
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_int8s
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_page_header
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_page_header
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_data_page_header
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_data_page_header
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_dictionary_page_header
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_dictionary_page_header
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS read_data_page_header_v2
      IMPORTING
        reader        TYPE ty_reader
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_data_page_header_v2
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_file_metadata
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_file_metadata
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_schema_element
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_schema_element
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_logical_type
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_logical_type
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_key_values
      IMPORTING
        writer TYPE ty_writer
        id     TYPE i
        value  TYPE zparq2a_if_format=>ty_key_values
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_row_group
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_row_group
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_column_chunk
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_column_chunk
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_column_metadata
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_column_metadata
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_statistics
      IMPORTING
        writer TYPE ty_writer
        id     TYPE i
        value  TYPE zparq2a_if_format=>ty_statistics
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_size_statistics
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_size_statistics
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_int8s
      IMPORTING
        writer TYPE ty_writer
        id     TYPE i
        value  TYPE zparq2a_if_format=>ty_int8s
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS write_page_header
      IMPORTING
        writer TYPE ty_writer
        value  TYPE zparq2a_if_format=>ty_page_header
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_metadata IMPLEMENTATION.

  METHOD read_footer.
    DATA head TYPE x LENGTH 4.
    DATA tail TYPE x LENGTH 4.
    DATA footer_length TYPE xstring.
    DATA footer TYPE xstring.

    DATA(size) = xstrlen( file ).
    IF size < 12.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Not a Parquet file: only { size } bytes|.
    ENDIF.
    head = file(4).
    DATA(tail_offset) = size - 4.
    tail = file+tail_offset(4).
    IF head <> magic.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Not a Parquet file: magic bytes missing at the start|.
    ELSEIF tail = magic_encrypted.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Encrypted footers (PARE) are not supported|.
    ELSEIF tail <> magic.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Not a Parquet file: magic bytes missing at the end|.
    ENDIF.
    DATA(length_offset) = size - 8.
    footer_length = file+length_offset(4).
    DATA(length) = zparq2a_cl_bytes=>int32_from_le( footer_length ).
    IF length <= 0 OR length > size - 12.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Footer length { length } does not fit a file of { size } bytes|.
    ENDIF.
    DATA(start) = length_offset - length.
    footer = file+start(length).
    result = decode_file_metadata( footer ).
  ENDMETHOD.

  METHOD decode_file_metadata.
    DATA(reader) = NEW zparq2a_cl_thrift_reader( data ).

    result = read_file_metadata( reader ).
    IF reader->get_position( ) <> xstrlen( data ).
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |{ xstrlen( data ) - reader->get_position( ) } bytes after the file metadata|.
    ENDIF.
  ENDMETHOD.

  METHOD encode_file_metadata.
    DATA(writer) = NEW zparq2a_cl_thrift_writer( ).

    write_file_metadata( writer = writer value = metadata ).
    result = writer->get_result( ).
  ENDMETHOD.

  METHOD decode_page_header.
    CLEAR: header, length.
    DATA(reader) = NEW zparq2a_cl_thrift_reader( data = data offset = offset ).

    header = read_page_header( reader ).
    length = reader->get_position( ) - offset.
  ENDMETHOD.

  METHOD encode_page_header.
    DATA(writer) = NEW zparq2a_cl_thrift_writer( ).

    write_page_header( writer = writer value = header ).
    result = writer->get_result( ).
  ENDMETHOD.

  METHOD read_file_metadata.
    reader->read_struct_begin( `FileMetaData` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-version = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND read_schema_element( reader ) TO result-schema.
        ENDDO.
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i64 ).
        result-num_rows = reader->read_i64( ).
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND read_row_group( reader ) TO result-row_groups.
        ENDDO.
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-list ).
        result-key_value_metadata = read_key_values( reader ).
        result-has_key_value_metadata = abap_true.
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-binary ).
        result-created_by = reader->read_string( ).
        result-has_created_by = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND reader->read_union( `ColumnOrder` ) TO result-column_orders.
        ENDDO.
        result-has_column_orders = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ( 4 ) ) ).
  ENDMETHOD.

  METHOD read_schema_element.
    reader->read_struct_begin( `SchemaElement` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-type = reader->read_i32( ).
        result-has_type = abap_true.
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-type_length = reader->read_i32( ).
        result-has_type_length = abap_true.
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ).
        result-repetition_type = reader->read_i32( ).
        result-has_repetition_type = abap_true.
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-binary ).
        result-name = reader->read_string( ).
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_children = reader->read_i32( ).
        result-has_num_children = abap_true.
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-i32 ).
        result-converted_type = reader->read_i32( ).
        result-has_converted_type = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-i32 ).
        result-scale = reader->read_i32( ).
        result-has_scale = abap_true.
      ELSEIF reader->field_is( id = 8 type = zparq2a_if_thrift=>c_type-i32 ).
        result-precision = reader->read_i32( ).
        result-has_precision = abap_true.
      ELSEIF reader->field_is( id = 9 type = zparq2a_if_thrift=>c_type-i32 ).
        result-field_id = reader->read_i32( ).
        result-has_field_id = abap_true.
      ELSEIF reader->field_is( id = 10 type = zparq2a_if_thrift=>c_type-struct ).
        result-logical_type = read_logical_type( reader ).
        result-has_logical_type = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 4 ) ) ).
  ENDMETHOD.

  METHOD read_logical_type.
    reader->read_struct_begin( `LogicalType` ).
    WHILE reader->next_field( ).
      IF result-kind <> 0.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Union LogicalType has more than one member set|.
      ENDIF.
      IF reader->field_is( id = zparq2a_if_format=>c_logical_type-decimal type = zparq2a_if_thrift=>c_type-struct ).
        result-kind = zparq2a_if_format=>c_logical_type-decimal.
        read_decimal_type( EXPORTING reader = reader CHANGING value = result ).
      ELSEIF reader->field_is( id = zparq2a_if_format=>c_logical_type-time type = zparq2a_if_thrift=>c_type-struct ).
        result-kind = zparq2a_if_format=>c_logical_type-time.
        read_time_type( EXPORTING reader = reader CHANGING value = result ).
      ELSEIF reader->field_is( id   = zparq2a_if_format=>c_logical_type-timestamp
                               type = zparq2a_if_thrift=>c_type-struct ).
        result-kind = zparq2a_if_format=>c_logical_type-timestamp.
        read_time_type( EXPORTING reader = reader CHANGING value = result ).
      ELSEIF reader->field_is( id = zparq2a_if_format=>c_logical_type-integer type = zparq2a_if_thrift=>c_type-struct ).
        result-kind = zparq2a_if_format=>c_logical_type-integer.
        read_int_type( EXPORTING reader = reader CHANGING value = result ).
      ELSE.
        DATA(member) = reader->read_unknown( ).
        IF member-type <> zparq2a_if_thrift=>c_type-struct.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |Member { member-id } of union LogicalType is not a struct|.
        ENDIF.
        result-kind = member-id.
        IF member-value <> zparq2a_if_thrift=>empty_struct.
          result-value = member-value.
        ENDIF.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( ).
  ENDMETHOD.

  METHOD read_decimal_type.
    reader->read_struct_begin( `DecimalType` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        value-scale = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        value-precision = reader->read_i32( ).
      ELSE.
        APPEND reader->read_unknown( ) TO value-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ) ).
  ENDMETHOD.

  METHOD read_time_type.
    reader->read_struct_begin( `TimeType` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-bool_true ).
        value-is_adjusted_to_utc = reader->read_bool( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-struct ).
        value-unit = reader->read_union( `TimeUnit` ).
      ELSE.
        APPEND reader->read_unknown( ) TO value-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ) ).
  ENDMETHOD.

  METHOD read_int_type.
    reader->read_struct_begin( `IntType` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-byte ).
        value-bit_width = reader->read_i8( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-bool_true ).
        value-is_signed = reader->read_bool( ).
      ELSE.
        APPEND reader->read_unknown( ) TO value-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ) ).
  ENDMETHOD.

  METHOD read_key_values.
    DATA key_value TYPE zparq2a_if_format=>ty_key_value.

    DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
      CLEAR key_value.
      reader->read_struct_begin( `KeyValue` ).
      WHILE reader->next_field( ).
        IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-binary ).
          key_value-key = reader->read_string( ).
        ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-binary ).
          key_value-value = reader->read_string( ).
          key_value-has_value = abap_true.
        ELSE.
          APPEND reader->read_unknown( ) TO key_value-unknown.
        ENDIF.
      ENDWHILE.
      reader->read_struct_end( VALUE #( ( 1 ) ) ).
      APPEND key_value TO result.
    ENDDO.
  ENDMETHOD.

  METHOD read_row_group.
    reader->read_struct_begin( `RowGroup` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND read_column_chunk( reader ) TO result-columns.
        ENDDO.
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i64 ).
        result-total_byte_size = reader->read_i64( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i64 ).
        result-num_rows = reader->read_i64( ).
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND read_sorting_column( reader ) TO result-sorting_columns.
        ENDDO.
        result-has_sorting_columns = abap_true.
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-i64 ).
        result-file_offset = reader->read_i64( ).
        result-has_file_offset = abap_true.
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-i64 ).
        result-total_compressed_size = reader->read_i64( ).
        result-has_total_compressed_size = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-i16 ).
        result-ordinal = reader->read_i16( ).
        result-has_ordinal = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ) ).
  ENDMETHOD.

  METHOD read_sorting_column.
    reader->read_struct_begin( `SortingColumn` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-column_idx = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-descending = reader->read_bool( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-nulls_first = reader->read_bool( ).
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ) ).
  ENDMETHOD.

  METHOD read_column_chunk.
    reader->read_struct_begin( `ColumnChunk` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-binary ).
        result-file_path = reader->read_string( ).
        result-has_file_path = abap_true.
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i64 ).
        result-file_offset = reader->read_i64( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-struct ).
        result-meta_data = read_column_metadata( reader ).
        result-has_meta_data = abap_true.
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i64 ).
        result-offset_index_offset = reader->read_i64( ).
        result-has_offset_index_offset = abap_true.
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-i32 ).
        result-offset_index_length = reader->read_i32( ).
        result-has_offset_index_length = abap_true.
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-i64 ).
        result-column_index_offset = reader->read_i64( ).
        result-has_column_index_offset = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-i32 ).
        result-column_index_length = reader->read_i32( ).
        result-has_column_index_length = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 2 ) ) ).
  ENDMETHOD.

  METHOD read_column_metadata.
    reader->read_struct_begin( `ColumnMetaData` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-type = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-i32 ) TIMES.
          APPEND reader->read_i32( ) TO result-encodings.
        ENDDO.
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-binary ) TIMES.
          APPEND reader->read_string( ) TO result-path_in_schema.
        ENDDO.
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i32 ).
        result-codec = reader->read_i32( ).
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-i64 ).
        result-num_values = reader->read_i64( ).
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-i64 ).
        result-total_uncompressed_size = reader->read_i64( ).
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-i64 ).
        result-total_compressed_size = reader->read_i64( ).
      ELSEIF reader->field_is( id = 8 type = zparq2a_if_thrift=>c_type-list ).
        result-key_value_metadata = read_key_values( reader ).
        result-has_key_value_metadata = abap_true.
      ELSEIF reader->field_is( id = 9 type = zparq2a_if_thrift=>c_type-i64 ).
        result-data_page_offset = reader->read_i64( ).
      ELSEIF reader->field_is( id = 10 type = zparq2a_if_thrift=>c_type-i64 ).
        result-index_page_offset = reader->read_i64( ).
        result-has_index_page_offset = abap_true.
      ELSEIF reader->field_is( id = 11 type = zparq2a_if_thrift=>c_type-i64 ).
        result-dictionary_page_offset = reader->read_i64( ).
        result-has_dictionary_page_offset = abap_true.
      ELSEIF reader->field_is( id = 12 type = zparq2a_if_thrift=>c_type-struct ).
        result-statistics = read_statistics( reader ).
        result-has_statistics = abap_true.
      ELSEIF reader->field_is( id = 13 type = zparq2a_if_thrift=>c_type-list ).
        DO reader->read_list_size( zparq2a_if_thrift=>c_type-struct ) TIMES.
          APPEND read_page_encoding_stats( reader ) TO result-encoding_stats.
        ENDDO.
        result-has_encoding_stats = abap_true.
      ELSEIF reader->field_is( id = 14 type = zparq2a_if_thrift=>c_type-i64 ).
        result-bloom_filter_offset = reader->read_i64( ).
        result-has_bloom_filter_offset = abap_true.
      ELSEIF reader->field_is( id = 15 type = zparq2a_if_thrift=>c_type-i32 ).
        result-bloom_filter_length = reader->read_i32( ).
        result-has_bloom_filter_length = abap_true.
      ELSEIF reader->field_is( id = 16 type = zparq2a_if_thrift=>c_type-struct ).
        result-size_statistics = read_size_statistics( reader ).
        result-has_size_statistics = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ( 4 ) ( 5 ) ( 6 ) ( 7 ) ( 9 ) ) ).
  ENDMETHOD.

  METHOD read_page_encoding_stats.
    reader->read_struct_begin( `PageEncodingStats` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-page_type = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ).
        result-count = reader->read_i32( ).
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ) ).
  ENDMETHOD.

  METHOD read_statistics.
    reader->read_struct_begin( `Statistics` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-binary ).
        result-max = reader->read_binary( ).
        result-has_max = abap_true.
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-binary ).
        result-min = reader->read_binary( ).
        result-has_min = abap_true.
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i64 ).
        result-null_count = reader->read_i64( ).
        result-has_null_count = abap_true.
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i64 ).
        result-distinct_count = reader->read_i64( ).
        result-has_distinct_count = abap_true.
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-binary ).
        result-max_value = reader->read_binary( ).
        result-has_max_value = abap_true.
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-binary ).
        result-min_value = reader->read_binary( ).
        result-has_min_value = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-is_max_value_exact = reader->read_bool( ).
        result-has_is_max_value_exact = abap_true.
      ELSEIF reader->field_is( id = 8 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-is_min_value_exact = reader->read_bool( ).
        result-has_is_min_value_exact = abap_true.
      ELSEIF reader->field_is( id = 9 type = zparq2a_if_thrift=>c_type-i64 ).
        result-nan_count = reader->read_i64( ).
        result-has_nan_count = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( ).
  ENDMETHOD.

  METHOD read_size_statistics.
    reader->read_struct_begin( `SizeStatistics` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i64 ).
        result-unencoded_bytes = reader->read_i64( ).
        result-has_unencoded_bytes = abap_true.
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-list ).
        result-rep_level_histogram = read_int8s( reader ).
        result-has_rep_histogram = abap_true.
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-list ).
        result-def_level_histogram = read_int8s( reader ).
        result-has_def_histogram = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( ).
  ENDMETHOD.

  METHOD read_int8s.
    DO reader->read_list_size( zparq2a_if_thrift=>c_type-i64 ) TIMES.
      APPEND reader->read_i64( ) TO result.
    ENDDO.
  ENDMETHOD.

  METHOD read_page_header.
    reader->read_struct_begin( `PageHeader` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-type = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-uncompressed_page_size = reader->read_i32( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ).
        result-compressed_page_size = reader->read_i32( ).
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i32 ).
        result-crc = reader->read_i32( ).
        result-has_crc = abap_true.
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-struct ).
        result-data_page_header = read_data_page_header( reader ).
        result-has_data_page_header = abap_true.
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-struct ).
        result-dictionary_page_header = read_dictionary_page_header( reader ).
        result-has_dictionary_page_header = abap_true.
      ELSEIF reader->field_is( id = 8 type = zparq2a_if_thrift=>c_type-struct ).
        result-data_page_header_v2 = read_data_page_header_v2( reader ).
        result-has_data_page_header_v2 = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ) ).
  ENDMETHOD.

  METHOD read_data_page_header.
    reader->read_struct_begin( `DataPageHeader` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_values = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ).
        result-definition_level_encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i32 ).
        result-repetition_level_encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-struct ).
        result-statistics = read_statistics( reader ).
        result-has_statistics = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ( 4 ) ) ).
  ENDMETHOD.

  METHOD read_dictionary_page_header.
    reader->read_struct_begin( `DictionaryPageHeader` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_values = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-is_sorted = reader->read_bool( ).
        result-has_is_sorted = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ) ).
  ENDMETHOD.

  METHOD read_data_page_header_v2.
    result-is_compressed = abap_true.
    reader->read_struct_begin( `DataPageHeaderV2` ).
    WHILE reader->next_field( ).
      IF reader->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_values = reader->read_i32( ).
      ELSEIF reader->field_is( id = 2 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_nulls = reader->read_i32( ).
      ELSEIF reader->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ).
        result-num_rows = reader->read_i32( ).
      ELSEIF reader->field_is( id = 4 type = zparq2a_if_thrift=>c_type-i32 ).
        result-encoding = reader->read_i32( ).
      ELSEIF reader->field_is( id = 5 type = zparq2a_if_thrift=>c_type-i32 ).
        result-def_levels_byte_length = reader->read_i32( ).
      ELSEIF reader->field_is( id = 6 type = zparq2a_if_thrift=>c_type-i32 ).
        result-rep_levels_byte_length = reader->read_i32( ).
      ELSEIF reader->field_is( id = 7 type = zparq2a_if_thrift=>c_type-bool_true ).
        result-is_compressed = reader->read_bool( ).
        result-has_is_compressed = abap_true.
      ELSEIF reader->field_is( id = 8 type = zparq2a_if_thrift=>c_type-struct ).
        result-statistics = read_statistics( reader ).
        result-has_statistics = abap_true.
      ELSE.
        APPEND reader->read_unknown( ) TO result-unknown.
      ENDIF.
    ENDWHILE.
    reader->read_struct_end( VALUE #( ( 1 ) ( 2 ) ( 3 ) ( 4 ) ( 5 ) ( 6 ) ) ).
  ENDMETHOD.

  METHOD write_file_metadata.
    writer->write_struct_begin( value-unknown ).
    writer->write_i32_field( id = 1 value = value-version ).
    writer->write_list_field( id           = 2
                              element_type = zparq2a_if_thrift=>c_type-struct
                              size         = lines( value-schema ) ).
    LOOP AT value-schema REFERENCE INTO DATA(element).
      write_schema_element( writer = writer value = element->* ).
    ENDLOOP.
    writer->write_i64_field( id = 3 value = value-num_rows ).
    writer->write_list_field( id           = 4
                              element_type = zparq2a_if_thrift=>c_type-struct
                              size         = lines( value-row_groups ) ).
    LOOP AT value-row_groups REFERENCE INTO DATA(row_group).
      write_row_group( writer = writer value = row_group->* ).
    ENDLOOP.
    IF value-has_key_value_metadata = abap_true.
      write_key_values( writer = writer id = 5 value = value-key_value_metadata ).
    ENDIF.
    IF value-has_created_by = abap_true.
      writer->write_string_field( id = 6 value = value-created_by ).
    ENDIF.
    IF value-has_column_orders = abap_true.
      writer->write_list_field( id           = 7
                                element_type = zparq2a_if_thrift=>c_type-struct
                                size         = lines( value-column_orders ) ).
      LOOP AT value-column_orders INTO DATA(column_order).
        writer->write_union( column_order ).
      ENDLOOP.
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_schema_element.
    writer->write_struct_begin( value-unknown ).
    IF value-has_type = abap_true.
      writer->write_i32_field( id = 1 value = value-type ).
    ENDIF.
    IF value-has_type_length = abap_true.
      writer->write_i32_field( id = 2 value = value-type_length ).
    ENDIF.
    IF value-has_repetition_type = abap_true.
      writer->write_i32_field( id = 3 value = value-repetition_type ).
    ENDIF.
    writer->write_string_field( id = 4 value = value-name ).
    IF value-has_num_children = abap_true.
      writer->write_i32_field( id = 5 value = value-num_children ).
    ENDIF.
    IF value-has_converted_type = abap_true.
      writer->write_i32_field( id = 6 value = value-converted_type ).
    ENDIF.
    IF value-has_scale = abap_true.
      writer->write_i32_field( id = 7 value = value-scale ).
    ENDIF.
    IF value-has_precision = abap_true.
      writer->write_i32_field( id = 8 value = value-precision ).
    ENDIF.
    IF value-has_field_id = abap_true.
      writer->write_i32_field( id = 9 value = value-field_id ).
    ENDIF.
    IF value-has_logical_type = abap_true.
      writer->write_field_begin( id = 10 type = zparq2a_if_thrift=>c_type-struct ).
      write_logical_type( writer = writer value = value-logical_type ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_logical_type.
    writer->write_struct_begin( ).
    CASE value-kind.
      WHEN 0.
        " no member set
      WHEN zparq2a_if_format=>c_logical_type-decimal.
        writer->write_field_begin( id = value-kind type = zparq2a_if_thrift=>c_type-struct ).
        writer->write_struct_begin( value-unknown ).
        writer->write_i32_field( id = 1 value = value-scale ).
        writer->write_i32_field( id = 2 value = value-precision ).
        writer->write_struct_end( ).
      WHEN zparq2a_if_format=>c_logical_type-time OR zparq2a_if_format=>c_logical_type-timestamp.
        writer->write_field_begin( id = value-kind type = zparq2a_if_thrift=>c_type-struct ).
        writer->write_struct_begin( value-unknown ).
        writer->write_bool_field( id = 1 value = value-is_adjusted_to_utc ).
        writer->write_union_field( id = 2 value = value-unit ).
        writer->write_struct_end( ).
      WHEN zparq2a_if_format=>c_logical_type-integer.
        writer->write_field_begin( id = value-kind type = zparq2a_if_thrift=>c_type-struct ).
        writer->write_struct_begin( value-unknown ).
        writer->write_i8_field( id = 1 value = value-bit_width ).
        writer->write_bool_field( id = 2 value = value-is_signed ).
        writer->write_struct_end( ).
      WHEN OTHERS.
        writer->write_field_begin( id = value-kind type = zparq2a_if_thrift=>c_type-struct ).
        IF value-value IS INITIAL.
          writer->write_raw( CONV #( zparq2a_if_thrift=>empty_struct ) ).
        ELSE.
          writer->write_raw( value-value ).
        ENDIF.
    ENDCASE.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_key_values.
    writer->write_list_field( id = id element_type = zparq2a_if_thrift=>c_type-struct size = lines( value ) ).
    LOOP AT value REFERENCE INTO DATA(key_value).
      writer->write_struct_begin( key_value->unknown ).
      writer->write_string_field( id = 1 value = key_value->key ).
      IF key_value->has_value = abap_true.
        writer->write_string_field( id = 2 value = key_value->value ).
      ENDIF.
      writer->write_struct_end( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD write_row_group.
    writer->write_struct_begin( value-unknown ).
    writer->write_list_field( id           = 1
                              element_type = zparq2a_if_thrift=>c_type-struct
                              size         = lines( value-columns ) ).
    LOOP AT value-columns REFERENCE INTO DATA(column).
      write_column_chunk( writer = writer value = column->* ).
    ENDLOOP.
    writer->write_i64_field( id = 2 value = value-total_byte_size ).
    writer->write_i64_field( id = 3 value = value-num_rows ).
    IF value-has_sorting_columns = abap_true.
      writer->write_list_field( id           = 4
                                element_type = zparq2a_if_thrift=>c_type-struct
                                size         = lines( value-sorting_columns ) ).
      LOOP AT value-sorting_columns REFERENCE INTO DATA(sorting_column).
        writer->write_struct_begin( sorting_column->unknown ).
        writer->write_i32_field( id = 1 value = sorting_column->column_idx ).
        writer->write_bool_field( id = 2 value = sorting_column->descending ).
        writer->write_bool_field( id = 3 value = sorting_column->nulls_first ).
        writer->write_struct_end( ).
      ENDLOOP.
    ENDIF.
    IF value-has_file_offset = abap_true.
      writer->write_i64_field( id = 5 value = value-file_offset ).
    ENDIF.
    IF value-has_total_compressed_size = abap_true.
      writer->write_i64_field( id = 6 value = value-total_compressed_size ).
    ENDIF.
    IF value-has_ordinal = abap_true.
      writer->write_i16_field( id = 7 value = value-ordinal ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_column_chunk.
    writer->write_struct_begin( value-unknown ).
    IF value-has_file_path = abap_true.
      writer->write_string_field( id = 1 value = value-file_path ).
    ENDIF.
    writer->write_i64_field( id = 2 value = value-file_offset ).
    IF value-has_meta_data = abap_true.
      writer->write_field_begin( id = 3 type = zparq2a_if_thrift=>c_type-struct ).
      write_column_metadata( writer = writer value = value-meta_data ).
    ENDIF.
    IF value-has_offset_index_offset = abap_true.
      writer->write_i64_field( id = 4 value = value-offset_index_offset ).
    ENDIF.
    IF value-has_offset_index_length = abap_true.
      writer->write_i32_field( id = 5 value = value-offset_index_length ).
    ENDIF.
    IF value-has_column_index_offset = abap_true.
      writer->write_i64_field( id = 6 value = value-column_index_offset ).
    ENDIF.
    IF value-has_column_index_length = abap_true.
      writer->write_i32_field( id = 7 value = value-column_index_length ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_column_metadata.
    writer->write_struct_begin( value-unknown ).
    writer->write_i32_field( id = 1 value = value-type ).
    writer->write_list_field( id           = 2
                              element_type = zparq2a_if_thrift=>c_type-i32
                              size         = lines( value-encodings ) ).
    LOOP AT value-encodings INTO DATA(encoding).
      writer->write_i32( encoding ).
    ENDLOOP.
    writer->write_list_field( id           = 3
                              element_type = zparq2a_if_thrift=>c_type-binary
                              size         = lines( value-path_in_schema ) ).
    LOOP AT value-path_in_schema INTO DATA(name).
      writer->write_string( name ).
    ENDLOOP.
    writer->write_i32_field( id = 4 value = value-codec ).
    writer->write_i64_field( id = 5 value = value-num_values ).
    writer->write_i64_field( id = 6 value = value-total_uncompressed_size ).
    writer->write_i64_field( id = 7 value = value-total_compressed_size ).
    IF value-has_key_value_metadata = abap_true.
      write_key_values( writer = writer id = 8 value = value-key_value_metadata ).
    ENDIF.
    writer->write_i64_field( id = 9 value = value-data_page_offset ).
    IF value-has_index_page_offset = abap_true.
      writer->write_i64_field( id = 10 value = value-index_page_offset ).
    ENDIF.
    IF value-has_dictionary_page_offset = abap_true.
      writer->write_i64_field( id = 11 value = value-dictionary_page_offset ).
    ENDIF.
    IF value-has_statistics = abap_true.
      write_statistics( writer = writer id = 12 value = value-statistics ).
    ENDIF.
    IF value-has_encoding_stats = abap_true.
      writer->write_list_field( id           = 13
                                element_type = zparq2a_if_thrift=>c_type-struct
                                size         = lines( value-encoding_stats ) ).
      LOOP AT value-encoding_stats REFERENCE INTO DATA(stats).
        writer->write_struct_begin( stats->unknown ).
        writer->write_i32_field( id = 1 value = stats->page_type ).
        writer->write_i32_field( id = 2 value = stats->encoding ).
        writer->write_i32_field( id = 3 value = stats->count ).
        writer->write_struct_end( ).
      ENDLOOP.
    ENDIF.
    IF value-has_bloom_filter_offset = abap_true.
      writer->write_i64_field( id = 14 value = value-bloom_filter_offset ).
    ENDIF.
    IF value-has_bloom_filter_length = abap_true.
      writer->write_i32_field( id = 15 value = value-bloom_filter_length ).
    ENDIF.
    IF value-has_size_statistics = abap_true.
      writer->write_field_begin( id = 16 type = zparq2a_if_thrift=>c_type-struct ).
      write_size_statistics( writer = writer value = value-size_statistics ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_statistics.
    writer->write_field_begin( id = id type = zparq2a_if_thrift=>c_type-struct ).
    writer->write_struct_begin( value-unknown ).
    IF value-has_max = abap_true.
      writer->write_binary_field( id = 1 value = value-max ).
    ENDIF.
    IF value-has_min = abap_true.
      writer->write_binary_field( id = 2 value = value-min ).
    ENDIF.
    IF value-has_null_count = abap_true.
      writer->write_i64_field( id = 3 value = value-null_count ).
    ENDIF.
    IF value-has_distinct_count = abap_true.
      writer->write_i64_field( id = 4 value = value-distinct_count ).
    ENDIF.
    IF value-has_max_value = abap_true.
      writer->write_binary_field( id = 5 value = value-max_value ).
    ENDIF.
    IF value-has_min_value = abap_true.
      writer->write_binary_field( id = 6 value = value-min_value ).
    ENDIF.
    IF value-has_is_max_value_exact = abap_true.
      writer->write_bool_field( id = 7 value = value-is_max_value_exact ).
    ENDIF.
    IF value-has_is_min_value_exact = abap_true.
      writer->write_bool_field( id = 8 value = value-is_min_value_exact ).
    ENDIF.
    IF value-has_nan_count = abap_true.
      writer->write_i64_field( id = 9 value = value-nan_count ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_size_statistics.
    writer->write_struct_begin( value-unknown ).
    IF value-has_unencoded_bytes = abap_true.
      writer->write_i64_field( id = 1 value = value-unencoded_bytes ).
    ENDIF.
    IF value-has_rep_histogram = abap_true.
      write_int8s( writer = writer id = 2 value = value-rep_level_histogram ).
    ENDIF.
    IF value-has_def_histogram = abap_true.
      write_int8s( writer = writer id = 3 value = value-def_level_histogram ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

  METHOD write_int8s.
    writer->write_list_field( id = id element_type = zparq2a_if_thrift=>c_type-i64 size = lines( value ) ).
    LOOP AT value INTO DATA(element).
      writer->write_i64( element ).
    ENDLOOP.
  ENDMETHOD.

  METHOD write_page_header.
    writer->write_struct_begin( value-unknown ).
    writer->write_i32_field( id = 1 value = value-type ).
    writer->write_i32_field( id = 2 value = value-uncompressed_page_size ).
    writer->write_i32_field( id = 3 value = value-compressed_page_size ).
    IF value-has_crc = abap_true.
      writer->write_i32_field( id = 4 value = value-crc ).
    ENDIF.
    IF value-has_data_page_header = abap_true.
      DATA(data_page) = REF #( value-data_page_header ).
      writer->write_field_begin( id = 5 type = zparq2a_if_thrift=>c_type-struct ).
      writer->write_struct_begin( data_page->unknown ).
      writer->write_i32_field( id = 1 value = data_page->num_values ).
      writer->write_i32_field( id = 2 value = data_page->encoding ).
      writer->write_i32_field( id = 3 value = data_page->definition_level_encoding ).
      writer->write_i32_field( id = 4 value = data_page->repetition_level_encoding ).
      IF data_page->has_statistics = abap_true.
        write_statistics( writer = writer id = 5 value = data_page->statistics ).
      ENDIF.
      writer->write_struct_end( ).
    ENDIF.
    IF value-has_dictionary_page_header = abap_true.
      DATA(dictionary_page) = REF #( value-dictionary_page_header ).
      writer->write_field_begin( id = 7 type = zparq2a_if_thrift=>c_type-struct ).
      writer->write_struct_begin( dictionary_page->unknown ).
      writer->write_i32_field( id = 1 value = dictionary_page->num_values ).
      writer->write_i32_field( id = 2 value = dictionary_page->encoding ).
      IF dictionary_page->has_is_sorted = abap_true.
        writer->write_bool_field( id = 3 value = dictionary_page->is_sorted ).
      ENDIF.
      writer->write_struct_end( ).
    ENDIF.
    IF value-has_data_page_header_v2 = abap_true.
      DATA(v2) = REF #( value-data_page_header_v2 ).
      writer->write_field_begin( id = 8 type = zparq2a_if_thrift=>c_type-struct ).
      writer->write_struct_begin( v2->unknown ).
      writer->write_i32_field( id = 1 value = v2->num_values ).
      writer->write_i32_field( id = 2 value = v2->num_nulls ).
      writer->write_i32_field( id = 3 value = v2->num_rows ).
      writer->write_i32_field( id = 4 value = v2->encoding ).
      writer->write_i32_field( id = 5 value = v2->def_levels_byte_length ).
      writer->write_i32_field( id = 6 value = v2->rep_levels_byte_length ).
      IF v2->has_is_compressed = abap_true.
        writer->write_bool_field( id = 7 value = v2->is_compressed ).
      ENDIF.
      IF v2->has_statistics = abap_true.
        write_statistics( writer = writer id = 8 value = v2->statistics ).
      ENDIF.
      writer->write_struct_end( ).
    ENDIF.
    writer->write_struct_end( ).
  ENDMETHOD.

ENDCLASS.
