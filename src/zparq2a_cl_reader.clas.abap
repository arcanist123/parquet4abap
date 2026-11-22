"! <p class="shorttext synchronized">Parquet: reader</p>
"! Reads a Parquet file, in memory, into an internal table. The line type says
"! which columns to read: each component is filled from the column with the
"! same name, ignoring case. Columns the line type does not name are skipped.
"! <p>A component typed as a data reference reads an optional column: a null
"! leaves the reference unbound. A null in any other component is an error.
"! Values are converted as follows:</p>
"! <ul>
"! <li><em>i</em>, <em>int8</em>, <em>b</em>, <em>s</em>: INT32, INT64, also unsigned; the value must fit</li>
"! <li><em>f</em>: INT32, INT64, FLOAT, DOUBLE</li>
"! <li><em>p</em>: DECIMAL in any physical type, or INT32 and INT64; ABAP rounds to the decimals of the component</li>
"! <li><em>abap_bool</em>: BOOLEAN</li>
"! <li><em>c</em>, <em>n</em>, <em>string</em>: UTF-8 text (STRING, ENUM, JSON); the text must fit</li>
"! <li><em>x</em>: binary values of exactly its length; <em>xstring</em>: any binary value</li>
"! <li><em>d</em>: DATE; <em>t</em>: TIME in whole seconds</li>
"! </ul>
"! <p>Integer components take INT32 and INT64 columns with other logical types, such as
"! TIMESTAMP, as the stored number. Files must be flat and PLAIN-encoded, see
"! ZPARQ2A_CL_CHUNK_READER. Pages may be uncompressed or GZIP; SET_COMPRESSOR adds codecs.</p>
CLASS zparq2a_cl_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Uses COMPRESSOR for every column chunk with its codec
    METHODS set_compressor
      IMPORTING
        compressor TYPE REF TO zparq2a_if_compressor.

    "! @parameter file | the whole Parquet file
    "! @parameter data | the rows of the file, in the order of the file
    "! @raising zparq2a_cx_error | the file is not valid or not supported, or does not fit the line type
    METHODS read
      IMPORTING
        file TYPE xstring
      EXPORTING
        data TYPE ANY TABLE
      RAISING
        zparq2a_cx_error.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_compressor,
        codec      TYPE i,
        compressor TYPE REF TO zparq2a_if_compressor,
      END OF ty_compressor,
      ty_compressors TYPE HASHED TABLE OF ty_compressor WITH UNIQUE KEY codec.

    "! Unscaled value of a DECIMAL: up to 31 digits
    TYPES ty_unscaled TYPE p LENGTH 16 DECIMALS 0.

    CONSTANTS:
      "! How a value of the file becomes the value of a component
      BEGIN OF c_conversion,
        "! as ABAP assigns it
        move    TYPE i VALUE 1,
        decimal TYPE i VALUE 2,
        date    TYPE i VALUE 3,
        time    TYPE i VALUE 4,
        text    TYPE i VALUE 5,
        "! x: binary of the same length
        bytes   TYPE i VALUE 6,
      END OF c_conversion.

    TYPES:
      "! A component and the column it is read from
      BEGIN OF ty_target,
        component  TYPE string,
        optional   TYPE abap_bool,
        "! Type of the value: the component or, if optional, the referenced type
        type       TYPE REF TO cl_abap_elemdescr,
        "! Index of the column among the leaves of the schema, from 1
        leaf       TYPE i,
        element    TYPE zparq2a_if_format=>ty_schema_element,
        conversion TYPE i,
        "! 10^scale for DECIMAL; units per second for TIME
        factor     TYPE ty_unscaled,
        "! INT32 and INT64 values are unsigned
        unsigned   TYPE abap_bool,
      END OF ty_target,
      ty_targets TYPE STANDARD TABLE OF ty_target WITH EMPTY KEY.

    TYPES:
      "! A value as the column stores it, see ZPARQ2A_CL_DEC_PLAIN
      BEGIN OF ty_value,
        boolean TYPE abap_bool,
        int32   TYPE i,
        int64   TYPE int8,
        real    TYPE f,
        bytes   TYPE xstring,
      END OF ty_value.

    TYPES ty_chunk_readers TYPE STANDARD TABLE OF REF TO zparq2a_cl_chunk_reader WITH EMPTY KEY.

    DATA compressors TYPE ty_compressors.

    "! The columns of a flat schema, without the root
    CLASS-METHODS leaves
      IMPORTING
        metadata      TYPE zparq2a_if_format=>ty_file_metadata
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_schema_elements
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS map_targets
      IMPORTING
        line_type     TYPE REF TO cl_abap_structdescr
        leaves        TYPE zparq2a_if_format=>ty_schema_elements
      RETURNING
        VALUE(result) TYPE ty_targets
      RAISING
        zparq2a_cx_error.

    "! Picks the conversion for the column, if the component can take its values
    CLASS-METHODS map_conversion
      CHANGING
        target TYPE ty_target
      RAISING
        zparq2a_cx_error.

    METHODS get_compressor
      IMPORTING
        codec         TYPE i
      RETURNING
        VALUE(result) TYPE REF TO zparq2a_if_compressor
      RAISING
        zparq2a_cx_error.

    METHODS read_row_group
      IMPORTING
        file      TYPE xstring
        row_group TYPE zparq2a_if_format=>ty_row_group
        targets   TYPE ty_targets
        line_type TYPE REF TO cl_abap_structdescr
      CHANGING
        data      TYPE ANY TABLE
      RAISING
        zparq2a_cx_error.

    "! Reads the next value of the target's column into the component of ROW
    CLASS-METHODS read_value
      IMPORTING
        target TYPE ty_target
        reader TYPE REF TO zparq2a_cl_chunk_reader
        row    TYPE i
      CHANGING
        line   TYPE any
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS convert
      IMPORTING
        target TYPE ty_target
        value  TYPE ty_value
      CHANGING
        result TYPE simple
      RAISING
        zparq2a_cx_error
        cx_sy_conversion_error
        cx_sy_arithmetic_error.

    "! Unscaled DECIMAL value, big-endian two's complement
    CLASS-METHODS decimal_from_bytes
      IMPORTING
        bytes         TYPE xstring
      RETURNING
        VALUE(result) TYPE ty_unscaled
      RAISING
        cx_sy_arithmetic_error.

