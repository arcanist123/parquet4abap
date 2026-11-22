CLASS ltcl_schema DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_base,
        key  TYPE i,
        note TYPE string,
      END OF ty_base,
      BEGIN OF ty_with_include,
        first TYPE i.
        INCLUDE TYPE ty_base.
    TYPES:
        last  TYPE i,
      END OF ty_with_include.

    METHODS flat_types FOR TESTING RAISING zparq2a_cx_error.
    METHODS decimals FOR TESTING RAISING zparq2a_cx_error.
    METHODS optional_columns FOR TESTING RAISING zparq2a_cx_error.
    METHODS includes_are_flattened FOR TESTING RAISING zparq2a_cx_error.
    METHODS root_element FOR TESTING RAISING zparq2a_cx_error.
    METHODS decimal_lengths FOR TESTING.
    METHODS unsupported_line_types FOR TESTING.

    METHODS assert_column
      IMPORTING
        columns        TYPE zparq2a_cl_schema=>ty_columns
        name           TYPE string
        physical_type  TYPE i
        converted_type TYPE i DEFAULT -1
        logical_type   TYPE i DEFAULT 0.

ENDCLASS.


CLASS ltcl_schema IMPLEMENTATION.

  METHOD assert_column.
    DATA(column) = VALUE #( columns[ element-name = name ] OPTIONAL ).

    cl_abap_unit_assert=>assert_equals( act = column-element-name exp = name msg = |{ name }: column missing| ).
    cl_abap_unit_assert=>assert_equals( act = column-element-type exp = physical_type msg = |{ name }: type| ).
    cl_abap_unit_assert=>assert_equals( act = column-element-has_converted_type
                                        exp = xsdbool( converted_type >= 0 )
                                        msg = |{ name }: has converted type| ).
    IF converted_type >= 0.
      cl_abap_unit_assert=>assert_equals( act = column-element-converted_type
                                          exp = converted_type
                                          msg = |{ name }: converted type| ).
    ENDIF.
    cl_abap_unit_assert=>assert_equals( act = column-element-logical_type-kind
                                        exp = logical_type
                                        msg = |{ name }: logical type| ).
    cl_abap_unit_assert=>assert_equals( act = column-element-has_logical_type
                                        exp = xsdbool( logical_type <> 0 )
                                        msg = |{ name }: has logical type| ).
  ENDMETHOD.

  METHOD flat_types.
    DATA(columns) = zparq2a_cl_schema=>from_table( zparq2a_cl_samples=>flat_rows( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( columns ) exp = 16 ).
    LOOP AT columns INTO DATA(column).
      cl_abap_unit_assert=>assert_equals( act = column-element-repetition_type
                                          exp = zparq2a_if_format=>c_repetition-required ).
      cl_abap_unit_assert=>assert_equals( act = column-element-name exp = to_lower( column-component ) ).
    ENDLOOP.

    assert_column( columns = columns name = `id` physical_type = zparq2a_if_format=>c_type-int32 ).
    assert_column( columns        = columns
                   name           = `tiny`
                   physical_type  = zparq2a_if_format=>c_type-int32
                   converted_type = zparq2a_if_format=>c_converted_type-uint_8
                   logical_type   = zparq2a_if_format=>c_logical_type-integer ).
    assert_column( columns        = columns
                   name           = `short`
                   physical_type  = zparq2a_if_format=>c_type-int32
                   converted_type = zparq2a_if_format=>c_converted_type-int_16
                   logical_type   = zparq2a_if_format=>c_logical_type-integer ).
    assert_column( columns = columns name = `big` physical_type = zparq2a_if_format=>c_type-int64 ).
    assert_column( columns = columns name = `ratio` physical_type = zparq2a_if_format=>c_type-double ).
    assert_column( columns = columns name = `flag` physical_type = zparq2a_if_format=>c_type-boolean ).
    assert_column( columns        = columns
                   name           = `code`
                   physical_type  = zparq2a_if_format=>c_type-byte_array
                   converted_type = zparq2a_if_format=>c_converted_type-utf8
                   logical_type   = zparq2a_if_format=>c_logical_type-string ).
    assert_column( columns        = columns
                   name           = `digits`
                   physical_type  = zparq2a_if_format=>c_type-byte_array
                   converted_type = zparq2a_if_format=>c_converted_type-utf8
                   logical_type   = zparq2a_if_format=>c_logical_type-string ).
    assert_column( columns        = columns
                   name           = `text`
                   physical_type  = zparq2a_if_format=>c_type-byte_array
                   converted_type = zparq2a_if_format=>c_converted_type-utf8
                   logical_type   = zparq2a_if_format=>c_logical_type-string ).
    assert_column( columns = columns name = `raw` physical_type = zparq2a_if_format=>c_type-byte_array ).
    assert_column( columns = columns name = `hash` physical_type = zparq2a_if_format=>c_type-fixed_len_byte_array ).
    cl_abap_unit_assert=>assert_equals( act = columns[ element-name = `hash` ]-element-type_length exp = 4 ).
    assert_column( columns        = columns
                   name           = `day`
                   physical_type  = zparq2a_if_format=>c_type-int32
                   converted_type = zparq2a_if_format=>c_converted_type-date
                   logical_type   = zparq2a_if_format=>c_logical_type-date ).
    assert_column( columns       = columns
                   name          = `time`
                   physical_type = zparq2a_if_format=>c_type-int32
                   logical_type  = zparq2a_if_format=>c_logical_type-time ).

    DATA(time) = columns[ element-name = `time` ]-element-logical_type.
    cl_abap_unit_assert=>assert_equals( act = time-unit-member exp = zparq2a_if_format=>c_time_unit-millis ).
    cl_abap_unit_assert=>assert_false( time-is_adjusted_to_utc ).
    DATA(tiny) = columns[ element-name = `tiny` ]-element-logical_type.
    cl_abap_unit_assert=>assert_equals( act = tiny-bit_width exp = 8 ).
    cl_abap_unit_assert=>assert_false( tiny-is_signed ).
  ENDMETHOD.

  METHOD decimals.
    DATA(columns) = zparq2a_cl_schema=>from_table( zparq2a_cl_samples=>flat_rows( ) ).

    " p LENGTH 4 DECIMALS 3: 7 digits, INT32
    assert_column( columns        = columns
                   name           = `price`
                   physical_type  = zparq2a_if_format=>c_type-int32
                   converted_type = zparq2a_if_format=>c_converted_type-decimal
                   logical_type   = zparq2a_if_format=>c_logical_type-decimal ).
    DATA(price) = columns[ element-name = `price` ]-element.
    cl_abap_unit_assert=>assert_equals( act = price-precision exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = price-scale exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = price-logical_type-precision exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = price-logical_type-scale exp = 3 ).

    " p LENGTH 8 DECIMALS 2: 15 digits, INT64
    DATA(amount) = columns[ element-name = `amount` ]-element.
    cl_abap_unit_assert=>assert_equals( act = amount-type exp = zparq2a_if_format=>c_type-int64 ).
    cl_abap_unit_assert=>assert_equals( act = amount-precision exp = 15 ).
    cl_abap_unit_assert=>assert_equals( act = amount-scale exp = 2 ).

    " p LENGTH 16 DECIMALS 4: 31 digits, 13 bytes
    DATA(total) = columns[ element-name = `total` ]-element.
    cl_abap_unit_assert=>assert_equals( act = total-type exp = zparq2a_if_format=>c_type-fixed_len_byte_array ).
    cl_abap_unit_assert=>assert_equals( act = total-type_length exp = 13 ).
    cl_abap_unit_assert=>assert_equals( act = total-precision exp = 31 ).
    cl_abap_unit_assert=>assert_equals( act = total-scale exp = 4 ).
  ENDMETHOD.

  METHOD optional_columns.
    DATA(columns) = zparq2a_cl_schema=>from_table( zparq2a_cl_samples=>optional_rows( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( columns ) exp = 7 ).
    cl_abap_unit_assert=>assert_false( columns[ 1 ]-optional ).
    cl_abap_unit_assert=>assert_equals( act = columns[ 1 ]-element-repetition_type
                                        exp = zparq2a_if_format=>c_repetition-required ).
    LOOP AT columns FROM 2 INTO DATA(column).
      cl_abap_unit_assert=>assert_true( act = column-optional msg = column-component ).
      cl_abap_unit_assert=>assert_equals( act = column-element-repetition_type
                                          exp = zparq2a_if_format=>c_repetition-optional
                                          msg = column-component ).
    ENDLOOP.
    assert_column( columns = columns name = `count` physical_type = zparq2a_if_format=>c_type-int32 ).
    assert_column( columns = columns name = `flag` physical_type = zparq2a_if_format=>c_type-boolean ).
    assert_column( columns        = columns
                   name           = `amount`
                   physical_type  = zparq2a_if_format=>c_type-int64
                   converted_type = zparq2a_if_format=>c_converted_type-decimal
                   logical_type   = zparq2a_if_format=>c_logical_type-decimal ).
  ENDMETHOD.

  METHOD includes_are_flattened.
    DATA rows TYPE STANDARD TABLE OF ty_with_include WITH EMPTY KEY.

    DATA(columns) = zparq2a_cl_schema=>from_table( rows ).

    cl_abap_unit_assert=>assert_equals(
      act = VALUE string_table( FOR column IN columns ( column-element-name ) )
      exp = VALUE string_table( ( `first` ) ( `key` ) ( `note` ) ( `last` ) ) ).
  ENDMETHOD.

  METHOD root_element.
    DATA(elements) = zparq2a_cl_schema=>to_elements(
                       zparq2a_cl_schema=>from_table( zparq2a_cl_samples=>optional_rows( ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( elements ) exp = 8 ).
    cl_abap_unit_assert=>assert_equals( act = elements[ 1 ]-name exp = `schema` ).
    cl_abap_unit_assert=>assert_equals( act = elements[ 1 ]-num_children exp = 7 ).
    cl_abap_unit_assert=>assert_false( elements[ 1 ]-has_type ).
    cl_abap_unit_assert=>assert_false( elements[ 1 ]-has_repetition_type ).
    cl_abap_unit_assert=>assert_equals( act = elements[ 2 ]-name exp = `id` ).
  ENDMETHOD.

  METHOD decimal_lengths.
    " smallest n with 10^precision <= 2^(8n - 1)
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 1 ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 2 ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 3 ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 9 ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 10 ) exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 18 ) exp = 8 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 31 ) exp = 13 ).
    cl_abap_unit_assert=>assert_equals( act = zparq2a_cl_schema=>decimal_length( 38 ) exp = 16 ).
  ENDMETHOD.

  METHOD unsupported_line_types.
    TYPES:
      BEGIN OF ty_nested,
        id   TYPE i,
        part TYPE ty_base,
      END OF ty_nested,
      BEGIN OF ty_generic_reference,
        id  TYPE i,
        any TYPE REF TO data,
      END OF ty_generic_reference,
      BEGIN OF ty_table_component,
        id    TYPE i,
        names TYPE string_table,
      END OF ty_table_component,
      BEGIN OF ty_decfloat,
        id    TYPE i,
        value TYPE decfloat34,
      END OF ty_decfloat.
    DATA numbers TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA nested TYPE STANDARD TABLE OF ty_nested WITH EMPTY KEY.
    DATA generic TYPE STANDARD TABLE OF ty_generic_reference WITH EMPTY KEY.
    DATA tables TYPE STANDARD TABLE OF ty_table_component WITH EMPTY KEY.
    DATA decfloats TYPE STANDARD TABLE OF ty_decfloat WITH EMPTY KEY.

    TRY.
        zparq2a_cl_schema=>from_table( numbers ).
        cl_abap_unit_assert=>fail( `A table of integers was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        zparq2a_cl_schema=>from_table( nested ).
        cl_abap_unit_assert=>fail( `A nested structure was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        zparq2a_cl_schema=>from_table( generic ).
        cl_abap_unit_assert=>fail( `REF TO data was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        zparq2a_cl_schema=>from_table( tables ).
        cl_abap_unit_assert=>fail( `A table component was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        zparq2a_cl_schema=>from_table( decfloats ).
        cl_abap_unit_assert=>fail( `DECFLOAT34 was accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
