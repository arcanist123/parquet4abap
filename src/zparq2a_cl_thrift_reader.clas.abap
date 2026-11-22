"! <p class="shorttext synchronized">Parquet: Thrift Compact Protocol reader</p>
"! Reads Thrift Compact Protocol values from an <em>xstring</em>. To read a
"! struct, call read_struct_begin, then next_field until it returns false.
"! For each field, test field_is for the fields you know and read their
"! value; keep any other field with read_unknown. read_struct_end checks
"! the required fields. A field whose wire type differs from the expected
"! one does not match field_is and is kept as unknown. Malformed input
"! raises ZPARQ2A_CX_ERROR.
CLASS zparq2a_cl_thrift_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Deepest nesting of structs and containers that is accepted
    CONSTANTS max_depth TYPE i VALUE 64.

    "! @parameter data | encoded data
    "! @parameter offset | offset of the first value
    METHODS constructor
      IMPORTING
        data   TYPE xstring
        offset TYPE i DEFAULT 0
      RAISING
        zparq2a_cx_error.

    "! @parameter name | struct name for error messages
    METHODS read_struct_begin
      IMPORTING
        name TYPE string
      RAISING
        zparq2a_cx_error.

    "! Reads the next field header of the current struct
    "! @parameter result | abap_false at the end of the struct
    METHODS next_field
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        zparq2a_cx_error.

    "! Does the current field have this id and wire type?
    "! A match counts the field as present for read_struct_end.
    "! @parameter type | wire type; bool_true matches either boolean type
    METHODS field_is
      IMPORTING
        id            TYPE i
        type          TYPE i
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Reads the value of the current field as raw bytes
    METHODS read_unknown
      RETURNING
        VALUE(result) TYPE zparq2a_if_thrift=>ty_field
      RAISING
        zparq2a_cx_error.

    "! @parameter required | ids of required fields; one that was not
    "! matched by field_is raises
    METHODS read_struct_end
      IMPORTING
        required TYPE zparq2a_if_thrift=>ty_ids OPTIONAL
      RAISING
        zparq2a_cx_error.

    "! A boolean field value, or a boolean list element
    METHODS read_bool
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        zparq2a_cx_error.

    "! @parameter result | -128..127
    METHODS read_i8
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_i16
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_i32
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_i64
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    METHODS read_binary
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! A binary value holding UTF-8 text
    METHODS read_string
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zparq2a_cx_error.

    "! Header of a list or set
    METHODS read_list_begin
      RETURNING
        VALUE(result) TYPE zparq2a_if_thrift=>ty_list_header
      RAISING
        zparq2a_cx_error.

    "! Header of a list whose elements must have the given wire type
    "! @parameter element_type | bool_true for a list of booleans
    "! @parameter result | number of elements
    METHODS read_list_size
      IMPORTING
        element_type  TYPE i
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    "! A union whose members are structs, kept as member id and raw struct
    METHODS read_union
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE zparq2a_if_thrift=>ty_union
      RAISING
        zparq2a_cx_error.

    "! Reads a value of the given wire type as raw bytes
    METHODS read_raw
      IMPORTING
        type          TYPE i
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zparq2a_cx_error.

    "! Offset of the next byte to read
    METHODS get_position
      RETURNING
        VALUE(result) TYPE i.

  PROTECTED SECTION.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_frame,
        name    TYPE string,
        last_id TYPE i,
        seen    TYPE zparq2a_if_thrift=>ty_ids,
      END OF ty_frame,
      ty_frames TYPE STANDARD TABLE OF ty_frame WITH EMPTY KEY.

    DATA bytes TYPE xstring.
    DATA reader TYPE REF TO zparq2a_cl_byte_reader.
    DATA frames TYPE ty_frames.
    DATA field_id TYPE i.
    DATA field_type TYPE i.
    "! The current field is a boolean whose value is still to be read
    DATA bool_pending TYPE abap_bool.
    DATA depth TYPE i.

    METHODS skip
      IMPORTING
        type TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS skip_struct
      RAISING
        zparq2a_cx_error.

    METHODS enter
      RAISING
        zparq2a_cx_error.

    METHODS leave.

    METHODS read_size
      RETURNING
        VALUE(result) TYPE i
      RAISING
        zparq2a_cx_error.

    METHODS read_zigzag
      IMPORTING
        min           TYPE int8
        max           TYPE int8
      RETURNING
        VALUE(result) TYPE int8
      RAISING
        zparq2a_cx_error.

    METHODS check_element_type
      IMPORTING
        type TYPE i
      RAISING
        zparq2a_cx_error.

