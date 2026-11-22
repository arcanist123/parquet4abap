CLASS ltcl_thrift_reader DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS assert_error
      IMPORTING
        bytes TYPE xstring
        msg   TYPE string.

    "! Reads one struct, skipping every field
    METHODS read_struct
      IMPORTING
        bytes TYPE xstring
      RAISING
        zparq2a_cx_error.

    METHODS field_headers FOR TESTING RAISING zparq2a_cx_error.
    METHODS booleans FOR TESTING RAISING zparq2a_cx_error.
    METHODS integers FOR TESTING RAISING zparq2a_cx_error.
    METHODS binary_and_string FOR TESTING RAISING zparq2a_cx_error.
    METHODS list_headers FOR TESTING RAISING zparq2a_cx_error.
    METHODS unknown_fields FOR TESTING RAISING zparq2a_cx_error.
    METHODS type_mismatch FOR TESTING RAISING zparq2a_cx_error.
    METHODS unions FOR TESTING RAISING zparq2a_cx_error.
    METHODS start_offset FOR TESTING RAISING zparq2a_cx_error.
    METHODS required_fields FOR TESTING.
    METHODS malformed_input FOR TESTING.
    METHODS nesting_limit FOR TESTING.

ENDCLASS.


CLASS ltcl_thrift_reader IMPLEMENTATION.

  METHOD assert_error.
    TRY.
        read_struct( bytes ).
        cl_abap_unit_assert=>fail( |{ msg }: { bytes } accepted| ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD read_struct.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( bytes ).

    cut->read_struct_begin( `Test` ).
    WHILE cut->next_field( ).
      cut->read_unknown( ).
    ENDWHILE.
    cut->read_struct_end( ).
  ENDMETHOD.

  METHOD field_headers.
    " field 1 i32 = 150 (short form), field 100 i64 = -1 (long form),
    " field 101 i32 = 0 (short form after a long one), field 3 i32 (id going back)
    DATA(cut) = NEW zparq2a_cl_thrift_reader( CONV #( '15AC02' && '06C80101' && '1500' && '050602' && '00' ) ).

    cut->read_struct_begin( `Test` ).
    cl_abap_unit_assert=>assert_true( cut->next_field( ) ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i32( ) exp = 150 ).
    cl_abap_unit_assert=>assert_true( cut->next_field( ) ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 100 type = zparq2a_if_thrift=>c_type-i64 ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i64( ) exp = -1 ).
    cl_abap_unit_assert=>assert_true( cut->next_field( ) ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 101 type = zparq2a_if_thrift=>c_type-i32 ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i32( ) exp = 0 ).
    cl_abap_unit_assert=>assert_true( cut->next_field( ) ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 3 type = zparq2a_if_thrift=>c_type-i32 ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i32( ) exp = 1 ).
    cl_abap_unit_assert=>assert_false( cut->next_field( ) ).
    cut->read_struct_end( VALUE #( ( 1 ) ( 3 ) ( 100 ) ( 101 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_position( ) exp = 13 ).
  ENDMETHOD.

  METHOD booleans.
    " field 1 true, field 2 false, field 3 list<bool> [true, false, false]
    " with 0 as the second false, as older writers wrote it
    DATA(cut) = NEW zparq2a_cl_thrift_reader( CONV #( '1112' && '1931' && '010200' && '00' ) ).

    cut->read_struct_begin( `Test` ).
    cut->next_field( ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 1 type = zparq2a_if_thrift=>c_type-bool_true ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bool( ) exp = abap_true ).
    cut->next_field( ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 2 type = zparq2a_if_thrift=>c_type-bool_true ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bool( ) exp = abap_false ).
    cut->next_field( ).
    cl_abap_unit_assert=>assert_true( cut->field_is( id = 3 type = zparq2a_if_thrift=>c_type-list ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_list_size( zparq2a_if_thrift=>c_type-bool_true ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bool( ) exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bool( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_bool( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_false( cut->next_field( ) ).
    cut->read_struct_end( ).
  ENDMETHOD.

  METHOD integers.
    DATA(cut) = NEW zparq2a_cl_thrift_reader(
      CONV #( '80' && '7F' && 'FFFF03' && 'FEFF03' && 'FEFFFFFF0F' && 'FFFFFFFF0F' && 'FFFFFFFFFFFFFFFFFF01' ) ).

    cl_abap_unit_assert=>assert_equals( act = cut->read_i8( ) exp = -128 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i8( ) exp = 127 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i16( ) exp = -32768 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i16( ) exp = 32767 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i32( ) exp = 2147483647 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i32( ) exp = -2147483648 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i64( ) exp = zparq2a_cl_bytes=>min_int8 ).

    TRY.
        NEW zparq2a_cl_thrift_reader( '808004' )->read_i16( ).
        cl_abap_unit_assert=>fail( `32768 accepted as i16` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        NEW zparq2a_cl_thrift_reader( '8080808010' )->read_i32( ).
        cl_abap_unit_assert=>fail( `2^31 accepted as i32` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD binary_and_string.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( CONV #( '00' && '0300FF10' && '03616263' ) ).

    cl_abap_unit_assert=>assert_initial( cut->read_binary( ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_binary( ) exp = CONV xstring( '00FF10' ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_string( ) exp = `abc` ).

    TRY.
        NEW zparq2a_cl_thrift_reader( '050102' )->read_binary( ).
        cl_abap_unit_assert=>fail( `binary longer than the data accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD list_headers.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( '05E5' ).

    DATA(header) = cut->read_list_begin( ).
    cl_abap_unit_assert=>assert_equals( act = header-size exp = 0 ).
    header = cut->read_list_begin( ).
    cl_abap_unit_assert=>assert_equals( act = header-size exp = 14 ).
    cl_abap_unit_assert=>assert_equals( act = header-element_type exp = zparq2a_if_thrift=>c_type-i32 ).

    cut = NEW zparq2a_cl_thrift_reader( CONV #( 'F810' && '00000000000000000000000000000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_list_size( zparq2a_if_thrift=>c_type-binary ) exp = 16 ).

    TRY.
        NEW zparq2a_cl_thrift_reader( '15' )->read_list_size( zparq2a_if_thrift=>c_type-struct ).
        cl_abap_unit_assert=>fail( `list<i32> accepted as list<struct>` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        NEW zparq2a_cl_thrift_reader( 'F6FF01' )->read_list_begin( ).
        cl_abap_unit_assert=>fail( `list of 255 elements in 0 bytes accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unknown_fields.
    " every wire type once, then a known field 15
    DATA(data) = CONV xstring(
      '11' &&                                   " 1: bool true
      '13' && 'FF' &&                           " 2: byte
      '14' && '03' &&                           " 3: i16
      '17' && '000000000000F03F' &&             " 4: double 1.0
      '1D' && '00112233445566778899AABBCCDDEEFF' && " 5: uuid
      '1B' && '00' &&                           " 6: empty map
      '1B' && '0258' && '0201AA' && '0401BB' && " 7: map<i32,binary> {1: AA, 2: BB}
      '1A' && '25' && '0204' &&                 " 8: set<i32> {1, 2}
      '19' && '2C' && '150000' && '00' &&       " 9: list<struct> [{1: 0}, {}]
      '1C' && '1C1100' && '00' &&               " 10: struct {1: {1: true}}
      '55' && '1E' &&                           " 15: i32 15
      '00' ).
    DATA(cut) = NEW zparq2a_cl_thrift_reader( data ).
    DATA unknown TYPE zparq2a_if_thrift=>ty_fields.
    DATA value TYPE i.

    cut->read_struct_begin( `Test` ).
    WHILE cut->next_field( ).
      IF cut->field_is( id = 15 type = zparq2a_if_thrift=>c_type-i32 ).
        value = cut->read_i32( ).
      ELSE.
        APPEND cut->read_unknown( ) TO unknown.
      ENDIF.
    ENDWHILE.
    cut->read_struct_end( VALUE #( ( 15 ) ) ).

    cl_abap_unit_assert=>assert_equals( act = value exp = 15 ).
    cl_abap_unit_assert=>assert_equals( act = cut->get_position( ) exp = xstrlen( data ) ).
    cl_abap_unit_assert=>assert_equals(
      act = unknown
      exp = VALUE zparq2a_if_thrift=>ty_fields(
        ( id = 1 type = zparq2a_if_thrift=>c_type-bool_true )
        ( id = 2 type = zparq2a_if_thrift=>c_type-byte value = 'FF' )
        ( id = 3 type = zparq2a_if_thrift=>c_type-i16 value = '03' )
        ( id = 4 type = zparq2a_if_thrift=>c_type-double value = '000000000000F03F' )
        ( id = 5 type = zparq2a_if_thrift=>c_type-uuid value = '00112233445566778899AABBCCDDEEFF' )
        ( id = 6 type = zparq2a_if_thrift=>c_type-map value = '00' )
        ( id = 7 type = zparq2a_if_thrift=>c_type-map value = '02580201AA0401BB' )
        ( id = 8 type = zparq2a_if_thrift=>c_type-set value = '250204' )
        ( id = 9 type = zparq2a_if_thrift=>c_type-list value = '2C15000000' )
        ( id = 10 type = zparq2a_if_thrift=>c_type-struct value = '1C110000' ) ) ).
  ENDMETHOD.

  METHOD type_mismatch.
    " field 1 is expected as i32 but arrives as binary
    DATA(cut) = NEW zparq2a_cl_thrift_reader( CONV #( '18' && '0161' && '00' ) ).

    cut->read_struct_begin( `Test` ).
    cut->next_field( ).
    cl_abap_unit_assert=>assert_false( cut->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ) ).
    cl_abap_unit_assert=>assert_false( cut->field_is( id = 1 type = zparq2a_if_thrift=>c_type-bool_true ) ).
    DATA(field) = cut->read_unknown( ).
    cl_abap_unit_assert=>assert_equals( act = field-value exp = CONV xstring( '0161' ) ).
    cut->next_field( ).
    TRY.
        cut->read_struct_end( VALUE #( ( 1 ) ) ).
        cl_abap_unit_assert=>fail( `field of the wrong type counted as present` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unions.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( CONV #( '2C0000' && '1C15000000' && '00' ) ).

    DATA(union) = cut->read_union( `Test` ).
    cl_abap_unit_assert=>assert_equals( act = union-member exp = 2 ).
    cl_abap_unit_assert=>assert_initial( union-value ).
    union = cut->read_union( `Test` ).
    cl_abap_unit_assert=>assert_equals( act = union-member exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = union-value exp = CONV xstring( '150000' ) ).
    union = cut->read_union( `Test` ).
    cl_abap_unit_assert=>assert_equals( act = union-member exp = 0 ).

    TRY.
        NEW zparq2a_cl_thrift_reader( '1C002C0000' )->read_union( `Test` ).
        cl_abap_unit_assert=>fail( `union with two members accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
    TRY.
        NEW zparq2a_cl_thrift_reader( '150000' )->read_union( `Test` ).
        cl_abap_unit_assert=>fail( `union with an i32 member accepted` ).
      CATCH zparq2a_cx_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD start_offset.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( data = 'FFFF1502' offset = 2 ).

    cl_abap_unit_assert=>assert_equals( act = cut->get_position( ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = cut->read_i8( ) exp = 21 ).
  ENDMETHOD.

  METHOD required_fields.
    DATA(cut) = NEW zparq2a_cl_thrift_reader( '150200' ).

    TRY.
        cut->read_struct_begin( `Test` ).
        WHILE cut->next_field( ).
          cut->field_is( id = 1 type = zparq2a_if_thrift=>c_type-i32 ).
          cut->read_unknown( ).
        ENDWHILE.
        cut->read_struct_end( VALUE #( ( 1 ) ( 2 ) ) ).
        cl_abap_unit_assert=>fail( `missing field 2 accepted` ).
      CATCH zparq2a_cx_error INTO DATA(error).
        cl_abap_unit_assert=>assert_char_cp( act = error->get_text( ) exp = '*field 2 of Test*' ).
    ENDTRY.
  ENDMETHOD.

  METHOD malformed_input.
    assert_error( bytes = '15' msg = `missing value` ).
    assert_error( bytes = '1500' msg = `missing stop` ).
    assert_error( bytes = '1E00' msg = `wire type 14` ).
    assert_error( bytes = '050000' msg = `field id 0` ).
    assert_error( bytes = '05FFFF0300' msg = `field id -32768` ).
    assert_error( bytes = '1B01' msg = `map without key and value types` ).
    assert_error( bytes = '1B01E10000' msg = `map with key type 14` ).
    assert_error( bytes = '19100000' msg = `list of stop elements` ).
    assert_error( bytes = '1880' msg = `truncated binary length` ).
  ENDMETHOD.

  METHOD nesting_limit.
    DATA bytes TYPE xstring.
    DATA struct_field TYPE x LENGTH 1 VALUE '1C'.
    DATA stop TYPE x LENGTH 1 VALUE '00'.

    " max_depth + 1 nested structs, each in field 1 of the one before
    DO zparq2a_cl_thrift_reader=>max_depth TIMES.
      CONCATENATE bytes struct_field INTO bytes IN BYTE MODE.
    ENDDO.
    DO zparq2a_cl_thrift_reader=>max_depth + 1 TIMES.
      CONCATENATE bytes stop INTO bytes IN BYTE MODE.
    ENDDO.
    assert_error( bytes = bytes msg = `nesting too deep` ).

    DATA(at_limit) = bytes+1.
    TRY.
        read_struct( at_limit ).
      CATCH zparq2a_cx_error INTO DATA(error).
        cl_abap_unit_assert=>fail( |nesting at the limit rejected: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
