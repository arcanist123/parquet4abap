"! <p class="shorttext synchronized">Parquet: schema from ABAP types</p>
"! Maps the line type of an internal table to a flat Parquet schema, with RTTI.
"! Each component becomes a column named like the component, in lower case:
"! <ul>
"! <li><em>i</em>: INT32; <em>int8</em>: INT64; <em>f</em>: DOUBLE</li>
"! <li><em>b</em>, <em>s</em>: INT32 with logical type INTEGER(8, unsigned) and INTEGER(16, signed)</li>
"! <li><em>p</em>: DECIMAL with 2 * length - 1 digits, as INT32, INT64 or FIXED_LEN_BYTE_ARRAY</li>
"! <li><em>c</em>, <em>n</em>, <em>string</em>: BYTE_ARRAY STRING; <em>abap_bool</em>: BOOLEAN</li>
"! <li><em>x</em>: FIXED_LEN_BYTE_ARRAY; <em>xstring</em>: BYTE_ARRAY</li>
"! <li><em>d</em>: INT32 DATE; <em>t</em>: INT32 TIME in milliseconds, not adjusted to UTC</li>
"! </ul>
"! A component typed as a data reference to one of these types is an optional
"! column, and an unbound reference is null. Other components are required.
CLASS zparq2a_cl_schema DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_column,
        "! Name of the ABAP component
        component TYPE string,
        "! The component is a data reference; unbound means null
        optional  TYPE abap_bool,
        "! Type kind of the value, one of CL_ABAP_TYPEDESCR=>TYPEKIND_*
        type_kind TYPE abap_typekind,
        "! The leaf node of the column
        element   TYPE zparq2a_if_format=>ty_schema_element,
      END OF ty_column,
      ty_columns TYPE STANDARD TABLE OF ty_column WITH EMPTY KEY.

    "! @raising zparq2a_cx_error | the line type is not a flat structure of supported types
    CLASS-METHODS from_table
      IMPORTING
        table         TYPE ANY TABLE
      RETURNING
        VALUE(result) TYPE ty_columns
      RAISING
        zparq2a_cx_error.

    "! Schema of the file footer: the root node and one leaf per column
    CLASS-METHODS to_elements
      IMPORTING
        columns       TYPE ty_columns
      RETURNING
        VALUE(result) TYPE zparq2a_if_format=>ty_schema_elements.

    "! Bytes FIXED_LEN_BYTE_ARRAY needs for a signed DECIMAL of PRECISION digits
    CLASS-METHODS decimal_length
      IMPORTING
        precision     TYPE i
      RETURNING
        VALUE(result) TYPE i.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES ty_element_type TYPE REF TO cl_abap_elemdescr.

    CLASS-METHODS map_component
      IMPORTING
        name          TYPE string
        type          TYPE REF TO cl_abap_datadescr
      RETURNING
        VALUE(result) TYPE ty_column
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS map_element
      IMPORTING
        type   TYPE ty_element_type
      CHANGING
        column TYPE ty_column
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS map_decimal
      IMPORTING
        type   TYPE ty_element_type
      CHANGING
        column TYPE ty_column
      RAISING
        zparq2a_cx_error.

    CLASS-METHODS set_type
      IMPORTING
        physical_type TYPE i
      CHANGING
        element       TYPE zparq2a_if_format=>ty_schema_element.

    CLASS-METHODS set_converted_type
      IMPORTING
        converted_type TYPE i
      CHANGING
        element        TYPE zparq2a_if_format=>ty_schema_element.

    CLASS-METHODS set_logical_type
      IMPORTING
        logical_type TYPE zparq2a_if_format=>ty_logical_type
      CHANGING
        element      TYPE zparq2a_if_format=>ty_schema_element.

ENDCLASS.