ENDCLASS.


CLASS zparq2a_cl_thrift_reader IMPLEMENTATION.

  METHOD constructor.
    bytes = data.
    reader = NEW #( data ).
    reader->skip( offset ).
  ENDMETHOD.

  METHOD read_struct_begin.
    enter( ).
    APPEND VALUE #( name = name ) TO frames.
  ENDMETHOD.

  METHOD next_field.
    DATA(frame) = REF #( frames[ lines( frames ) ] ).
    DATA(start) = reader->get_position( ).
    DATA(header) = reader->read_byte( ).

    field_type = header MOD 16.
    bool_pending = abap_false.
    IF field_type = zparq2a_if_thrift=>c_type-stop.
      field_id = 0.
      RETURN.
    ENDIF.
    check_element_type( field_type ).

    DATA(delta) = header DIV 16.
    IF delta = 0.
      field_id = read_i16( ).
    ELSE.
      field_id = frame->last_id + delta.
    ENDIF.
    IF field_id <= 0 OR field_id > 32767.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Field id { field_id } in { frame->name } at offset { start } is out of range|.
    ENDIF.
    frame->last_id = field_id.
    IF field_type = zparq2a_if_thrift=>c_type-bool_true OR field_type = zparq2a_if_thrift=>c_type-bool_false.
      bool_pending = abap_true.
    ENDIF.
    result = abap_true.
  ENDMETHOD.

  METHOD field_is.
    IF id <> field_id.
      RETURN.
    ENDIF.
    IF type = zparq2a_if_thrift=>c_type-bool_true OR type = zparq2a_if_thrift=>c_type-bool_false.
      result = bool_pending.
    ELSE.
      result = xsdbool( type = field_type ).
    ENDIF.
    IF result = abap_true.
      DATA(frame) = REF #( frames[ lines( frames ) ] ).
      APPEND id TO frame->seen.
    ENDIF.
  ENDMETHOD.

  METHOD read_unknown.
    result-id = field_id.
    result-type = field_type.
    IF bool_pending = abap_true.
      bool_pending = abap_false.
    ELSE.
      result-value = read_raw( field_type ).
    ENDIF.
  ENDMETHOD.

  METHOD read_struct_end.
    DATA(frame) = frames[ lines( frames ) ].

    LOOP AT required INTO DATA(id).
      IF NOT line_exists( frame-seen[ table_line = id ] ).
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Required field { id } of { frame-name } is missing|.
      ENDIF.
    ENDLOOP.
    DELETE frames INDEX lines( frames ).
    leave( ).
  ENDMETHOD.

  METHOD read_bool.
    IF bool_pending = abap_true.
      bool_pending = abap_false.
      result = xsdbool( field_type = zparq2a_if_thrift=>c_type-bool_true ).
    ELSE.
      " list element: 1 is true; writers use 2 or 0 for false
      result = xsdbool( reader->read_byte( ) = zparq2a_if_thrift=>c_type-bool_true ).
    ENDIF.
  ENDMETHOD.

  METHOD read_i8.
    result = reader->read_byte( ).
    IF result > 127.
      result = result - 256.
    ENDIF.
  ENDMETHOD.

  METHOD read_i16.
    result = read_zigzag( min = -32768 max = 32767 ).
  ENDMETHOD.

  METHOD read_i32.
    result = read_zigzag( min = -2147483648 max = 2147483647 ).
  ENDMETHOD.

  METHOD read_i64.
    result = reader->read_zigzag_varint( ).
  ENDMETHOD.

  METHOD read_binary.
    result = reader->read_bytes( read_size( ) ).
  ENDMETHOD.

  METHOD read_string.
    result = zparq2a_cl_bytes=>utf8_decode( read_binary( ) ).
  ENDMETHOD.

  METHOD read_list_begin.
    DATA(start) = reader->get_position( ).
    DATA(header) = reader->read_byte( ).

    result-element_type = header MOD 16.
    result-size = header DIV 16.
    IF result-size = 15.
      result-size = read_size( ).
    ENDIF.
    IF result-element_type = zparq2a_if_thrift=>c_type-bool_false.
      " some writers mark boolean lists with the false type
      result-element_type = zparq2a_if_thrift=>c_type-bool_true.
    ELSEIF result-element_type = zparq2a_if_thrift=>c_type-stop.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Invalid element type in list header at offset { start }|.
    ENDIF.
    check_element_type( result-element_type ).
  ENDMETHOD.

  METHOD read_list_size.
    DATA(start) = reader->get_position( ).
    DATA(header) = read_list_begin( ).

    IF header-element_type <> element_type.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |List at offset { start } has elements of type { header-element_type }, expected { element_type }|.
    ENDIF.
    result = header-size.
  ENDMETHOD.

  METHOD read_union.
    read_struct_begin( name ).
    WHILE next_field( ).
      IF result-member <> 0.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Union { name } has more than one member set|.
      ELSEIF field_type <> zparq2a_if_thrift=>c_type-struct.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Member { field_id } of union { name } is not a struct|.
      ENDIF.
      result-member = field_id.
      result-value = read_raw( zparq2a_if_thrift=>c_type-struct ).
      IF result-value = zparq2a_if_thrift=>empty_struct.
        CLEAR result-value.
      ENDIF.
    ENDWHILE.
    read_struct_end( ).
  ENDMETHOD.

  METHOD read_raw.
    DATA(start) = reader->get_position( ).

    skip( type ).
    DATA(length) = reader->get_position( ) - start.
    IF length > 0.
      result = bytes+start(length).
    ENDIF.
  ENDMETHOD.

  METHOD get_position.
    result = reader->get_position( ).
  ENDMETHOD.

  METHOD skip.
    CASE type.
      WHEN zparq2a_if_thrift=>c_type-bool_true OR zparq2a_if_thrift=>c_type-bool_false
          OR zparq2a_if_thrift=>c_type-byte.
        " a boolean outside a field header takes one byte
        reader->skip( 1 ).
      WHEN zparq2a_if_thrift=>c_type-i16 OR zparq2a_if_thrift=>c_type-i32 OR zparq2a_if_thrift=>c_type-i64.
        reader->read_varint( ).
      WHEN zparq2a_if_thrift=>c_type-double.
        reader->skip( 8 ).
      WHEN zparq2a_if_thrift=>c_type-uuid.
        reader->skip( 16 ).
      WHEN zparq2a_if_thrift=>c_type-binary.
        reader->skip( read_size( ) ).
      WHEN zparq2a_if_thrift=>c_type-list OR zparq2a_if_thrift=>c_type-set.
        DATA(list) = read_list_begin( ).
        enter( ).
        DO list-size TIMES.
          skip( list-element_type ).
        ENDDO.
        leave( ).
      WHEN zparq2a_if_thrift=>c_type-map.
        DATA(size) = read_size( ).
        IF size > 0.
          DATA(types) = reader->read_byte( ).
          check_element_type( types DIV 16 ).
          check_element_type( types MOD 16 ).
          enter( ).
          DO size TIMES.
            skip( types DIV 16 ).
            skip( types MOD 16 ).
          ENDDO.
          leave( ).
        ENDIF.
      WHEN zparq2a_if_thrift=>c_type-struct.
        skip_struct( ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zparq2a_cx_error
          EXPORTING
            text = |Unknown wire type { type } before offset { reader->get_position( ) }|.
    ENDCASE.
  ENDMETHOD.

  METHOD skip_struct.
    read_struct_begin( `struct` ).
    WHILE next_field( ).
      IF bool_pending = abap_true.
        bool_pending = abap_false.
      ELSE.
        skip( field_type ).
      ENDIF.
    ENDWHILE.
    read_struct_end( ).
  ENDMETHOD.

  METHOD enter.
    depth = depth + 1.
    IF depth > max_depth.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Nesting deeper than { max_depth } levels at offset { reader->get_position( ) }|.
    ENDIF.
  ENDMETHOD.

  METHOD leave.
    depth = depth - 1.
  ENDMETHOD.

  METHOD read_size.
    DATA(start) = reader->get_position( ).
    DATA(value) = reader->read_varint( ).

    IF value < 0 OR value > reader->get_remaining( ).
      " every element takes at least one byte
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Size at offset { start } exceeds the remaining data|.
    ENDIF.
    result = value.
  ENDMETHOD.

  METHOD read_zigzag.
    DATA(start) = reader->get_position( ).

    result = reader->read_zigzag_varint( ).
    IF result < min OR result > max.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Value { result } at offset { start } is outside { min }..{ max }|.
    ENDIF.
  ENDMETHOD.

  METHOD check_element_type.
    IF type < zparq2a_if_thrift=>c_type-bool_true OR type > zparq2a_if_thrift=>c_type-uuid.
      RAISE EXCEPTION TYPE zparq2a_cx_error
        EXPORTING
          text = |Unknown wire type { type } before offset { reader->get_position( ) }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
