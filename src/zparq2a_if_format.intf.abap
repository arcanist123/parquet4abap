"! <p class="shorttext synchronized">Parquet: file format definitions</p>
"! Enumerations and metadata structs of parquet.thrift (apache/parquet-format).
"! An optional field comes with a <em>has_</em> flag that tells whether it is
"! set. Fields that are not modelled here are kept in <em>unknown</em>, so
"! decoding and re-encoding gives the original bytes.
INTERFACE zparq2a_if_format
  PUBLIC.

  CONSTANTS:
    "! Physical types (Type)
    BEGIN OF c_type,
      boolean              TYPE i VALUE 0,
      int32                TYPE i VALUE 1,
      int64                TYPE i VALUE 2,
      int96                TYPE i VALUE 3,
      float                TYPE i VALUE 4,
      double               TYPE i VALUE 5,
      byte_array           TYPE i VALUE 6,
      fixed_len_byte_array TYPE i VALUE 7,
    END OF c_type.

  CONSTANTS:
    "! ConvertedType
    BEGIN OF c_converted_type,
      utf8             TYPE i VALUE 0,
      map              TYPE i VALUE 1,
      map_key_value    TYPE i VALUE 2,
      list             TYPE i VALUE 3,
      enum             TYPE i VALUE 4,
      decimal          TYPE i VALUE 5,
      date             TYPE i VALUE 6,
      time_millis      TYPE i VALUE 7,
      time_micros      TYPE i VALUE 8,
      timestamp_millis TYPE i VALUE 9,
      timestamp_micros TYPE i VALUE 10,
      uint_8           TYPE i VALUE 11,
      uint_16          TYPE i VALUE 12,
      uint_32          TYPE i VALUE 13,
      uint_64          TYPE i VALUE 14,
      int_8            TYPE i VALUE 15,
      int_16           TYPE i VALUE 16,
      int_32           TYPE i VALUE 17,
      int_64           TYPE i VALUE 18,
      json             TYPE i VALUE 19,
      bson             TYPE i VALUE 20,
      interval         TYPE i VALUE 21,
    END OF c_converted_type.

  CONSTANTS:
    "! FieldRepetitionType
    BEGIN OF c_repetition,
      required TYPE i VALUE 0,
      optional TYPE i VALUE 1,
      repeated TYPE i VALUE 2,
    END OF c_repetition.

  CONSTANTS:
    "! Encoding
    BEGIN OF c_encoding,
      plain                   TYPE i VALUE 0,
      plain_dictionary        TYPE i VALUE 2,
      rle                     TYPE i VALUE 3,
      bit_packed              TYPE i VALUE 4,
      delta_binary_packed     TYPE i VALUE 5,
      delta_length_byte_array TYPE i VALUE 6,
      delta_byte_array        TYPE i VALUE 7,
      rle_dictionary          TYPE i VALUE 8,
      byte_stream_split       TYPE i VALUE 9,
      alp                     TYPE i VALUE 10,
    END OF c_encoding.

  CONSTANTS:
    "! CompressionCodec
    BEGIN OF c_codec,
      uncompressed TYPE i VALUE 0,
      snappy       TYPE i VALUE 1,
      gzip         TYPE i VALUE 2,
      lzo          TYPE i VALUE 3,
      brotli       TYPE i VALUE 4,
      lz4          TYPE i VALUE 5,
      zstd         TYPE i VALUE 6,
      lz4_raw      TYPE i VALUE 7,
    END OF c_codec.

  CONSTANTS:
    "! PageType
    BEGIN OF c_page_type,
      data_page       TYPE i VALUE 0,
      index_page      TYPE i VALUE 1,
      dictionary_page TYPE i VALUE 2,
      data_page_v2    TYPE i VALUE 3,
    END OF c_page_type.

  CONSTANTS:
    "! Members of the LogicalType union
    BEGIN OF c_logical_type,
      string        TYPE i VALUE 1,
      map           TYPE i VALUE 2,
      list          TYPE i VALUE 3,
      enum          TYPE i VALUE 4,
      decimal       TYPE i VALUE 5,
      date          TYPE i VALUE 6,
      time          TYPE i VALUE 7,
      timestamp     TYPE i VALUE 8,
      integer       TYPE i VALUE 10,
      unknown       TYPE i VALUE 11,
      json          TYPE i VALUE 12,
      bson          TYPE i VALUE 13,
      uuid          TYPE i VALUE 14,
      float16       TYPE i VALUE 15,
      variant       TYPE i VALUE 16,
      geometry      TYPE i VALUE 17,
      geography     TYPE i VALUE 18,
      file          TYPE i VALUE 19,
      finite_vector TYPE i VALUE 20,
    END OF c_logical_type.

  CONSTANTS:
    "! Members of the TimeUnit union
    BEGIN OF c_time_unit,
      millis TYPE i VALUE 1,
      micros TYPE i VALUE 2,
      nanos  TYPE i VALUE 3,
    END OF c_time_unit.

  CONSTANTS:
    "! Members of the ColumnOrder union
    BEGIN OF c_column_order,
      type_order           TYPE i VALUE 1,
      ieee_754_total_order TYPE i VALUE 2,
      int96_order          TYPE i VALUE 3,
    END OF c_column_order.

  TYPES:
    "! Signed 64-bit values, used for histograms
    ty_int8s TYPE STANDARD TABLE OF int8 WITH EMPTY KEY,
    "! Enumeration values, such as a list of encodings
    ty_ints  TYPE STANDARD TABLE OF i WITH EMPTY KEY.

  TYPES:
    "! KeyValue
    BEGIN OF ty_key_value,
      key       TYPE string,
      value     TYPE string,
      has_value TYPE abap_bool,
      unknown   TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_key_value,
    ty_key_values TYPE STANDARD TABLE OF ty_key_value WITH EMPTY KEY.

  TYPES:
    "! Statistics
    BEGIN OF ty_statistics,
      max                    TYPE xstring,
      has_max                TYPE abap_bool,
      min                    TYPE xstring,
      has_min                TYPE abap_bool,
      null_count             TYPE int8,
      has_null_count         TYPE abap_bool,
      distinct_count         TYPE int8,
      has_distinct_count     TYPE abap_bool,
      max_value              TYPE xstring,
      has_max_value          TYPE abap_bool,
      min_value              TYPE xstring,
      has_min_value          TYPE abap_bool,
      is_max_value_exact     TYPE abap_bool,
      has_is_max_value_exact TYPE abap_bool,
      is_min_value_exact     TYPE abap_bool,
      has_is_min_value_exact TYPE abap_bool,
      nan_count              TYPE int8,
      has_nan_count          TYPE abap_bool,
      unknown                TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_statistics.

  TYPES:
    "! SizeStatistics
    BEGIN OF ty_size_statistics,
      "! unencoded_byte_array_data_bytes
      unencoded_bytes      TYPE int8,
      has_unencoded_bytes  TYPE abap_bool,
      "! repetition_level_histogram
      rep_level_histogram  TYPE ty_int8s,
      has_rep_histogram    TYPE abap_bool,
      "! definition_level_histogram
      def_level_histogram  TYPE ty_int8s,
      has_def_histogram    TYPE abap_bool,
      unknown              TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_size_statistics.

  TYPES:
    "! LogicalType: the member that is set, with the parameters of DECIMAL,
    "! TIME, TIMESTAMP and INTEGER
    BEGIN OF ty_logical_type,
      "! Member id, see c_logical_type
      kind               TYPE i,
      "! DECIMAL
      scale              TYPE i,
      "! DECIMAL
      precision          TYPE i,
      "! TIME, TIMESTAMP
      is_adjusted_to_utc TYPE abap_bool,
      "! TIME, TIMESTAMP; member see c_time_unit
      unit               TYPE zparq2a_if_thrift=>ty_union,
      "! INTEGER: 8, 16, 32 or 64
      bit_width          TYPE i,
      "! INTEGER
      is_signed          TYPE abap_bool,
      "! Other kinds: the member's encoded struct; empty means an empty struct
      value              TYPE xstring,
      "! DECIMAL, TIME, TIMESTAMP, INTEGER: fields not modelled here
      unknown            TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_logical_type.

  TYPES:
    "! SchemaElement
    BEGIN OF ty_schema_element,
      type                TYPE i,
      has_type            TYPE abap_bool,
      type_length         TYPE i,
      has_type_length     TYPE abap_bool,
      repetition_type     TYPE i,
      has_repetition_type TYPE abap_bool,
      name                TYPE string,
      num_children        TYPE i,
      has_num_children    TYPE abap_bool,
      converted_type      TYPE i,
      has_converted_type  TYPE abap_bool,
      scale               TYPE i,
      has_scale           TYPE abap_bool,
      precision           TYPE i,
      has_precision       TYPE abap_bool,
      field_id            TYPE i,
      has_field_id        TYPE abap_bool,
      logical_type        TYPE ty_logical_type,
      has_logical_type    TYPE abap_bool,
      unknown             TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_schema_element,
    ty_schema_elements TYPE STANDARD TABLE OF ty_schema_element WITH EMPTY KEY.

  TYPES:
    "! PageEncodingStats
    BEGIN OF ty_page_encoding_stats,
      page_type TYPE i,
      encoding  TYPE i,
      count     TYPE i,
      unknown   TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_page_encoding_stats,
    ty_page_encoding_stats_list TYPE STANDARD TABLE OF ty_page_encoding_stats WITH EMPTY KEY.

  TYPES:
    "! ColumnMetaData
    BEGIN OF ty_column_metadata,
      type                       TYPE i,
      encodings                  TYPE ty_ints,
      path_in_schema             TYPE string_table,
      codec                      TYPE i,
      num_values                 TYPE int8,
      total_uncompressed_size    TYPE int8,
      total_compressed_size      TYPE int8,
      key_value_metadata         TYPE ty_key_values,
      has_key_value_metadata     TYPE abap_bool,
      data_page_offset           TYPE int8,
      index_page_offset          TYPE int8,
      has_index_page_offset      TYPE abap_bool,
      dictionary_page_offset     TYPE int8,
      has_dictionary_page_offset TYPE abap_bool,
      statistics                 TYPE ty_statistics,
      has_statistics             TYPE abap_bool,
      encoding_stats             TYPE ty_page_encoding_stats_list,
      has_encoding_stats         TYPE abap_bool,
      bloom_filter_offset        TYPE int8,
      has_bloom_filter_offset    TYPE abap_bool,
      bloom_filter_length        TYPE i,
      has_bloom_filter_length    TYPE abap_bool,
      size_statistics            TYPE ty_size_statistics,
      has_size_statistics        TYPE abap_bool,
      unknown                    TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_column_metadata.

  TYPES:
    "! ColumnChunk
    BEGIN OF ty_column_chunk,
      file_path               TYPE string,
      has_file_path           TYPE abap_bool,
      file_offset             TYPE int8,
      meta_data               TYPE ty_column_metadata,
      has_meta_data           TYPE abap_bool,
      offset_index_offset     TYPE int8,
      has_offset_index_offset TYPE abap_bool,
      offset_index_length     TYPE i,
      has_offset_index_length TYPE abap_bool,
      column_index_offset     TYPE int8,
      has_column_index_offset TYPE abap_bool,
      column_index_length     TYPE i,
      has_column_index_length TYPE abap_bool,
      unknown                 TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_column_chunk,
    ty_column_chunks TYPE STANDARD TABLE OF ty_column_chunk WITH EMPTY KEY.

  TYPES:
    "! SortingColumn
    BEGIN OF ty_sorting_column,
      column_idx  TYPE i,
      descending  TYPE abap_bool,
      nulls_first TYPE abap_bool,
      unknown     TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_sorting_column,
    ty_sorting_columns TYPE STANDARD TABLE OF ty_sorting_column WITH EMPTY KEY.

  TYPES:
    "! RowGroup
    BEGIN OF ty_row_group,
      columns                   TYPE ty_column_chunks,
      total_byte_size           TYPE int8,
      num_rows                  TYPE int8,
      sorting_columns           TYPE ty_sorting_columns,
      has_sorting_columns       TYPE abap_bool,
      file_offset               TYPE int8,
      has_file_offset           TYPE abap_bool,
      total_compressed_size     TYPE int8,
      has_total_compressed_size TYPE abap_bool,
      ordinal                   TYPE i,
      has_ordinal               TYPE abap_bool,
      unknown                   TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_row_group,
    ty_row_groups TYPE STANDARD TABLE OF ty_row_group WITH EMPTY KEY.

  TYPES:
    "! FileMetaData, the footer of a Parquet file
    BEGIN OF ty_file_metadata,
      version                TYPE i,
      "! Depth-first list of all schema nodes; the first one is the root
      schema                 TYPE ty_schema_elements,
      num_rows               TYPE int8,
      row_groups             TYPE ty_row_groups,
      key_value_metadata     TYPE ty_key_values,
      has_key_value_metadata TYPE abap_bool,
      created_by             TYPE string,
      has_created_by         TYPE abap_bool,
      "! One per leaf column; member see c_column_order
      column_orders          TYPE zparq2a_if_thrift=>ty_unions,
      has_column_orders      TYPE abap_bool,
      unknown                TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_file_metadata.

  TYPES:
    "! DataPageHeader
    BEGIN OF ty_data_page_header,
      num_values                TYPE i,
      encoding                  TYPE i,
      definition_level_encoding TYPE i,
      repetition_level_encoding TYPE i,
      statistics                TYPE ty_statistics,
      has_statistics            TYPE abap_bool,
      unknown                   TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_data_page_header.

  TYPES:
    "! DictionaryPageHeader
    BEGIN OF ty_dictionary_page_header,
      num_values    TYPE i,
      encoding      TYPE i,
      is_sorted     TYPE abap_bool,
      has_is_sorted TYPE abap_bool,
      unknown       TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_dictionary_page_header.

  TYPES:
    "! DataPageHeaderV2
    BEGIN OF ty_data_page_header_v2,
      num_values             TYPE i,
      num_nulls              TYPE i,
      num_rows               TYPE i,
      encoding               TYPE i,
      "! definition_levels_byte_length
      def_levels_byte_length TYPE i,
      "! repetition_levels_byte_length
      rep_levels_byte_length TYPE i,
      "! Defaults to true when not set
      is_compressed          TYPE abap_bool,
      has_is_compressed      TYPE abap_bool,
      statistics             TYPE ty_statistics,
      has_statistics         TYPE abap_bool,
      unknown                TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_data_page_header_v2.

  TYPES:
    "! PageHeader; an index page header is kept in unknown
    BEGIN OF ty_page_header,
      type                       TYPE i,
      uncompressed_page_size     TYPE i,
      compressed_page_size       TYPE i,
      crc                        TYPE i,
      has_crc                    TYPE abap_bool,
      data_page_header           TYPE ty_data_page_header,
      has_data_page_header       TYPE abap_bool,
      dictionary_page_header     TYPE ty_dictionary_page_header,
      has_dictionary_page_header TYPE abap_bool,
      data_page_header_v2        TYPE ty_data_page_header_v2,
      has_data_page_header_v2    TYPE abap_bool,
      unknown                    TYPE zparq2a_if_thrift=>ty_fields,
    END OF ty_page_header.

ENDINTERFACE.
