CLASS ltcl_chunk_reader DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS required_column FOR TESTING RAISING zparq2a_cx_error.
    METHODS optional_column FOR TESTING RAISING zparq2a_cx_error.
    METHODS gzip_pages_v2 FOR TESTING RAISING zparq2a_cx_error.
    METHODS no_more_values FOR TESTING RAISING zparq2a_cx_error.
    METHODS chunk_outside_file FOR TESTING RAISING zparq2a_cx_error.
    METHODS wrong_compressor FOR TESTING RAISING zparq2a_cx_error.
    METHODS dictionary_page FOR TESTING RAISING zparq2a_cx_error.

    "! Reader of column COLUMN (from 1) in row group ROW_GROUP (from 1)
    METHODS chunk_reader
      IMPORTING
        file          TYPE xstring
        row_group     TYPE i DEFAULT 1
        column        TYPE i
        compressor    TYPE REF TO zparq2a_if_compressor OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO zparq2a_cl_chunk_reader
      RAISING
        zparq2a_cx_error.

    METHODS golden
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

ENDCLASS.


CLASS ltcl_chunk_reader IMPLEMENTATION.

  METHOD chunk_reader.
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    result = NEW #( file       = file
                    chunk      = metadata-row_groups[ row_group ]-columns[ column ]
                    element    = metadata-schema[ column + 1 ]
                    compressor = COND #( WHEN compressor IS BOUND THEN compressor
                                         ELSE NEW zparq2a_cl_comp_none( ) ) ).
  ENDMETHOD.

  METHOD golden.
    DATA(files) = zparq2a_cl_golden=>files( ).
    result = files[ name = name ]-data.
  ENDMETHOD.

  METHOD required_column.
    DATA id TYPE i.
    DATA ids TYPE string_table.

    DATA(reader) = chunk_reader( file = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) )
                                 column = 1 ).
    DO 4 TIMES.
      reader->read( IMPORTING value = id null = DATA(null) ).
      cl_abap_unit_assert=>assert_false( null ).
      APPEND |{ id }| TO ids.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = ids
                                        exp = VALUE string_table( ( `1` ) ( `2` )
                                                                  ( `-2147483648` ) ( `2147483647` ) ) ).
  ENDMETHOD.

  METHOD optional_column.
    DATA count TYPE i.
    DATA counts TYPE string_table.

    " COUNT is null in every third row
    DATA(reader) = chunk_reader( file = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>optional_rows( ) )
                                 column = 2 ).
    DO 6 TIMES.
      reader->read( IMPORTING value = count null = DATA(null) ).
      APPEND COND string( WHEN null = abap_true THEN `null` ELSE |{ count }| ) TO counts.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = counts
                                        exp = VALUE string_table( ( `100` ) ( `200` ) ( `null` )
                                                                  ( `400` ) ( `500` ) ( `null` ) ) ).
  ENDMETHOD.

  METHOD gzip_pages_v2.
    DATA text TYPE xstring.
    DATA names TYPE string_table.

    " pyarrow: data pages v2, one value per page, rows 1 to 3 in the first row group
    DATA(reader) = chunk_reader( file       = golden( `pa_v2_plain_pages` )
                                 column     = 6
                                 compressor = NEW zparq2a_cl_comp_gzip( ) ).
    DO 3 TIMES.
      reader->read( IMPORTING value = text null = DATA(null) ).
      APPEND COND string( WHEN null = abap_true THEN `null` ELSE zparq2a_cl_bytes=>utf8_decode( text ) ) TO names.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = names
                                        exp = VALUE string_table( ( `alpha` ) ( `beta` ) ( `null` ) ) ).

    reader = chunk_reader( file       = golden( `pa_v2_plain_pages` )
                           row_group  = 2
                           column     = 6
                           compressor = NEW zparq2a_cl_comp_gzip( ) ).
    reader->read( IMPORTING value = text null = null ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_bytes=>utf8_decode( text ) exp = `ä€` ).
  ENDMETHOD.

  METHOD no_more_values.
    DATA id TYPE i.

    DATA(reader) = chunk_reader( file = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) )
                                 column = 1 ).
    DO 4 TIMES.
      reader->read( IMPORTING value = id ).
    ENDDO.
    TRY.
        reader->read( IMPORTING value = id ).
        cl_abap_unit_assert=>fail( `A fifth value was read from a chunk of 4` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD chunk_outside_file.
    DATA(file) = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) ).
    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    DATA(chunk) = metadata-row_groups[ 1 ]-columns[ 1 ].

    chunk-meta_data-total_compressed_size = xstrlen( file ).
    TRY.
        NEW zparq2a_cl_chunk_reader( file       = file
                                     chunk      = chunk
                                     element    = metadata-schema[ 2 ]
                                     compressor = NEW zparq2a_cl_comp_none( ) ).
        cl_abap_unit_assert=>fail( `A chunk that ends after the file was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD wrong_compressor.
    TRY.
        chunk_reader( file       = NEW zparq2a_cl_writer( )->write( zparq2a_cl_samples=>flat_rows( ) )
                      column     = 1
                      compressor = NEW zparq2a_cl_comp_gzip( ) ).
        cl_abap_unit_assert=>fail( `GZIP was accepted for an uncompressed chunk` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD dictionary_page.
    DATA id TYPE i.

    " pyarrow's default: dictionary encoding
    DATA(reader) = chunk_reader( file = golden( `pa_index_crc_bloom` ) column = 1 ).
    TRY.
        reader->read( IMPORTING value = id ).
        cl_abap_unit_assert=>fail( `A dictionary page was read as values` ).
      CATCH zparq2a_cx_error INTO DATA(error).
        cl_abap_unit_assert=>assert_char_cp( act = error->get_text( ) exp = '*dictionary*' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