CLASS zparq2a_cl_schema IMPLEMENTATION.

  METHOD from_table.
    DATA line_type TYPE REF TO cl_abap_datadescr.
    DATA structure TYPE REF TO cl_abap_structdescr.
    DATA components TYPE abap_component_view_tab.

    DATA(table_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( table ) ).
    line_type = table_type->get_table_line_type( ).
    IF line_type->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `The table needs a structured line type`.
    ENDIF.
    structure = CAST #( line_type ).
    components = structure->get_included_view( ).
    LOOP AT components INTO DATA(component).
      APPEND map_component( name = component-name type = component-type ) TO result.
    ENDLOOP.
    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = `The line type has no components`.
    ENDIF.
  ENDMETHOD.

  METHOD map_component.
    DATA type_of_value TYPE REF TO cl_abap_typedescr.

    result-component = name.
    result-element-name = to_lower( name ).
    type_of_value = type.
    IF type_of_value->kind = cl_abap_typedescr=>kind_ref.
      type_of_value = CAST cl_abap_refdescr( type_of_value )->get_referenced_type( ).
      result-optional = abap_true.
    ENDIF.
    IF type_of_value->kind <> cl_abap_typedescr=>kind_elem.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Component { name }: only elementary types and data references to them are supported|.
    ENDIF.

    result-type_kind = type_of_value->type_kind.
    result-element-has_repetition_type = abap_true.
    result-element-repetition_type = COND #( WHEN result-optional = abap_true
                                             THEN zparq2a_if_format=>c_repetition-optional
                                             ELSE zparq2a_if_format=>c_repetition-required ).
    map_element( EXPORTING type = CAST #( type_of_value ) CHANGING column = result ).
  ENDMETHOD.

  METHOD map_element.
    CASE type->type_kind.
      WHEN cl_abap_typedescr=>typekind_int.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_int1.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
        set_converted_type( EXPORTING converted_type = zparq2a_if_format=>c_converted_type-uint_8
                            CHANGING element = column-element ).
        set_logical_type( EXPORTING logical_type = VALUE #( kind      = zparq2a_if_format=>c_logical_type-integer
                                                            bit_width = 8
                                                            is_signed = abap_false )
                          CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_int2.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
        set_converted_type( EXPORTING converted_type = zparq2a_if_format=>c_converted_type-int_16
                            CHANGING element = column-element ).
        set_logical_type( EXPORTING logical_type = VALUE #( kind      = zparq2a_if_format=>c_logical_type-integer
                                                            bit_width = 16
                                                            is_signed = abap_true )
                          CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_int8.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int64 CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_float.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-double CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_packed.
        map_decimal( EXPORTING type = type CHANGING column = column ).
      WHEN cl_abap_typedescr=>typekind_char OR cl_abap_typedescr=>typekind_num OR cl_abap_typedescr=>typekind_string.
        IF type->type_kind = cl_abap_typedescr=>typekind_char AND type->get_relative_name( ) = `ABAP_BOOL`.
          set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-boolean CHANGING element = column-element ).
        ELSE.
          set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-byte_array CHANGING element = column-element ).
          set_converted_type( EXPORTING converted_type = zparq2a_if_format=>c_converted_type-utf8
                              CHANGING element = column-element ).
          set_logical_type( EXPORTING logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-string )
                            CHANGING element = column-element ).
          " c, n and string are all written as text
          column-type_kind = cl_abap_typedescr=>typekind_string.
        ENDIF.
      WHEN cl_abap_typedescr=>typekind_hex.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array
                  CHANGING element = column-element ).
        column-element-has_type_length = abap_true.
        column-element-type_length = type->length.
      WHEN cl_abap_typedescr=>typekind_xstring.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-byte_array CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_date.
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
        set_converted_type( EXPORTING converted_type = zparq2a_if_format=>c_converted_type-date
                            CHANGING element = column-element ).
        set_logical_type( EXPORTING logical_type = VALUE #( kind = zparq2a_if_format=>c_logical_type-date )
                          CHANGING element = column-element ).
      WHEN cl_abap_typedescr=>typekind_time.
        " a converted type would claim the time is adjusted to UTC
        set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
        set_logical_type( EXPORTING logical_type = VALUE #(
                                      kind               = zparq2a_if_format=>c_logical_type-time
                                      is_adjusted_to_utc = abap_false
                                      unit               = VALUE #( member = zparq2a_if_format=>c_time_unit-millis ) )
                          CHANGING element = column-element ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Component { column-component }: ABAP type kind { type->type_kind } is not supported|.
    ENDCASE.
  ENDMETHOD.

  METHOD map_decimal.
    DATA(precision) = 2 * type->length - 1.
    DATA(scale) = type->decimals.

    IF precision <= 9.
      set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int32 CHANGING element = column-element ).
    ELSEIF precision <= 18.
      set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-int64 CHANGING element = column-element ).
    ELSE.
      set_type( EXPORTING physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array
                CHANGING element = column-element ).
      column-element-has_type_length = abap_true.
      column-element-type_length = decimal_length( precision ).
    ENDIF.
    set_converted_type( EXPORTING converted_type = zparq2a_if_format=>c_converted_type-decimal
                        CHANGING element = column-element ).
    column-element-has_scale = abap_true.
    column-element-scale = scale.
    column-element-has_precision = abap_true.
    column-element-precision = precision.
    set_logical_type( EXPORTING logical_type = VALUE #( kind      = zparq2a_if_format=>c_logical_type-decimal
                                                        scale     = scale
                                                        precision = precision )
                      CHANGING element = column-element ).
  ENDMETHOD.

  METHOD decimal_length.
    DATA largest TYPE f.
    DATA limit TYPE f VALUE 128.

    " n bytes hold -2^(8n-1) .. 2^(8n-1) - 1
    largest = CONV f( 10 ) ** precision.
    result = 1.
    WHILE limit < largest.
      result = result + 1.
      limit = limit * 256.
    ENDWHILE.
  ENDMETHOD.

  METHOD set_type.
    element-has_type = abap_true.
    element-type = physical_type.
  ENDMETHOD.

  METHOD set_converted_type.
    element-has_converted_type = abap_true.
    element-converted_type = converted_type.
  ENDMETHOD.

  METHOD set_logical_type.
    element-has_logical_type = abap_true.
    element-logical_type = logical_type.
  ENDMETHOD.

  METHOD to_elements.
    APPEND VALUE #( name             = `schema`
                    has_num_children = abap_true
                    num_children     = lines( columns ) ) TO result.
    LOOP AT columns INTO DATA(column).
      APPEND column-element TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