ENDCLASS.


CLASS zparq2a_cl_reader IMPLEMENTATION.

  METHOD set_compressor.
    DATA(codec) = compressor->get_codec( ).

    DELETE TABLE compressors WITH TABLE KEY codec = codec.
    INSERT VALUE #( codec = codec compressor = compressor ) INTO TABLE compressors.
  ENDMETHOD.

  METHOD get_compressor.
    READ TABLE compressors INTO DATA(entry) WITH TABLE KEY codec = codec.
    IF sy-subrc = 0.
      result = entry-compressor.
      RETURN.
    ENDIF.
    CASE codec.
      WHEN zparq2a_if_compressor=>codecs-uncompressed.
        result = NEW zparq2a_cl_comp_none( ).
      WHEN zparq2a_if_compressor=>codecs-gzip.
        result = NEW zparq2a_cl_comp_gzip( ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Codec { codec } is not supported; SET_COMPRESSOR can add it|.
    ENDCASE.
    INSERT VALUE #( codec = codec compressor = result ) INTO TABLE compressors.
  ENDMETHOD.

  METHOD read.
    DATA line_type TYPE REF TO cl_abap_datadescr.

    CLEAR data.
    DATA(table_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( data ) ).
    line_type = table_type->get_table_line_type( ).
    IF line_type->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `The table needs a structured line type`.
    ENDIF.

    DATA(metadata) = zparq2a_cl_metadata=>read_footer( file ).
    DATA(leaves) = leaves( metadata ).
    DATA(targets) = map_targets( line_type = CAST #( line_type ) leaves = leaves ).
    LOOP AT metadata-row_groups INTO DATA(row_group).
      IF lines( row_group-columns ) <> lines( leaves ).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Row group { sy-tabix } has { lines( row_group-columns ) } columns, the schema { lines( leaves ) }|.
      ENDIF.
      read_row_group(
        EXPORTING
          file      = file
          row_group = row_group
          targets   = targets
          line_type = CAST #( line_type )
        CHANGING
          data      = data ).
    ENDLOOP.
  ENDMETHOD.

  METHOD leaves.
    IF metadata-schema IS INITIAL.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `The file has no schema`.
    ENDIF.
    DATA(root) = metadata-schema[ 1 ].
    IF root-num_children <> lines( metadata-schema ) - 1.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `Nested schemas are not supported yet`.
    ENDIF.
    LOOP AT metadata-schema FROM 2 INTO DATA(element).
      IF element-num_children > 0 OR element-has_type = abap_false.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = `Nested schemas are not supported yet`.
      ENDIF.
      IF element-repetition_type = zparq2a_if_format=>c_repetition-repeated.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Column { element-name } is repeated, which is not supported yet|.
      ENDIF.
      APPEND element TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD map_targets.
    DATA target TYPE ty_target.
    DATA value_type TYPE REF TO cl_abap_typedescr.

    DATA(components) = line_type->get_included_view( ).
    IF components IS INITIAL.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `The line type has no components`.
    ENDIF.
    LOOP AT components INTO DATA(component).
      CLEAR target.
      target-component = component-name.
      value_type = component-type.
      IF value_type->kind = cl_abap_typedescr=>kind_ref.
        value_type = CAST cl_abap_refdescr( value_type )->get_referenced_type( ).
        target-optional = abap_true.
      ENDIF.
      IF value_type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Component { component-name }: only elementary types and data references to them are supported|.
      ENDIF.
      target-type = CAST #( value_type ).

      LOOP AT leaves INTO DATA(leaf).
        IF to_upper( leaf-name ) = component-name.
          target-leaf = sy-tabix.
          target-element = leaf.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF target-leaf = 0.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |The file has no column { to_lower( component-name ) }|.
      ENDIF.
      map_conversion( CHANGING target = target ).
      APPEND target TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD map_conversion.
    DATA scale TYPE i.

    DATA(element) = target-element.
    DATA(physical_type) = element-type.
    DATA(logical_kind) = COND i( WHEN element-has_logical_type = abap_true THEN element-logical_type-kind ).
    DATA(converted) = COND i( WHEN element-has_converted_type = abap_true THEN element-converted_type ELSE -1 ).
    DATA(integer) = xsdbool( physical_type = zparq2a_if_format=>c_type-int32
                             OR physical_type = zparq2a_if_format=>c_type-int64 ).
    DATA(binary) = xsdbool( physical_type = zparq2a_if_format=>c_type-byte_array
                            OR physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array ).
    DATA(decimal) = xsdbool( logical_kind = zparq2a_if_format=>c_logical_type-decimal
                             OR converted = zparq2a_if_format=>c_converted_type-decimal ).
    DATA(text) = xsdbool( logical_kind = zparq2a_if_format=>c_logical_type-string
                          OR logical_kind = zparq2a_if_format=>c_logical_type-enum
                          OR logical_kind = zparq2a_if_format=>c_logical_type-json
                          OR converted = zparq2a_if_format=>c_converted_type-utf8
                          OR converted = zparq2a_if_format=>c_converted_type-enum
                          OR converted = zparq2a_if_format=>c_converted_type-json ).
    DATA(date) = xsdbool( logical_kind = zparq2a_if_format=>c_logical_type-date
                          OR converted = zparq2a_if_format=>c_converted_type-date ).
    DATA(time_unit) = COND i(
      WHEN logical_kind = zparq2a_if_format=>c_logical_type-time THEN element-logical_type-unit-member
      WHEN converted = zparq2a_if_format=>c_converted_type-time_millis THEN zparq2a_if_format=>c_time_unit-millis
      WHEN converted = zparq2a_if_format=>c_converted_type-time_micros THEN zparq2a_if_format=>c_time_unit-micros ).
    target-unsigned = xsdbool(
      ( logical_kind = zparq2a_if_format=>c_logical_type-integer AND element-logical_type-is_signed = abap_false )
      OR converted = zparq2a_if_format=>c_converted_type-uint_8
      OR converted = zparq2a_if_format=>c_converted_type-uint_16
      OR converted = zparq2a_if_format=>c_converted_type-uint_32
      OR converted = zparq2a_if_format=>c_converted_type-uint_64 ).

    CASE target-type->type_kind.
      WHEN cl_abap_typedescr=>typekind_int OR cl_abap_typedescr=>typekind_int1
          OR cl_abap_typedescr=>typekind_int2 OR cl_abap_typedescr=>typekind_int8.
        IF integer = abap_true AND decimal = abap_false.
          target-conversion = c_conversion-move.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_float.
        IF ( integer = abap_true AND decimal = abap_false )
            OR physical_type = zparq2a_if_format=>c_type-float
            OR physical_type = zparq2a_if_format=>c_type-double.
          target-conversion = c_conversion-move.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_packed.
        IF decimal = abap_true AND ( integer = abap_true OR binary = abap_true ).
          target-conversion = c_conversion-decimal.
          scale = COND #( WHEN element-has_logical_type = abap_true THEN element-logical_type-scale
                          ELSE element-scale ).
        ELSEIF integer = abap_true.
          target-conversion = c_conversion-decimal.
        ENDIF.
        target-factor = 1.
        DO scale TIMES.
          target-factor = target-factor * 10.
        ENDDO.
      WHEN cl_abap_typedescr=>typekind_date.
        IF physical_type = zparq2a_if_format=>c_type-int32 AND date = abap_true.
          target-conversion = c_conversion-date.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_time.
        IF ( physical_type = zparq2a_if_format=>c_type-int32 AND time_unit = zparq2a_if_format=>c_time_unit-millis )
            OR ( physical_type = zparq2a_if_format=>c_type-int64
                 AND ( time_unit = zparq2a_if_format=>c_time_unit-micros
                       OR time_unit = zparq2a_if_format=>c_time_unit-nanos ) ).
          target-conversion = c_conversion-time.
          target-factor = SWITCH #( time_unit
                                    WHEN zparq2a_if_format=>c_time_unit-millis THEN 1000
                                    WHEN zparq2a_if_format=>c_time_unit-micros THEN 1000000
                                    ELSE 1000000000 ).
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_char.
        IF target-type->get_relative_name( ) = `ABAP_BOOL`.
          IF physical_type = zparq2a_if_format=>c_type-boolean.
            target-conversion = c_conversion-move.
          ENDIF.
        ELSEIF binary = abap_true AND text = abap_true.
          target-conversion = c_conversion-text.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_num OR cl_abap_typedescr=>typekind_string.
        IF binary = abap_true AND text = abap_true.
          target-conversion = c_conversion-text.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_hex.
        IF binary = abap_true.
          target-conversion = c_conversion-bytes.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_xstring.
        IF binary = abap_true.
          target-conversion = c_conversion-move.
        ENDIF.
    ENDCASE.

    IF target-conversion = 0.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Column { element-name } (physical type { physical_type }, logical type { logical_kind }) | &&
                 |cannot be read into component { target-component } (ABAP type kind { target-type->type_kind })|.
    ENDIF.
  ENDMETHOD.

  METHOD read_row_group.
    DATA readers TYPE ty_chunk_readers.
    DATA line TYPE REF TO data.
    FIELD-SYMBOLS <line> TYPE any.

    LOOP AT targets INTO DATA(target).
      DATA(chunk) = row_group-columns[ target-leaf ].
      IF chunk-meta_data-num_values <> row_group-num_rows.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Column { target-element-name } has { chunk-meta_data-num_values } values | &&
                   |in a row group of { row_group-num_rows } rows|.
      ENDIF.
      APPEND NEW zparq2a_cl_chunk_reader( file       = file
                                          chunk      = chunk
                                          element    = target-element
                                          compressor = get_compressor( chunk-meta_data-codec ) ) TO readers.
    ENDLOOP.

    CREATE DATA line TYPE HANDLE line_type.
    ASSIGN line->* TO <line>.
    DO row_group-num_rows TIMES.
      DATA(row) = sy-index.
      CLEAR <line>.
      LOOP AT targets INTO target.
        read_value( EXPORTING target = target
                              reader = readers[ sy-tabix ]
                              row    = row
                    CHANGING  line   = <line> ).
      ENDLOOP.
      INSERT <line> INTO TABLE data.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Row { lines( data ) + 1 } has the same key as an earlier row|.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD read_value.
    DATA value TYPE ty_value.
    DATA null TYPE abap_bool.
    FIELD-SYMBOLS <component> TYPE any.
    DATA reference TYPE REF TO data.
    FIELD-SYMBOLS <result> TYPE simple.

    CASE target-element-type.
      WHEN zparq2a_if_format=>c_type-boolean.
        reader->read( IMPORTING value = value-boolean null = null ).
      WHEN zparq2a_if_format=>c_type-int32.
        reader->read( IMPORTING value = value-int32 null = null ).
      WHEN zparq2a_if_format=>c_type-int64.
        reader->read( IMPORTING value = value-int64 null = null ).
      WHEN zparq2a_if_format=>c_type-float OR zparq2a_if_format=>c_type-double.
        reader->read( IMPORTING value = value-real null = null ).
      WHEN OTHERS.
        reader->read( IMPORTING value = value-bytes null = null ).
    ENDCASE.

    ASSIGN COMPONENT target-component OF STRUCTURE line TO <component>.
    IF target-optional = abap_true.
      IF null = abap_true.
        RETURN.
      ENDIF.
      " a new data object for every row; the component is a reference to its type
      CREATE DATA reference TYPE HANDLE target-type.
      <component> ?= reference.
      ASSIGN reference->* TO <result>.
    ELSEIF null = abap_true.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Column { target-element-name } has a null in row { row }; | &&
                 |component { target-component } needs to be a data reference to take it|.
    ELSE.
      ASSIGN <component> TO <result>.
    ENDIF.

    TRY.
        convert( EXPORTING target = target
                           value  = value
                 CHANGING  result = <result> ).
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error INTO DATA(error).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text     = |Column { target-element-name }, row { row }: the value does not fit | &&
                       |component { target-component }|
            previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD convert.
    CONSTANTS midnight TYPE t VALUE '000000'.
    CONSTANTS two_pow_32 TYPE int8 VALUE 4294967296.
    CONSTANTS seconds_per_day TYPE int8 VALUE 86400.
    DATA number TYPE int8.
    DATA unscaled TYPE ty_unscaled.
    DATA time TYPE t.
    DATA text TYPE string.

    " INT32 and INT64 as one number
    number = COND #( WHEN target-element-type = zparq2a_if_format=>c_type-int32 THEN value-int32
                     ELSE value-int64 ).

    CASE target-conversion.
      WHEN c_conversion-move.
        CASE target-element-type.
          WHEN zparq2a_if_format=>c_type-boolean.
            result = value-boolean.
          WHEN zparq2a_if_format=>c_type-int32 OR zparq2a_if_format=>c_type-int64.
            IF target-unsigned = abap_true AND number < 0.
              IF target-element-type = zparq2a_if_format=>c_type-int64.
                RAISE EXCEPTION TYPE zparq2a_cx_error
                  EXPORTING
                    text = |Column { target-element-name }: an unsigned 64-bit value above 2^63 does not fit|.
              ENDIF.
              number = number + two_pow_32.
            ENDIF.
            result = number.
          WHEN zparq2a_if_format=>c_type-float OR zparq2a_if_format=>c_type-double.
            result = value-real.
          WHEN OTHERS.
            result = value-bytes.
        ENDCASE.
      WHEN c_conversion-decimal.
        IF target-element-type = zparq2a_if_format=>c_type-int32
            OR target-element-type = zparq2a_if_format=>c_type-int64.
          unscaled = number.
        ELSE.
          unscaled = decimal_from_bytes( value-bytes ).
        ENDIF.
        result = unscaled / target-factor.
      WHEN c_conversion-date.
        result = zparq2a_cl_schema=>date_from_days( number ).
      WHEN c_conversion-time.
        IF number < 0 OR number MOD target-factor <> 0 OR number DIV target-factor >= seconds_per_day.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |Column { target-element-name }: time { number } is not a whole second of a day|.
        ENDIF.
        time = midnight + number DIV target-factor.
        result = time.
      WHEN c_conversion-text.
        text = zparq2a_cl_bytes=>utf8_decode( value-bytes ).
        CASE target-type->type_kind.
          WHEN cl_abap_typedescr=>typekind_char.
            " trailing blanks are not part of a c value
            IF numofchar( text ) > target-type->output_length.
              RAISE EXCEPTION TYPE zparq2a_cx_error
                EXPORTING
                  text = |Column { target-element-name }: text of { strlen( text ) } characters | &&
                         |does not fit component { target-component }|.
            ENDIF.
          WHEN cl_abap_typedescr=>typekind_num.
            IF strlen( text ) > target-type->output_length OR text CN '0123456789'.
              RAISE EXCEPTION TYPE zparq2a_cx_error
                EXPORTING
                  text = |Column { target-element-name }: "{ text }" does not fit component { target-component }|.
            ENDIF.
        ENDCASE.
        result = text.
      WHEN c_conversion-bytes.
        IF xstrlen( value-bytes ) <> target-type->length.
          RAISE EXCEPTION TYPE zparq2a_cx_error
            EXPORTING
              text = |Column { target-element-name }: { xstrlen( value-bytes ) } bytes | &&
                     |do not fit component { target-component } of { target-type->length } bytes|.
        ENDIF.
        result = value-bytes.
    ENDCASE.
  ENDMETHOD.

  METHOD decimal_from_bytes.
    CONSTANTS all_bits TYPE x LENGTH 1 VALUE 'FF'.
    DATA byte TYPE x LENGTH 1.
    DATA byte_value TYPE i.
    DATA offset TYPE i.

    IF bytes IS INITIAL.
      RETURN.
    ENDIF.
    " a negative value is the bitwise complement of abs( value ) - 1
    byte = bytes(1).
    byte_value = byte.
    DATA(negative) = xsdbool( byte_value >= 128 ).
    DO xstrlen( bytes ) TIMES.
      byte = bytes+offset(1).
      IF negative = abap_true.
        byte = byte BIT-XOR all_bits.
      ENDIF.
      byte_value = byte.
      result = result * 256 + byte_value.
      offset = offset + 1.
    ENDDO.
    IF negative = abap_true.
      result = - result - 1.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
